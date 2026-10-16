import AppKit
import SteamKit
import SwiftUI

@main
struct NativeSteamMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: AppModel
    @State private var engine = FocusEngine()

    init() {
        _model = State(initialValue: AppModel(snapshot: loadSnapshotOrDie()))
    }

    var body: some Scene {
        Window("Native Steam", id: "main") {
            SteamRootView(model: model, engine: engine)
                .frame(minWidth: 820, minHeight: 560)
                .background(WindowConfigurator(pinnedSize: model.launch.isAutomated ? CGSize(width: 1440, height: 900) : nil))
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 900)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.presented)
        .commands {
            SteamCommands(model: model, engine: engine)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// Configures the hosting NSWindow: Steam chrome colour, mouse-moved events for input
/// tracking, traffic lights centred in the 52 pt Steam nav bar, and (for screenshot
/// automation) a fixed 1440×900 content size.
private struct WindowConfigurator: NSViewRepresentable {
    let pinnedSize: CGSize?

    func makeNSView(context: Context) -> ConfiguringView {
        let view = ConfiguringView()
        view.pinnedSize = pinnedSize
        return view
    }

    func updateNSView(_ nsView: ConfiguringView, context: Context) {
        nsView.layoutTrafficLights()
    }

    final class ConfiguringView: NSView {
        var pinnedSize: CGSize?
        private var configured = false
        private var observers: [NSObjectProtocol] = []

        /// Height of the custom nav bar (TopNavBar) the traffic lights are centred in.
        private let barHeight: CGFloat = 52
        private let leadingInset: CGFloat = 20

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, !configured else { return }
            configured = true
            window.backgroundColor = NSColor(red: 0x17 / 255, green: 0x1A / 255, blue: 0x21 / 255, alpha: 1)
            window.acceptsMouseMovedEvents = true
            window.titlebarSeparatorStyle = .none
            window.tabbingMode = .disallowed

            let names: [Notification.Name] = [
                NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification,
                NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                NSWindow.didExitFullScreenNotification, NSWindow.didUpdateNotification,
            ]
            for name in names {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.layoutTrafficLights() }
                })
            }
            if let size = pinnedSize {
                DispatchQueue.main.async {
                    window.setContentSize(size)
                    window.center()
                    self.layoutTrafficLights()
                }
            }
            layoutTrafficLights()
        }


        /// Vertically centres the close / minimise / zoom buttons in the nav bar.
        func layoutTrafficLights() {
            guard let window, !window.styleMask.contains(.fullScreen),
                  let close = window.standardWindowButton(.closeButton),
                  let mini = window.standardWindowButton(.miniaturizeButton),
                  let zoom = window.standardWindowButton(.zoomButton),
                  let titlebar = close.superview else { return }
            let spacing: CGFloat = 20
            let titlebarHeight = titlebar.frame.height
            for (i, button) in [close, mini, zoom].enumerated() {
                let y = titlebarHeight - barHeight / 2 - button.frame.height / 2
                let origin = NSPoint(x: leadingInset + CGFloat(i) * spacing, y: y)
                if button.frame.origin != origin { button.setFrameOrigin(origin) }
            }
        }
    }
}
