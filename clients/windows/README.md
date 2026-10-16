# Native Steam — Windows (WinUI 3)

The Windows client of **Native Steam**, an unofficial concept of what a fully native Steam client
could look like: one adaptive UI that is equally good with mouse & keyboard, touch and a gamepad.
Built with C# + WinUI 3 (Windows App SDK). It renders the shared [`data/snapshot.json`](../../data/snapshot.json)
and follows [`docs/DESIGN.md`](../../docs/DESIGN.md).

> Not affiliated with Valve. No Valve logo is used; the app mark is the text wordmark `STEAM`
> next to a Segoe Fluent gamepad glyph. Purchase / install buttons are purely visual.

| Store | Library | Game |
|---|---|---|
| ![Store](../../docs/screenshots/windows/store.png) | ![Library](../../docs/screenshots/windows/library.png) | ![Game](../../docs/screenshots/windows/game.png) |
| **Community** | **Kestrel (profile)** | **Gamepad** |
| ![Community](../../docs/screenshots/windows/community.png) | ![Profile](../../docs/screenshots/windows/profile.png) | ![Gamepad](../../docs/screenshots/windows/gamepad.png) |

Screenshots are produced by CI (see below), not by hand.

## Requirements

- Windows 10 version 1809 (build 17763) or later; Windows 11 recommended (Mica needs Windows 11 —
  on Windows 10 the chrome falls back to solid `#171a21`).
