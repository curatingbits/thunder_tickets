# MADR Tickets — UI Assessment (Aug 21, 2026)

Reviewed live at http://127.0.0.1:3009 (dev, 2026-27 season, 42 games, 0 sold).
Pages: login, dashboard, games index, game show. Desktop 2001px + mobile 390px.

## Verdict

The app is competent and consistent — Tailwind dark theme, real responsive
work, 44px touch targets, sensible zone structure on the dashboard. It reads
like a solid v1 admin tool. The gap to "good" is not styling; it's **density,
hierarchy, and design-system discipline**. Three problems do most of the damage.

---

## Top 3 issues (fix these and the app jumps a tier)

### 1. The games index wastes ~90% of the screen (highest impact)
Each game is a full `.card` — 42 cards, 6,108px of scroll for what is
fundamentally a 42-row table. At 2001px wide, the middle 40% of every row is
empty space, and the four financial columns are rendered at
`text-2xl font-bold` — heading-sized type for tabular data.

Fix: make it a real table on `lg:` and up (sticky header, right-aligned
numerals, `tabular-nums`, `text-sm`), keep the card layout only below `md:`.
Expect ~42 rows in 2–3 screens instead of 12. Add a sortable header and a
season total row.

### 2. There is no design system — colors are ad hoc and partially broken
- `app/assets/tailwind/application.css` defines a full Tokyo Night palette
  (`--color-tokyo-*`) that **nothing uses**. Every view hardcodes
  `bg-gray-800`, `text-blue-400`, `border-gray-700`.
- `layouts/application.html.erb:21` sets `bg-gray-950`; the CSS `body` rule
  sets `#1a1b26`. Two competing background definitions.
- Semantic meaning is inconsistent: red is used for both "loss" and "cost"
  (`games/index.html.erb:75` renders every game's cost in red — cost is not
  bad news), and 0-of-3 sold shows red even for a game 3 months out.
- **Real bug:** `dashboard/index.html.erb:44-46` and `:262-279` build class
  names by interpolation (`bg-<%= ... %>-500/20`, `border-l-<%= ... %>-500`).
  Tailwind's scanner can't see those strings, so those classes are only
  present if some other file happens to emit them. Same pattern in
  `games/index.html.erb`. These will silently render unstyled in production.

Fix: define semantic tokens once (`--color-surface`, `--color-positive`,
`--color-negative`, `--color-muted`, `--color-accent`), map them onto the
Tokyo Night vars already sitting there, and replace interpolated class names
with full literal ternaries.

### 3. Dashboard hierarchy is flat — 20+ numbers all shouting
Every stat is `text-2xl/3xl font-bold` in a saturated color. ROI, gross
margin, sell-through and avg markup get equal visual weight to "Avg
Revenue/Game." Nothing tells you where to look first.

Also, in a pre-season state (0 sold) the page leads with **-100.0% ROI in
red** and three cards reading 0.0%. That's technically correct and
emotionally wrong — the season hasn't started. It's a missing empty state,
not a metric.

Fix: one hero metric (net profit vs. break-even), a secondary row at
`text-lg`, and everything else as label/value pairs. Add a pre-season empty
state: "Season starts Oct 7 · 126 tickets · $20,843 committed" instead of
-100% ROI.

---

## Secondary findings

- **Nav duplication:** desktop and mobile nav are two hand-maintained lists of
  the same 5 links in `layouts/application.html.erb` (lines 36–42 and 95–127).
  Extract to one array + partial; add icons to desktop for symmetry.
- **No active-page state on mobile nav** beyond a bg tint; fine, but the
  desktop underline treatment isn't mirrored.
- **Flash messages** use inline `onclick` (line 150) — should be a Stimulus
  controller, and they don't auto-dismiss.
- **Only 2 flash types** styled (notice/everything-else-is-red). Alerts and
  warnings collapse into the same red.
- **Season switcher** is a bare `<select>` in the page body, visually
  disconnected from the "Season: 2026-27" indicator in the nav. Two controls
  for one concept, in two places.
- **Charts:** Chart.js canvases have no loading or empty-state skeleton — the
  "Profit by Game" area just collapses to centered gray text.
- **Typography:** default system stack. One webfont with tabular numerals
  (Inter, JetBrains Mono for figures) would do a lot of the "looks designed"
  work for near-zero effort.
- **Accessibility:** icon-only buttons lack labels in places; `text-gray-500`
  on `bg-gray-900` for secondary copy is ~3.4:1, under WCAG AA for small text.
  The mobile menu panel has no focus trap or `aria-expanded`.
- **No search anywhere** — buyers and games are both browse-only lists.
- **Emoji in `<title>`** ("🐴 MADR TICKETS") on some pages but not others,
  because of `content_for(:title)` inconsistency.

## Recommended sequence

1. Kill the interpolated Tailwind classes (correctness bug, ~30 min).
2. Games index → table on desktop (biggest perceived win).
3. Semantic color tokens + single background source of truth.
4. Dashboard hierarchy pass + pre-season empty state.
5. Nav DRY-up, webfont, contrast fixes.

Steps 1–4 are roughly a day of focused work and would be a visible step
change. Nothing here requires re-architecting.
