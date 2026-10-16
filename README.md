<div align="center">

# Native Steam

**What if Steam were fully native on every platform?**

One design. Six native toolkits. One adaptive UI that's equally at home with a
mouse, a touchscreen or a gamepad.

<img src="docs/screenshots/macos/store.png" alt="Native Steam on macOS — the Store" width="900">

`SwiftUI` · `WinUI 3` · `GTK 4 + libadwaita` · `Jetpack Compose` · `Next.js` · shared `Rust` core

</div>

> [!NOTE]
> This is an unofficial fan concept and is **not affiliated with, endorsed by or
> connected to Valve Corporation**. Steam is a trademark of Valve Corporation.
> No Valve logos are used. Game names and artwork belong to their respective
> owners and are loaded at runtime from Steam's public CDN — none are
> redistributed in this repository (apart from the screenshots below).

## The idea

Steam today ships three different UIs: the desktop client (a web view),
Big Picture mode (controller-first) and the mobile app. Each is great at one
input method and awkward at the others.

Native Steam asks what it would look like if the client were built with each
platform's **own** toolkit, and **one adaptive design** worked well with all
three input styles:

- **Mouse & keyboard**: hover states, arrow-key spatial navigation,
  `Ctrl/⌘+1…4` to switch tabs, `Ctrl/⌘+F` to search.
- **Touch**: 44 pt / 48 dp targets, snapping shelves, a bottom tab bar on
  narrow screens.
- **Gamepad**: `LB`/`RB` switch tabs, the D-pad moves focus spatially, `A`/`B`
  select and go back, and a Big Picture-style button-hint bar appears whenever a
  controller is the last input.

It keeps Steam's look (dark blue palette, uppercase tracked tabs,
artwork-first layouts). The full spec is in [docs/DESIGN.md](docs/DESIGN.md).

## Platforms

| Platform | Toolkit | Language | Source |
|---|---|---|---|
| macOS | SwiftUI | Swift | [`clients/apple`](clients/apple) |
| iOS / iPadOS | SwiftUI | Swift | [`clients/apple`](clients/apple) |
| Windows | WinUI 3 (Windows App SDK) | C# | [`clients/windows`](clients/windows) |
| Linux | GTK 4 + libadwaita | Rust | [`clients/linux`](clients/linux) |
| Android | Jetpack Compose | Kotlin | [`clients/android`](clients/android) |
| Web | Next.js (static export) | TypeScript | [`clients/web`](clients/web) |

Every client implements the same four tabs (**Store**, **Library**,
**Community** and the persona tab, **KESTREL**), plus a store app page and a
library game page.

## Screenshots

### macOS: SwiftUI
Steam-style top bar with the traffic lights built in, Liquid Glass where it belongs, and a collections sidebar.

<table>
<tr><td><img src="docs/screenshots/macos/store.png" width="440" alt="macos store"></td><td><img src="docs/screenshots/macos/library.png" width="440" alt="macos library"></td></tr>
<tr><td><img src="docs/screenshots/macos/community.png" width="440" alt="macos community"></td><td><img src="docs/screenshots/macos/profile.png" width="440" alt="macos profile"></td></tr>
</table>

<details><summary>Game page, store page, gamepad mode</summary>

<table>
<tr><td><img src="docs/screenshots/macos/game.png" width="440" alt="macos game"></td><td><img src="docs/screenshots/macos/app.png" width="440" alt="macos app"></td></tr>
<tr><td><img src="docs/screenshots/macos/gamepad.png" width="440" alt="macos gamepad"></td></tr>
</table>
</details>

### iOS / iPadOS: SwiftUI
Same code as macOS. Below 700 pt it switches to the native tab bar, with Kestrel's avatar on the persona tab.

<table>
<tr><td><img src="docs/screenshots/ios/store.png" width="170" alt="ios store"></td><td><img src="docs/screenshots/ios/library.png" width="170" alt="ios library"></td><td><img src="docs/screenshots/ios/community.png" width="170" alt="ios community"></td><td><img src="docs/screenshots/ios/profile.png" width="170" alt="ios profile"></td><td><img src="docs/screenshots/ios/game.png" width="170" alt="ios game"></td></tr>
</table>

<details><summary>iPad, gamepad mode</summary>

<table>
<tr><td><img src="docs/screenshots/ios/ipad-library.png" width="300" alt="ios ipad-library"></td><td><img src="docs/screenshots/ios/gamepad.png" width="300" alt="ios gamepad"></td></tr>
</table>
</details>