- [.NET 10 SDK](https://dotnet.microsoft.com/download) (LTS) or newer — the app targets `net10.0-windows10.0.19041.0`
  and runs on the .NET 10 runtime.
- Windows App SDK **1.8** — restored from NuGet automatically. The app is **unpackaged and
  self-contained** (`WindowsPackageType=None`, `WindowsAppSDKSelfContained=true`), so no MSIX,
  no developer mode and no separately installed Windows App Runtime are needed.
- Visual Studio 2022/2026 with the *WinUI application development* workload is optional
  (open `NativeSteam.sln`); the `dotnet` CLI is enough.

## Build & run

```powershell
# from the repo root
dotnet build clients/windows/NativeSteam/NativeSteam.csproj -c Release -p:Platform=x64
dotnet run --project clients/windows/NativeSteam/NativeSteam.csproj -p:Platform=x64

# Arm64 devices (Surface Pro X, Copilot+ PCs…)
dotnet build clients/windows/NativeSteam/NativeSteam.csproj -c Release -p:Platform=ARM64
```

The executable lands in `NativeSteam/bin/<Platform>/<Configuration>/net10.0-windows10.0.19041.0/win-<arch>/NativeSteam.exe`.
`data/snapshot.json` is linked into the build output as `Assets/snapshot.json` (never copied into this folder);
regenerate it with `cargo run --release -p steam-snapshot` in `core/`.

### Command-line switches

Mostly for deterministic screenshots, but handy for development too:

| Switch | Effect |
|---|---|
| `--tab store\|library\|community\|profile` | Start on that tab. |
| `--game <appId>` | Open the Library game page (implies `--tab library`), e.g. `--game 1145350`. |
| `--app <appId>` | Open the Store app page, e.g. `--app 3470960`. |
| `--input gamepad` | Start in gamepad mode: hints bar, LB/RB glyphs and a focused card. |
| `--size 1440x900` | Client-area size in effective pixels (scaled by the window's DPI). |

## Project layout

```
NativeSteam.sln
NativeSteam/
  App.xaml(.cs)          resources (XamlControlsResources + Themes/Steam.xaml), launch, logging
  MainWindow.cs          Mica Alt, tall custom title bar, caption colours, --size
  ShellPage.xaml(.cs)    title bar + NavigationView (Top) tab strip, bottom tabs, Frames, hints bar,
                         keyboard accelerators, input-mode tracking, passthrough regions
  Themes/Steam.xaml      brand tokens (DESIGN.md §1), card / row / chip / gradient button styles, shelves
  Controls/              ArtImage (CDN art with placeholder), CardButton (focus scale + lookahead),
                         PriceBlock, SectionHeader
  Pages/                 Store, AppPage (store app page), Library, GamePage, Community, Profile
  Models/Snapshot.cs     System.Text.Json mirror of core/crates/steam-model (camelCase, source-generated)
  ViewModels/            display-ready wrappers so XAML only needs plain {x:Bind}
  Services/              DataStore, LaunchOptions, InputModeService, GamepadController, Navigation, Palette
scripts/screenshots.ps1  launches the app per screen and captures PNGs
```

## Adaptive layout

- **Regular (≥ 700 epx):** Steam-desktop top bar in the title bar: `STEAM` wordmark, a WinUI
  `NavigationView` in `Top` mode styled with uppercase, tracked labels and an accent underline, then
  search, friends and the persona button. Mica Alt shows through the translucent title bar.
- **Compact (< 700 epx):** the tab strip collapses (VisualStateManager `AdaptiveTrigger`) and a
  bottom tab bar appears (Store · Library · Community · avatar + `KESTREL`). Shelves stay swipeable,
  the library grid becomes exactly three portrait columns.
- Library gets its collections sidebar at ≥ 1000 epx (chips below that); Community shows Activity |
  News | Hubs + Friends as three columns at ≥ 1340, a right rail at ≥ 1100 and a segmented control on
  compact widths. Content is capped at 1600 epx and centred.
- Each tab has its own `Frame`, so every tab keeps its own back stack (Store → app page,
  Library → game page, …). Re-selecting the active tab pops to its root.

## Input

The shell tracks the **last-used input** (`InputModeService`) and adapts, per DESIGN.md §3.

**Mouse** — hover lifts cards (3 px) and lights them with `surfaceHover`; shelves show an auto-hiding
scrollbar; mouse button 4 (back) navigates back.

**Keyboard** — every content container has `XYFocusKeyboardNavigation="Enabled"`, so arrow keys do
spatial navigation; Enter/Space activate; Esc / Backspace / Alt+← / Ctrl+[ go back; Tab follows
the normal order. `Ctrl+1…4` switch tabs, `Ctrl+F` focuses search. Focused cards scale to **1.04**
(120 ms, `UIElement.ScaleTransition`) inside a **2 px white + accent** high-visibility focus ring
(`FocusVisualPrimaryBrush` / `FocusVisualSecondaryBrush` / `FocusVisualMargin`), and shelves scroll
the focused card into view with roughly one card of look-ahead (`StartBringIntoView` with an
expanded `TargetRect`).

**Gamepad** — WinUI 3 desktop apps don't get gamepad navigation for free, so `GamepadController`
polls `Windows.Gaming.Input.Gamepad` every 16 ms on a `DispatcherQueueTimer`, edge-detects buttons
and maps the left stick onto the D-pad with key-repeat:

| Button | Action |
|---|---|
| D-pad / left stick | `FocusManager.TryMoveFocus(direction, new FindNextElementOptions { SearchRoot = XamlRoot.Content })` |
| A | Invoke the focused element through its automation peer (`IInvokeProvider`, then toggle / selection-item / expand-collapse); pages the hero carousel when it is focused |
| B | Back; at a tab's root, move focus to the tab bar |
| Y | Focus search (Store) / the library filter |
| X | Secondary action — favourite (Library, game page), wishlist (store app page) |
| LB / RB | Previous / next tab (wraps) |
| LT / RT | Previous / next library collection (Community sections on compact) |

While a gamepad is the last input, a Big-Picture-style **hints bar** is pinned to the bottom
(`Ⓐ Select  Ⓑ Back  Ⓧ Favorite  Ⓨ Search  LT/RT Collection  LB/RB Switch tab`, context-dependent)
and small `LB` / `RB` glyphs frame the tab strip. Any mouse click, wheel or real pointer movement
switches back to mouse mode.

**Touch** — large targets (cards, 48 epx buttons, 64 epx bottom tabs), panning `ScrollViewer`s with
optional snap points on shelves, press-state feedback on every card.

## CI and screenshots

[`.github/workflows/windows.yml`](../../.github/workflows/windows.yml) runs on `windows-latest`:

1. `dotnet build -c Release -p:Platform=x64` (and an ARM64 build at the end).
2. `scripts/screenshots.ps1` raises the runner's display to 1920×1080 if needed, then for each shot
   starts `NativeSteam.exe` with the switches above at `--size 1440x900`, waits for the window and
   ~12 s for CDN artwork, brings it to the front, copies the window's DWM frame bounds from the
   screen (falling back to `PrintWindow` with `PW_RENDERFULLCONTENT`) and kills the process.
3. The PNGs (`store`, `library`, `community`, `profile`, `game`, `gamepad`, plus `app`,
   `library-compact`, `store-compact`) are uploaded as the `windows-screenshots` artifact; the app's
   `nativesteam.log` is uploaded as `windows-app-log`. Copy them into `docs/screenshots/windows/`.

Run the same capture locally on Windows (Windows PowerShell 5.1 or pwsh):

```powershell
powershell -ExecutionPolicy Bypass -File clients/windows/scripts/screenshots.ps1
powershell -ExecutionPolicy Bypass -File clients/windows/scripts/screenshots.ps1 -Only gamepad,game
```

## Troubleshooting

- The app writes `nativesteam.log` next to `NativeSteam.exe` (start-up route, snapshot path, and
  any unhandled exception).
- `--size` is in effective pixels; on a 150 % display `--size 1440x900` gives a 2160×1350 px window.
