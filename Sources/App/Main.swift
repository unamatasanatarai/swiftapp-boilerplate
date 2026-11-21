import AppKit

@main
struct AppMain {
    // Retain strong reference to delegate for the lifetime of NSApp.run()
    private static var appDelegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        autoreleasepool {
            let delegate = AppDelegate()
            appDelegate = delegate
            app.delegate = delegate
        }
        app.run()
    }
}
