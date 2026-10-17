import Cocoa

public final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var appearanceObservation: NSKeyValueObservation?

    public override init() {
        super.init()
        setupStatusItem()
        setupMenu()
        setupAppearanceObserver()
    }

    public var currentMenu: NSMenu {
        return menu
    }

    public var currentStatusItem: NSStatusItem {
        return statusItem
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.toolTip = "\(AppConfig.appName) — Running"
        }
        updateIcon()
    }

    private func setupAppearanceObserver() {
        // Observe application appearance changes
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateIcon()
            }
        }

        // Also observe system-wide theme changes (Light/Dark mode toggle)
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateIcon()
        }
    }

    public func updateIcon() {
        guard let button = statusItem.button else { return }

        // Determine effective appearance from button / system
        let appearance = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) ?? NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        let isDark = (appearance == .darkAqua)

        button.image = Self.renderBadgeIcon(isDark: isDark)
    }

    public static func renderBadgeIcon(isDark: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let badgeRect = rect.insetBy(dx: 1, dy: 1)
            let path = NSBezierPath(roundedRect: badgeRect, xRadius: 3.5, yRadius: 3.5)

            // Light mode: black background, white "sa" text
            // Dark mode: white background, black "sa" text
            let bgColor = isDark ? NSColor.white : NSColor.black
            let textColor = isDark ? NSColor.black : NSColor.white

            bgColor.setFill()
            path.fill()

            let font = NSFont.systemFont(ofSize: 10, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor
            ]
            let str = NSAttributedString(string: "sa", attributes: attrs)
            let strSize = str.size()
            let strRect = NSRect(
                x: (rect.width - strSize.width) / 2,
                y: (rect.height - strSize.height) / 2 - 0.5,
                width: strSize.width,
                height: strSize.height
            )
            str.draw(in: strRect)
            return true
        }
        // Explicitly set isTemplate = false so macOS does not monochrome tint it
        image.isTemplate = false
        return image
    }

    private func setupMenu() {
        menu = NSMenu()

        let appItem = NSMenuItem(
            title: "\(AppConfig.appName) v\(AppConfig.version)",
            action: nil,
            keyEquivalent: ""
        )
        appItem.isEnabled = false
        menu.addItem(appItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit \(AppConfig.appName)",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }
}
