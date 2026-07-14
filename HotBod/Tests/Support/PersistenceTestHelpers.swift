import Foundation
@testable import HotBod

enum PersistenceTestHelpers {
  static func makeIsolatedPersistenceDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("hotbod-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  static func withIsolatedPersistence<T>(
    _ body: () async throws -> T
  ) async throws -> T {
    let url = try makeIsolatedPersistenceDirectory()
    PersistenceHelper.configureForTesting(baseURL: url)
    defer {
      PersistenceHelper.resetTestingConfiguration()
      try? FileManager.default.removeItem(at: url)
    }
    return try await body()
  }

  @MainActor
  static func withIsolatedPersistenceOnMainActor<T>(
    _ body: @MainActor () async throws -> T
  ) async throws -> T {
    let url = try makeIsolatedPersistenceDirectory()
    PersistenceHelper.configureForTesting(baseURL: url)
    defer {
      PersistenceHelper.resetTestingConfiguration()
      try? FileManager.default.removeItem(at: url)
    }
    return try await body()
  }
}
