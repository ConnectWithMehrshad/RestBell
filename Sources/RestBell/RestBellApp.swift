import AppKit
import SwiftUI

@main
@MainActor
final class RestBellApp: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let bell = BellPlayer()
    private lazy var timer = TimerModel(
        duration: TimerSettings.duration,
        beep: { [bell] in bell.play(TimerSettings.bellSound) },
        onStateChange: { [weak self] state in self?.updateStatusItem(for: state) }
    )
    private let statusItem = NSStatusBar.system.statusItem(withLength: 80)
    private let statusFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
    private let durationsItem = NSMenuItem.sectionHeader(title: "")
    private let timerItem = NSMenuItem()
    private lazy var settingsWindow: NSWindow = {
        let window = NSWindow(contentViewController: NSHostingController(rootView: TimerSettingsView()))
        window.title = "RestBell Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }()

    static func main() {
        let app = NSApplication.shared
        let delegate = RestBellApp()
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        LaunchAtLogin.configureDefault()
        configureEditMenu()
        timerItem.target = self
        timerItem.action = #selector(toggleTimer)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        let quitItem = NSMenuItem(title: "Quit RestBell", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp

        let menu = NSMenu()
        menu.items = [durationsItem, timerItem, settingsItem, .separator(), quitItem]
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.alignment = .center
        updateStatusItem(for: timer.state)
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer.pauseAndReset()
        bell.stop()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let isReady = timer.state == .ready
        timerItem.title = isReady ? "Start" : "Reset"
        durationsItem.isHidden = !isReady
        if isReady {
            let work = TimerSettings.minutes(for: .work)
            let rest = TimerSettings.minutes(for: .rest)
            durationsItem.title = "\(work) min work · \(rest) min rest"
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    private func updateStatusItem(for state: TimerModel.State) {
        statusItem.button?.attributedTitle = NSAttributedString(string: state.title, attributes: [.font: statusFont])
    }

    private func configureEditMenu() {
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let editItem = NSMenuItem()
        editItem.submenu = editMenu
        let mainMenu = NSMenu()
        // AppKit reserves the first item for the application menu.
        mainMenu.items = [NSMenuItem(), editItem]
        NSApp.mainMenu = mainMenu
    }

    @objc private func toggleTimer() {
        if timer.state == .ready {
            timer.start()
        } else {
            timer.pauseAndReset()
            bell.stop()
        }
    }

    @objc private func showSettings() {
        NSApp.activate()
        settingsWindow.makeKeyAndOrderFront(nil)
        settingsWindow.orderFrontRegardless()
    }
}
