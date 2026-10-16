# Native Steam — Web

The web client of [Native Steam](../../README.md): a fully static Next.js app
that renders `data/snapshot.json` with one adaptive UI for **mouse & keyboard,
touch and gamepad**. It follows [docs/DESIGN.md](../../docs/DESIGN.md).

> Unofficial concept, not affiliated with Valve. No Valve logos are used. Game
> art loads from Steam's public CDN at runtime. The purchase, install and play
> buttons don't do anything real.

| Desktop | Mobile |
|---|---|
| ![Store](../../docs/screenshots/web/store.png) | ![Store on mobile](../../docs/screenshots/web/store-mobile.png) |
| ![Library](../../docs/screenshots/web/library.png) | ![Library on mobile](../../docs/screenshots/web/library-mobile.png) |
| ![Gamepad mode](../../docs/screenshots/web/gamepad.png) | ![Profile on mobile](../../docs/screenshots/web/profile-mobile.png) |

## Stack

- **Next.js 16** (App Router, TypeScript, Turbopack) with `output: "export"`. Every route, including all 35 library game pages and 53 store app pages, is prerendered to plain HTML with `generateStaticParams`.
- **React 19** and **plain CSS** (one stylesheet per area under `src/app/styles/`). The brand tokens from DESIGN.md §1 are CSS custom properties in `tokens.css`.
- **lucide-react** for icons. The platform glyphs are small inline SVGs.
- **Playwright** (dev only) for the screenshot script.
- **pnpm** and Node 24.

### Data

`scripts/copy-snapshot.mjs` copies `../../data/snapshot.json` into
`src/generated/snapshot.json` (gitignored) before `dev`, `build` and
`typecheck`. `src/lib/types.ts` mirrors the Rust model in
`core/crates/steam-model`. Only server components read the snapshot (through
`src/lib/data.ts`), so the 600 KB JSON never ships to the browser. Each page
passes its client components just the slice they need. `*Label` fields are
rendered as-is, and every nullable field has a fallback.

## Run, build and export

```sh
cd clients/web
pnpm install
pnpm dev            # http://localhost:3000
pnpm build          # type-check + static export to out/
pnpm serve          # serve out/ at http://127.0.0.1:4173
pnpm typecheck      # tsc --noEmit only
```

To host under a sub-path such as GitHub Pages, set `BASE_PATH` when you build:

```sh
BASE_PATH=/native-steam pnpm build
```

`.github/workflows/web.yml` builds on every push and PR that touches the web
client or the data. On `main` (or a manual `workflow_dispatch`) it deploys
`out/` to GitHub Pages, using the base path that `actions/configure-pages`
reports.

### Screenshots

```sh
pnpm exec playwright install chromium   # once
pnpm build && pnpm screenshots          # all shots → docs/screenshots/web/
pnpm screenshots gamepad store-mobile   # just some
```

The script serves `out/` on a random local port and opens each page at
1440×900 @1x (desktop) or 390×844 @2x (mobile, touch). It waits until every
on-screen image has loaded, then saves the PNGs. Reduced motion is on, so the
hero carousel stays still.

## Routes

| Route | Page |
|---|---|
| `/`, `/store/` | Store: search, tag chips, featured carousel, offers, top sellers, new & trending, most played, upcoming |
| `/store/app/[appId]/` | Store app page |
| `/library/` | Library: collections sidebar or chips, recent games, sortable grid |
| `/library/game/[appId]/` | Library game page |
| `/community/` | Friend activity, news, hubs, friends |
| `/profile/` | The persona tab (KESTREL) |

## Adaptive shell

The size class depends on window width, not device type, and is handled in
CSS:

- **Compact (< 700 px)**: a bottom tab bar (the persona tab shows the avatar),
  large page titles, swipeable shelves and a 3-column library grid. Community
  uses an `Activity | News | Hubs` segmented control.
