import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let monitors = MonitorCoordinator()
    private var menuBarController: MenuBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start monitoring
        monitors.startAll()

        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create and start menu bar controller
        menuBarController = MenuBarController(statusItem: statusItem, monitors: monitors)
        menuBarController.startUpdating()

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: DashboardView(monitors: monitors))
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController.stopUpdating()
        monitors.stopAll()
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
