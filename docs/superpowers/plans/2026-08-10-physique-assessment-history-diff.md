# Physique Assessment History & Diff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist a rolling last-12 physique assessment history, compute a structured + Vision “Since last assessment” diff locally, and surface history + read-only past snapshots in the Physique tab — without changing training bias rules beyond “newest wins.”

**Architecture:** Upgrade `PhysiqueAssessmentRepository` from single-active JSON to a history document (`physique_assessments.json`) with legacy migration. Add a pure `PhysiqueAssessmentDiffEngine` that compares two assessments (+ optional front ratios). Wire AppEnvironment history load/save; render Since-last on the current report and a Physique-owned history NavigationLink stack. Progress photo UI stays untouched.

**Tech Stack:** Swift 6, SwiftUI, XCTest, XcodeGen (`xcodegen generate` after new HotBod/ files), `HotBod.xctestplan` PR configuration.

**Spec:** `docs/superpowers/specs/2026-08-10-physique-assessment-history-diff-design.md`

## Global Constraints

- iOS 17+.
- Local-first only — no cloud history sync in this slice.
- Active assessment for training bias = newest history entry (`assessments.first`).
- Diff must not rewrite priorities / training bias.
- Prefer: “appeared,” “priority shifted,” “visual trend.”
- Avoid: medical claims, exact body-fat %, genetic destiny, lookalike claims.
- Cap history at 12; migrate legacy `physique_assessment.json`.
- After new Swift files under `HotBod/`, run `xcodegen generate`.
- Simulator: use `id=EB7BE0BD-179B-4A37-9202-69D87FC47B75` if `iPhone 16 Pro` is ambiguous.
- Regression tests use `testRegression_` prefix where applicable.
- Do not alter unrelated uncommitted local changes.

## File Structure

| File | Responsibility |
|------|----------------|
| `HotBod/Domain/Models/PhysiqueAssessmentHistoryDocument.swift` | Codable `{ assessments: [...] }` wrapper |
| `HotBod/Domain/Models/PhysiqueAssessmentDiff.swift` | Diff value type |
| `HotBod/Domain/Physique/PhysiqueAssessmentDiffEngine.swift` | Pure structured + Vision trend comparison |
| `HotBod/Data/Repositories/RepositoryProtocols.swift` | Extend `PhysiqueAssessmentRepository` |
| `HotBod/Data/Local/LocalPhysiqueAssessmentRepository.swift` | History persist, prune, migrate |
| `HotBod/Tests/Support/InMemoryRepositories.swift` | In-memory history |
| `HotBod/App/AppEnvironment.swift` | `physiqueAssessmentHistory` state |
| `HotBod/App/AppEnvironment+Physique.swift` | Load history; helper for since-last diff |
| `HotBod/Features/Physique/PhysiqueView.swift` | Since-last section + history entry |
| `HotBod/Features/Physique/PhysiqueAssessmentHistoryView.swift` | List + read-only detail |
| `HotBod/Features/Physique/PhysiqueAssessmentReportContent.swift` | Shared report body (current vs past) |
| `HotBod/App/UITestConfiguration.swift` | `-SeedPhysiqueHistory` seed |
| `HotBod/Tests/Support/FixtureBuilders.swift` | Assessment factory overrides |
| `HotBod/Tests/UnitTests/RepositoryDomainTests.swift` | History / migration tests |
| `HotBod/Tests/UnitTests/PhysiqueAssessmentDiffTests.swift` | Diff unit tests |
| `HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift` | Bias uses newest |
| `HotBod/Tests/UITests/PhysiqueUITests.swift` | Since-last + history smoke |

---

### Task 1: History repository + migration + InMemory

**Files:**
- Create: `HotBod/Domain/Models/PhysiqueAssessmentHistoryDocument.swift`
- Modify: `HotBod/Data/Repositories/RepositoryProtocols.swift`
- Modify: `HotBod/Data/Local/LocalPhysiqueAssessmentRepository.swift`
- Modify: `HotBod/Tests/Support/InMemoryRepositories.swift`
- Modify: `HotBod/Tests/UnitTests/RepositoryDomainTests.swift`
- Modify: `HotBod/Tests/Support/FixtureBuilders.swift` (optional overrides for `id`/`createdAt` already exist — add muscle/physique overrides only if needed later)

**Interfaces:**
- Consumes: existing `PhysiqueAssessment`, `PersistenceHelper`
- Produces:
  ```swift
  struct PhysiqueAssessmentHistoryDocument: Codable, Hashable {
      var assessments: [PhysiqueAssessment] // newest-first
  }

  protocol PhysiqueAssessmentRepository: Sendable {
      func fetchActive() async throws -> PhysiqueAssessment?
      func fetchHistory() async throws -> [PhysiqueAssessment]
      func fetch(id: UUID) async throws -> PhysiqueAssessment?
      func saveActive(_ assessment: PhysiqueAssessment) async throws
      func clearActive() async throws
      func clearAll() async throws
  }

  // LocalPhysiqueAssessmentRepository
  static let maxHistoryCount = 12
  init(
      historyKey: String = "physique_assessments.json",
      legacyKey: String = "physique_assessment.json"
  )
  ```