### Windows: WinUI 3
Mica title bar, `NavigationView` styled as Steam's top bar, XY focus navigation, and gamepad support through `Windows.Gaming.Input`.

<table>
<tr><td><img src="docs/screenshots/windows/store.png" width="440" alt="windows store"></td><td><img src="docs/screenshots/windows/library.png" width="440" alt="windows library"></td></tr>
<tr><td><img src="docs/screenshots/windows/community.png" width="440" alt="windows community"></td><td><img src="docs/screenshots/windows/profile.png" width="440" alt="windows profile"></td></tr>
</table>

<details><summary>Game page, store page, gamepad mode, compact</summary>

<table>
<tr><td><img src="docs/screenshots/windows/game.png" width="440" alt="windows game"></td><td><img src="docs/screenshots/windows/app.png" width="440" alt="windows app"></td></tr>
<tr><td><img src="docs/screenshots/windows/gamepad.png" width="440" alt="windows gamepad"></td></tr>
</table>
<img src="docs/screenshots/windows/library-compact.png" width="220" alt="windows compact library"> <img src="docs/screenshots/windows/store-compact.png" width="220" alt="windows compact store">
</details>

<sub>Written on a Mac; built and screenshotted on GitHub's `windows-latest` runners by [`windows.yml`](.github/workflows/windows.yml).</sub>

### Linux: GTK 4 + libadwaita (Rust)
Uses the shared Rust crate `steam-model` directly. `AdwBreakpoint`s switch the layout from a Steam top bar to an `AdwViewSwitcherBar` on narrow windows.

<table>
<tr><td><img src="docs/screenshots/linux/store.png" width="440" alt="linux store"></td><td><img src="docs/screenshots/linux/library.png" width="440" alt="linux library"></td></tr>
<tr><td><img src="docs/screenshots/linux/community.png" width="440" alt="linux community"></td><td><img src="docs/screenshots/linux/profile.png" width="440" alt="linux profile"></td></tr>
</table>

<details><summary>Game page, store page, gamepad mode, compact</summary>

<table>
<tr><td><img src="docs/screenshots/linux/game.png" width="440" alt="linux game"></td><td><img src="docs/screenshots/linux/app.png" width="440" alt="linux app"></td></tr>
<tr><td><img src="docs/screenshots/linux/gamepad.png" width="440" alt="linux gamepad"></td></tr>
</table>
<img src="docs/screenshots/linux/library-compact.png" width="220" alt="linux compact library">
</details>

<sub>Captured with GTK's macOS backend; the app uses client-side decorations, so it looks the same on Linux.</sub>

### Android: Jetpack Compose
Material 3 with a Steam colour scheme, edge-to-edge, predictive back, and D-pad and controller focus throughout.

<table>
<tr><td><img src="docs/screenshots/android/store.png" width="170" alt="android store"></td><td><img src="docs/screenshots/android/library.png" width="170" alt="android library"></td><td><img src="docs/screenshots/android/community.png" width="170" alt="android community"></td><td><img src="docs/screenshots/android/profile.png" width="170" alt="android profile"></td><td><img src="docs/screenshots/android/game.png" width="170" alt="android game"></td></tr>
</table>

<details><summary>Tablet, gamepad mode</summary>

<table>
<tr><td><img src="docs/screenshots/android/tablet-store.png" width="440" alt="android tablet-store"></td><td><img src="docs/screenshots/android/tablet-library.png" width="440" alt="android tablet-library"></td></tr>
</table>
<img src="docs/screenshots/android/gamepad.png" width="200" alt="android gamepad">
</details>

### Web: Next.js
Static export; it can be deployed to GitHub Pages as a live demo with [`web.yml`](.github/workflows/web.yml).

<table>
<tr><td><img src="docs/screenshots/web/store.png" width="440" alt="web store"></td><td><img src="docs/screenshots/web/library.png" width="440" alt="web library"></td></tr>
<tr><td><img src="docs/screenshots/web/community.png" width="440" alt="web community"></td><td><img src="docs/screenshots/web/profile.png" width="440" alt="web profile"></td></tr>
</table>

<details><summary>Mobile, game page, store page, gamepad mode</summary>

