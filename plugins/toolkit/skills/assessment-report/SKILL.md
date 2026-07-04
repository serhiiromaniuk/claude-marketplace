---
name: assessment-report
description: Produce polished, scored assessment reports as branded PDFs (and optionally publish to Confluence). Use when the user wants a gap/risk analysis, infrastructure or cloud audit, security review, cost review, due-diligence, architecture review, or post-incident report — anything shaped as "findings → scored → executive dashboard → PDF". Bundles a reusable design system, a Chrome-CDP PDF renderer (page numbers + bookmarks), a scoring methodology, read-only discovery playbooks, and an extensible set of report types.
---

# Assessment Report

Turn raw findings into a **dual-audience deliverable**: an executive dashboard for budget-holders plus detailed, evidence-backed sections for engineers — rendered as a clean, branded PDF and optionally published to Confluence.

This skill is **general**. The visual language, scoring, and renderer are shared; the *shape* of a given report comes from a **report type** under `report-types/`. Available types: `gap-risk` (general scored gap/risk assessment), `security-review` (threat-centric OWASP/CIS/NIST posture), `cost-review` (FinOps/cloud-spend), `due-diligence` (tech/vendor DD with a RAG verdict), `architecture-review` (Well-Architected 6-pillar), and `post-incident` (blameless post-mortem). Add new types over time without touching the engine.

## When to use
Trigger on requests like: "do a gap/risk analysis of X", "audit this AWS account / cloud setup", "security review report", "cost review", "vendor/tech due-diligence", "post-incident write-up", or "turn these findings into a stakeholder PDF". If the user just wants raw analysis with no document, you may skip the rendering steps.

## Workflow

1. **Pick the report type.** Look in `report-types/`. If one matches, load its `type.md`. If none fits, use `gap-risk` as the general base and adapt. If genuinely ambiguous, ask the user.
2. **Gather data — read-only first.** Follow `reference/discovery-playbook.md` (AWS describe/list, SSH read commands, Terraform, Confluence/Jira). **Never mutate** anything during discovery. Record each finding's evidence and a confidence level (Verified / Inferred / Assumed).
3. **Score it.** Apply `reference/scoring.md`: per-finding risk = Likelihood × Impact (1–25); per-area letter grade across 5 weighted dimensions; residual risk after fix; a deferral stance (Fix now / Schedule / Accept-interim). Compute a composite posture score.
4. **Build the HTML.** Copy `assets/template.html` to your scratchpad and fill it in following the active `type.md` section list and `assets/STYLE.md` for components. Keep it clean — do NOT overflood; if a section gets heavy, push detail to an appendix.
5. **Render the PDF.** Use the canonical renderer (see below). Never use `chrome --print-to-pdf` directly — it shifts layout and drops page numbers/bookmarks.
6. **Verify visually.** Rasterize a few pages with `pdftoppm -png -r 80 -f N -l N out.pdf chk` and Read the PNGs. Check for: overflow (especially cover height vs A4), footer collisions, SVG-text clipping (mono is wider — long captions can spill their viewBox), matrix bubble collisions, and any page that reads 50%+ empty (add a pull-quote / insight cards).
7. **Publish (optional, only if asked).** Follow `reference/confluence-publish.md` — create the page via the Atlassian MCP, then attach the PDF. **Publishing is an outward-facing action: confirm with the user first.**

## Rendering (canonical, copy-paste)

```bash
SK=~/.claude/skills/assessment-report
PORT=9333
google-chrome --headless=new --disable-gpu --no-sandbox \
  --remote-debugging-port=$PORT --remote-allow-origins=* about:blank >/tmp/chrome.log 2>&1 &
CHROME_PID=$!
for i in $(seq 1 30); do curl -s http://127.0.0.1:$PORT/json/version >/dev/null 2>&1 && break; sleep 0.3; done
node "$SK/assets/render.mjs" "/abs/path/report.html" "$HOME/report.pdf" $PORT "My Report · Confidential"
kill $CHROME_PID 2>/dev/null
pdfinfo "$HOME/report.pdf" | grep -i pages
```

Requirements: `google-chrome` (headless) + `node` (18+, global `WebSocket`). No npm installs, no PDF libraries. `pdftoppm`/`pdfinfo` (poppler) are used only for verification. If those HTML→PDF libraries (weasyprint/wkhtmltopdf) happen to exist they are NOT preferred — the CDP path gives the bookmarks/page-numbers the others can't.

## Design identity (the "blueprint" system — see assets/STYLE.md)
The look is deliberate and ownable, not a generic corporate report. Three things must appear on every report:
- **Palette** — blueprint-navy + architectural-cyan + **terracotta**. Severity & grade scales are **unchanged** (they carry meaning, don't restyle them).
- **Three type voices** — **serif** display (headlines, big numbers, grades) · **sans** body · **mono** annotation (every label, eyebrow, axis, table header). Serif resolves to Liberation Serif on Linux render boxes — it renders; don't assume Georgia is installed.
- **Signature chrome** — isometric logomark · a clay **tile-glyph** (`h4::before`) on every label · an architect's **scale-tick rule** under every section header · a faint **subject motif** (an isometric skyline on the cover; re-skin per report).
- **Pacing** — no 50%+ blank pages: fill with a **pull-quote** or a row of **insight cards**, never padding. **Accessibility** — caption gray is `--muted` (#475569) min; cover accent text is `--cyan-l`.

## Key conventions (don't relearn these)
- **One renderer.** The CDP path (`render.mjs`) is canonical. The old `--print-to-pdf` CLI produced subtly different margins — never mix the two within a project.
- **Cover height.** A4 printable height ≈ 246 mm after default margins. Set `.cover { height: 244mm }` or it spills a sliver onto page 2.
- **Footer.** Page numbers come from the renderer's `footerTemplate`, not from in-page CSS. Keep any in-page `.footer { display:none }`. CSS `position:fixed` footers collide in paged media — avoid.
- **Print color.** Every page needs `-webkit-print-color-adjust:exact; print-color-adjust:exact;`.
- **Self-contained.** All CSS/SVG inline; no external fonts/images/CDNs (the renderer reads a local file://). The serif/mono/sans stacks are all system fonts — no embedding needed.
- **TOC + bookmarks.** Internal `<a href="#id">` links stay clickable in the PDF; real `<h2>` headings become bookmarks automatically. Use `01/02/03` numerals, not `①②③` glyphs (they render inconsistently).

## Files
- `assets/template.html` — design-system skeleton with one live example of every component.
- `assets/STYLE.md` — design tokens (palette, type, spacing) + component catalog.
- `assets/render.mjs` — the canonical renderer.
- `report-types/README.md` — how report types work + the registry of available types.
- `report-types/gap-risk/` — the general gap/risk type (`type.md` spec + `example.html`, a full worked report).
- `report-types/{security-review,cost-review,due-diligence,architecture-review,post-incident}/` — the specialized types, each a `type.md` spec + a full synthetic `example.html`.
- `reference/scoring.md` — scoring rubric.
- `reference/discovery-playbook.md` — read-only data-gathering recipes.
- `reference/confluence-publish.md` — publish + attach flow and its gotchas.
