import SwiftUI

/// Steam-desktop style top nav bar for regular widths (DESIGN §2):
/// `[‹] STEAM  STORE  LIBRARY  COMMUNITY  KESTREL  ……  [search] [friends] [avatar]`
struct TopNavBar: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    @Environment(\.layout) private var layout

    private var barHeight: CGFloat {
        #if os(macOS)
        52
        #else
        56
        #endif
    }

    private var leadingInset: CGFloat {
        #if os(macOS)
        78 // traffic lights
        #else
        layout.gutter - 8
        #endif
    }

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: leadingInset, height: 1)

            Button { model.pop() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(model.canGoBack ? Steam.textBody : Steam.textMuted.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .disabled(!model.canGoBack)
            .steamFocusable("chrome.back", cornerRadius: 4, scales: false, lifts: false, isChrome: true, action: { model.pop() })
            .accessibilityLabel("Back")
            .help("Back (⌘[)")

            SteamWordmark(size: 16)
                .fixedSize()
                .padding(.leading, 10)
                .padding(.trailing, layout.width < 1150 ? 16 : 30)

            if engine.gamepadConnected {
                ControllerGlyph(.lb, size: 20).padding(.trailing, 12)
            }

            HStack(spacing: layout.width < 1150 ? 8 : 18) {
                ForEach(AppTab.allCases) { tab in
                    TopTabButton(tab: tab)
                }
            }
            .steamFocusSection()

            if engine.gamepadConnected {
                ControllerGlyph(.rb, size: 20).padding(.leading, 12)
            }

            Spacer(minLength: 16)

            HStack(spacing: 10) {
                SearchAffordance(iconOnly: layout.width < 1250)
                FriendsButton()
                ProfileChip(showsName: layout.width >= 1150)
            }
            .padding(.trailing, layout.gutter - 8)
        }
        .frame(height: barHeight)
        .background {
            Steam.bgChrome
                .overlay(alignment: .bottom) { Rectangle().fill(Color.black.opacity(0.35)).frame(height: 1) }
                .ignoresSafeArea(edges: .top)
            #if os(macOS)
                .gesture(WindowDragGesture())
                .allowsWindowActivationEvents(true)
            #endif
        }
        .focusScope("chrome")
    }
}

private struct TopTabButton: View {
    let tab: AppTab
    @Environment(AppModel.self) private var model

    var body: some View {
        let active = model.tab == tab
        Button { model.select(tab) } label: {
            TopTabLabel(title: model.title(for: tab).uppercased(), active: active)
        }
        .buttonStyle(.pressable)
        .steamFocusable("chrome.tab.\(tab.rawValue)", cornerRadius: 4, scales: false, lifts: false, isChrome: true) {
            model.select(tab)
        }
        .accessibilityAddTraits(active ? .isSelected : [])
        .help("\(model.title(for: tab)) (⌘\(String(tab.shortcutKey.character)))")
    }
}

private struct TopTabLabel: View {
    let title: String
    let active: Bool
    @Environment(\.cardHighlighted) private var highlighted

    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .semibold))
            .tracking(1.3)
            .foregroundStyle(active ? Steam.textTitle : (highlighted ? Steam.textBody : Steam.textSecondary))
            .padding(.horizontal, 6)
            .frame(maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Steam.accent)
                    .frame(height: 3)
                    .opacity(active ? 1 : 0)
            }
            .contentShape(Rectangle())
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct SearchAffordance: View {
    var iconOnly = false
    @Environment(AppModel.self) private var model

    var body: some View {
        Button { search() } label: {
            SearchAffordanceLabel(iconOnly: iconOnly)
        }
        .buttonStyle(.pressable)
        .steamFocusable("chrome.search", cornerRadius: 15, scales: false, lifts: false, isChrome: true, action: search)
        .accessibilityLabel("Search")
    }

    private func search() {
        if model.tab != .store && model.tab != .library { model.tab = .store }
        model.paths[model.tab] = []
        model.requestSearch()
    }
}

private struct SearchAffordanceLabel: View {
    var iconOnly = false
    @Environment(\.cardHighlighted) private var highlighted
    var body: some View {
        if iconOnly {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Steam.textBody)
                .frame(width: 34, height: 30)
                .background(Capsule().fill(highlighted ? Steam.surfaceHover : Color.white.opacity(0.07)))
        } else {
            field
        }
    }

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
            Text("Search")
            Spacer(minLength: 8)
            #if os(macOS)
            Text("⌘F").font(.system(size: 11, weight: .medium)).foregroundStyle(Steam.textMuted)
            #endif
        }
        .font(.system(size: 13))
        .foregroundStyle(Steam.textSecondary)
        .padding(.horizontal, 12)
        .frame(width: 184, height: 30)
        .background(Capsule().fill(highlighted ? Steam.surfaceHover : Color.white.opacity(0.07)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
    }
}

private struct FriendsButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button { open() } label: {
            FriendsButtonLabel(online: model.onlineFriendCount)
        }
        .buttonStyle(.pressable)
        .steamFocusable("chrome.friends", cornerRadius: 15, scales: false, lifts: false, isChrome: true, action: open)
        .accessibilityLabel("Friends, \(model.onlineFriendCount) online")
        .help("Friends")
    }

    private func open() {
        model.tab = .community
        model.paths[.community] = [.friends]
    }
}

private struct FriendsButtonLabel: View {
    let online: Int
    @Environment(\.cardHighlighted) private var highlighted
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2.fill")
            Text("\(online)")
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
            Circle().fill(Steam.statusOnline).frame(width: 6, height: 6)
        }
        .font(.system(size: 13))
        .foregroundStyle(Steam.textBody)
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Capsule().fill(highlighted ? Steam.surfaceHover : Color.white.opacity(0.07)))
        .fixedSize()
    }
}

private struct ProfileChip: View {
    var showsName = true
    @Environment(AppModel.self) private var model

    var body: some View {
        Button { model.select(.profile) } label: {
            ProfileChipLabel(user: model.snapshot.user, showsName: showsName)
        }
        .buttonStyle(.pressable)
        .steamFocusable("chrome.avatar", cornerRadius: 6, scales: false, lifts: false, isChrome: true) {
            model.select(.profile)
        }
        .accessibilityLabel("\(model.persona), online")
    }
}

private struct ProfileChipLabel: View {
    let user: UserProfile
    var showsName = true
    @Environment(\.cardHighlighted) private var highlighted
    var body: some View {
        HStack(spacing: 8) {
            AvatarView(user.avatarUrl, status: user.status, size: 26, borderWidth: 1.5)
            if showsName {
                nameStack
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, showsName ? 10 : 4)
        .frame(height: 38)
        .background(RoundedRectangle(cornerRadius: 6).fill(highlighted ? Steam.surfaceHover : .clear))
    }

    private var nameStack: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(user.personaName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Steam.statusOnline)
                    .fixedSize()
                Text("Online")
                    .font(.system(size: 10))
                    .foregroundStyle(Steam.textSecondary)
            }
    }
}
