import Foundation
import HealthKit

enum BodyMassSyncPolicy {
    /// Manual weight sticks until a newer Health sample arrives.
    /// A missing source takes the Health sample. An existing Health weight is left alone when it is already close.
    static func shouldApply(profile: UserProfile, sample: HealthBodyMassSample) -> Bool {
        guard (30...250).contains(sample.kilograms) else { return false }
        if profile.bodyMassSource == .manual {
            let lockedAt = profile.bodyMassLockedAt ?? profile.updatedAt
            if sample.measuredAt <= lockedAt { return false }
        }
        if profile.bodyMassSource == .health,
           let current = profile.weightKg,
           abs(current - sample.kilograms) < 0.2 {
            return false
        }
        return true
    }
}

struct NoOpHealthKitReadinessService: HealthKitReadinessService, Sendable {
    var isAvailable: Bool { false }

    func requestAuthorizationIfNeeded() async {}

    func fetchReadinessSnapshot() async -> HealthReadinessSnapshot {
        .empty
    }

    func fetchLatestBodyMass() async -> HealthBodyMassSample? {
        nil
    }
}

actor HealthKitReadinessServiceImpl: HealthKitReadinessService {
    private let store = HKHealthStore()
    private let fallback = NoOpHealthKitReadinessService()

    nonisolated var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorizationIfNeeded() async {
        guard isAvailable else { return }
        var readTypes = Set<HKObjectType>()
        if let heartRate = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            readTypes.insert(heartRate)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleep)
        }
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            readTypes.insert(bodyMass)
        }
        guard !readTypes.isEmpty else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
        } catch {
            // Authorization denied or entitlement missing — readiness stays optional.
        }
    }

    func fetchReadinessSnapshot() async -> HealthReadinessSnapshot {
        guard isAvailable else { return await fallback.fetchReadinessSnapshot() }

        async let heartRate = fetchRestingHeartRate()
        async let sleepHours = fetchSleepHoursLastNight()

        let bpm = await heartRate
        let hours = await sleepHours
        let sleepScore = hours.map(Self.sleepScore(hours:))
        let hint = Self.recoveryHint(restingHeartRate: bpm, sleepHours: hours)

        if bpm == nil, hours == nil {
            return .empty
        }

        return HealthReadinessSnapshot(
            restingHeartRateBPM: bpm,
            sleepHoursLastNight: hours,
            recoveryHint: hint,
            sleepScore: sleepScore
        )
    }

    func fetchLatestBodyMass() async -> HealthBodyMassSample? {
        guard isAvailable else { return nil }
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
        let start = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? .distantPast
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 8,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let match = (samples as? [HKQuantitySample])?.first { sample in
                    let kilograms = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                    return (30...250).contains(kilograms)
                }
                guard let match else {
                    continuation.resume(returning: nil)
                    return
                }
                let kilograms = match.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                continuation.resume(
                    returning: HealthBodyMassSample(kilograms: kilograms, measuredAt: match.endDate)
                )
            }
            store.execute(query)
        }
    }

    private func fetchRestingHeartRate() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, _ in
                guard let quantity = statistics?.averageQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: bpm > 0 ? bpm : nil)
            }
            store.execute(query)
        }
    }

    private func fetchSleepHoursLastNight() async -> Double? {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -1, to: end) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let asleepSeconds = samples
                    .filter { asleepValues.contains($0.value) }
                    .map { $0.endDate.timeIntervalSince($0.startDate) }
                    .reduce(0, +)
                let hours = asleepSeconds / 3600
                continuation.resume(returning: hours > 0 ? hours : nil)
            }
            store.execute(query)
        }
    }

    static func sleepScore(hours: Double) -> Double {
        switch hours {
        case ..<5: return 0.35
        case 5..<6.5: return 0.55
        case 6.5..<7.5: return 0.75
        case 7.5..<9: return 0.95
        default: return 0.7
        }
    }

    static func recoveryHint(restingHeartRate: Double?, sleepHours: Double?) -> String? {
        var hints: [String] = []
        if let sleepHours, sleepHours < 6.5 {
            hints.append("Sleep was shorter than usual last night.")
        }
        if let restingHeartRate, restingHeartRate > 70 {
            hints.append("Resting heart rate is slightly elevated.")
        }
        guard !hints.isEmpty else { return nil }
        return hints.joined(separator: " ")
    }
}

enum HealthKitReadinessServiceFactory {
    static func makeDefault() -> any HealthKitReadinessService {
        if HKHealthStore.isHealthDataAvailable() {
            return HealthKitReadinessServiceImpl()
        }
        return NoOpHealthKitReadinessService()
    }
}
