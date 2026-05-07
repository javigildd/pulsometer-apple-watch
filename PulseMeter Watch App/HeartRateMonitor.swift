import Foundation
import HealthKit
import WatchKit
import Combine

@MainActor
final class HeartRateMonitor: NSObject, ObservableObject {
    enum Zone { case below, inRange, above }

    @Published var currentHeartRate: Double = 0
    @Published var isRunning: Bool = false
    @Published var zone: Zone = .inRange

    var minBPM: Double = 150
    var maxBPM: Double = 170

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private var lastZone: Zone?
    private var lastAlertDate: Date = .distantPast
    private let alertCooldown: TimeInterval = 10

    func start() {
        Task { await requestAuthAndStart() }
    }

    private func requestAuthAndStart() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let hrType = HKQuantityType(.heartRate)
        let typesToRead: Set<HKObjectType> = [hrType, HKObjectType.activitySummaryType()]
        let typesToShare: Set<HKSampleType> = [HKQuantityType.workoutType()]

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            try startWorkout()
        } catch {
            print("PulseMeter: auth/start error: \(error)")
        }
    }

    private func startWorkout() throws {
        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .unknown

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: config
        )

        session.delegate = self
        builder.delegate = self

        self.session = session
        self.builder = builder

        let startDate = Date()
        session.startActivity(with: startDate)
        builder.beginCollection(withStart: startDate) { [weak self] success, error in
            Task { @MainActor in
                if success {
                    self?.isRunning = true
                } else if let error {
                    print("PulseMeter: beginCollection error: \(error)")
                }
            }
        }
    }

    func stop() {
        session?.end()
        let activeBuilder = builder
        activeBuilder?.endCollection(withEnd: Date()) { _, _ in
            activeBuilder?.finishWorkout { _, _ in }
        }
        isRunning = false
        currentHeartRate = 0
        lastZone = nil
        zone = .inRange
    }

    fileprivate func handleNewHR(_ bpm: Double) {
        guard bpm > 0 else { return }
        currentHeartRate = bpm

        let newZone: Zone
        if bpm > maxBPM { newZone = .above }
        else if bpm < minBPM { newZone = .below }
        else { newZone = .inRange }

        defer {
            zone = newZone
            lastZone = newZone
        }

        guard let previous = lastZone, previous != newZone else { return }

        let now = Date()
        guard now.timeIntervalSince(lastAlertDate) >= alertCooldown else { return }

        switch newZone {
        case .above:
            playDoubleHaptic()
            lastAlertDate = now
        case .below:
            // Only alert when slowing down from running, not when warming up.
            if previous == .inRange || previous == .above {
                playSingleHaptic()
                lastAlertDate = now
            }
        case .inRange:
            break
        }
    }

    private func playSingleHaptic() {
        WKInterfaceDevice.current().play(.notification)
    }

    private func playDoubleHaptic() {
        let device = WKInterfaceDevice.current()
        device.play(.notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            device.play(.notification)
        }
    }
}

extension HeartRateMonitor: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        print("PulseMeter: session failed: \(error)")
    }
}

extension HeartRateMonitor: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let hrType = HKQuantityType(.heartRate)
        guard collectedTypes.contains(hrType) else { return }
        guard let stats = workoutBuilder.statistics(for: hrType) else { return }

        let unit = HKUnit.count().unitDivided(by: .minute())
        guard let bpm = stats.mostRecentQuantity()?.doubleValue(for: unit) else { return }

        Task { @MainActor [weak self] in
            self?.handleNewHR(bpm)
        }
    }
}
