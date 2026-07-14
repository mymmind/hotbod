import XCTest
@testable import HotBod

// MARK: - URL stub

final class StubURLProtocol: URLProtocol {
  nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

  override static func canInit(with request: URLRequest) -> Bool { true }

  override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let handler = Self.requestHandler else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }
    do {
      let (response, data) = try handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}

// MARK: - Mock AI

final class MockAIWorkoutServiceTests: XCTestCase {
  let service = MockAIWorkoutService()

  func testClassifyExplainIntent() async {
    let intent = await service.classifyIntent("Can you explain today's workout?")
    XCTAssertEqual(intent, .explainWorkout)
  }

  func testClassifyModifyIntentFromShorter() async {
    let intent = await service.classifyIntent("Make this workout shorter")
    XCTAssertEqual(intent, .modifyWorkout)
  }

  func testClassifyModifyIntentFromShoulder() async {
    let intent = await service.classifyIntent("Shoulder discomfort - adjust exercises")
    XCTAssertEqual(intent, .modifyWorkout)
  }

  func testClassifyGenerateIntent() async {
    let intent = await service.classifyIntent("Generate a new workout")
    XCTAssertEqual(intent, .generateWorkout)
  }

  func testClassifyProteinIntent() async {
    let intent = await service.classifyIntent("How much protein today?")
    XCTAssertEqual(intent, .proteinHelp)
  }

  func testClassifyPlateauIntent() async {
    let intent = await service.classifyIntent("Bench is going down — plateau?")
    XCTAssertEqual(intent, .analyzePlateau)
  }

  func testClassifyMotivationIntent() async {
    let intent = await service.classifyIntent("Review my week")
    XCTAssertEqual(intent, .motivation)
  }

  func testClassifyGeneralFallback() async {
    let intent = await service.classifyIntent("Hello coach")
    XCTAssertEqual(intent, .generalTrainingQuestion)
  }

  func testRespondExplainUsesWorkoutRationale() async throws {
    let workout = makeCoachStubWorkout(rationale: "Push day for chest and shoulders.")
    let context = makeCoachStubContext(currentWorkout: workout)
    let result = try await service.respond(to: "Why this workout?", context: context)
    XCTAssertEqual(result.message.intent, .explainWorkout)
    XCTAssertTrue(result.message.content.contains("Push day"))
    XCTAssertNil(result.proposedWorkout)
  }

  func testRespondProteinMentionsRemainingGap() async throws {
    let context = makeCoachStubContext(proteinToday: 80, proteinGoal: 160)
    let result = try await service.respond(to: "protein help", context: context)
    XCTAssertEqual(result.message.intent, .proteinHelp)
    XCTAssertTrue(result.message.content.contains("80"))
    XCTAssertTrue(result.message.content.contains("remaining"))
  }

  func testRespondModifyProposesWorkoutWhenPossible() async throws {
    let workout = makeCoachStubWorkout(rationale: "Push day for chest and shoulders.")
    var expanded = workout
    expanded.estimatedDurationMinutes = 60
    expanded.exercises = [
      PlannedExercise(
        exerciseId: "bench_press",
        orderIndex: 0,
        targetSets: [
          PlannedSet(targetRepsMin: 8, targetRepsMax: 10),
          PlannedSet(targetRepsMin: 8, targetRepsMax: 10),
          PlannedSet(targetRepsMin: 8, targetRepsMax: 10)
        ]
      ),
      PlannedExercise(
        exerciseId: "bench_press",
        orderIndex: 1,
        targetSets: [PlannedSet(targetRepsMin: 10, targetRepsMax: 12)]
      )
    ]
    let context = makeCoachStubContext(currentWorkout: expanded)
    let result = try await service.respond(to: "Make it 30 minutes", context: context)
    XCTAssertEqual(result.message.intent, .modifyWorkout)
    XCTAssertNotNil(result.proposedWorkout)
  }

  func testRespondModifyWithoutWorkoutDoesNotPropose() async throws {
    let context = makeCoachStubContext()
    let result = try await service.respond(to: "Make it 30 minutes", context: context)
    XCTAssertEqual(result.message.intent, .modifyWorkout)
    XCTAssertNil(result.proposedWorkout)
  }
}

// MARK: - Mock food search

final class MockFoodSearchServiceTests: XCTestCase {
  let service = MockFoodSearchService()

  func testSearchEmptyQueryReturnsEmpty() async throws {
    let results = try await service.searchFoods(query: "")
    XCTAssertTrue(results.isEmpty)
  }

  func testSearchChickenReturnsMatch() async throws {
    let results = try await service.searchFoods(query: "chicken")
    XCTAssertFalse(results.isEmpty)
    XCTAssertTrue(results.contains { $0.name.contains("Chicken") })
  }

  func testSearchYogurtReturnsMatch() async throws {
    let results = try await service.searchFoods(query: "yogurt")
    XCTAssertTrue(results.contains { $0.id == "greek_yogurt" })
  }

  func testSearchShortQueryReturnsBroadResults() async throws {
    let results = try await service.searchFoods(query: "pr")
    XCTAssertFalse(results.isEmpty)
  }