<table>
<tr><td><img src="docs/screenshots/web/store-mobile.png" width="200" alt="web store-mobile"></td><td><img src="docs/screenshots/web/library-mobile.png" width="200" alt="web library-mobile"></td><td><img src="docs/screenshots/web/community-mobile.png" width="200" alt="web community-mobile"></td><td><img src="docs/screenshots/web/profile-mobile.png" width="200" alt="web profile-mobile"></td></tr>
</table>
<table>
<tr><td><img src="docs/screenshots/web/game.png" width="440" alt="web game"></td><td><img src="docs/screenshots/web/store-app.png" width="440" alt="web store-app"></td></tr>
<tr><td><img src="docs/screenshots/web/gamepad.png" width="440" alt="web gamepad"></td></tr>
</table>
</details>

## Gamepad mode

When a controller is the last thing you touched, every client shows a Big
Picture-style focus ring and button-hint bar:

<table><tr>
<td><img src="docs/screenshots/windows/gamepad.png" width="440" alt="windows gamepad"></td>
<td><img src="docs/screenshots/linux/gamepad.png" width="440" alt="linux gamepad"></td>
</tr></table>

| Button | Action |
|---|---|
| `LB` / `RB` | previous / next tab |
| D-pad / left stick | spatial focus |
| `A` / `B` | select / back |
| `Y` | search |
| `X` | favorite (Library) / wishlist (Store) |
| `LT` / `RT` | page through Library collections / Community sections |

Keyboard follows the same model: arrow keys move focus spatially,
`Enter` selects, `Esc` goes back, `Ctrl/⌘+1…4` switches tabs and
`Ctrl/⌘+F` searches.


## Real data, fake user

```
 Steam public APIs ──► core/ (Rust) ──► data/snapshot.json ──► every client
                        ├─ steam-api       (store, charts, news, players)
                        ├─ steam-seed      (deterministic fake account)
                        ├─ steam-model     (shared schema; GTK client links it directly)
                        └─ steam-snapshot  (CLI that writes the snapshot)
```

**Live from Steam (no API key needed):**
- the storefront: featured, specials, top sellers, new & trending, popular upcoming
- prices and discounts
- review scores
- screenshots and library artwork
- achievement icons
- the most-played chart with live player counts
- official news posts

**Seeded:** the signed-in user, **Kestrel**. Steam needs an account (and an API
key) for library stats, friends and profiles, so `steam-seed` builds a
believable one on top of the real data:
- 35 real games with hand-tuned playtime
- achievement progress using the games' real achievement icons
- 12 friends
- a friend-activity feed
- badges and profile showcases

It uses a fixed seed, so the same data always produces the same user.

To refresh the snapshot:

```bash
cd core && cargo run --release -p steam-snapshot
```

All `*Label` fields (e.g. `"142.3 hrs on record"`, `"Offer ends Oct 30"`) are
formatted once in Rust, so six languages render identical text.

## Building

Each client has its own README with full instructions.

| Client | Requirements | Run |
|---|---|---|
| [Web](clients/web) | Node 20+, pnpm | `cd clients/web && pnpm install && pnpm dev` |
| [macOS / iOS](clients/apple) | Xcode 26+ | open `clients/apple/NativeSteam.xcodeproj`, run `NativeSteam-macOS` or `NativeSteam-iOS` |
| [Android](clients/android) | JDK 17, Android SDK | `cd clients/android && ./gradlew installDebug` |
| [Linux](clients/linux) | Rust, GTK ≥ 4.14, libadwaita ≥ 1.5 | `cd clients/linux && cargo run --release` |
| [Windows](clients/windows) | Windows 10/11, .NET 10 SDK | `dotnet run --project clients/windows/NativeSteam/NativeSteam.csproj -p:Platform=x64` |
| [Core](core) | Rust | `cd core && cargo test` |

Every client accepts the same flags for automation and screenshots (on the
web they're query params, on Android intent extras): `tab` (`store`,
`library`, `community` or `profile`), `game <appId>`, `app <appId>`, and
`input gamepad`.

## Ideas & contributions welcome

- [UniFFI](https://mozilla.github.io/uniffi-rs/) bindings, so Swift, Kotlin and
  C# call the Rust core directly instead of decoding JSON
- live store refresh at runtime (the API client already exists in `steam-api`)
- a store `apps` map so every owned or charted game gets a complete store page
- Steam Deck / SteamOS Game Mode polish for the GTK client
- more platforms: tvOS, visionOS, Wear OS? 👀


## License

[MIT](LICENSE) © 2026 Sam Svindland
