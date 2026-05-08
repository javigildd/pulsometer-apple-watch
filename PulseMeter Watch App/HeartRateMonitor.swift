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
    private var hrQuery: HKAnchoredObjectQuery?

    private var lastZone: Zone?
    private var lastAlertDate: Date = .distantPast
    private var armed: Bool = false
    private let repeatAlertInterval: TimeInterval = 25
    private let crossingCooldown: TimeInterval = 5

    func start() {
        Task { await requestAuthAndStart() }
    }

    private func requestAuthAndStart() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let hrType = HKQuantityType(.heartRate)
        let typesToRead: Set<HKObjectType> = [hrType]
        let typesToShare: Set<HKSampleType> = [HKQuantityType.workoutType()]

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            try startSession()
            startHeartRateQuery()
            isRunning = true
        } catch {
            print("PulseMeter: auth/start error: \(error)")
        }
    }

    private func startSession() throws {
        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .unknown

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        session.delegate = self
        session.startActivity(with: Date())
        self.session = session
    }

    private func startHeartRateQuery() {
        let hrType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: Date(),
            end: nil,
            options: .strictStartDate
        )

        let query = HKAnchoredObjectQuery(
            type: hrType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.process(samples: samples)
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.process(samples: samples)
        }

        healthStore.execute(query)
        self.hrQuery = query
    }

    private nonisolated func process(samples: [HKSample]?) {
        guard let qs = samples as? [HKQuantitySample], !qs.isEmpty else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let sorted = qs.sorted { $0.endDate < $1.endDate }
        guard let latest = sorted.last?.quantity.doubleValue(for: unit) else { return }
        Task { @MainActor [weak self] in
            self?.handleNewHR(latest)
        }
    }

    func stop() {
        session?.end()
        session = nil
        if let query = hrQuery {
            healthStore.stop(query)
            hrQuery = nil
        }
        isRunning = false
        currentHeartRate = 0
        lastZone = nil
        armed = false
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
            if newZone == .inRange || newZone == .above { armed = true }
        }

        // First sample: just establish baseline.
        guard let previous = lastZone else { return }

        let now = Date()
        let timeSinceLast = now.timeIntervalSince(lastAlertDate)
        let zoneChanged = (newZone != previous)

        let shouldFire: Bool = {
            switch newZone {
            case .inRange:
                return false
            case .above:
                if zoneChanged { return timeSinceLast >= crossingCooldown }
                return timeSinceLast >= repeatAlertInterval
            case .below:
                guard armed else { return false }
                if zoneChanged { return timeSinceLast >= crossingCooldown }
                return timeSinceLast >= repeatAlertInterval
            }
        }()

        guard shouldFire else { return }

        switch newZone {
        case .above:   playDoubleHaptic()
        case .below:   playSingleHaptic()
        case .inRange: break
        }
        lastAlertDate = now
    }

    private func playSingleHaptic() {
        WKInterfaceDevice.current().play(.start)
    }

    private func playDoubleHaptic() {
        let device = WKInterfaceDevice.current()
        device.play(.failure)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            device.play(.failure)
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
