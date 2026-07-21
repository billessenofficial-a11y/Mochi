import Foundation
import HealthKit

@MainActor
final class AudiogramService: ObservableObject {
    @Published private(set) var latestDate: Date?
    @Published private(set) var pointCount = 0
    @Published private(set) var isLoading = false
    @Published private(set) var message = "Not connected"

    private let healthStore = HKHealthStore()

    func requestLatestAudiogram() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            message = "Apple Health is unavailable on this device"
            return
        }

        isLoading = true
        defer { isLoading = false }
        let type = HKObjectType.audiogramSampleType()

        do {
            try await healthStore.requestAuthorization(toShare: [], read: [type])
            let sample = try await latestSample(of: type)
            latestDate = sample?.endDate
            pointCount = sample?.sensitivityPoints.count ?? 0
            message = sample == nil ? "No audiogram found in Apple Health" : "Audiogram available"
        } catch {
            message = "Audiogram access wasn’t granted"
        }
    }

    private func latestSample(of type: HKAudiogramSampleType) async throws -> HKAudiogramSample? {
        try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples?.first as? HKAudiogramSample)
                }
            }
            healthStore.execute(query)
        }
    }
}