- **Regular (≥ 700 px)**: a Steam-style top nav with uppercase tracked tabs and
  a 3 px accent underline. The library gets a collections sidebar from
  1000 px, and the community gets a right rail (hubs and friends) from 1100 px.

Each tab keeps its own navigation stack: switching back to a tab returns to
where you left it, and re-selecting the active tab pops to its root.

## How input works

All of this lives in `src/components/shell/` and `src/lib/spatial.ts`.

**Last-used input.** `InputContext` tracks the last-used input and writes it
to `<html data-input="mouse|touch|keyboard|gamepad">`. An inline script sets
the attribute before first paint, so there's no flash:

- A pointer press sets `mouse` or `touch`.
- Real mouse movement (more than 12 px) sets `mouse`.
- Any key press sets `keyboard`.
- Any gamepad button or stick sets `gamepad`.

CSS keys off this attribute:

- The focus ring (2 px white ring plus a 4 px accent glow), the 1.04 card scale and brighter artwork appear only for `keyboard` and `gamepad`.
- Hover lifts apply only to `mouse`.
- Press feedback and 44 px targets apply only to `touch`.
- Shelves turn off scroll-snap while keys or a gamepad drive them.

**Spatial navigation** (`lib/spatial.ts`). Arrow keys, the D-pad and the left
stick move focus to the nearest focusable element in that direction, based on
bounding rects:

- Left and right stay within the current row.
- Up and down prefer elements that overlap on the cross axis, then the one whose leading edge lines up.
- A focused card's scale transform is factored out before measuring.
- An item that's still animating into a carousel is measured by its visible part.

`reveal()` then scrolls every scrollable ancestor, so the focused item stays
fully visible. Inside horizontal shelves it keeps about a card of lookahead.
The page itself scrolls clear of the sticky nav and the bottom bars.

**Gamepad.** `Controller` polls the Gamepad API in `requestAnimationFrame`
once a pad connects. D-pad and stick repeat after 380 ms, then every 110 ms.

| Button | Action |
|---|---|
| A | Activate the focused item |
| B | Back. Pops the current tab's stack, or returns to where a link was opened from. At a tab root, it moves focus to the tab bar. It also closes the screenshot viewer. |
| X | The focused item's secondary action: favorite (library), wishlist (store) or like (activity) |
| Y | Focus search (Store or Library; from other tabs it jumps to Store search) |
| LB / RB | Previous / next tab (wraps) |
| LT / RT | Previous / next library collection or community section |
| Right stick | Free scroll |

While a gamepad is the last input, a Big Picture-style **hints bar** sits at
the bottom (above the compact tab bar). Its X hint updates to match the
focused item. **LB and RB glyphs** appear at both ends of the nav whenever a
pad is connected.

When you navigate with keys or a gamepad, focus moves into the new page. Going
back restores the element you left from.

**Keyboard.**

| Key | Action |
|---|---|
| Arrow keys | Spatial navigation |
| Enter / Space | Activate |
| Esc / Backspace | Back |
| Tab | Normal DOM order |
| ⌘/Ctrl + 1…4 | Switch tabs |
| ⌘/Ctrl + F | Search |
| ⌘/Ctrl + [ | Back |

**`?input=gamepad`** (or `keyboard`) forces that mode on load and focuses the
first item in the content. Pointer *movement* won't override it, but a real
click or tap will. The screenshot script uses this for `gamepad.png`. Try
<code>/library/?input=gamepad</code> and use the arrow keys as a D-pad.

## Layout

```
src/
  app/                 routes + global styles (styles/*.css)
  components/
    shell/             Shell, top nav, tab bar, hints bar, input + nav contexts, controller
    store/ library/ community/ profile/
    ui/                Art (lazy CDN image + placeholder), Shelf, price block, lightbox…
  lib/                 types.ts (model), data.ts (build-time reader), spatial.ts, tabs.ts
scripts/               copy-snapshot, static server, screenshots
```
