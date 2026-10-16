import SwiftUI

/// The adaptive shell (DESIGN §2): a bottom tab bar on compact widths (< 700 pt),
/// a Steam-desktop top nav bar on regular widths. One NavigationStack per tab.
public struct SteamRootView: View {
    let model: AppModel
    @State private var engine: FocusEngine
    @State private var coordinator: InputCoordinator

    public init(model: AppModel, engine: FocusEngine) {
        self.model = model
        _engine = State(initialValue: engine)
        _coordinator = State(initialValue: InputCoordinator(model: model, engine: engine))
    }

    public var body: some View {
        GeometryReader { geo in
            let layout = LayoutMetrics(width: geo.size.width)
            ShellView(isCompact: layout.isCompact)
                .environment(\.layout, layout)
        }
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { engine.viewport = $0 }
        .environment(model)
        .environment(engine)
        .preferredColorScheme(.dark)
        .tint(Steam.accent)
        #if os(iOS)
        .background(TouchObserverInstaller(coordinator: coordinator))
        #endif
        .task { coordinator.start() }
        .onChange(of: model.tab) { _, _ in
            if engine.showsFocus { engine.requestDefaultFocus() }
        }
        .onChange(of: model.currentPath) { _, _ in
            if engine.showsFocus { engine.requestDefaultFocus() }
        }
    }
}

private struct ShellView: View {
    let isCompact: Bool
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    #if os(macOS)
    @FocusState private var systemFocus: String?
    #endif

    var body: some View {
        Group {
            if isCompact {
                CompactShell()
            } else {
                RegularShell()
            }
        }
        .onAppear(perform: configureTabBarFocus)
        .onChange(of: isCompact) { _, _ in configureTabBarFocus() }
        #if os(macOS)
        .environment(\.systemFocusBinding, $systemFocus)
        .onChange(of: engine.focusedID) { _, id in
            if systemFocus != id { systemFocus = id }
        }
        .onChange(of: systemFocus) { _, id in
            // Follow SwiftUI focus only right after a Tab key press; ignore the automatic
            // focus AppKit assigns when the window becomes key or a view goes away.
            if let id, id != engine.focusedID, Date() < engine.acceptsSystemFocusUntil { engine.focus(id) }
        }
        #endif
    }

    private func configureTabBarFocus() {
        if isCompact {
            engine.focusTabBar = nil
        } else {
            let model = model
            let engine = engine
            engine.focusTabBar = { engine.focus("chrome.tab.\(model.tab.rawValue)") }
        }
    }
}

// MARK: - Regular

private struct RegularShell: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine

    var body: some View {
        VStack(spacing: 0) {
            TopNavBar()
                .zIndex(1)
            ZStack {
                TabStack(tab: model.tab)
                    .id(model.tab)
                    .transition(.opacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                // Fills the horizontal safe areas (e.g. iPhone landscape) behind the stack.
                Group {
                    if model.tab == .store || model.tab == .community {
                        Steam.storeBackground
                    } else {
                        Steam.libraryBackground
                    }
                }
                .ignoresSafeArea()
            }
        }
        .overlay(alignment: .bottom) {
            if engine.showsHints { HintsBar() }
        }
        .animation(.easeOut(duration: 0.2), value: engine.showsHints)
        .background(Steam.bgChrome.ignoresSafeArea())
        #if os(macOS)
        .ignoresSafeArea(.container, edges: .top)
        #endif
    }
}

// MARK: - Compact

private struct CompactShell: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.tab) {
            Tab("STORE", systemImage: AppTab.store.systemImage, value: AppTab.store) {
                TabStack(tab: .store)
            }
            Tab("LIBRARY", systemImage: AppTab.library.systemImage, value: AppTab.library) {
                TabStack(tab: .library)
            }
            Tab("COMMUNITY", systemImage: AppTab.community.systemImage, value: AppTab.community) {
                TabStack(tab: .community)
            }
            Tab(value: AppTab.profile) {
                TabStack(tab: .profile)
            } label: {
                Label {
                    Text(model.persona.uppercased())
                } icon: {
                    AvatarTabIcon(url: model.snapshot.user.avatarUrl)
                }
            }
        }
    }
}

/// The persona tab shows the user's avatar (DESIGN §2).
private struct AvatarTabIcon: View {
    let url: String
    @State private var image: DecodedImage?

    var body: some View {
        Group {
            #if os(iOS)
            if let image, let ui = Self.tabImage(image) {
                Image(uiImage: ui).renderingMode(.original)
            } else {
                Image(systemName: AppTab.profile.systemImage)
            }
            #else
            Image(systemName: AppTab.profile.systemImage)
            #endif
        }
        .task {
            image = await ImagePipeline.shared.load(url, maxPixel: 96)
        }
    }

    #if os(iOS)
    static func tabImage(_ image: DecodedImage) -> UIImage? {
        let size = CGSize(width: 26, height: 26)
        let renderer = UIGraphicsImageRenderer(size: size)
        let rendered = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(roundedRect: rect, cornerRadius: 5).addClip()
            UIImage(cgImage: image.cgImage).draw(in: rect)
            UIColor(Steam.statusOnline).setStroke()
            let border = UIBezierPath(roundedRect: rect.insetBy(dx: 0.75, dy: 0.75), cornerRadius: 5)
            border.lineWidth = 1.5
            border.stroke()
        }
        return rendered.withRenderingMode(.alwaysOriginal)
    }
    #endif
}

// MARK: - Tab stack

struct TabStack: View {
    let tab: AppTab
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    @Environment(\.layout) private var layout

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.paths[tab]) {
            TabRoot(tab: tab)
                .navigationDestination(for: Route.self) { route in
                    RouteView(route: route)
                }
        }
        #if os(iOS)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if layout.isCompact && engine.showsHints { HintsBar() }
        }
        #endif
    }
}

private struct TabRoot: View {
    let tab: AppTab

    var body: some View {
        switch tab {
        case .store: StoreView()
        case .library: LibraryView()
        case .community: CommunityView()
        case .profile: ProfileView()
        }
    }
}

struct RouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case .storeApp(let id): StoreAppPage(appId: id)
        case .game(let id): GamePage(appId: id)
        case .friends: FriendsPage()
        }
    }
}

// MARK: - Per-screen chrome

extension View {
    /// Applies the screen-level navigation chrome: on regular widths the system bar is
    /// hidden (the Steam top nav bar takes over); on compact iOS it's a native bar.
    /// `fullBleed` pages put artwork under a transparent bar: no inline title, no edge effect.
    func screenChrome(title: String, large: Bool = true, fullBleed: Bool = false) -> some View {
        modifier(ScreenChrome(title: title, large: large, fullBleed: fullBleed))
    }
}

private struct ScreenChrome: ViewModifier {
    let title: String
    var large: Bool
    var fullBleed: Bool
    @Environment(\.layout) private var layout

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(large ? .large : .inline)
            .toolbar(layout.isCompact ? .automatic : .hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(!layout.isCompact)
            .scrollEdgeEffectHidden(fullBleed, for: .top)
            .toolbar {
                if fullBleed {
                    ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) }
                }
            }
        #else
        content
            .navigationTitle(title)
            .navigationBarBackButtonHidden(true) // the Steam nav bar has its own back button
        #endif
    }
}
