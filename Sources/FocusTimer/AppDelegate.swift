import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    let engine = TimerEngine()
    let store = SessionStore()
    private let notifications = NotificationManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "FocusTimer")
            button.imagePosition = .imageLeft
            button.title = " 25:00"
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 420)
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(engine: engine, store: store)
        )

        notifications.requestAuthorization()

        engine.onTick = { [weak self] time in
            self?.statusItem.button?.title = " \(time)"
        }

        engine.onStart = { [weak self] in
            guard let self, self.engine.focusModeEnabled else { return }
            FocusMode.enable()
        }

        engine.onComplete = { [weak self] session in
            guard let self else { return }
            if self.engine.focusModeEnabled { FocusMode.disable() }
            self.notifications.fireCompletion(for: session)
            Task {
                await self.store.save(session)
                await NotesIntegration.appendEntry(for: session)
            }
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