**Semantics:**
- `fetchActive()` → `fetchHistory().first`
- `saveActive`: if same `id` exists, remove it; insert at front; prune to 12; write history doc; remove legacy key if present
- `fetch(id:)` → first match in history
- `clearActive()` / `clearAll()` → remove history + legacy keys (both clear everything in v1)
- Migration: on first read, if history missing/empty and legacy file decodes to `PhysiqueAssessment`, wrap as one-item history, save history, remove legacy

- [ ] **Step 1: Write failing tests**

Append to `LocalPhysiqueAssessmentRepositoryTests` in `RepositoryDomainTests.swift`:

```swift
func testSaveActivePrependsAndFetchHistoryNewestFirst() async throws {
    try await PersistenceTestHelpers.withIsolatedPersistence {
        let repo = LocalPhysiqueAssessmentRepository(
            historyKey: "physique_history_\(UUID().uuidString).json",
            legacyKey: "physique_legacy_\(UUID().uuidString).json"
        )
        let older = FixtureBuilders.makePhysiqueAssessment(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let newer = FixtureBuilders.makePhysiqueAssessment(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 2_000)
        )
        try await repo.saveActive(older)
        try await repo.saveActive(newer)
        let history = try await repo.fetchHistory()
        XCTAssertEqual(history.map(\.id), [newer.id, older.id])
        XCTAssertEqual(try await repo.fetchActive()?.id, newer.id)
    }
}

func testSaveActivePrunesToTwelve() async throws {
    try await PersistenceTestHelpers.withIsolatedPersistence {
        let repo = LocalPhysiqueAssessmentRepository(
            historyKey: "physique_history_\(UUID().uuidString).json",
            legacyKey: "physique_legacy_\(UUID().uuidString).json"
        )
        for i in 0..<13 {
            try await repo.saveActive(
                FixtureBuilders.makePhysiqueAssessment(
                    id: UUID(),
                    createdAt: Date(timeIntervalSince1970: TimeInterval(i))
                )
            )
        }
        let history = try await repo.fetchHistory()
        XCTAssertEqual(history.count, 12)
    }
}

func testSaveActiveReplacesExistingIdAndMovesToFront() async throws {
    try await PersistenceTestHelpers.withIsolatedPersistence {
        let repo = LocalPhysiqueAssessmentRepository(
            historyKey: "physique_history_\(UUID().uuidString).json",
            legacyKey: "physique_legacy_\(UUID().uuidString).json"
        )
        let id = UUID()
        var first = FixtureBuilders.makePhysiqueAssessment(id: id, createdAt: Date(timeIntervalSince1970: 1))
        first.whyTodaySummary = "first"
        try await repo.saveActive(first)
        try await repo.saveActive(
            FixtureBuilders.makePhysiqueAssessment(
                id: UUID(),
                createdAt: Date(timeIntervalSince1970: 2)
            )
        )
        var updated = first
        updated.whyTodaySummary = "updated"
        updated.createdAt = Date(timeIntervalSince1970: 3)
        try await repo.saveActive(updated)
        let history = try await repo.fetchHistory()
        XCTAssertEqual(history.first?.id, id)
        XCTAssertEqual(history.first?.whyTodaySummary, "updated")
        XCTAssertEqual(history.filter { $0.id == id }.count, 1)
    }
}

func testMigratesLegacySingleActiveFile() async throws {
    try await PersistenceTestHelpers.withIsolatedPersistence {
        let historyKey = "physique_history_\(UUID().uuidString).json"
        let legacyKey = "physique_legacy_\(UUID().uuidString).json"
        let assessment = FixtureBuilders.makePhysiqueAssessment()
        PersistenceHelper.save(assessment, to: legacyKey)
        let repo = LocalPhysiqueAssessmentRepository(historyKey: historyKey, legacyKey: legacyKey)
        let history = try await repo.fetchHistory()
        XCTAssertEqual(history.map(\.id), [assessment.id])
        XCTAssertNil(PersistenceHelper.load(PhysiqueAssessment.self, from: legacyKey))
        XCTAssertNotNil(PersistenceHelper.load(PhysiqueAssessmentHistoryDocument.self, from: historyKey))
    }
}

func testInMemoryPhysiqueAssessmentRepositoryHistorySemantics() async throws {
    let repo = InMemoryPhysiqueAssessmentRepository()
    let a = FixtureBuilders.makePhysiqueAssessment(createdAt: Date(timeIntervalSince1970: 1))
    let b = FixtureBuilders.makePhysiqueAssessment(createdAt: Date(timeIntervalSince1970: 2))
    try await repo.saveActive(a)
    try await repo.saveActive(b)
    XCTAssertEqual(try await repo.fetchHistory().map(\.id), [b.id, a.id])
    XCTAssertEqual(try await repo.fetch(id: a.id)?.id, a.id)
    try await repo.clearAll()
    XCTAssertTrue(try await repo.fetchHistory().isEmpty)
}
```

