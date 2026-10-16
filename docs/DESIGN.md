# Native Steam — Design Spec

One design, six native implementations. Every client renders the same
`data/snapshot.json` and should be recognisably the *same app* while feeling
at home on its platform. When this spec and a platform's conventions conflict,
keep the **brand** (colour, density, uppercase tab labels, artwork-first
layouts) and follow the **platform** for controls, navigation chrome, fonts and
icons.

The twist: real Steam has three UIs (desktop, Big Picture, mobile). Native
Steam has **one adaptive UI** that works equally well with
**mouse & keyboard, touch, and gamepad**.

---

## 1. Brand tokens

| Token | Value | Use |
|---|---|---|
| `bgChrome` | `#171a21` | Nav bar, tab bar, sidebars, title bar |
| `bgStore` | gradient `#1b2838` → `#0e1620` (top→bottom) | Store & Community page background |
| `bgLibrary` | gradient `#1e2329` → `#0e1014` | Library & Profile page background |
| `surface` | `#16202d` | Cards on store/community |
| `surfaceNeutral` | `#23262e` | Cards on library/profile |
| `surfaceHover` | `#2a475e` | Hover/pressed state of cards & rows |
| `divider` | `rgba(255,255,255,0.08)` | Hairlines |
| `textTitle` | `#ffffff` | Titles, focused labels |
| `textBody` | `#c7d5e0` | Body copy |
| `textSecondary` | `#8f98a0` | Meta (dates, hours, counts) |
| `textMuted` | `#67707b` | Disabled, tertiary |
| `accent` | `#1a9fff` | Primary actions, selection, focus |
| `accentLink` | `#66c0f4` | Links, positive review label |
| `play` | gradient `#75b022` → `#588a1b` | **PLAY** button (white text) |
| `install` | gradient `#47bfff` → `#1a44c2` | **INSTALL / Add to Cart** button |
| `discountBg` / `discountText` | `#4c6b22` / `#beee11` | Discount badge (`-40%`) |
| `priceBg` | `rgba(0,0,0,0.25)` | Price block behind badge |
| `priceOriginal` | `#738895` (strikethrough) | Pre-discount price |
| `priceFinal` | `#beee11` if discounted, else `#c7d5e0` | Final price |
| `reviewPositive` / `Mixed` / `Negative` | `#66c0f4` / `#b9a074` / `#a34c25` | `review.tone` |
| `statusInGame` | `#90ba3c` | Friend in-game (name + avatar border) |
| `statusOnline` | `#57cbde` | Online |
| `statusAway` | `#57cbde` @ 50% | Away |
| `statusOffline` | `#898989` | Offline |
| `levelColor` | from data | Steam level ring (`user.levelColor`, `friend.levelColor`) |

**Shape:** cards 6 px radius, buttons 4 px, avatars 4 px (Steam avatars are
square), chips/pills fully rounded. Artwork is never letterboxed. Use the
correct aspect (`portrait` 2:3, `header` 460:215, `capsule` 616:353, `hero`
~3.1:1) with aspect-fill + clip.

**Spacing:** 4 · 8 · 12 · 16 · 24 · 32 · 48. Page gutters 16 (compact) / 24–32 (regular).

**Type:** platform system font (SF Pro, Segoe UI Variable, Roboto, Cantarell /
system, `system-ui` on web). Steam's voice comes from:
- **Section headers**: UPPERCASE, 13–14 pt, semibold, letter-spacing ~0.06em,
  `textTitle` at 90%, with an optional "See all ›" at the trailing edge.
- **Top-level tab labels**: UPPERCASE, semibold, letter-spacing ~0.08em.
  The fourth tab is the persona name, `KESTREL`.
- Titles are sentence-case game names, never uppercased.

**Icons:** platform-native icon sets (SF Symbols, Material Symbols, Segoe
Fluent Icons, Adwaita symbolic, Lucide on web). **Do not use Valve's logo**
anywhere; the app mark is the plain text wordmark `STEAM` (bold, tracked) or a
generic glyph. This is an unofficial concept.

**Artwork & images:** all image URLs in the snapshot are Steam CDN URLs.
Load asynchronously, cache in memory and on disk, show a `surface`-coloured
placeholder (optionally with the game name) while loading or on failure.

---

## 2. Adaptive shell

Two size classes, switched on available width (not device type):

### Compact (< 700 pt/dp/px wide) — phones, narrow windows
- **Bottom tab bar** with four items: Store (bag/storefront icon), Library
  (grid icon), Community (people icon), and the persona tab showing the
  user's **avatar** with the label `KESTREL`.
- Each tab is its own navigation stack (push for details, back to pop).
- Large title / header at top of each tab with a search affordance on Store
  and Library.
- Shelves scroll horizontally with snap; grids are 3 columns of portraits.

