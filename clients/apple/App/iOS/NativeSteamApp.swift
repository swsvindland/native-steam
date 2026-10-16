import SteamKit
import SwiftUI
import UIKit

@main
struct NativeSteamApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: AppModel
    @State private var engine = FocusEngine()

    init() {
        _model = State(initialValue: AppModel(snapshot: loadSnapshotOrDie()))
    }

    var body: some Scene {
        WindowGroup {
            SteamRootView(model: model, engine: engine)
                .onAppear(perform: applyOrientationOverride)
        }
        .commands {
            SteamCommands(model: model, engine: engine)
        }
    }

    /// Screenshot automation: `-orientation landscape` asks the scene to rotate
    /// (the headless simulator has no rotate command).
    private func applyOrientationOverride() {
        guard UserDefaults.standard.string(forKey: "orientation")?.lowercased() == "landscape" else { return }
        DispatchQueue.main.async {
            for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { error in
                    print("orientation request failed: \(error)")
                }
                scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        UserDefaults.standard.string(forKey: "orientation")?.lowercased() == "landscape" ? .landscape : .all
    }
}
