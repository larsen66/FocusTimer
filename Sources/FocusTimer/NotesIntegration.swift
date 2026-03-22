import Foundation
import AppKit

struct NoteItem: Sendable, Identifiable, Hashable {
    var id: String { "\(folder)//\(title)" }
    let folder: String
    let title: String
}

enum NotesIntegration {

    // MARK: - Fetch all notes (folder + title)

    static func fetchAllNotes() async -> [NoteItem] {
        let script = """
        tell application "Notes"
            set noteList to {}
            repeat with f in folders
                set fName to name of f
                repeat with n in notes of f
                    set end of noteList to fName & "||" & (name of n)
                end repeat
            end repeat
            return noteList
        end tell
        """
        let raw = await runScriptList(script)
        return raw.compactMap { s -> NoteItem? in
            let parts = s.components(separatedBy: "||")
            guard parts.count >= 2 else { return nil }
            return NoteItem(folder: parts[0], title: parts[1...].joined(separator: "||"))
        }
    }

    // MARK: - Fetch tasks/items from a specific note

    static func fetchNoteTasks(from note: NoteItem) async -> [String] {
        let escapedTitle = escapeAS(note.title)
        let escapedFolder = escapeAS(note.folder)
        let script = """
        tell application "Notes"
            try
                set theFolder to folder "\(escapedFolder)"
                set theNote to note "\(escapedTitle)" of theFolder
                return body of theNote
            on error
                try
                    set theNote to first note whose name is "\(escapedTitle)"
                    return body of theNote
                on error
                    return ""
                end try
            end try
        end tell
        """
        let html = await runScriptString(script) ?? ""
        return extractItems(from: html)
    }

    // MARK: - Add a task item to an existing note

    static func addTaskToNote(_ task: String, to note: NoteItem) async {
        let escapedTask   = escapeAS(task)
        let escapedNote   = escapeAS(note.title)
        let escapedFolder = escapeAS(note.folder)
        // Append as a proper HTML bullet list item — Notes renders <ul><li> as a bullet point
        let bullet = "<ul><li>\(escapedTask)</li></ul>"
        let script = """
        tell application "Notes"
            try
                set theFolder to folder "\(escapedFolder)"
                set theNote to note "\(escapedNote)" of theFolder
                set body of theNote to (body of theNote) & "\(bullet)"
            on error
                try
                    set theNote to first note whose name is "\(escapedNote)"
                    set body of theNote to (body of theNote) & "\(bullet)"
                end try
            end try
        end tell
        """
        await MainActor.run { runScriptSync(script) }
    }

    // MARK: - Create a new note

    /// Creates a new note in the given folder and returns the resulting NoteItem.
    static func createNote(title: String, inFolder folder: String = "FocusTimer") async -> NoteItem? {
        let escapedTitle  = escapeAS(title)
        let escapedFolder = escapeAS(folder)
        let script = """
        tell application "Notes"
            if not (exists folder "\(escapedFolder)") then
                make new folder with properties {name:"\(escapedFolder)"}
            end if
            set theFolder to folder "\(escapedFolder)"
            if not (exists note "\(escapedTitle)" of theFolder) then
                make new note at theFolder with properties {name:"\(escapedTitle)", body:""}
            end if
        end tell
        """
        await MainActor.run { runScriptSync(script) }
        return NoteItem(folder: folder, title: title)
    }

    // MARK: - Prepend session log to the task bullet line

    static func appendEntry(for session: Session) async {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "dd.MM"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        let mins = session.logDurationSeconds / 60
        let secs = session.logDurationSeconds % 60
        let duration = secs > 0 ? "\(mins):\(String(format: "%02d", secs)) min" : "\(mins) min"
        let entry = "[\(dateFmt.string(from: session.startDate)), \(timeFmt.string(from: session.startDate))][\(duration)]"

        if let noteTitle = session.noteTitle, !session.taskName.isEmpty {
            await prependEntryToTaskLine(entry: entry, task: session.taskName, noteTitle: noteTitle)
        } else if let noteTitle = session.noteTitle {
            // No task name — prepend to top of the note
            let esc = escapeAS(entry)
            let escapedNote = escapeAS(noteTitle)
            let script = """
            tell application "Notes"
                try
                    set theNote to first note whose name is "\(escapedNote)"
                    set body of theNote to "\(esc)<br>" & (body of theNote)
                end try
            end tell
            """
            await MainActor.run { runScriptSync(script) }
        } else {
            // No note selected — write to FocusTimer Log
            let esc = escapeAS(entry)
            let folder  = escapeAS("FocusTimer")
            let logNote = escapeAS("FocusTimer Log")
            let script = """
            tell application "Notes"
                if not (exists folder "\(folder)") then
                    make new folder with properties {name:"\(folder)"}
                end if
                set theFolder to folder "\(folder)"
                if not (exists note "\(logNote)" of theFolder) then
                    make new note at theFolder with properties {name:"\(logNote)", body:"FocusTimer Log"}
                end if
                set theNote to note "\(logNote)" of theFolder
                set body of theNote to "\(esc)<br>" & (body of theNote)
            end tell
            """
            await MainActor.run { runScriptSync(script) }
        }
    }

