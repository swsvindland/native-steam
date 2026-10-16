import SwiftUI

/// Store app page (DESIGN §4.1, pushed on select).
struct StoreAppPage: View {
    let appId: Int
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        Group {
            if let item = model.storeItem(appId) {
                content(item)
            } else {
                ContentUnavailableView("App not found", systemImage: "questionmark.square.dashed",
                                       description: Text("App \(appId) isn’t in this snapshot."))
            }
        }
        .background(Steam.storeBottom.ignoresSafeArea())
        .screenChrome(title: model.storeItem(appId)?.name ?? "Store", large: false, fullBleed: true)
        .focusScope("store.app.\(appId)")
    }

    private func content(_ item: StoreItem) -> some View {
        ScrollView {
            ZStack(alignment: .top) {
                PageBackdrop(url: item.images.background ?? item.images.hero ?? item.images.capsule)
                VStack(alignment: .leading, spacing: layout.isCompact ? 20 : 28) {
                    if layout.isCompact {
                        CompactHeader(item: item)
                    } else {
                        RegularHeader(item: item)
                    }
                    PurchaseBox(item: item)
                    if let description = item.shortDescription, layout.isCompact {
                        Text(description)
                            .font(.system(size: 15))
                            .foregroundStyle(Steam.textBody)
                            .lineSpacing(3)
                    }
                    if layout.isCompact {
                        InfoTable(item: item)
                    }
                }
                .padding(.horizontal, layout.gutter)
                .padding(.top, layout.isCompact ? 0 : 28)
                .padding(.bottom, 48)
                .frame(maxWidth: 1240)
                .frame(maxWidth: .infinity)
            }
        }
        .focusScrollContainer(.vertical)
        .ignoresSafeArea(edges: layout.isCompact ? .top : [])
    }
}

/// Darkened full-bleed store background that fades into the page colour.
private struct PageBackdrop: View {
    let url: String
    @Environment(\.layout) private var layout

    var body: some View {
        RemoteImage(url, maxPixel: 1920, placeholderColor: Steam.storeTop)
            .frame(height: layout.isCompact ? 360 : 620)
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: Steam.storeTop.opacity(0.6), location: 0),
                        .init(color: Steam.storeTop.opacity(0.8), location: 0.55),
                        .init(color: Steam.storeBottom, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
    }
}

// MARK: - Headers

private struct RegularHeader: View {
    let item: StoreItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text((["All Games"] + item.genres.prefix(1) + [item.name]).joined(separator: "  ›  "))
                    .font(.system(size: 12))
                    .foregroundStyle(Steam.textBody.opacity(0.8))
                Text(item.name)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Steam.textTitle)
            }
            .shadow(color: .black.opacity(0.5), radius: 8, y: 1)
            HStack(alignment: .top, spacing: 20) {
                MediaCarousel(item: item)
                    .frame(maxWidth: .infinity)
                InfoColumn(item: item)
                    .frame(width: 340)
            }
            .padding(14)
            .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: Radius.card))
        }
    }
}

private struct CompactHeader: View {
    let item: StoreItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Color.clear.frame(height: 96) // room under the transparent nav bar
            RemoteImage(item.images.header, maxPixel: 900, placeholder: item.name)
                .aspectRatio(Aspect.header, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
            Text(item.name)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Steam.textTitle)
            if let review = item.review {
                ReviewSummaryView(review: review)
            }
            MediaCarousel(item: item)
        }
    }
}

// MARK: - Screenshots carousel

private struct MediaCarousel: View {
    let item: StoreItem
    @Environment(\.layout) private var layout
    @State private var selected = 0

    var body: some View {
        if item.screenshots.isEmpty {
            RemoteImage(item.images.capsule, maxPixel: 1400, placeholder: item.name)
                .aspectRatio(Aspect.screenshot, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else if layout.isCompact {
            Shelf(Array(item.screenshots.enumerated()).map { IndexedShot(index: $0.offset, shot: $0.element) }, spacing: 10) { entry in
                RemoteImage(entry.shot.full, maxPixel: 1200)
                    .aspectRatio(Aspect.screenshot, contentMode: .fit)
                    .frame(width: 300)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card))
                    .steamFocusable("store.shot.\(entry.index)")
            }
        } else {
            VStack(spacing: 10) {
                let shot = item.screenshots[min(selected, item.screenshots.count - 1)]
                RemoteImage(shot.full, maxPixel: 1600)
                    .aspectRatio(Aspect.screenshot, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .id(shot.full)
                    .transition(.opacity)
                HStack(spacing: 8) {
                    ForEach(Array(item.screenshots.enumerated()), id: \.offset) { i, shot in
                        Button { withAnimation(.easeOut(duration: 0.2)) { selected = i } } label: {
                            RemoteImage(shot.thumbnail, maxPixel: 400)
                                .aspectRatio(Aspect.screenshot, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(i == selected ? Color.white : .clear, lineWidth: 2)
                                )
                                .opacity(i == selected ? 1 : 0.6)
                        }
                        .buttonStyle(.pressable)
                        .steamFocusable("store.shot.\(i)", cornerRadius: 3, lifts: false) {
                            withAnimation(.easeOut(duration: 0.2)) { selected = i }
                        }
                    }
                }
            }
        }
    }
}

private struct IndexedShot: Identifiable {
    let index: Int
    let shot: Screenshot
    var id: Int { index }
}

// MARK: - Info column

private struct InfoColumn: View {
    let item: StoreItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RemoteImage(item.images.header, maxPixel: 900, placeholder: item.name)
                .aspectRatio(Aspect.header, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            if let description = item.shortDescription {
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(Steam.textBody)
                    .lineSpacing(2)
                    .lineLimit(7)
            }
            InfoTable(item: item)
        }
    }
}

