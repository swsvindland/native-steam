import SwiftUI

/// STORE tab (DESIGN §4.1).
struct StoreView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layout.isCompact ? 28 : 36) {
                StoreSearchBar()
                if model.storeQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                    StoreSections()
                } else {
                    StoreSearchResults()
                }
            }
            .padding(.horizontal, layout.gutter)
            .padding(.top, layout.isCompact ? 4 : 24)
            .padding(.bottom, 48)
            .frame(maxWidth: 1240)
            .frame(maxWidth: .infinity)
        }
        .focusScrollContainer(.vertical)
        .background(Steam.storeBackground.ignoresSafeArea())
        .screenChrome(title: "Store")
        .focusScope("store")
    }
}

private struct StoreSections: View {
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        let store = model.snapshot.store
        let cardWidth: CGFloat = layout.isCompact ? 250 : 292

        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Featured & Recommended")
            FeaturedCarousel(items: store.featured)
        }

        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Special Offers") { SeeAllLabel() }
            Shelf(store.specials) { item in
                StoreShelfCard(item: item, subtitle: item.discountEndsLabel, focusID: "store.special.\(item.appId)", width: cardWidth)
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Top Sellers") { SeeAllLabel() }
            if layout.isCompact {
                Shelf(store.topSellers) { item in
                    StoreShelfCard(item: item, subtitle: item.genres.prefix(2).joined(separator: " · "),
                                   focusID: "store.top.\(item.appId)", width: cardWidth)
                }
            } else {
                TwoColumnList(items: store.topSellers) { item in
                    StoreListRow(item: item, focusID: "store.top.\(item.appId)")
                }
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("New & Trending") { SeeAllLabel() }
            Shelf(store.newReleases) { item in
                StoreShelfCard(item: item, subtitle: item.releaseDate, focusID: "store.new.\(item.appId)", width: cardWidth)
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Most Played") {
                HStack(spacing: 6) {
                    LiveDot()
                    Text("Live").font(.system(size: 12, weight: .medium)).foregroundStyle(Steam.textSecondary)
                }
            }
            if layout.isCompact {
                VStack(spacing: 8) {
                    ForEach(store.mostPlayed) { entry in
                        MostPlayedRow(entry: entry, focusID: "store.most.\(entry.appId)")
                    }
                }
            } else {
                TwoColumnList(items: store.mostPlayed, columnMajor: true) { entry in
                    MostPlayedRow(entry: entry, focusID: "store.most.\(entry.appId)")
                }
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Popular Upcoming") { SeeAllLabel() }
            Shelf(store.comingSoon) { item in
                StoreShelfCard(item: item, subtitle: item.releaseDate.map { "Releases \($0)" },
                               focusID: "store.soon.\(item.appId)", width: cardWidth)
            }
        }
    }
}

/// Two columns of rows. `columnMajor` fills the left column first (ranked lists).
struct TwoColumnList<Item: Identifiable, Row: View>: View {
    let items: [Item]
    var columnMajor = false
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        let half = (items.count + 1) / 2
        let left = columnMajor ? Array(items.prefix(half)) : items.enumerated().filter { $0.offset % 2 == 0 }.map(\.element)
        let right = columnMajor ? Array(items.dropFirst(half)) : items.enumerated().filter { $0.offset % 2 == 1 }.map(\.element)
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 8) { ForEach(left) { row($0) } }
                .frame(maxWidth: .infinity)
            VStack(spacing: 8) { ForEach(right) { row($0) } }
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Search + tags

private struct StoreSearchBar: View {
    @Environment(AppModel.self) private var model
    @Environment(FocusEngine.self) private var engine
    @Environment(\.layout) private var layout
    @FocusState private var fieldFocused: Bool

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if !layout.isCompact {
                    ForEach(["Your Store", "New & Noteworthy", "Categories", "Points Shop", "News"], id: \.self) { title in
                        Text(title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Steam.textBody)
                            .padding(.horizontal, 6)
                            .fixedSize()
                    }
                    Spacer(minLength: 12)
                }
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Steam.textSecondary)
                    TextField("Search the store", text: $model.storeQuery)
                        .textFieldStyle(.plain)
                        .focused($fieldFocused)
                        .foregroundStyle(Steam.textTitle)
                        #if os(iOS)
                        .submitLabel(.search)
                        #endif
                    if !model.storeQuery.isEmpty {
                        Button { model.storeQuery = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(Steam.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .frame(height: layout.isCompact ? 40 : 34)
                .frame(maxWidth: layout.isCompact ? .infinity : 280)
                .background(
                    RoundedRectangle(cornerRadius: layout.isCompact ? 10 : 4, style: .continuous)
                        .fill(layout.isCompact ? Color.white.opacity(0.08) : Color(hex: 0x316282, opacity: 0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: layout.isCompact ? 10 : 4, style: .continuous)
                        .strokeBorder(fieldFocused ? Steam.accent : Color.clear, lineWidth: 1.5)
                )
                .steamFocusable("store.search", cornerRadius: 6, scales: false, lifts: false) {
                    fieldFocused = true
                }
            }
            .padding(layout.isCompact ? 0 : 6)
            .padding(.leading, layout.isCompact ? 0 : 6)
            .background {
                if !layout.isCompact {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [Color(hex: 0x3E7EA7, opacity: 0.55), Color(hex: 0x396AA7, opacity: 0.25)],
                            startPoint: .leading, endPoint: .trailing))
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                }
            }

            TagChipsRow()
        }
        .onChange(of: model.searchRequest) { _, _ in fieldFocused = true }
        .onChange(of: fieldFocused) { _, focused in engine.textInputActive = focused }
    }
}

private struct TagChipsRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.layout) private var layout

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(model.snapshot.store.popularTags) { tag in
                    Button { model.storeQuery = tag.name } label: {
                        ChipLabel(tag.name, selected: model.storeQuery == tag.name)
                    }
                    .buttonStyle(.pressable)
                    .steamFocusable("store.tag.\(tag.id)", cornerRadius: 16, lifts: false) {
                        model.storeQuery = tag.name
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, layout.gutter, for: .scrollContent)
        .focusScrollContainer(.horizontal, margin: layout.gutter)
        .padding(.horizontal, -layout.gutter)
        .padding(.vertical, -8)
    }
}

private struct StoreSearchResults: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let results = model.storeResults
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Results for “\(model.storeQuery)”", count: results.count)
            if results.isEmpty {
                Text("No matches in this snapshot. Try a tag like Indie or RPG.")
                    .font(.system(size: 14))
                    .foregroundStyle(Steam.textSecondary)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 8) {
                    ForEach(results) { item in
                        StoreListRow(item: item, focusID: "store.result.\(item.appId)")
                    }
                }
            }
        }
    }
}