    /// Fetches the note body, inserts `entry` before `task` on its bullet line, writes back.
    private static func prependEntryToTaskLine(entry: String, task: String, noteTitle: String) async {
        let escapedNote = escapeAS(noteTitle)

        // 1. Fetch body HTML
        let getScript = """
        tell application "Notes"
            try
                set theNote to first note whose name is "\(escapedNote)"
                return body of theNote
            on error
                return ""
            end try
        end tell
        """
        guard let html = await runScriptString(getScript), !html.isEmpty else { return }

        // 2. Find the task text in the HTML and insert entry before it (first occurrence)
        let modified: String
        if let range = html.range(of: task) {
            modified = String(html[html.startIndex..<range.lowerBound])
                     + entry + " "
                     + String(html[range.lowerBound...])
        } else {
            // Task not found in body — prepend to top
            modified = entry + "<br>" + html
        }

        // 3. Write back
        let escapedBody = escapeAS(modified)
        let setScript = """
        tell application "Notes"
            try
                set theNote to first note whose name is "\(escapedNote)"
                set body of theNote to "\(escapedBody)"
            end try
        end tell
        """
        await MainActor.run { runScriptSync(setScript) }
    }

    // MARK: - HTML parsing

    private static func extractItems(from html: String) -> [String] {
        var items: [String] = []

        // Try <li> items first (checklists and bullet lists)
        if let regex = try? NSRegularExpression(pattern: "<li[^>]*>(.*?)</li>", options: [.dotMatchesLineSeparators, .caseInsensitive]) {
            let ns = html as NSString
            for match in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
                let range = match.range(at: 1)
                if range.location != NSNotFound {
                    let raw = ns.substring(with: range)
                    let stripped = stripTags(raw)
                    if !stripped.isEmpty { items.append(stripped) }
                }
            }
        }

        // Fallback: try <p> paragraphs
        if items.isEmpty {
            if let regex = try? NSRegularExpression(pattern: "<p[^>]*>(.*?)</p>", options: [.dotMatchesLineSeparators, .caseInsensitive]) {
                let ns = html as NSString
                for match in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
                    let range = match.range(at: 1)
                    if range.location != NSNotFound {
                        let raw = ns.substring(with: range)
                        let stripped = stripTags(raw)
                        if !stripped.isEmpty { items.append(stripped) }
                    }
                }
            }
        }

        // Deduplicate preserving order
        var seen = Set<String>()
        return items.filter { seen.insert($0).inserted }
    }

    private static func stripTags(_ html: String) -> String {
        let s = html
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return s
    }

    // MARK: - AppleScript runners

    private static func escapeAS(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    static func runScriptList(_ source: String) async -> [String] {
        await MainActor.run {
            var error: NSDictionary?
            guard let script = NSAppleScript(source: source) else { return [] }
            let result = script.executeAndReturnError(&error)
            if let error { print("AppleScript error: \(error)") }
            guard result.numberOfItems > 0 else { return [] }
            var items: [String] = []
            for i in 1...result.numberOfItems {
                if let s = result.atIndex(i)?.stringValue { items.append(s) }
            }
            return items
        }
    }

    private static func runScriptString(_ source: String) async -> String? {
        await MainActor.run {
            var error: NSDictionary?
            guard let script = NSAppleScript(source: source) else { return nil }
            let result = script.executeAndReturnError(&error)
            if let error { print("AppleScript error: \(error)") }
            return result.stringValue
        }
    }

    private static func runScriptSync(_ source: String) {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return }
        script.executeAndReturnError(&error)
        if let error { print("AppleScript error: \(error)") }
    }
}
