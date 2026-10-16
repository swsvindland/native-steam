#!/usr/bin/env python3
"""Summarise launchbench JSONL (and optional Lighthouse JSON) into Markdown
tables and an SVG scoreboard.

    python3 bench/report.py bench/results/macos-2026-10-16.jsonl \
        [--web bench/results/web-2026-10-16.json] [--svg docs/benchmarks/scoreboard.svg]

Medians are reported (robust to the odd slow run); p90 alongside.
"""
import argparse
import json
import statistics
from pathlib import Path

NAMES = {
    "native-steam": "Native Steam (SwiftUI)",
    "epic": "Epic Games Launcher (new, preview)",
    "steam": "Steam",
}
ORDER = ["native-steam", "epic", "steam"]

# Chart colours (validated: ours vs neutral context on the Steam chrome surface).
OURS, OTHER = "#3987e5", "#5b6570"
SURFACE, TEXT, TEXT2, GRID = "#171a21", "#e6edf3", "#8f98a0", "#2a2f38"


def median(xs):
    xs = [x for x in xs if x is not None]
    return statistics.median(xs) if xs else None


def p90(xs):
    xs = sorted(x for x in xs if x is not None)
    if not xs:
        return None
    return xs[min(len(xs) - 1, round(0.9 * (len(xs) - 1)))]


def secs(ms):
    return "—" if ms is None else f"{ms / 1000:.2f} s"


def load(path):
    rows = [json.loads(l) for l in Path(path).read_text().splitlines() if l.strip()]
    by = {}
    for r in rows:
        by.setdefault((r["app"], r["mode"]), []).append(r)
    return by


def summarise(by):
    out = {}
    for app in ORDER:
        s = {}
        cold = by.get((app, "cold"), [])
        if cold:
            for k in ("ttw_ms", "tfc_ms", "tvc_ms"):
                vals = [r.get(k) for r in cold]
                s[k] = median(vals)
                s[k + "_p90"] = p90(vals)
            s["mem"] = median([r.get("footprint_mib") for r in cold])
            s["procs"] = median([r.get("processes") for r in cold])
            s["runs"] = len(cold)
        reopen = by.get((app, "reopen"), [])
        if reopen:
            s["reopen_ttw"] = median([r.get("ttw_ms") for r in reopen])
            s["reopen_tvc"] = median([r.get("tvc_ms") for r in reopen])
        clicks = by.get((app, "click"), [])
        for target in ("store", "library"):
            vals = [r.get("tvc_ms") for r in clicks if r.get("target", "").lower() == target]
            if vals:
                s[f"click_{target}"] = median(vals)
        out[app] = s
    return out


def markdown(summary, web=None):
    lines = []
    lines.append("| | Window shown | First content | Store visually complete | Memory | Processes |")
    lines.append("|---|---:|---:|---:|---:|---:|")
    for app in ORDER:
        s = summary.get(app, {})
        if "tvc_ms" not in s:
            continue
        lines.append(
            f"| **{NAMES[app]}** | {secs(s['ttw_ms'])} | {secs(s['tfc_ms'])} | "
            f"**{secs(s['tvc_ms'])}** <sub>p90 {secs(s['tvc_ms_p90'])}</sub> | "
            f"{s['mem']:.0f} MiB | {s['procs']:.0f} |"
        )
    lines.append("")
    lines.append("| | Background → window | Background → visually complete | Open Library tab | Open Store tab |")
    lines.append("|---|---:|---:|---:|---:|")
    for app in ORDER:
        s = summary.get(app, {})
        if not any(k in s for k in ("reopen_tvc", "click_store", "click_library")):
            continue
        lines.append(
            f"| **{NAMES[app]}** | {secs(s.get('reopen_ttw'))} | {secs(s.get('reopen_tvc'))} | "
            f"{secs(s.get('click_library'))} | {secs(s.get('click_store'))} |"
        )
    if web:
        lines.append("")
        lines.append("| Store front (web) | Performance | FCP | LCP | Total blocking | Page weight | JavaScript | Requests |")
        lines.append("|---|---:|---:|---:|---:|---:|---:|---:|")
        for w in web:
            if w.get("error"):
                lines.append(f"| **{w['name']}** | {w['error']} | | | | | | |")
                continue
            lines.append(
                f"| **{w['name']}** | {w['score']:.0f} | {secs(w['fcp'])} | {secs(w['lcp'])} | "
                f"{w['tbt']:.0f} ms | {w['bytes'] / 1e6:.1f} MB | {w['js_bytes'] / 1e6:.2f} MB | {w['requests']} |"
            )
    return "\n".join(lines)