private struct InfoTable: View {
    let item: StoreItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let review = item.review {
                row("All Reviews") {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(review.label)
                            .foregroundStyle(Steam.reviewColor(review.tone))
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(review.percentPositive)% of \(review.totalLabel) positive")
                            .font(.system(size: 11))
                            .foregroundStyle(Steam.textSecondary)
                    }
                }
            }
            if let date = item.releaseDate {
                row("Release Date") { Text(date).font(.system(size: 12)).foregroundStyle(Steam.textBody) }
            }
            if !item.developers.isEmpty {
                row("Developer") {
                    Text(item.developers.joined(separator: ", "))
                        .font(.system(size: 12))
                        .foregroundStyle(Steam.accentLink)
                }
            }
            if let meta = item.metacritic {
                row("Metacritic") {
                    Text("\(meta)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(meta >= 75 ? Color(hex: 0x66CC33) : Color(hex: 0xFFCC33), in: RoundedRectangle(cornerRadius: 2))
                }
            }
            if !item.genres.isEmpty {
                FlowChips(items: item.genres)
            }
        }
    }

    private func row<V: View>(_ label: String, @ViewBuilder value: () -> V) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label).captionCaps(size: 10, color: Steam.textMuted)
                .frame(width: 96, alignment: .leading)
            value()
        }
    }
}

struct ReviewSummaryView: View {
    let review: ReviewSummary
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: review.tone == "negative" ? "hand.thumbsdown.fill" : "hand.thumbsup.fill")
                .foregroundStyle(Steam.reviewColor(review.tone))
            Text(review.label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Steam.reviewColor(review.tone))
            Text("\(review.percentPositive)% · \(review.totalLabel)")
                .font(.system(size: 13))
                .foregroundStyle(Steam.textSecondary)
        }
    }
}

/// Simple wrapping chips row.
struct FlowChips: View {
    let items: [String]
    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Steam.accentLink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: 0x67C1F5, opacity: 0.15), in: RoundedRectangle(cornerRadius: 3))
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Purchase box

private struct PurchaseBox: View {
    let item: StoreItem
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        let wishlisted = model.wishlist.contains(item.appId)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(item.price?.isFree == true ? "Play \(item.name)" : "Buy \(item.name)")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Steam.textTitle)
                    .lineLimit(1)
                Spacer(minLength: 8)
                PlatformIcons(item.platforms, size: 15)
            }
            HStack(spacing: 8) {
                if item.controllerSupport == "full" {
                    ControllerBadge(full: true)
                } else if item.controllerSupport == "partial" {
                    ControllerBadge(full: false)
                }
                if let ends = item.discountEndsLabel {
                    Text("SPECIAL PROMOTION! \(ends)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Steam.discountText)
                        .lineLimit(1)
                }
            }
            if layout.isCompact {
                PriceBlock(price: item.price, releaseDate: item.releaseDate, large: true)
                HStack(spacing: 10) {
                    cartButton
                    wishlistButton(wishlisted)
                }
            } else {
                HStack(spacing: 12) {
                    Spacer()
                    PriceBlock(price: item.price, releaseDate: item.releaseDate, large: true)
                    cartButton
                    wishlistButton(wishlisted)
                }
            }
        }
        .padding(layout.isCompact ? 14 : 18)
        .background(
            LinearGradient(colors: [Color(hex: 0x4C6B8A, opacity: 0.45), Color(hex: 0x1B2838, opacity: 0.6)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Radius.card)
        )
        .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Color.white.opacity(0.06)))
    }

    private var cartButton: some View {
        Button {} label: {
            GradientButtonLabel(item.price == nil ? "Follow" : (item.price?.isFree == true ? "Play Game" : "Add to Cart"),
                                systemImage: item.price == nil ? "bell.fill" : "cart.fill",
                                gradient: Steam.install, height: 44)
        }
        .buttonStyle(.pressable)
        .steamFocusable("store.app.cart", cornerRadius: Radius.button, isDefault: true, action: {}, secondary: {
            model.toggleWishlist(item.appId)
        })
    }

    private func wishlistButton(_ wishlisted: Bool) -> some View {
        Button { model.toggleWishlist(item.appId) } label: {
            SecondaryButtonLabel(wishlisted ? "On Wishlist" : "Wishlist",
                                 systemImage: wishlisted ? "heart.fill" : "heart")
        }
        .buttonStyle(.pressable)
        .steamFocusable("store.app.wishlist", cornerRadius: Radius.button, lifts: false) {
            model.toggleWishlist(item.appId)
        }
    }
}

struct ControllerBadge: View {
    let full: Bool
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "gamecontroller.fill")
            Text(full ? "Full Controller Support" : "Partial Controller Support")
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(full ? Steam.accentLink : Steam.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 3))
    }
}
