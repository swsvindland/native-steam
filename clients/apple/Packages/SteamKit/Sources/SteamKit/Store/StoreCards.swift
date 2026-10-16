import SwiftUI

/// Shelf card: `header` artwork, name, a subtitle line and the price block.
struct StoreShelfCard: View {
    let item: StoreItem
    var subtitle: String?
    let focusID: String
    var width: CGFloat
    var isDefault = false

    @Environment(AppModel.self) private var model

    var body: some View {
        Button(action: open) {
            StoreShelfCardContent(item: item, subtitle: subtitle, wishlisted: model.wishlist.contains(item.appId))
                .frame(width: width)
        }
        .buttonStyle(.pressable)
        .steamFocusable(focusID, isDefault: isDefault, action: open, secondary: { model.toggleWishlist(item.appId) })
        .accessibilityLabel(item.name)
    }

    private func open() { model.push(.storeApp(item.appId)) }
}

private struct StoreShelfCardContent: View {
    let item: StoreItem
    var subtitle: String?
    var wishlisted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(item.images.header, maxPixel: 700, placeholder: item.name)
                .aspectRatio(Aspect.header, contentMode: .fit)
                .overlay(alignment: .topTrailing) {
                    if wishlisted {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Steam.accent, in: Circle())
                            .padding(8)
                    }
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Steam.textTitle)
                    .lineLimit(1)
                Text(subtitle ?? " ")
                    .font(.system(size: 12))
                    .foregroundStyle(Steam.textSecondary)
                    .lineLimit(1)
                HStack(alignment: .center, spacing: 8) {
                    if let review = item.review {
                        HStack(spacing: 5) {
                            ToneDot(review.tone)
                            Text(review.label)
                                .font(.system(size: 11))
                                .foregroundStyle(Steam.reviewColor(review.tone))
                                .lineLimit(1)
                        }
                    } else if !item.genres.isEmpty {
                        Text(item.genres.prefix(2).joined(separator: " · "))
                            .font(.system(size: 11))
                            .foregroundStyle(Steam.textMuted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    PriceBlock(price: item.price)
                }
                .padding(.top, 4)
            }
            .padding(10)
        }
        .background(CardBackground())
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

/// Compact list row (Top Sellers on regular): small capsule, name, platforms, review dot, price.
struct StoreListRow: View {
    let item: StoreItem
    let focusID: String

    @Environment(AppModel.self) private var model

    var body: some View {
        Button(action: open) {
            StoreListRowContent(item: item)
        }
        .buttonStyle(.pressable)
        .steamFocusable(focusID, lifts: false, action: open, secondary: { model.toggleWishlist(item.appId) })
        .accessibilityLabel(item.name)
    }

    private func open() { model.push(.storeApp(item.appId)) }
}

private struct StoreListRowContent: View {
    let item: StoreItem

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(item.images.smallCapsule, maxPixel: 400, placeholder: nil)
                .frame(width: 128, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            VStack(alignment: .leading, spacing: 5) {
                Text(item.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Steam.textTitle)
                    .lineLimit(1)
                HStack(spacing: 10) {
                    PlatformIcons(item.platforms, size: 11)
                    if let review = item.review {
                        HStack(spacing: 5) {
                            ToneDot(review.tone)
                            Text(review.label)
                                .font(.system(size: 11))
                                .foregroundStyle(Steam.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            PriceBlock(price: item.price, releaseDate: item.releaseDate)
        }
        .padding(8)
        .background(CardBackground())
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

/// Ranked Most Played row.
struct MostPlayedRow: View {
    let entry: ChartEntry
    let focusID: String

    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        Button(action: open) {
            MostPlayedRowContent(entry: entry, compact: layout.isCompact)
        }
        .buttonStyle(.pressable)
        .steamFocusable(focusID, lifts: false, action: open)
        .accessibilityLabel("Number \(entry.rank), \(entry.name), \(entry.currentPlayersLabel)")
    }

    private func open() { model.push(.storeApp(entry.appId)) }
}

private struct MostPlayedRowContent: View {
    let entry: ChartEntry
    let compact: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(entry.rank)")
                .font(.system(size: 15, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(entry.rank <= 3 ? Steam.textTitle : Steam.textSecondary)
                .frame(width: 34, alignment: .leading)
            RemoteImage(entry.images.header, maxPixel: 400)
                .frame(width: compact ? 96 : 120, height: compact ? 45 : 56)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            VStack(alignment: .leading, spacing: 5) {
                Text(entry.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Steam.textTitle)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    LiveDot()
                    Text(entry.currentPlayersLabel)
                        .foregroundStyle(Steam.statusInGame)
                    if !compact {
                        Text("·").foregroundStyle(Steam.textMuted)
                        Text(entry.peakTodayLabel).foregroundStyle(Steam.textSecondary)
                    }
                }
                .font(.system(size: 12))
                .lineLimit(1)
            }
            Spacer(minLength: 8)
            if !compact { PriceBlock(price: entry.price) }
        }
        .padding(8)
        .background(CardBackground())
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}
