import Cocoa
import os

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(subsystem: AppConfig.bundleIdentifier, category: "Application")
    private var statusBarController: StatusBarController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusBarController = StatusBarController()
        Self.logger.info("\(AppConfig.appName, privacy: .public) started successfully.")
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