Keep existing `testLocalPhysiqueAssessmentRepositoryPersistsActive` working (update init to use unique history/legacy keys).

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/LocalPhysiqueAssessmentRepositoryTests test
```

Expected: FAIL (missing protocol methods / history document)

- [ ] **Step 3: Implement document, protocol, Local + InMemory**

`LocalPhysiqueAssessmentRepository` sketch:

```swift
actor LocalPhysiqueAssessmentRepository: PhysiqueAssessmentRepository {
    static let maxHistoryCount = 12
    private let historyKey: String
    private let legacyKey: String

    init(
        historyKey: String = "physique_assessments.json",
        legacyKey: String = "physique_assessment.json"
    ) {
        self.historyKey = historyKey
        self.legacyKey = legacyKey
    }

    func fetchActive() async throws -> PhysiqueAssessment? {
        try await fetchHistory().first
    }

    func fetchHistory() async throws -> [PhysiqueAssessment] {
        try migrateLegacyIfNeeded()
        return loadDocument().assessments
    }

    func fetch(id: UUID) async throws -> PhysiqueAssessment? {
        try await fetchHistory().first { $0.id == id }
    }

    func saveActive(_ assessment: PhysiqueAssessment) async throws {
        try migrateLegacyIfNeeded()
        var assessments = loadDocument().assessments
        assessments.removeAll { $0.id == assessment.id }
        assessments.insert(assessment, at: 0)
        if assessments.count > Self.maxHistoryCount {
            assessments = Array(assessments.prefix(Self.maxHistoryCount))
        }
        PersistenceHelper.save(
            PhysiqueAssessmentHistoryDocument(assessments: assessments),
            to: historyKey
        )
        PersistenceHelper.remove(legacyKey)
    }

    func clearActive() async throws { try await clearAll() }

    func clearAll() async throws {
        PersistenceHelper.remove(historyKey)
        PersistenceHelper.remove(legacyKey)
    }

    private func loadDocument() -> PhysiqueAssessmentHistoryDocument {
        PersistenceHelper.load(PhysiqueAssessmentHistoryDocument.self, from: historyKey)
            ?? PhysiqueAssessmentHistoryDocument(assessments: [])
    }

    private func migrateLegacyIfNeeded() throws {
        let existing = PersistenceHelper.load(
            PhysiqueAssessmentHistoryDocument.self,
            from: historyKey
        )
        if let existing, !existing.assessments.isEmpty { return }
        guard let legacy = PersistenceHelper.load(PhysiqueAssessment.self, from: legacyKey) else {
            return
        }
        PersistenceHelper.save(
            PhysiqueAssessmentHistoryDocument(assessments: [legacy]),
            to: historyKey
        )
        PersistenceHelper.remove(legacyKey)
    }
}
```

`InMemoryPhysiqueAssessmentRepository`:

```swift
actor InMemoryPhysiqueAssessmentRepository: PhysiqueAssessmentRepository {
    private var assessments: [PhysiqueAssessment] = []

    func fetchActive() async throws -> PhysiqueAssessment? { assessments.first }
    func fetchHistory() async throws -> [PhysiqueAssessment] { assessments }
    func fetch(id: UUID) async throws -> PhysiqueAssessment? {
        assessments.first { $0.id == id }
    }
    func saveActive(_ assessment: PhysiqueAssessment) async throws {
        assessments.removeAll { $0.id == assessment.id }
        assessments.insert(assessment, at: 0)
        if assessments.count > 12 {
            assessments = Array(assessments.prefix(12))
        }
    }
    func clearActive() async throws { assessments = [] }
    func clearAll() async throws { assessments = [] }
}
```

Update existing local persist test to construct repo with unique `historyKey`/`legacyKey`.

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/LocalPhysiqueAssessmentRepositoryTests test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Models/PhysiqueAssessmentHistoryDocument.swift \
  HotBod/Data/Repositories/RepositoryProtocols.swift \
  HotBod/Data/Local/LocalPhysiqueAssessmentRepository.swift \
  HotBod/Tests/Support/InMemoryRepositories.swift \
  HotBod/Tests/UnitTests/RepositoryDomainTests.swift \
  HotBod.xcodeproj/project.pbxproj
git commit -m "feat: persist rolling physique assessment history"
```

---

### Task 2: Diff engine (structured + Vision)

**Files:**
- Create: `HotBod/Domain/Models/PhysiqueAssessmentDiff.swift`
- Create: `HotBod/Domain/Physique/PhysiqueAssessmentDiffEngine.swift`
- Create: `HotBod/Tests/UnitTests/PhysiqueAssessmentDiffTests.swift`
- Modify: `HotBod/Tests/Support/FixtureBuilders.swift` — extend `makePhysiqueAssessment` with optional overrides for physique, priorities, directions, photo ids

