import AppKit

@main
@MainActor
struct YiyiApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        // strong reference lifetime for the delegate
        _ = delegate
        app.run()
    }
}
