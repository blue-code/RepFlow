import Foundation
import HealthKit

final class HealthKitService: HealthKitServiceProtocol {

    private let store = HKHealthStore()

    private var typesToShare: Set<HKSampleType> {
        var set: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            set.insert(energy)
        }
        return set
    }

    private var typesToRead: Set<HKObjectType> {
        var set: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            set.insert(energy)
        }
        return set
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }

    func saveWorkout(
        exercise: ExerciseKind,
        start: Date,
        end: Date,
        totalReps: Int,
        kcal: Double?
    ) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        let activity: HKWorkoutActivityType
        switch exercise {
        case .pushUp, .pikePushUp, .dip: activity = .functionalStrengthTraining
        case .pullUp, .inverseRow:       activity = .traditionalStrengthTraining
        }

        let config = HKWorkoutConfiguration()
        config.activityType = activity

        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        try await builder.beginCollection(at: start)

        if let kcal, let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            let qty = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
            let sample = HKCumulativeQuantitySample(type: energyType, quantity: qty, start: start, end: end)
            try await builder.addSamples([sample])
        }

        try await builder.endCollection(at: end)

        let metadata: [String: Any] = [
            "RepFlowReps": totalReps,
            "RepFlowExercise": exercise.rawValue
        ]
        try await builder.addMetadata(metadata)

        _ = try await builder.finishWorkout()
    }
}
