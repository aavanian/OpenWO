#if os(iOS)
import HealthKit

public protocol HealthKitManaging: AnyObject {
    func requestAuthorizationIfNeeded() async
    func startWorkout(activityType: HKWorkoutActivityType, startDate: Date) async throws
    func endWorkout(at date: Date) async throws
    func discardWorkout() async
}

public final class HealthKitManager: HealthKitManaging {
    private let healthStore = HKHealthStore()
    private var workoutSession: AnyObject?
    private var workoutBuilder: HKWorkoutBuilder?

    public init() {}

    public func requestAuthorizationIfNeeded() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let workoutType = HKObjectType.workoutType()
        let status = healthStore.authorizationStatus(for: workoutType)
        guard status == .notDetermined else { return }

        try? await healthStore.requestAuthorization(toShare: [workoutType], read: [])
    }

    public func startWorkout(activityType: HKWorkoutActivityType, startDate: Date) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType

        if #available(iOS 26, *) {
            try await startLiveWorkout(configuration: configuration, startDate: startDate)
        } else {
            try await startSilentWorkout(configuration: configuration, startDate: startDate)
        }
    }

    public func endWorkout(at date: Date) async throws {
        if #available(iOS 26, *), let session = workoutSession as? HKWorkoutSession {
            self.workoutSession = nil
            let builder = session.associatedWorkoutBuilder()
            session.end()
            try await builder.endCollection(at: date)
            try await builder.finishWorkout()
        } else if let builder = workoutBuilder {
            self.workoutSession = nil
            self.workoutBuilder = nil
            try await builder.endCollection(at: date)
            try await builder.finishWorkout()
        }
    }

    public func discardWorkout() async {
        let now = Date()
        if #available(iOS 26, *), let session = workoutSession as? HKWorkoutSession {
            self.workoutSession = nil
            let builder = session.associatedWorkoutBuilder()
            session.end()
            try? await builder.endCollection(at: now)
            builder.discardWorkout()
        } else if let builder = workoutBuilder {
            self.workoutSession = nil
            self.workoutBuilder = nil
            try? await builder.endCollection(at: now)
            builder.discardWorkout()
        }
    }

    // MARK: - iOS 26+: Live workout with system UI indicator

    @available(iOS 26, *)
    private func startLiveWorkout(configuration: HKWorkoutConfiguration, startDate: Date) async throws {
        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )

        session.startActivity(with: startDate)
        try await builder.beginCollection(at: startDate)

        self.workoutSession = session
    }

    // MARK: - iOS 25 and earlier: Silent recording via HKWorkoutBuilder

    private func startSilentWorkout(configuration: HKWorkoutConfiguration, startDate: Date) async throws {
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        try await builder.beginCollection(at: startDate)
        self.workoutBuilder = builder
    }
}
#endif