### Regular (≥ 700) — tablets, desktop, TV
- **Top nav bar** in `bgChrome`, Steam-desktop style:
  `[STEAM wordmark]  STORE  LIBRARY  COMMUNITY  KESTREL  ……  [search] [friends/status] [avatar]`
  The active tab label is `textTitle` with a 3 px `accent` underline;
  inactive labels are `textSecondary`.
- On platforms where a native sidebar or tab control is the idiomatic
  top-level navigation (e.g. WinUI `NavigationView` Top mode, `AdwViewSwitcher`,
  SwiftUI toolbar tabs) use that control **styled** to match the above.
- Library gets a **collections sidebar** (≥ 1000 wide).
- Community gets a right rail (≥ 1100 wide).

Content max-width on very wide windows: ~1600, centred.

---

## 3. Input model — mouse, touch **and** gamepad

All three are first-class. The UI tracks the **last-used input** and adapts:

| | Mouse & keyboard | Touch | Gamepad |
|---|---|---|---|
| Focus ring | keyboard only | hidden | **always visible** |
| Hover | lift + `surfaceHover` | none | n/a |
| Button hints bar | hidden | hidden | **visible** |
| Targets | ≥ 28 pt | ≥ 44 pt / 48 dp | big cards, ≥ 48 |

### Focus treatment (keyboard & gamepad)
Focused element: **scale 1.04** (cards) with 120 ms ease-out, a **2 px white
inner ring + 4 px `accent` @ 55% outer glow**, and brighter artwork. Only one
thing is ever focused. Horizontal shelves auto-scroll so the focused item
stays fully visible with ~1 card of lookahead.

### Gamepad mapping (Xbox names; PlayStation / Switch equivalents)
| Button | Action |
|---|---|
| **LB / RB** | previous / next top-level tab (wraps) |
| **D-pad / left stick** | spatial focus movement (up/down/left/right) |
| **A** | activate focused item |
| **B** | back (pop navigation; at root: move focus to tab bar) |
| **Y** | focus search (Store / Library) |
| **X** | secondary action (favorite in Library, wishlist in Store) |
| **LT / RT** | page between Library collections / Community sections |
| **Menu** | open context actions for focused item (optional) |

When a gamepad is the last input, show a **hints bar** pinned to the bottom
(above the compact tab bar), Big-Picture style, in `bgChrome` @ 95%:
`Ⓐ Select   Ⓑ Back   Ⓨ Search   LB/RB Switch tab`. When a gamepad is present
the top nav/tab bar also shows small `LB` and `RB` glyphs at either end.

### Keyboard
Arrow keys = spatial navigation, Enter/Space = activate, Esc/Backspace = back,
Tab follows platform order. Shortcuts: `⌘/Ctrl+1…4` switch tabs,
`⌘/Ctrl+F` search, `⌘/Ctrl+[` back.

### Touch
Swipeable shelves with snap, pull-to-refresh where idiomatic, no
hover-only information, press-state feedback, platform back gestures.

---

## 4. The four tabs

### 4.1 STORE (`store`)
Top to bottom:
1. **Search field** ("Search the store") + **tag chips** row from
   `store.popularTags` (horizontally scrollable).
2. **FEATURED & RECOMMENDED** — hero carousel of `store.featured`.
   *Regular:* a big card: `capsule` image (left ~62%), right panel with name,
   2×2 `screenshots` thumbnails, `review.label`, genres as chips, price block.
   Page dots + prev/next arrows (mouse), auto-advance every 6 s (paused while
   focused/hovered). *Compact:* full-width `capsule` card with name + price
   overlay, swipe paging, dots.
3. **SPECIAL OFFERS** — shelf of `store.specials` cards: `header` image,
   name, `discountEndsLabel`, price block (badge + strikethrough + final).
4. **TOP SELLERS** — *regular:* two-column list rows (`smallCapsule`, name,
   platform icons, review tone dot, price block). *Compact:* shelf.
5. **NEW & TRENDING** — shelf of `store.newReleases`.
6. **MOST PLAYED** — ranked list (`#1`…), `header` thumb, name,
   `currentPlayersLabel` (with a green "live" dot), `peakTodayLabel`, price.
7. **POPULAR UPCOMING** — shelf of `store.comingSoon` with `releaseDate`.

**Price block** component (reuse everywhere): if `discountLabel` →
green badge + (`initialLabel` struck through over `finalLabel` in
`priceFinal`); else just `finalLabel`; `price == null` → "Coming soon" /
`releaseDate`.

**Store app page** (push on select): `background` or `hero` image header
with gradient fade, name, screenshots carousel (`screenshots[].full`),
`shortDescription`, genres/developers, review summary (`label`, `percentPositive`%,
`totalLabel`), platforms, controller support badge ("Full Controller Support"),
price block + **Add to Cart** (`install` gradient; purely visual — no purchase
flow) + **Wishlist** secondary button.

### 4.2 LIBRARY (`library`)
1. **Collections**: *regular ≥1000:* left sidebar (`bgChrome`) with a filter
   field and `library.collections` (name + count); *compact/regular <1000:*
   horizontal chips. "All Games" is selected by default.