# --------------------------------------------------------------------------- SVG

def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def panel(x, y, w, title, unit_note, rows, fmt):
    """Horizontal bar panel. rows: [(label, value, is_ours)]."""
    out = []
    label_w = 0
    bar_x = x
    bar_w = w - 82
    vmax = max((v for _, v, _ in rows if v is not None), default=1) or 1
    out.append(f'<text x="{x}" y="{y}" fill="{TEXT}" font-size="15" font-weight="600">{esc(title)}</text>')
    out.append(f'<text x="{x}" y="{y + 18}" fill="{TEXT2}" font-size="12">{esc(unit_note)}</text>')
    yy = y + 40
    for label, v, ours in rows:
        out.append(f'<text x="{bar_x}" y="{yy}" fill="{TEXT if ours else TEXT2}" font-size="12"'
                   f'{" font-weight=\"600\"" if ours else ""}>{esc(label)}</text>')
        by = yy + 8
        out.append(f'<rect x="{bar_x}" y="{by}" width="{bar_w}" height="14" rx="4" fill="{GRID}"/>')
        if v is not None:
            bw = max(6, bar_w * v / vmax)
            out.append(f'<rect x="{bar_x}" y="{by}" width="{bw:.1f}" height="14" rx="4" fill="{OURS if ours else OTHER}"/>')
            out.append(f'<text x="{bar_x + bar_w + 8}" y="{by + 12}" fill="{TEXT}" font-size="13" '
                       f'font-weight="{600 if ours else 400}">{esc(fmt(v))}</text>')
        else:
            out.append(f'<text x="{bar_x + bar_w + 8}" y="{by + 12}" fill="{TEXT2}" font-size="13">n/a</text>')
        yy += 46
    return out, yy


def scoreboard_svg(summary, title, subtitle, web=None):
    W, pad, gap = 980, 28, 36
    col_w = (W - pad * 2 - gap) / 2

    def row(app, key, scale=1.0):
        v = summary.get(app, {}).get(key)
        return (NAMES[app], None if v is None else v * scale, app == "native-steam")

    s_fmt = lambda v: f"{v:.2f} s"
    specs = [
        ("Cold start → store fully drawn", "median of 10 · lower is better",
         [row(a, "tvc_ms", 1 / 1000) for a in ORDER], s_fmt),
        ("Memory after cold start", "all processes incl. WebKit / CEF helpers",
         [row(a, "mem") for a in ORDER], lambda v: f"{v:,.0f} MiB"),
        ("Background → window fully drawn", "reopen from the Dock · median of 5",
         [row(a, "reopen_tvc", 1 / 1000) for a in ORDER], s_fmt),
        ("Switch to the Store tab", "click → fully drawn · median of 5",
         [row(a, "click_store", 1 / 1000) for a in ORDER], s_fmt),
    ]
    body, y, bottom = [], 96, 0
    for i, (t, note, rows, fmt) in enumerate(specs):
        px = pad + (i % 2) * (col_w + gap)
        py = y + (i // 2) * 210
        if all(v is None for _, v, _ in rows):
            continue
        out, yy = panel(px, py, col_w, t, note, rows, fmt)
        body += out
        bottom = max(bottom, yy)
    H = int(bottom + 30)
    head = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" '
        f'font-family="-apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif" role="img" '
        f'aria-label="{esc(title)}">',
        f'<rect width="{W}" height="{H}" rx="10" fill="{SURFACE}"/>',
        f'<text x="{pad}" y="42" fill="{TEXT}" font-size="20" font-weight="700" letter-spacing="1.5">{esc(title)}</text>',
        f'<text x="{pad}" y="64" fill="{TEXT2}" font-size="13">{esc(subtitle)}</text>',
    ]
    return "\n".join(head + body + ["</svg>"]) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("results", nargs="+")
    ap.add_argument("--web")
    ap.add_argument("--svg")
    ap.add_argument("--subtitle", default="")
    a = ap.parse_args()
    by = {}
    for p in a.results:
        for k, v in load(p).items():
            by.setdefault(k, []).extend(v)
    summary = summarise(by)
    web = json.loads(Path(a.web).read_text()) if a.web else None
    print(markdown(summary, web))
    if a.svg:
        Path(a.svg).parent.mkdir(parents=True, exist_ok=True)
        Path(a.svg).write_text(scoreboard_svg(summary, "COLD OPEN, HEAD TO HEAD", a.subtitle, web))
        print(f"\nwrote {a.svg}")


if __name__ == "__main__":
    main()