**Interfaces:**
- Consumes: `PhysiqueAssessment`, `PhysiqueBuildSummary`, `PhysiqueFocusMuscle`, `PhysiqueArchetypeCatalogEntry`, `BodyPhotoVisionMetrics.comparisonSummary`
- Produces:
  ```swift
  struct PhysiqueBuildFieldChange: Hashable {
      var field: String   // human label e.g. "Frame"
      var from: String
      var to: String
  }

  struct PhysiquePriorityChanges: Hashable {
      var added: [PhysiqueFocusMuscle]
      var removed: [PhysiqueFocusMuscle]
      var reordered: Bool
  }

  struct PhysiqueDirectionChanges: Hashable {
      var added: [String]   // archetypeId
      var removed: [String]
  }

  struct PhysiqueAssessmentDiff: Hashable {
      var previousId: UUID
      var currentId: UUID
      var previousDate: Date
      var currentDate: Date
      var buildChanges: [PhysiqueBuildFieldChange]
      var priorityChanges: PhysiquePriorityChanges
      var directionChanges: PhysiqueDirectionChanges
      var visionTrends: [String]
      var summaryLines: [String]
      var hasMeaningfulChange: Bool
  }

  enum PhysiqueAssessmentDiffEngine {
      static func diff(
          previous: PhysiqueAssessment,
          current: PhysiqueAssessment,
          previousFrontRatio: Double? = nil,
          currentFrontRatio: Double? = nil,
          catalog: [String: PhysiqueArchetypeCatalogEntry] = PhysiqueArchetypeCatalogLoader.indexedById()
      ) -> PhysiqueAssessmentDiff
  }
  ```

**Build fields to compare (label → keypath):**

| Label | KeyPath |
|-------|---------|
| Frame | `\PhysiqueBuildSummary.frameSize` |
| Shoulder to waist | `\.shoulderToWaist` |
| Waist | `\.waist` |
| Torso | `\.torso` |
| Muscularity | `\.muscularity` |
| Leanness | `\.leanness` |

(Skip `overallArchetype` in field list — it often restates the whole summary; if it changes alone, still include as `"Overall"`.)

**Priority rules:**
- `previousMuscles` / `currentMuscles` = `developmentPriorities.map(\.muscle)` ordered
- `added` = in current not in previous (preserve current order)
- `removed` = in previous not in current (preserve previous order)
- `reordered` = same set (`Set` equal) AND ordered arrays unequal

**Direction rules:**
- Compare `Set(physiqueDirections.map(\.archetypeId))`
- For summary labels: resolve via catalog `genericLabel`; **skip** unknown ids

**Vision:**
- If both ratios non-nil, append `BodyPhotoVisionMetrics.comparisonSummary(currentRatio:currentFrontRatio, previousRatio:previousFrontRatio, hasPrevious:true)`
- Else `visionTrends = []`

**summaryLines (cap 5, prefer this order):**
1. Build: `"\(field) shifted: \(from) → \(to)."` for each build change (until cap)
2. Priorities: if added non-empty → `"Priority appeared: \(names)."`; if removed → `"Priority dropped: \(names)."`; else if reordered → `"Priority order shifted."`
3. Directions: if added → `"Direction appeared: \(labels)."`; if removed → `"Direction dropped: \(labels)."`
4. Do **not** duplicate Vision into `summaryLines` (UI shows under `Visual trend`)
5. If no build/priority/direction changes → `summaryLines = ["No meaningful change since last assessment."]`, `hasMeaningfulChange = false`
6. `hasMeaningfulChange` = any build/priority/direction change OR non-empty `visionTrends` that is not the stable phrase containing `"unchanged"` — simpler rule for v1: `hasMeaningfulChange = !(build/priority/direction empty) || !visionTrends.isEmpty`. Stable Vision still counts as a visual line but summary can stay “No meaningful change…” when structured empty; UI uses structured summary + optional vision caption separately. Spec stable case: show `No meaningful change since last assessment.` when **diff fields all stable** — treat Vision-stable as still “stable” for that string; only show Vision caption when `visionTrends` non-empty.

Implementer rule matching spec:
- `hasMeaningfulChange` = buildChanges non-empty OR priorities added/removed/reordered OR directions added/removed
- Stable summary string when `!hasMeaningfulChange`
- Always attach `visionTrends` independently when ratios exist

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import HotBod

final class PhysiqueAssessmentDiffTests: XCTestCase {
    func testBuildFieldChangeAppearsInSummary() {
        var previous = FixtureBuilders.makePhysiqueAssessment()
        var current = FixtureBuilders.makePhysiqueAssessment()
        previous.physique.frameSize = "Medium"
        current.physique.frameSize = "Large"
        let diff = PhysiqueAssessmentDiffEngine.diff(previous: previous, current: current)
        XCTAssertTrue(diff.hasMeaningfulChange)
        XCTAssertTrue(diff.buildChanges.contains { $0.field == "Frame" && $0.from == "Medium" && $0.to == "Large" })
        XCTAssertTrue(diff.summaryLines.contains { $0.contains("Frame") && $0.contains("Medium") && $0.contains("Large") })
    }