2. **RECENT GAMES** shelf (from `library.recentAppIds`): larger landscape cards
   using `hero` (fallback `capsule`) with `logo` overlaid, plus
   `lastPlayedLabel` beneath. First card double-width on regular.
3. **ALL GAMES (35)** grid of `portrait` covers (2:3). Installed games at full
   opacity; not-installed at ~65% with a small download glyph. Favorite =
   small star. `updateAvailable` = small blue dot. Hover/focus shows the name.
   Sort control: Alphabetical · Recently played · Hours played.
4. **Game page** (push on select, or right-hand detail pane on very wide
   screens): `hero` full-bleed with `logo` overlay and bottom gradient into
   `bgLibrary`; action row: big **PLAY** (`play` gradient) if installed, else
   **INSTALL** (`install` gradient) with `sizeLabel`; secondary buttons
   (favorite star, settings gear, info). Stats row: *Last played*
   `lastPlayedLabel` · *Play time* `playtimeLabel` · *Achievements*
   `unlocked/total` with a progress bar. Sections: ACHIEVEMENTS (icon strip of
   `highlighted`, locked ones desaturated/dimmed), FRIENDS WHO PLAY
   (`friendsPlaying` → avatars), SCREENSHOTS, ABOUT (`shortDescription`,
   developer, release date, controller support).

### 4.3 COMMUNITY (`community`)
Sections (*compact:* segmented control `Activity | News | Hubs`;
*regular:* Activity is the main column, News below or beside, Hubs + Friends
in the right rail ≥1100).
1. **FRIEND ACTIVITY** — `community.activity` cards. Header:
   avatar (status-coloured border) · **friendName** `headline` **appName** ·
   `timeLabel`. Body by `kind`:
   - `achievement`: achievement icon (64) + name + `unlockedLabel`.
   - `screenshot`: the `imageUrl` image 16:9, rounded.
   - `review`: thumbs up/down (`recommended`) + "Recommended / Not
     Recommended" + `hoursLabel`, then `body` quote.
   - `nowPlaying` / `newGame`: the game's `header` with name.
   Footer: 👍 `likes` · 💬 `comments` (icons, not emoji, on native platforms).
2. **NEWS** — `community.news` cards: `imageUrl` (fallback `appImages.header`),
   `appName` · `feedLabel` · `dateLabel`, **title**, `excerpt` (3 lines).
3. **POPULAR HUBS** — `community.hubs`: `header` art + name +
   `currentPlayersLabel` with live dot, ranked.
4. **FRIENDS** (rail on regular; reachable from Profile on compact):
   grouped *In-Game*, *Online*, *Offline*; avatar, name coloured by status,
   `statusLabel`.

### 4.4 KESTREL — the persona tab (`user`)
1. **Banner**: `user.backgroundUrl` (darkened, gradient to page bg) with the
   **avatar** (large, 4 px radius, 3 px `statusOnline` border),
   **personaName**, `realName` · `country`, and a **level ring** (circle
   outlined in `levelColor` with the number), `xpToNextLabel` + thin progress
   bar (`xpFraction`). "Edit Profile" button (visual only).
2. `summary` paragraph, `memberSinceLabel`.
3. **Stats row**: Games · Achievements · Perfect games · Hours · Friends ·
   Screenshots · Reviews (big number, small uppercase caption).
4. **BADGES**: `badges` as medallions (circle filled with `color`, symbol for
   `icon`, level number) + name.
5. **FAVORITE GAME**: library `hero` + `logo` of `favoriteGame` with hours +
   achievement progress.
6. **RECENT ACTIVITY**: `recentGames` rows (`header`, name, `totalLabel`,
   `lastPlayedLabel`, achievement progress bar).
7. **RARE ACHIEVEMENT SHOWCASE**: `rareAchievements` icons with game name.
8. **SCREENSHOT SHOWCASE**: `screenshots` (one large + three small).
9. **FRIENDS** (count + first ~8 avatars → full list).

---

## 5. Data contract

- Source of truth: `data/snapshot.json` (schema in
  `core/crates/steam-model/src/lib.rs`). JSON is camelCase.
- Bundle it with the app (don't fetch at runtime). Reference it in place
  (`../../data/snapshot.json`) or copy it in a build step; never hand-edit it.
- All `*Label` fields are pre-formatted display strings — render them as-is.
- Optional fields (`portrait`, `hero`, `logo`, `price`, `review`,
  `achievements`, …) can be `null`; always have a fallback.
- Regenerate with `cargo run --release -p steam-snapshot` in `core/`.

## 6. Screenshots

Each client contributes PNGs to `docs/screenshots/<platform>/`:
`store.png`, `library.png`, `community.png`, `profile.png`, plus
platform-relevant extras (`game.png` detail page, `gamepad.png` showing focus
ring + hints bar, `*-compact.png` / `*-tablet.png`). Desktop windows ~1440×900;
phones at native simulator resolution.
