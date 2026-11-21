import Cocoa

public final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu!

    /// Callback invoked when user selects "Open Window"
    public var onOpenWindow: (() -> Void)?

    /// Callback invoked when user selects "Quit"
    public var onQuitRequested: (() -> Void)?

    // Pre-rendered template badge icon initialized once.
    // Using isTemplate = true delegates tinting to macOS WindowServer GPU compositor,
    // eliminating appearance observation, KVO overhead, and dynamic drawing churn.
    private static let badgeIcon: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let badgeRect = rect.insetBy(dx: 1, dy: 1)
            let path = NSBezierPath(roundedRect: badgeRect, xRadius: 3.5, yRadius: 3.5)
            NSColor.black.setFill()
            path.fill()

            // Knock out "st" text using clear blend mode for monochrome template mask
            ctx.saveGState()
            ctx.setBlendMode(.clear)
            let baseFont = NSFont.systemFont(ofSize: 10, weight: .bold)
            let italicDescriptor = baseFont.fontDescriptor.withSymbolicTraits([.bold, .italic])
            let font = NSFont(descriptor: italicDescriptor, size: 10) ?? baseFont
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black
            ]
            let str = NSAttributedString(string: "st", attributes: attrs)
            let strSize = str.size()
            let strRect = NSRect(
                x: (rect.width - strSize.width) / 2,
                y: (rect.height - strSize.height) / 2 - 0.5,
                width: strSize.width,
                height: strSize.height
            )
            str.draw(in: strRect)
            ctx.restoreGState()
            return true
        }
        image.isTemplate = true
        return image
    }()

    public override init() {
        super.init()
        setupStatusItem()
        setupMenu()
    }

    public var currentMenu: NSMenu {
        return menu
    }

    public var currentStatusItem: NSStatusItem? {
        return statusItem
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.toolTip = "\(AppConfig.appName) — Running"
            button.image = Self.badgeIcon
        }
        self.statusItem = item
    }

    public func updateIcon() {
        // Template image is automatically tinted by WindowServer; no dynamic redrawing needed.
        statusItem?.button?.image = Self.badgeIcon
    }

    public static func renderBadgeIcon(isDark: Bool) -> NSImage {
        // Maintained for backward compatibility
        return badgeIcon
    }

    public func setupMenu() {
        menu = NSMenu()

        let appItem = NSMenuItem(
            title: "\(AppConfig.appName) v\(AppConfig.version)",
            action: nil,
            keyEquivalent: ""
        )
        appItem.isEnabled = false
        menu.addItem(appItem)

        menu.addItem(NSMenuItem.separator())

        if onOpenWindow != nil {
            let openWindowItem = NSMenuItem(
                title: "Open Window",
                action: #selector(openWindowAction),
                keyEquivalent: "o"
            )
            openWindowItem.target = self
            menu.addItem(openWindowItem)
            menu.addItem(NSMenuItem.separator())
        }

        let quitItem = NSMenuItem(
            title: "Quit \(AppConfig.appName)",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    public func refreshMenu() {
        setupMenu()
    }

    public func cleanup() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    @objc private func openWindowAction() {
        onOpenWindow?()
    }

    @objc private func quitAction() {
        if let onQuit = onQuitRequested {
            onQuit()
        } else {
            cleanup()
            NSApp.terminate(nil)
            exit(0)
        }
    }
}