    func testPriorityAddRemoveReorder() {
        var previous = FixtureBuilders.makePhysiqueAssessment()
        var current = FixtureBuilders.makePhysiqueAssessment()
        previous.developmentPriorities = [
            .init(muscle: .lateralDelts, reason: "a"),
            .init(muscle: .lats, reason: "b")
        ]
        current.developmentPriorities = [
            .init(muscle: .lats, reason: "b"),
            .init(muscle: .upperChest, reason: "c")
        ]
        let diff = PhysiqueAssessmentDiffEngine.diff(previous: previous, current: current)
        XCTAssertEqual(diff.priorityChanges.added, [.upperChest])
        XCTAssertEqual(diff.priorityChanges.removed, [.lateralDelts])
        XCTAssertFalse(diff.priorityChanges.reordered)

        current.developmentPriorities = [
            .init(muscle: .lats, reason: "b"),
            .init(muscle: .lateralDelts, reason: "a")
        ]
        previous.developmentPriorities = [
            .init(muscle: .lateralDelts, reason: "a"),
            .init(muscle: .lats, reason: "b")
        ]
        let reorder = PhysiqueAssessmentDiffEngine.diff(previous: previous, current: current)
        XCTAssertTrue(reorder.priorityChanges.reordered)
        XCTAssertTrue(reorder.priorityChanges.added.isEmpty)
        XCTAssertTrue(reorder.priorityChanges.removed.isEmpty)
    }

    func testDirectionAddRemoveSkipsUnknownCatalogIds() {
        var previous = FixtureBuilders.makePhysiqueAssessment()
        var current = FixtureBuilders.makePhysiqueAssessment()
        previous.physiqueDirections = [
            PhysiqueArchetypeMatch(
                archetypeId: "lean_fighter",
                rank: 1,
                similarityDimension: "silhouette",
                confidence: .medium
            )
        ]
        current.physiqueDirections = [
            PhysiqueArchetypeMatch(
                archetypeId: "v_taper_focus",
                rank: 1,
                similarityDimension: "taper",
                confidence: .medium
            ),
            PhysiqueArchetypeMatch(
                archetypeId: "not_in_catalog_xyz",
                rank: 2,
                similarityDimension: "x",
                confidence: .low
            )
        ]
        let diff = PhysiqueAssessmentDiffEngine.diff(previous: previous, current: current)
        XCTAssertEqual(Set(diff.directionChanges.added), ["v_taper_focus", "not_in_catalog_xyz"])
        XCTAssertEqual(diff.directionChanges.removed, ["lean_fighter"])
        let joined = diff.summaryLines.joined(separator: " ")
        XCTAssertTrue(joined.contains("V-taper focus") || joined.lowercased().contains("v-taper"))
        XCTAssertFalse(joined.contains("not_in_catalog_xyz"))
    }

    func testVisionTrendsWhenBothRatiosPresent() {
        let previous = FixtureBuilders.makePhysiqueAssessment()
        let current = FixtureBuilders.makePhysiqueAssessment()
        let diff = PhysiqueAssessmentDiffEngine.diff(
            previous: previous,
            current: current,
            previousFrontRatio: 1.30,
            currentFrontRatio: 1.40
        )
        XCTAssertFalse(diff.visionTrends.isEmpty)
        XCTAssertTrue(diff.visionTrends[0].localizedCaseInsensitiveContains("wider"))
    }

    func testVisionTrendsOmittedWhenRatioMissing() {
        let previous = FixtureBuilders.makePhysiqueAssessment()
        let current = FixtureBuilders.makePhysiqueAssessment()
        let diff = PhysiqueAssessmentDiffEngine.diff(
            previous: previous,
            current: current,
            previousFrontRatio: 1.30,
            currentFrontRatio: nil
        )
        XCTAssertTrue(diff.visionTrends.isEmpty)
    }

    func testStableSummaryWhenNothingChanged() {
        let previous = FixtureBuilders.makePhysiqueAssessment(id: UUID())
        var current = previous
        current.id = UUID()
        let diff = PhysiqueAssessmentDiffEngine.diff(previous: previous, current: current)
        XCTAssertFalse(diff.hasMeaningfulChange)
        XCTAssertEqual(diff.summaryLines, ["No meaningful change since last assessment."])
    }
}
```

Extend fixture if needed so `makePhysiqueAssessment` can take `physiqueDirections:` default `[]`.

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueAssessmentDiffTests test
```

Expected: FAIL

- [ ] **Step 3: Implement models + engine**

Keep engine file focused: private helpers `buildChanges`, `priorityChanges`, `directionChanges`, `makeSummaryLines`. Use `PhysiqueFocusMuscle.displayName` for priority names.

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/PhysiqueAssessmentDiffTests test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Domain/Models/PhysiqueAssessmentDiff.swift \
  HotBod/Domain/Physique/PhysiqueAssessmentDiffEngine.swift \
  HotBod/Tests/UnitTests/PhysiqueAssessmentDiffTests.swift \
  HotBod/Tests/Support/FixtureBuilders.swift \
  HotBod.xcodeproj/project.pbxproj
