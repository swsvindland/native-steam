import SwiftUI

/// Menu-bar commands: ⌘1–4 switch tabs, ⌘[ back, ⌘F search (macOS + iPadOS menu bar).
public struct SteamCommands: Commands {
    let model: AppModel
    let engine: FocusEngine

    public init(model: AppModel, engine: FocusEngine) {
        self.model = model
        self.engine = engine
    }

    public var body: some Commands {
        CommandGroup(before: .toolbar) {
            ForEach(AppTab.allCases) { tab in
                Button(model.title(for: tab)) {
                    model.tab = tab
                }
                .keyboardShortcut(tab.shortcutKey, modifiers: .command)
            }
            Divider()
        }
        CommandMenu("Go") {
            Button("Back") { model.pop() }
                .keyboardShortcut("[", modifiers: .command)
            Button("Next Tab") { model.nextTab() }
                .keyboardShortcut("]", modifiers: [.command, .shift])
            Button("Previous Tab") { model.previousTab() }
                .keyboardShortcut("[", modifiers: [.command, .shift])
        }
        CommandGroup(after: .textEditing) {
            Button("Search") {
                if model.tab != .store && model.tab != .library { model.tab = .store }
                model.paths[model.tab] = []
                model.requestSearch()
            }
            .keyboardShortcut("f", modifiers: .command)
        }
    }
}