  func testGetFoodDetailsFormatsName() async throws {
    let details = try await service.getFoodDetails(id: "chicken_breast")
    XCTAssertEqual(details.id, "chicken_breast")
    XCTAssertEqual(details.proteinGrams, 25)
    XCTAssertFalse(details.name.isEmpty)
  }
}

// MARK: - USDA + URLProtocol

final class USDAFoodSearchServiceStubTests: XCTestCase {
  private var priorAPIKey: String?

  override func setUp() {
    super.setUp()
    priorAPIKey = ProcessInfo.processInfo.environment["USDA_API_KEY"]
    setenv("USDA_API_KEY", "test-stub-key", 1)
    StubURLProtocol.requestHandler = nil
    URLProtocol.registerClass(StubURLProtocol.self)
  }

  override func tearDown() {
    URLProtocol.unregisterClass(StubURLProtocol.self)
    StubURLProtocol.requestHandler = nil
    if let priorAPIKey {
      setenv("USDA_API_KEY", priorAPIKey, 1)
    } else {
      unsetenv("USDA_API_KEY")
    }
    super.tearDown()
  }

  func testSearchParsesUSDAJSON() async throws {
    StubURLProtocol.requestHandler = { request in
      XCTAssertTrue(request.url?.absoluteString.contains("foods/search") == true)
      let body = """
      {"foods":[{"fdcId":123,"description":"Chicken Breast","brandOwner":null,"foodNutrients":[{"nutrientId":1003,"value":31.0}]}]}
      """
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, Data(body.utf8))
    }

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    let session = URLSession(configuration: config)
    let service = USDAFoodSearchService(session: session)

    let results = try await service.searchFoods(query: "chicken")
    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results.first?.id, "fdc_123")
    XCTAssertEqual(results.first?.name, "Chicken Breast")
    XCTAssertEqual(results.first?.proteinPer100g, 31)
  }

  func testSearchRejectsSingleCharacterQuery() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    let service = USDAFoodSearchService(session: URLSession(configuration: config))
    let results = try await service.searchFoods(query: "a")
    XCTAssertTrue(results.isEmpty)
  }

  func testSearchThrowsWhenNotConfigured() async {
    unsetenv("USDA_API_KEY")
    FoodAPIConfig.testOverrideConfigured = false
    defer {
      FoodAPIConfig.testOverrideConfigured = nil
      setenv("USDA_API_KEY", "test-stub-key", 1)
    }
    let service = USDAFoodSearchService()
    do {
      _ = try await service.searchFoods(query: "chicken")
      XCTFail("Expected notConfigured")
    } catch let error as FoodSearchError {
      if case .notConfigured = error {
        // expected
      } else {
        XCTFail("Expected notConfigured, got \(error)")
      }
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }

  func testGetFoodDetailsParsesUSDAJSON() async throws {
    StubURLProtocol.requestHandler = { request in
      XCTAssertTrue(request.url?.absoluteString.contains("/food/456") == true)
      let body = """
      {"fdcId":456,"description":"Greek Yogurt","servingSize":{"value":170,"unit":"g"},\
      "foodNutrients":[{"nutrientId":1003,"value":10.0},{"nutrientId":1008,"value":100.0}]}
      """
      let response = HTTPURLResponse(
        url: request.url!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
      )!
      return (response, Data(body.utf8))
    }

    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    let service = USDAFoodSearchService(session: URLSession(configuration: config))

    let details = try await service.getFoodDetails(id: "fdc_456")
    XCTAssertEqual(details.name, "Greek Yogurt")
    XCTAssertEqual(details.proteinGrams, 10)
    XCTAssertEqual(details.calories, 100)
  }
}

// MARK: - Fixtures

private func makeCoachStubWorkout(rationale: String = "Balanced session.") -> GeneratedWorkout {
  GeneratedWorkout(
    id: UUID(),
    title: "Upper Push",
    estimatedDurationMinutes: 45,
    focus: [.chest],
    exercises: [
      PlannedExercise(
        exerciseId: "bench_press",
        orderIndex: 0,
        targetSets: [PlannedSet(targetRepsMin: 8, targetRepsMax: 10)]
      )
    ],
    rationale: rationale,
    safetyNotes: [],
    generatedBy: .rulesEngine,
    createdAt: Date()
  )
}

private func makeCoachStubContext(
  currentWorkout: GeneratedWorkout? = nil,
  proteinToday: Double = 0,
  proteinGoal: Double = 160
) -> CoachContext {
  CoachContext(
    userProfile: UserProfileSummary(
      goal: .buildMuscle,
      experienceLevel: .intermediate,
      proteinGoalGrams: proteinGoal
    ),
    currentWorkout: currentWorkout,
    recentWorkouts: [],
    exerciseStats: [],
    proteinSummary: ProteinSummary(todayGrams: proteinToday, goalGrams: proteinGoal, streakDays: 0),
    bodyProgressSummary: BodyProgressSummary(photoCount: 0, latestPhotoDate: nil, averageLightingScore: nil),
    recovery: [:],
    limitations: [],
    allowedExerciseIds: ["bench_press"],
    availableEquipment: [.barbell],
    targetDurationMinutes: 45
  )
}
