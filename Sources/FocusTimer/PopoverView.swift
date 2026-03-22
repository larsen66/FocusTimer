import SwiftUI

// MARK: - Design tokens

extension Color {
    static let meshOrange    = Color(red: 0.56, green: 0.20, blue: 0.03)
    static let meshOrangeHi  = Color(red: 0.66, green: 0.26, blue: 0.05)
    static let meshOrangeDim = Color(red: 0.44, green: 0.13, blue: 0.01)
    static let ink           = Color(white: 0.055)
    static let inkMid        = Color(white: 0.10)
    static let inkLight      = Color(white: 0.16)
    static let dim           = Color(white: 0.28)
    static let muted         = Color(white: 0.45)
    static let soft          = Color(white: 0.68)
    static let bright        = Color(white: 0.90)
}

var orangeGradient: LinearGradient {
    LinearGradient(
        colors: [Color.meshOrange, Color.meshOrange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Grain overlay (rasterised once via drawingGroup)

struct GrainOverlay: View {
    var opacity: Double = 0.045
    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRandom(seed: 42)
            let count = Int(size.width * size.height * 0.22)
            for _ in 0..<count {
                let x     = rng.next() * size.width
                let y     = rng.next() * size.height
                let br    = 0.5 + rng.next() * 0.5
                let alpha = opacity * (0.4 + rng.next() * 0.6)
                ctx.fill(
                    Path(CGRect(x: x, y: y, width: 1.0, height: 1.0)),
                    with: .color(Color(white: br, opacity: alpha))
                )
            }
        }
        .allowsHitTesting(false)
        .drawingGroup()
    }
}

private struct SeededRandom {
    private var s: UInt32
    init(seed: UInt32) { s = seed == 0 ? 1 : seed }
    mutating func next() -> Double {
        s ^= s << 13; s ^= s >> 17; s ^= s << 5
        return Double(s) / Double(UInt32.max)
    }
}

// MARK: - Button styles

struct PrimaryBtn: ButtonStyle {
    var wide = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .frame(maxWidth: wide ? .infinity : nil)
            .padding(.horizontal, wide ? 0 : 20)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(orangeGradient)
                    .overlay(GrainOverlay(opacity: 0.08).clipShape(Capsule()))
            )
            .foregroundStyle(Color(white: 0.92))
            .brightness(configuration.isPressed ? -0.07 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.13), value: configuration.isPressed)
    }
}

struct GhostBtn: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, design: .monospaced))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(Color.inkLight)
                    .overlay(Capsule().stroke(Color(white: 0.20), lineWidth: 0.5))
            )
            .foregroundStyle(Color.muted)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.13), value: configuration.isPressed)
    }
}

// MARK: - Custom top tab bar

private enum AppTab { case timer, settings }

struct PopoverView: View {
    var engine: TimerEngine
    @ObservedObject var store: SessionStore
    @State private var activeTab: AppTab = .timer

    var body: some View {
        VStack(spacing: 0) {
            tabBar

            Divider()
                .background(Color(white: 0.13))

            ZStack {
                if activeTab == .timer {
                    TimerDisplayView(engine: engine, store: store)
                        .transition(.opacity)
                } else {
                    SettingsView(engine: engine, store: store)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 300, height: 420)
        .background(meshBackground)
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            tabButton(.timer,    icon: "timer",     label: "TIMER")
            tabButton(.settings, icon: "gearshape", label: "SETTINGS")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Color(white: 0.04)
                .overlay(GrainOverlay(opacity: 0.025))
        )
    }

    @ViewBuilder
    private func tabButton(_ tab: AppTab, icon: String, label: String) -> some View {
        let active = activeTab == tab
        Button {
            withAnimation(.easeInOut(duration: 0.14)) { activeTab = tab }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: active ? .semibold : .regular))
                Text(label)
                    .font(.system(size: 10, weight: active ? .semibold : .regular, design: .monospaced))
                    .tracking(0.6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(
                Group {
                    if active {
                        Capsule().fill(orangeGradient)
                            .overlay(GrainOverlay(opacity: 0.07).clipShape(Capsule()))
                    } else {
                        Capsule().fill(Color.clear)
                    }
                }
            )
            .foregroundStyle(active ? Color(white: 0.92) : Color.dim)
        }
        .buttonStyle(.plain)
    }

    private var meshBackground: some View {
        ZStack {
            Color.ink
            RadialGradient(
                colors: [Color.meshOrangeHi.opacity(0.30), .clear],
                center: UnitPoint(x: 0.88, y: 0.04),
                startRadius: 0, endRadius: 220
            )
            RadialGradient(
                colors: [Color.meshOrangeDim.opacity(0.20), .clear],
                center: UnitPoint(x: 0.08, y: 0.94),
                startRadius: 0, endRadius: 175
            )
            RadialGradient(
                colors: [Color(red: 0.50, green: 0.10, blue: 0.0).opacity(0.09), .clear],
                center: UnitPoint(x: 0.48, y: 0.44),
                startRadius: 0, endRadius: 145
            )
            GrainOverlay(opacity: 0.038)
        }
        .ignoresSafeArea()
    }
}
