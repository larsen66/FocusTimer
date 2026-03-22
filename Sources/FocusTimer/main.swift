import AppKit

// Top-level code in main.swift is implicitly @MainActor in Swift 6.
// Direct bootstrap — no NIB, no storyboard, no @main.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
