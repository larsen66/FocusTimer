import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    var engine: TimerEngine
    @ObservedObject var store: SessionStore
    @State private var durationText: String = "25:00"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                sectionLabel("Timer")
                tile {
                    HStack {
                        Text("Session duration")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.soft)
                        Spacer()
                        TextField("MM:SS", text: $durationText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.bright)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .onSubmit { applyDuration() }
                    }
                    Button("Apply") { applyDuration() }
                        .buttonStyle(PrimaryBtn())
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 4)
                }

                sectionLabel("History")
                historyTile

                sectionLabel("Export")
                tile {
                    HStack(spacing: 8) {
                        Button("JSON") { exportJSON() }.buttonStyle(GhostBtn())
                        Button("CSV") { exportCSV() }.buttonStyle(GhostBtn())
                    }
                }

                sectionLabel("Apple Notes")
                tile {
                    Text("After each session, a log entry is written to the selected note. Format: [S3] Task — 25 min")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(Color.ink)
        .onAppear {
            let s = engine.sessionDuration
            durationText = String(format: "%d:%02d", s / 60, s % 60)
        }
    }

    private func applyDuration() {
        let t = durationText.trimmingCharacters(in: .whitespaces)
        let parts = t.components(separatedBy: ":")
        let seconds: Int
        if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]) {
            seconds = m * 60 + s
        } else if let m = Int(t) {
            seconds = m * 60
        } else {
            return
        }
        guard seconds > 0 else { return }
        engine.sessionDuration = seconds
        // Reformat canonical
        durationText = String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - History

    private var historyTile: some View {
        VStack(spacing: 0) {
            let stats = store.dailyStats()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.soft)
                    Text("\(stats.totalSessions) sessions · \(stats.totalMinutes) min")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.dim)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if store.sessions.isEmpty {
                Text("No sessions yet")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                Divider().background(Color(white: 0.16))
                let recent = Array(store.sessions.suffix(8).reversed().enumerated())
                let total = store.sessions.count
                ForEach(recent, id: \.offset) { offset, session in
                    let num = total - offset   // session number (most recent = total)
                    sessionRow(session, number: num)
                    if offset < recent.count - 1 {
                        Divider().background(Color(white: 0.13)).padding(.horizontal, 12)
                    }
                }
            }
        }
        .background(Color.inkMid)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(white: 0.16), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func sessionRow(_ session: Session, number: Int) -> some View {
        HStack(spacing: 10) {
            // Session number badge
            Text("S\(number)")
                .font(.system(size: 9, weight: .semibold))
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Capsule().fill(orangeGradient))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 1) {
                Text(session.taskName)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.soft)
                    .lineLimit(1)
                if let note = session.noteTitle {
                    Text(note)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.meshOrange.opacity(0.65))
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(session.durationSeconds / 60) min")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.dim)
                Text(session.startDate.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 9))
                    .foregroundStyle(Color(white: 0.25))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    // MARK: - Layout helpers

    @ViewBuilder
    private func tile<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(12)
        .background(Color.inkMid)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(white: 0.16), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.bottom, 4)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(Color.dim)
            .tracking(1.4)
            .padding(.top, 14)
            .padding(.bottom, 6)
            .padding(.horizontal, 4)
    }

    // MARK: - Export

    private func exportJSON() {
        guard let data = try? store.exportJSON(), let str = String(data: data, encoding: .utf8) else { return }
        savePanel(str, ext: "json")
    }

    private func exportCSV() {
        savePanel(store.exportCSV(), ext: "csv")
    }

    private func savePanel(_ content: String, ext: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = ext == "json" ? [.json] : [.commaSeparatedText]
        panel.nameFieldStringValue = "FocusTimer.\(ext)"
        panel.begin { resp in
            if resp == .OK, let url = panel.url {
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
