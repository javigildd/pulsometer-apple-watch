import SwiftUI

struct ContentView: View {
    @StateObject private var monitor = HeartRateMonitor()
    @AppStorage("minBPM") private var minBPM: Int = 150
    @AppStorage("maxBPM") private var maxBPM: Int = 170

    var body: some View {
        NavigationStack {
            if monitor.isRunning {
                runningView
            } else {
                idleView
            }
        }
    }

    private var idleView: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("PulseMeter")
                    .font(.headline)
                Text("\(minBPM) – \(maxBPM) BPM")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Button {
                    monitor.minBPM = Double(minBPM)
                    monitor.maxBPM = Double(maxBPM)
                    monitor.start()
                } label: {
                    Label("Empezar", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .tint(.green)

                NavigationLink {
                    SettingsView(minBPM: $minBPM, maxBPM: $maxBPM)
                } label: {
                    Label("Ajustes", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var runningView: some View {
        VStack(spacing: 4) {
            Text(monitor.currentHeartRate > 0 ? "\(Int(monitor.currentHeartRate))" : "--")
                .font(.system(size: 70, weight: .bold, design: .rounded))
                .foregroundStyle(zoneColor)
                .contentTransition(.numericText())
                .animation(.snappy, value: monitor.currentHeartRate)

            Text("BPM")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("\(minBPM) – \(maxBPM)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button(role: .destructive) {
                monitor.stop()
            } label: {
                Label("Parar", systemImage: "stop.fill")
            }
            .padding(.top, 4)
        }
    }

    private var zoneColor: Color {
        switch monitor.zone {
        case .below:   return .blue
        case .inRange: return .green
        case .above:   return .red
        }
    }
}

struct SettingsView: View {
    @Binding var minBPM: Int
    @Binding var maxBPM: Int

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Mínimo").font(.caption).foregroundStyle(.secondary)
                    Stepper(value: $minBPM, in: 60...219, step: 1) {
                        Text("\(minBPM) BPM").font(.title3.bold())
                    }
                    .onChange(of: minBPM) { _, new in
                        if new >= maxBPM { maxBPM = min(220, new + 1) }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Máximo").font(.caption).foregroundStyle(.secondary)
                    Stepper(value: $maxBPM, in: 61...220, step: 1) {
                        Text("\(maxBPM) BPM").font(.title3.bold())
                    }
                    .onChange(of: maxBPM) { _, new in
                        if new <= minBPM { minBPM = max(60, new - 1) }
                    }
                }

                Text("Por encima del máx → 2 vibraciones.\nAl bajar al mínimo → 1 vibración.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Rango")
    }
}

#Preview {
    ContentView()
}
