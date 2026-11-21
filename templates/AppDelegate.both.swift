import Cocoa
import os

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(subsystem: AppConfig.bundleIdentifier, category: "Application")

    private var statusBarController: StatusBarController?

    // Lazy window initialization: backing store and view hierarchy are allocated only on demand,
    // saving ~16MB of resident memory during routine background/status bar operation.
    private var mainWindow: NSWindow?

    // MARK: - Double Cmd+Q to Exit
    private var lastQuitRequestTime: TimeInterval = 0
    private let doubleQuitThreshold: TimeInterval = 2.0
    private var quitNoticeWindow: NSPanel?
    private var quitNoticeTimer: Timer?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupMainMenu()

        let sbController = StatusBarController()
        sbController.onOpenWindow = { [weak self] in
            self?.showWindow()
        }
        sbController.onQuitRequested = { [weak self] in
            self?.handleQuitRequested(nil)
        }
        sbController.refreshMenu()
        self.statusBarController = sbController

        showWindow()

        Self.logger.info("\(AppConfig.appName, privacy: .public) started successfully.")
    }

    public func showWindow() {
        let win = getOrCreateWindow()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func getOrCreateWindow() -> NSWindow {
        if let win = mainWindow { return win }
        let win = createWindow()
        mainWindow = win
        return win
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

        let quitItem = NSMenuItem(title: "Quit \(AppConfig.appName)", action: #selector(handleQuitRequested(_:)), keyEquivalent: "q")
        quitItem.target = self
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

    @objc public func handleQuitRequested(_ sender: Any?) {
        let now = ProcessInfo.processInfo.systemUptime
        let isKeyboardShortcut: Bool = {
            guard let event = NSApp.currentEvent, event.type == .keyDown else { return false }
            return event.modifierFlags.contains(.command) && (event.charactersIgnoringModifiers == "q" || event.characters == "q")
        }()

        if !isKeyboardShortcut || (now - lastQuitRequestTime <= doubleQuitThreshold) {
            quitNoticeTimer?.invalidate()
            if let panel = quitNoticeWindow {
                mainWindow?.removeChildWindow(panel)
                panel.orderOut(nil)
            }
            statusBarController?.cleanup()
            NSApp.terminate(nil)
            exit(0)
        }

        lastQuitRequestTime = now
        showQuitNotice()
    }

    private func showQuitNotice() {
        quitNoticeTimer?.invalidate()

        let panel: NSPanel
        if let existing = quitNoticeWindow {
            panel = existing
        } else {
            let newPanel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 210, height: 38),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newPanel.level = .floating
            newPanel.isOpaque = false
            newPanel.backgroundColor = .clear
            newPanel.hasShadow = true
            newPanel.ignoresMouseEvents = true

            let container = RoundedHUDView(frame: NSRect(x: 0, y: 0, width: 210, height: 38))
            let label = NSTextField(labelWithString: "Press ⌘Q again to quit")
            label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
            label.textColor = .white
            label.alignment = .center
            label.isBezeled = false
            label.drawsBackground = false
            label.isEditable = false
            label.isSelectable = false
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)

            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])

            newPanel.contentView = container
            self.quitNoticeWindow = newPanel
            panel = newPanel
        }

        // Center directly inside the application window if visible, otherwise center on screen
        let centerRect: NSRect
        if let appWin = mainWindow, appWin.isVisible {
            centerRect = appWin.frame
            appWin.addChildWindow(panel, ordered: .above)
        } else if let screen = NSScreen.main ?? NSScreen.screens.first {
            centerRect = screen.visibleFrame
            panel.orderFrontRegardless()
        } else {
            centerRect = NSRect(x: 0, y: 0, width: 800, height: 600)
            panel.orderFrontRegardless()
        }

        let x = centerRect.midX - panel.frame.width / 2
        let y = centerRect.midY - panel.frame.height / 2
        panel.setFrameOrigin(NSPoint(x: round(x), y: round(y)))

        panel.alphaValue = 0.0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1.0
        }

        quitNoticeTimer = Timer.scheduledTimer(withTimeInterval: doubleQuitThreshold, repeats: false) { [weak self, weak panel] _ in
            guard let self = self, let panel = panel else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                panel.animator().alphaValue = 0.0
            }, completionHandler: {
                self.mainWindow?.removeChildWindow(panel)
                panel.orderOut(nil)
                self.lastQuitRequestTime = 0
            })
        }
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

        let quitButton = NSButton(title: "Quit \(AppConfig.appName)", target: self, action: #selector(handleQuitRequested(_:)))
        quitButton.bezelStyle = .rounded
        container.addArrangedSubview(quitButton)

        win.contentView = container
        return win
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }

    public func applicationWillTerminate(_ notification: Notification) {
        statusBarController?.cleanup()
        exit(0)
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

// MARK: - Rounded Pill HUD View
private final class RoundedHUDView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let pillRect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: pillRect, xRadius: pillRect.height / 2, yRadius: pillRect.height / 2)
        NSColor(white: 0.12, alpha: 0.94).setFill()
        path.fill()

        NSColor(white: 1.0, alpha: 0.18).setStroke()
        path.lineWidth = 1.0
        path.stroke()
    }
}
