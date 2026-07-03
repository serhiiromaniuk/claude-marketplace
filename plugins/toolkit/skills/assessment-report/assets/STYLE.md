# Style Guide — Assessment Report design system (v3 "blueprint")

The visual language for all reports. Goal: looks **intentional and consulting-grade**, never a template. Print-first (A4), self-contained, dual-audience (stakeholder dashboard + engineer detail).

The system has a deliberate point of view: **"infrastructure / a system rendered as a blueprint."** Three things make it ownable — keep all three on every report:
1. a **subject-derived motif** (here an isometric city; re-skin per report),
2. a **three-voice type system** (serif display · sans body · mono annotation),
3. **signature chrome** (isometric logomark · a clay tile-glyph on every label · an architect's scale-tick rule under every section header).

The severity and grade scales are **unchanged and semantic** — never restyle them for decoration.

## Design tokens (CSS `:root`)

```css
/* blueprint identity */
--ink:#0c1726;  --navy:#0d2742;  --navy-2:#0a1d33;  --navy-hi:#356084;
--slate:#334155; --muted:#475569;        /* caption gray — AA on white; do NOT lighten */
--line:#e2e8f0; --panel:#f7f9fb; --panel2:#eef2f6;
--cyan:#2ba6c9; --cyan-d:#1a7f9c; --cyan-l:#8fd6e8;   /* architectural cyan — cool accent, "good"/info, links, eyebrows */
--clay:#c2603d; --clay-d:#9f4a2c; --clay-l:#e6a589;   /* terracotta — warm accent, subject motif, radar fill, tile-glyph */
/* severity (UNCHANGED) */   --crit:#7f1d1d; --high:#dc2626; --med:#d97706; --low:#2563eb; --ok:#16a34a;
/* grade bands (UNCHANGED) */--gA:#16a34a; --gB:#65a30d; --gC:#d97706; --gD:#ea580c; --gF:#b91c1c;
```

**Colour roles** — three brand colours, each with a job, so colour stays meaningful not decorative:
- **blueprint-navy** — structure: headers, section-number tiles, KPI base, table headers.
- **architectural-cyan** — the cool accent: eyebrows, links, effort pills, "good"/info callouts, the gauge/cost cool bars, radar guide rings, list markers.
- **terracotta (clay)** — the warm subject accent: the logomark/skyline, the recurring tile-glyph, **radar data fill**, Wave-3/hygiene, pull-quote rule.

## Type — three voices

```css
--serif:Georgia,"Liberation Serif","DejaVu Serif","Times New Roman",serif;
--sans:-apple-system,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
--mono:"SFMono-Regular",Consolas,"Liberation Mono",Menlo,monospace;
```

- **Serif = display.** All headlines (`h1` cover 50px, `h2` section 21px, `h3` 14px), **big numbers** (KPI `.n`, gauge centre, tenant score), and **grade letters**. This is where the document gets character. On Linux render boxes the serif resolves to **Liberation Serif** (Times-metric) — verified to render; don't assume Georgia is present.
- **Sans = body.** Paragraphs, table cells, bullets, the cover subtitle. Base 10.5px / line-height 1.5.
- **Mono = annotation (the "blueprint" voice).** Every `h4` label, the cover kicker/wordmark/meta, chip text, table headers (uppercase tracked), axis labels, the `OUT OF 100` gauge caption, pills, stance/score cells. This pervasive mono labelling is a big part of the identity — use it for *labels*, never for body copy.
- **Page** `@page { size:A4; margin:13mm 12mm 15mm 12mm }`. Always set `-webkit-print-color-adjust:exact; print-color-adjust:exact`.

## Signature elements (the through-line — keep on every report)
- **Isometric logomark** — a small cluster of isometric blocks (top diamond + two side faces) on the cover brandmark. Use ~3 blocks tinted cyan/clay to echo "N things assessed".
- **Tile-glyph** — a 6px clay square rotated 45° before every `h4` (via `h4::before`). When a label needs a leading pill, use `h4.plain` and hand-place the glyph so you can colour it to match (e.g. roadmap waves: ok / cyan / clay).
- **Scale-tick rule** — the section-header underline is an architect's scale bar: a 2px navy baseline with ticks every 13px (`.sec-head::after`), and the first 46px tinted clay (`.sec-head::before`). Replaces the plain 2px border.
- **Subject motif** — a faint line-art SVG (here an isometric skyline) filling the cover's lower band. **Re-skin per report** (topology, map, org chart…) but keep it line-art, low-opacity, atmospheric.

## Brand chrome
- **Cover** (`height:244mm`): blueprint navy→deep gradient + a faint **isometric grid texture** (two `repeating-linear-gradient`s at ±30°) + a cyan radial glow top-right. Lockup top-to-bottom: brandmark → kicker (mono, tracked, cyan-l) → big serif title → sans subtitle → numbered chips (`01/02/03`, mono) → **verdict box** (big serif grade + `vsep` + so-what) → **statstrip** (4 quick stats) → spacer → meta row (mono labels). The skyline sits behind, low-opacity.
- **Section header** `.sec-head`: navy rounded **number/letter tile** (serif numeral, lighter top edge for a 3D-block read) + `h2` + the scale-tick rule.
- **Footer**: supplied by the renderer (page numbers). In-page `.footer{display:none}`.

## Component catalog
All of these exist as live examples in `template.html` — copy from there.

| Component | Use for | Class / element |
|---|---|---|
| Brandmark | cover logo lockup | `.brandmark` (inline iso-block `<svg>` + `.wm`) |
| Skyline motif | cover subject visual | `.skyline` (inline line-art `<svg>`) |
| KPI strip | 3–4 headline numbers | `.kpis > .kpi` (variants `.cyan .amber .slate`) |
| Verdict box | cover grade + so-what | `.verdict` (`.big` serif grade · `.vsep` · `.vtext`/`.vh`) |
| Statstrip | 4 quick cover stats | `.statstrip > .s` (`.v` serif · `.l` mono) |
| Gauge (donut) | one composite 0–100 score | inline `<svg>` ring, `stroke-dasharray = round(score/100·402)` |
| Dimension bars | 5-dimension breakdown | `.dim` rows (mono label / bar / value) |
| Radar | per-area 5-axis profile | inline `<svg>` pentagon — **terracotta fill .32 + 2px clay stroke**, cyan guides, mono axes (S/R/O/I/C) |
| Severity bars | finding counts by severity | inline `<svg>` horizontal bars (severity colours) |
| Impact×Effort matrix | prioritization (the showpiece) | inline `<svg>` 2×2; bubble size+colour = severity; **space so none overlap** |
| Scorecard | per-area grade + profile | `.card` with `.grade` badge (serif) + radar |
| Findings table | detailed findings | `<table>` with `.sev` badges, confidence dot on ID |
| Risk register | ranked backlog | `<table>` with `score → residual`, `.st` stance pills |
| Callout | emphasis / warnings | `.callout` (`.warn` amber, `.risk` red) |
| Insight mini-cards | "so-what" under a diagram | `.ins` (`.ih` mono head) — 3-up, de-densifies sparse pages |
| Pull-quote | editorial pacing device | `.pq` (serif italic, clay rule) — fill a half-empty page with a real takeaway |
| Badges | severity / grade / status | `.sev .s-*`, `.grade .g*`, `.pill`, `.st .st-*` |
| Confidence dot | evidence certainty | `.cd .cv|.ci|.ca` (green/amber/grey) on the ID cell |

## Layout rules
- Grids: `.grid.g2` / `.grid.g3`; cards `.card` (white) and `.panel` (tinted).
- One section per page where practical; force with `.page` (`break-before:page`) and protect blocks with `.avoid` (`break-inside:avoid`).
- **Anti-overflood**: prefer scannable tables, badges and short bullets over prose. Heavy detail (raw evidence, standards mapping, command output) goes to the Appendix.
- **No empty-looking pages.** A page that's 50%+ blank reads as unfinished — fill it with a **pull-quote** and/or a row of **insight cards**, never with padding. (Reference/legend pages may breathe more.)
- **Dual audience order**: dashboard first (stakeholders), detailed sections next (engineers), bridged by a consolidated register and an impact/cost/roadmap section.

## Accessibility
- Caption gray is `--muted` (#475569, ~7:1 on white) — **never** lighter for small text. Chart axis/footnote text bumps to `#64748b` minimum.
- On the dark cover, accent text uses **`--cyan-l` (#8fd6e8)**, not mid cyan — keeps eyebrow/links above AA on the gradient.

## Severity & grade scales (unchanged — these encode meaning)
- Risk score 1–25 (L×I): 20–25 Critical · 12–19 High · 6–11 Medium · 1–5 Low.
- Posture band: 85–100 A Strong · 70–84 B Good · 55–69 C Fair · 40–54 D At-risk · <40 F Critical. (Security scale, not academic — "C" = fair.)
- Token discipline: let **one badge system lead per page** (severity on tenant pages; stance on the register). Don't stack severity + confidence + grade + stance with equal weight on the same page.

## Charts: hand-built SVG, not libraries
No chart library (keeps it self-contained for the renderer). Build each by copying and re-pointing the `template.html` example:
- **Donut** — a stroked circle, `stroke-dasharray = round(score/100·402)`; centre number serif, caption mono.
- **Radar** — pentagon grid + a data polygon. Precompute vertices: center (70,70), R=52; unit vectors S(0,−1) R(.951,−.309) O(.588,.809) I(−.588,.809) C(−.951,−.309); vertex = center + (value/100)·R·unit. Fill **terracotta** `.32` + **2px clay** stroke (not thin orange), cyan-tinted guide rings, mono axis letters.
- **Matrix** — quadrant rects + positioned `<circle>`s coloured by severity, radius by severity. **Lay bubbles on a loose grid inside each quadrant so none collide**; mono axis + quadrant labels.
