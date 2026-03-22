import Foundation

/// Activates / deactivates macOS Do Not Disturb via Shortcuts CLI.
/// On first use, auto-generates + signs the required shortcuts and opens them
/// for a one-time "Add" confirmation in the Shortcuts app.
enum FocusMode {

    static func enable()  { Task.detached(priority: .userInitiated) { runShortcut("Focus On")  } }
    static func disable() { Task.detached(priority: .userInitiated) { runShortcut("Focus Off") } }

    // MARK: - One-time setup

    /// Returns true if both shortcuts already exist.
    static func shortcutsExist() -> Bool {
        let list = shell("/usr/bin/shortcuts", args: ["list"])
        return list.contains("Focus On") && list.contains("Focus Off")
    }

    /// Generates, signs, and opens both shortcut files for the user to accept once.
    static func setupShortcuts() {
        for (option, name) in [("on", "Focus On"), ("off", "Focus Off")] {
            guard let signed = buildShortcut(option: option, name: name) else { continue }
            shell("/usr/bin/open", args: [signed.path])
            // Small delay so Shortcuts shows each dialog separately
            Thread.sleep(forTimeInterval: 1.0)
        }
    }

    // MARK: - Private helpers

    private static func runShortcut(_ name: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        p.arguments = ["run", name]
        p.standardOutput = FileHandle.nullDevice
        p.standardError  = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }

    @discardableResult
    private static func shell(_ path: String, args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError  = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    /// Builds and signs a minimal "Set Focus" shortcut file, returns the signed URL.
    private static func buildShortcut(option: String, name: String) -> URL? {
        let plist: [String: Any] = [
            "WFWorkflowClientVersion": "1249.2",
            "WFWorkflowClientRelease": "release",
            "WFWorkflowMinimumClientVersion": 900,
            "WFWorkflowMinimumClientVersionString": "900",
            "WFWorkflowHasShortcutInputVariables": false,
            "WFWorkflowIcon": [
                "WFWorkflowIconGlyphNumber": 59512,
                "WFWorkflowIconStartColor": 431817727
            ] as [String: Any],
            "WFWorkflowImportQuestions": [] as [Any],
            "WFWorkflowInputContentItemClasses": [] as [Any],
            "WFWorkflowOutputContentItemClasses": [] as [Any],
            "WFWorkflowTypes": [] as [Any],
            "WFWorkflowActions": [
                [
                    "WFWorkflowActionIdentifier": "is.workflow.actions.setfocus",
                    "WFWorkflowActionParameters": [
                        "WFSetFocusModeOption": option,
                        "WFFocusModeIdentifier": "com.apple.focus.do-not-disturb"
                    ] as [String: Any]
                ] as [String: Any]
            ] as [Any]
        ]

        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0) else {
            return nil
        }

        let tmp  = URL(fileURLWithPath: NSTemporaryDirectory())
        let raw  = tmp.appendingPathComponent("\(name).shortcut")
        let signed = tmp.appendingPathComponent("\(name)_signed.shortcut")
        try? data.write(to: raw, options: .atomic)

        shell("/usr/bin/shortcuts", args: ["sign", "--mode", "anyone",
                                           "--input",  raw.path,
                                           "--output", signed.path])
        return FileManager.default.fileExists(atPath: signed.path) ? signed : raw
    }
}