git commit -m "feat: add physique assessment diff engine"
```

---

### Task 3: AppEnvironment history + Since-last UI

**Files:**
- Modify: `HotBod/App/AppEnvironment.swift` — add `@Observable` property `physiqueAssessmentHistory: [PhysiqueAssessment] = []`
- Modify: `HotBod/App/AppEnvironment+Physique.swift` — load history on load/save; expose since-last helper
- Modify: `HotBod/Features/Physique/PhysiqueView.swift` — Since-last card after Build Summary; Assessment history button
- Create: `HotBod/Features/Physique/PhysiqueSinceLastCard.swift` (optional small extract — OK to keep private in PhysiqueView if < ~40 lines)
- Modify: `HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift`
- Modify: `HotBod/Tests/UnitTests/AppEnvironmentPhysiqueOrchestrationTests.swift` if load paths need updating

**Interfaces:**
- Consumes: `fetchHistory()`, `PhysiqueAssessmentDiffEngine`
- Produces:
  ```swift
  // AppEnvironment
  var physiqueAssessmentHistory: [PhysiqueAssessment]

  func loadActivePhysiqueAssessment() async
  // Implementation must set:
  //   history = fetchHistory()
  //   activePhysiqueAssessment = history.first

  func saveActivePhysiqueAssessment(_ assessment: PhysiqueAssessment) async
  // saveActive then refresh history + active

  func sinceLastPhysiqueDiff(
      photos: [BodyProgressPhoto]
  ) -> PhysiqueAssessmentDiff?
  // nil if history.count < 2
  // ratios from photos matching frontPhotoId.analysis?.shoulderWaistRatio
  ```

**UI (current report only):**
- After Build Summary card, before Development Priorities:
  - If `sinceLastPhysiqueDiff(photos:)` non-nil → show card
  - Title: `Since last assessment`
  - Subtitle: medium-date `previousDate → currentDate` via `Date.FormatStyle(date: .abbreviated, time: .omitted)` or `.formatted(date: .abbreviated, time: .omitted)`
  - Bullets: `summaryLines`
  - If `visionTrends` non-empty: caption `Visual trend` + lines
  - `.accessibilityIdentifier("physique.sinceLast")`
- Secondary `ForgeButton(title: "Assessment history", style: .secondary, accessibilityIdentifier: "physique.history")` — NavigationLink destination stub OK until Task 4 (or wire Task 4 list in same PR if sequential); **this task must at least show Since-last**. Prefer NavigationLink to `PhysiqueAssessmentHistoryView` empty shell that Task 4 fills — if shell is empty, Task 4 owns the destination file creation; Task 3 can leave button navigating to a placeholder `Text("History")` only if Task 4 immediately follows in the same session. **Preferred:** Task 3 adds Since-last only; Task 4 adds history button + screens.

**Exact Task 3 UI deliverable:** Since-last section only (no history navigation yet).

- [ ] **Step 1: Write failing tests**

```swift
func testLoadActivePhysiqueAssessmentPopulatesHistory() async throws {
    let repos = TestRepositories.empty()
    let older = FixtureBuilders.makePhysiqueAssessment(createdAt: Date(timeIntervalSince1970: 1))
    let newer = FixtureBuilders.makePhysiqueAssessment(createdAt: Date(timeIntervalSince1970: 2))
    try await repos.physiqueAssessment.saveActive(older)
    try await repos.physiqueAssessment.saveActive(newer)
    let env = AppEnvironment.makeForTests(repos: repos)
    await env.loadActivePhysiqueAssessment()
    XCTAssertEqual(env.activePhysiqueAssessment?.id, newer.id)
    XCTAssertEqual(env.physiqueAssessmentHistory.map(\.id), [newer.id, older.id])
}

func testRegression_trainingBiasUsesNewestAssessmentOnly() async throws {
    let repos = TestRepositories.empty()
    var profile = UserProfile.empty()
    profile.preferredMuscleGroups = []
    try await repos.userProfile.saveProfile(profile)

    var older = FixtureBuilders.makePhysiqueAssessment(createdAt: Date(timeIntervalSince1970: 1))
    older.trainingBias = PhysiqueTrainingBias(
        preferredMuscleGroups: [.quads],
        rationale: "old"
    )
    var newer = FixtureBuilders.makePhysiqueAssessment(createdAt: Date(timeIntervalSince1970: 2))
    newer.trainingBias = PhysiqueTrainingBias(
        preferredMuscleGroups: [.shoulders, .back],
        rationale: "new"
    )
    try await repos.physiqueAssessment.saveActive(older)
    try await repos.physiqueAssessment.saveActive(newer)

    let env = AppEnvironment.makeForTests(repos: repos)
    env.userProfile = profile
    await env.loadActivePhysiqueAssessment()
    let input = await env.makeWorkoutGenerationInput(profile: profile, splitDayFocus: .push)
    XCTAssertEqual(input.preferredMuscleGroups, [.shoulders, .back])
    XCTAssertFalse(input.preferredMuscleGroups.contains(.quads))
}

