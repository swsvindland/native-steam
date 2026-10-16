import SwiftUI

/// FEATURED & RECOMMENDED hero carousel (DESIGN §4.1.2).
struct FeaturedCarousel: View {
    let items: [StoreItem]
    @Environment(\.layout) private var layout

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else if layout.isCompact {
            FeaturedCompact(items: items)
        } else {
            FeaturedRegular(items: items)
        }
    }
}

// MARK: - Regular: big card + right panel, dots, arrows, auto-advance

private struct FeaturedRegular: View {
    let items: [StoreItem]
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    @State private var index = 0
    @State private var hovering = false

    private var paused: Bool {
        hovering || engine.focusedID == "store.featured" || model.launch.isAutomated
    }

    var body: some View {
        let item = items[index % items.count]
        VStack(spacing: 14) {
            ZStack {
                Button { open(item) } label: {
                    FeaturedRegularCard(item: item)
                }
                .buttonStyle(PressableStyle(pressedScale: 0.99))
                .id(item.appId)
                .transition(.opacity)
            }
            .steamFocusable(
                "store.featured", scales: false, lifts: false, isDefault: true,
                action: { open(items[index % items.count]) },
                secondary: { model.toggleWishlist(items[index % items.count].appId) },
                onMove: { dir in
                    switch dir {
                    case .left: advance(-1); return true
                    case .right: advance(1); return true
                    default: return false
                    }
                }
            )
            .overlay { arrows }
            .onHover { hovering = $0 }
            .shadow(color: .black.opacity(0.45), radius: 18, y: 10)

            PageDots(count: items.count, index: index % items.count) { i in
                withAnimation(.easeInOut(duration: 0.35)) { index = i }
            }
        }
        .task(id: index) {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled, !paused else { return }
            advance(1)
        }
    }

    private var arrows: some View {
        HStack {
            arrowButton("chevron.left") { advance(-1) }
            Spacer()
            arrowButton("chevron.right") { advance(1) }
        }
        .padding(.horizontal, 10)
        .opacity(hovering && engine.input == .pointer ? 1 : 0)
        .animation(.easeOut(duration: 0.15), value: hovering)
    }

    private func arrowButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 72)
                .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.12)))
        }
        .buttonStyle(.pressable)
    }

    private func advance(_ delta: Int) {
        withAnimation(.easeInOut(duration: 0.35)) {
            index = (index + delta + items.count) % items.count
        }
    }

    private func open(_ item: StoreItem) { model.push(.storeApp(item.appId)) }
}

private struct FeaturedRegularCard: View {
    let item: StoreItem

    var body: some View {
        GeometryReader { geo in
            let capsuleWidth = geo.size.width * 0.62
            HStack(spacing: 0) {
                RemoteImage(item.images.capsule, maxPixel: 1400, placeholder: item.name)
                    .frame(width: capsuleWidth, height: geo.size.height)
                FeaturedPanel(item: item)
                    .frame(width: geo.size.width - capsuleWidth, height: geo.size.height)
            }
        }
        .aspectRatio(1 / (0.62 / Aspect.capsule), contentMode: .fit)
        .background(
            LinearGradient(colors: [Color(hex: 0x0F1922), Color(hex: 0x213246)], startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

private struct FeaturedPanel: View {
    let item: StoreItem

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(item.name)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Steam.textTitle)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            ViewThatFits(in: .vertical) {
                screenshots(rows: 2)
                screenshots(rows: 1)
                Color.clear.frame(height: 0)
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                ForEach(item.genres.prefix(3), id: \.self) { genre in
                    Text(genre)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Steam.textBody)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                PlatformIcons(item.platforms, size: 13)
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.comingSoon ? "Coming Soon" : "Now Available")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Steam.textTitle)
                    if let review = item.review {
                        Text(review.label)
                            .font(.system(size: 13))
                            .foregroundStyle(Steam.reviewColor(review.tone))
                    } else if let date = item.releaseDate {
                        Text(date)
                            .font(.system(size: 13))
                            .foregroundStyle(Steam.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                PriceBlock(price: item.price, releaseDate: item.releaseDate)
            }
        }
        .padding(14)
    }

    private func screenshots(rows: Int) -> some View {
        let shots = Array(item.screenshots.prefix(rows * 2))
        return Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(0..<rows, id: \.self) { row in
                GridRow {
                    ForEach(0..<2, id: \.self) { col in
                        let i = row * 2 + col
                        RemoteImage(i < shots.count ? shots[i].thumbnail : nil, maxPixel: 600)
                            .aspectRatio(Aspect.screenshot, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }
            }
        }
    }
}

// MARK: - Compact: swipe-paged capsule cards with name + price overlay

private struct FeaturedCompact: View {
    let items: [StoreItem]
    @Environment(AppModel.self) private var model
    @State private var position = ScrollPosition(idType: Int.self)

    private var current: Int {
        position.viewID(type: Int.self) ?? items.first?.appId ?? 0
    }

    var body: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(items) { item in
                        Button { model.push(.storeApp(item.appId)) } label: {
                            FeaturedCompactCard(item: item)
                        }
                        .buttonStyle(.pressable)
                        .containerRelativeFrame(.horizontal)
                        .steamFocusable("store.featured.\(item.appId)", isDefault: item.appId == items.first?.appId,
                                        action: { model.push(.storeApp(item.appId)) },
                                        secondary: { model.toggleWishlist(item.appId) })
                        .id(item.appId)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 10)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, Space.m, for: .scrollContent)
            .focusScrollContainer(.horizontal, margin: Space.m, position: $position)
            .padding(.horizontal, -Space.m)
            .padding(.vertical, -10)

            PageDots(count: items.count, index: items.firstIndex { $0.appId == current } ?? 0) { i in
                withAnimation { position.scrollTo(id: items[i].appId) }
            }
        }
        .task(id: current) {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled, !model.launch.isAutomated else { return }
            let i = items.firstIndex { $0.appId == current } ?? 0
            withAnimation(.easeInOut(duration: 0.4)) {
                position.scrollTo(id: items[(i + 1) % items.count].appId)
            }
        }
    }
}

private struct FeaturedCompactCard: View {
    let item: StoreItem

    var body: some View {
        RemoteImage(item.images.capsule, maxPixel: 1200, placeholder: item.name)
            .aspectRatio(Aspect.capsule, contentMode: .fit)
            .overlay(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if let review = item.review {
                            Text(review.label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Steam.reviewColor(review.tone))
                        }
                    }
                    Spacer(minLength: 6)
                    PriceBlock(price: item.price, releaseDate: item.releaseDate)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .padding(.top, 40)
                .background(
                    LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.card + 4, style: .continuous))
    }
}

// MARK: - Dots

struct PageDots: View {
    let count: Int
    let index: Int
    var select: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Button { select(i) } label: {
                    Capsule()
                        .fill(i == index ? Steam.accentLink : Color.white.opacity(0.2))
                        .frame(width: i == index ? 22 : 14, height: 6)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Page \(i + 1) of \(count)")
            }
        }
        .animation(.easeOut(duration: 0.2), value: index)
    }
}
