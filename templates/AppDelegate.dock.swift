import Cocoa
import os

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(subsystem: AppConfig.bundleIdentifier, category: "Application")

    private var statusBarController: StatusBarController?

    // Lazy window initialization: backing store and view hierarchy are allocated only on demand,
    // saving ~16MB of resident memory during routine background/status bar operation.
    private lazy var window: NSWindow = createWindow()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupMainMenu()

        let sbController = StatusBarController()
        sbController.onOpenWindow = { [weak self] in
            self?.showWindow()
        }
        sbController.refreshMenu()
        self.statusBarController = sbController

        Self.logger.info("\(AppConfig.appName, privacy: .public) started successfully.")
    }

    public func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // Application Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About \(AppConfig.appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())

        let hideItem = NSMenuItem(title: "Hide \(AppConfig.appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(hideItem)

        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)

        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit \(AppConfig.appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu

        // Window Menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)

        let windowMenu = NSMenu(title: "Window")
        let openWindowItem = NSMenuItem(title: "Open Window", action: #selector(openWindowFromMenu), keyEquivalent: "o")
        openWindowItem.target = self
        windowMenu.addItem(openWindowItem)
        windowMenu.addItem(NSMenuItem.separator())

        let closeItem = NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(closeItem)
        let minimizeItem = NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(minimizeItem)
        windowMenuItem.submenu = windowMenu

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }

    @objc private func openWindowFromMenu() {
        showWindow()
    }

    private func createWindow() -> NSWindow {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 340),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.center()
        win.title = AppConfig.appName

        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .centerX
        container.distribution = .gravityAreas
        container.spacing = 14
        container.edgeInsets = NSEdgeInsets(top: 36, left: 32, bottom: 36, right: 32)

        let iconImage = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage
        if let iconImage = iconImage {
            let iconView = NSImageView(image: iconImage)
            iconView.imageScaling = .scaleProportionallyUpOrDown
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.widthAnchor.constraint(equalToConstant: 80).isActive = true
            iconView.heightAnchor.constraint(equalToConstant: 80).isActive = true
            container.addArrangedSubview(iconView)
        }

        let titleLabel = NSTextField(labelWithString: AppConfig.appName)
        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.alignment = .center
        container.addArrangedSubview(titleLabel)

        let versionLabel = NSTextField(labelWithString: "Version \(AppConfig.version) (Build \(AppConfig.buildNumber))")
        versionLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center
        container.addArrangedSubview(versionLabel)

        let statusLabel = NSTextField(labelWithString: "Your macOS application is running.")
        statusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = .labelColor
        statusLabel.alignment = .center
        container.addArrangedSubview(statusLabel)

        let quitButton = NSButton(title: "Quit \(AppConfig.appName)", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        quitButton.bezelStyle = .rounded
        container.addArrangedSubview(quitButton)

        win.contentView = container
        return win
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