func testSinceLastPhysiqueDiffNilWithSingleAssessment() async {
    let repos = TestRepositories.empty()
    try await repos.physiqueAssessment.saveActive(FixtureBuilders.makePhysiqueAssessment())
    let env = AppEnvironment.makeForTests(repos: repos)
    await env.loadActivePhysiqueAssessment()
    XCTAssertNil(env.sinceLastPhysiqueDiff(photos: []))
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testLoadActivePhysiqueAssessmentPopulatesHistory \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testRegression_trainingBiasUsesNewestAssessmentOnly \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testSinceLastPhysiqueDiffNilWithSingleAssessment \
  test
```

Expected: FAIL

- [ ] **Step 3: Implement env + Since-last UI**

```swift
// AppEnvironment+Physique.swift
func loadActivePhysiqueAssessment() async {
    let history = (try? await physiqueAssessmentRepository.fetchHistory()) ?? []
    physiqueAssessmentHistory = history
    activePhysiqueAssessment = history.first
}

func saveActivePhysiqueAssessment(_ assessment: PhysiqueAssessment) async {
    try? await physiqueAssessmentRepository.saveActive(assessment)
    await loadActivePhysiqueAssessment()
}

func sinceLastPhysiqueDiff(photos: [BodyProgressPhoto]) -> PhysiqueAssessmentDiff? {
    guard physiqueAssessmentHistory.count >= 2 else { return nil }
    let current = physiqueAssessmentHistory[0]
    let previous = physiqueAssessmentHistory[1]
    let currentRatio = photos.first { $0.id == current.frontPhotoId }?.analysis?.shoulderWaistRatio
    let previousRatio = photos.first { $0.id == previous.frontPhotoId }?.analysis?.shoulderWaistRatio
    return PhysiqueAssessmentDiffEngine.diff(
        previous: previous,
        current: current,
        previousFrontRatio: previousRatio,
        currentFrontRatio: currentRatio
    )
}
```

In `reportSection`, insert After Build Summary:

```swift
if let diff = environment.sinceLastPhysiqueDiff(photos: photos) {
    sinceLastCard(diff)
}
```

`sinceLastCard` uses ForgeCard + ForgeSectionHeader title `"Since last assessment"`, subtitle date range, ForEach summaryLines, optional Visual trend block.

- [ ] **Step 4: Run tests + build**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testLoadActivePhysiqueAssessmentPopulatesHistory \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testRegression_trainingBiasUsesNewestAssessmentOnly \
  -only-testing:HotBodTests/AppEnvironmentOrchestrationTests/testSinceLastPhysiqueDiffNilWithSingleAssessment \
  test
```

Expected: PASS; app compiles.

- [ ] **Step 5: Commit**

```bash
git add HotBod/App/AppEnvironment.swift HotBod/App/AppEnvironment+Physique.swift \
  HotBod/Features/Physique/PhysiqueView.swift \
  HotBod/Tests/UnitTests/AppEnvironmentOrchestrationTests.swift \
  HotBod.xcodeproj/project.pbxproj
git commit -m "feat: show since-last physique assessment diff"
```

---

### Task 4: History list + read-only detail + UI seed

**Files:**
- Create: `HotBod/Features/Physique/PhysiqueAssessmentReportContent.swift` — shared report body (build / priorities / directions / why today); parameter `showsActions: Bool`
- Create: `HotBod/Features/Physique/PhysiqueAssessmentHistoryView.swift` — list + detail
- Modify: `HotBod/Features/Physique/PhysiqueView.swift` — extract report into shared content; add `Assessment history` NavigationLink; current report keeps Reassess / add-side actions
- Modify: `HotBod/App/UITestConfiguration.swift` — `-SeedPhysiqueHistory`
- Modify: `HotBod/App/HotBodApp.swift` or wherever skip-onboarding seeds run — call seed after profile when flag set
- Modify: `HotBod/Tests/UITests/BaseUITestCase.swift` — optional `seedPhysiqueHistory` flag
- Modify: `HotBod/Tests/UITests/PhysiqueUITests.swift`

**Interfaces:**
- Consumes: `environment.physiqueAssessmentHistory`, `PhysiqueAssessmentDiffEngine`
- Produces:
  ```swift
  struct PhysiqueAssessmentReportContent: View {
      let assessment: PhysiqueAssessment
      // build, priorities, directions, why today — no Reassess
  }

  struct PhysiqueAssessmentHistoryView: View {
      // List newest-first
      // Row: date (abbreviated) + source Online/On-device + top priority.displayName
      // Current badge on first row: Text("Current")
      // a11y list: physique.history.list
      // a11y row: physique.history.<uuid>
      // Detail: ReportContent + optional Compare to previous section when neighbor exists
  }
  ```

**UITest seed (`-SeedPhysiqueHistory`):**
When `UITestConfiguration.isUITesting && arguments.contains("-SeedPhysiqueHistory")` and onboarding skipped:
1. Save older assessment (createdAt −30d) with frameSize `"Medium"`, priorities `[.lats, .upperChest]`
2. Save newer assessment (createdAt now) with frameSize `"Large"`, priorities `[.lateralDelts, .lats]`
3. Ensure `loadActivePhysiqueAssessment()` runs so UI sees history

Use fixed UUIDs for stable row identifiers in tests if helpful:
- older: `00000000-0000-0000-0000-0000000000A1`
- newer: `00000000-0000-0000-0000-0000000000A2`

**History empty helper:** if history count == 1, list still shows Current row; footer caption `Reassess later to unlock change history.` (only when count < 2)

**Compare to previous on detail:** when viewing index `i` and `i+1` exists, show Since-last-style card titled `Compared to previous` using `diff(previous: history[i+1], current: history[i], ...)`. Photos may be empty in history detail (Vision omitted) — OK.

- [ ] **Step 1: Write failing UI tests**

```swift
func testSinceLastAndHistoryWithSeededAssessments() {
    app.launchArguments.append("-SeedPhysiqueHistory")
    // relaunch required — set flag in setUp before launch, or:
}

// Prefer override in test:
final class PhysiqueHistoryUITests: BaseUITestCase {
    override func setUpWithError() throws {
        launchTab = "physique"
        // Add property on BaseUITestCase: var seedPhysiqueHistory = false
        seedPhysiqueHistory = true
        try super.setUpWithError()
    }

    func testSinceLastVisibleWithTwoAssessments() {
        XCTAssertTrue(app.otherElements["physique.sinceLast"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Since last assessment"].exists)
    }

    func testHistoryListShowsCurrentBadge() {
        XCTAssertTrue(app.buttons["physique.history"].waitForExistence(timeout: 10))
        app.buttons["physique.history"].tap()
        XCTAssertTrue(app.otherElements["physique.history.list"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Current"].waitForExistence(timeout: 5))
    }

    func testPastDetailHasNoReassess() {
        app.buttons["physique.history"].tap()
        // tap non-current row by a11y id
        let older = app.buttons["physique.history.00000000-0000-0000-0000-0000000000A1"]
        XCTAssertTrue(older.waitForExistence(timeout: 8))
        older.tap()
        XCTAssertFalse(app.buttons["physique.reassess"].exists)
    }
}
```

Wire `BaseUITestCase`:

```swift
var seedPhysiqueHistory = false
// in setUp launchArguments:
if seedPhysiqueHistory { app.launchArguments.append("-SeedPhysiqueHistory") }
```

- [ ] **Step 2: Run UI tests to verify they fail**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodUITests/PhysiqueHistoryUITests test
```

Expected: FAIL

- [ ] **Step 3: Implement shared report content, history views, seed, wire NavigationLink**

Seed helper (e.g. in `UITestConfiguration` or `AppEnvironment+Physique`):

```swift
static var shouldSeedPhysiqueHistory: Bool {
    isUITesting && ProcessInfo.processInfo.arguments.contains("-SeedPhysiqueHistory")
}

@MainActor
static func seedPhysiqueHistoryIfNeeded(in environment: AppEnvironment) async {
    guard shouldSeedPhysiqueHistory else { return }
    let olderId = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    let newerId = UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!
    var older = FixtureBuilders.makePhysiqueAssessment(
        id: olderId,
        createdAt: Date().addingTimeInterval(-30 * 24 * 3600)
    )
    older.physique.frameSize = "Medium"
    older.developmentPriorities = [
        .init(muscle: .lats, reason: "Width"),
        .init(muscle: .upperChest, reason: "Shelf")
    ]
    var newer = FixtureBuilders.makePhysiqueAssessment(
        id: newerId,
        createdAt: Date()
    )
    newer.physique.frameSize = "Large"
    newer.developmentPriorities = [
        .init(muscle: .lateralDelts, reason: "Caps"),
        .init(muscle: .lats, reason: "Width")
    ]
    await environment.saveActivePhysiqueAssessment(older)
    await environment.saveActivePhysiqueAssessment(newer)
}
```

**Note:** `FixtureBuilders` is in the test target — do **not** call it from app code. Duplicate a small private seed builder inside `UITestConfiguration` or `AppEnvironment` UI-test-only method that constructs `PhysiqueAssessment` inline (copy field values from fixture shape).

Call seed from the same place `-SkipOnboarding` finishes applying launch config (search `shouldSkipOnboarding` / `defaultOnboardedProfile` usage in `HotBodApp` / bootstrap).

Refactor `PhysiqueView.reportSection` to use `PhysiqueAssessmentReportContent` + action buttons below.

- [ ] **Step 4: Run UI + unit smoke**

```bash
xcodegen generate
xcodebuild -scheme HotBod -destination 'platform=iOS Simulator,id=EB7BE0BD-179B-4A37-9202-69D87FC47B75' \
  -only-testing:HotBodUITests/PhysiqueHistoryUITests \
  -only-testing:HotBodTests/PhysiqueAssessmentDiffTests \
  -only-testing:HotBodTests/LocalPhysiqueAssessmentRepositoryTests \
  test
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add HotBod/Features/Physique HotBod/App/UITestConfiguration.swift \
  HotBod/App/HotBodApp.swift HotBod/Tests/UITests \
  HotBod.xcodeproj/project.pbxproj
git commit -m "feat: add physique assessment history list and detail"
```

---

## Self-Review Checklist

| Spec requirement | Task |
|------------------|------|
| Rolling last 12 + prepend/prune/replace | Task 1 |
| Legacy migrate | Task 1 |
| fetchHistory / fetch(id) / clearAll | Task 1 |
| Structured build/priority/direction diff | Task 2 |
| Vision trends via ratios / omit if missing | Task 2 |
| Stable copy | Task 2 |
| Active = newest for bias | Task 1 + Task 3 regression |
| Since last on report | Task 3 |
| History list + read-only past + Current badge | Task 4 |
| Compare to previous optional | Task 4 |
| Progress unchanged | No Progress files in plan |
| No auto priority rewrite | No bias-writer changes |
| Unit / integration / UI tests | Tasks 1–4 |

**Placeholder scan:** none intentional.  
**Type consistency:** `PhysiqueAssessmentDiff` / `PhysiqueAssessmentDiffEngine.diff` / `sinceLastPhysiqueDiff` / history keys aligned across tasks.
