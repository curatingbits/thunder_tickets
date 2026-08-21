# One-off migration scripts

These were used once, on 2026-08-21, to migrate the views from hardcoded
Tailwind palette utilities (`bg-gray-800`, `text-green-400`, ...) to the
semantic tokens defined in `app/assets/tailwind/application.css`
(`bg-surface`, `text-positive`, ...).

They have already been applied and committed. They are kept only as a record
of exactly what was rewritten — re-running them is a no-op, since no
palette classes remain in `app/views/`.

Order they were run in:

1. `migrate_gray_to_tokens.rb`      — 312 replacements (surfaces, borders, text)
2. `migrate_semantic_colors.rb`     — 276 replacements (profit/loss/warning/accent)
3. `migrate_tinted_backgrounds.rb`  —  11 replacements (tinted alert backgrounds)

If you add a new view, use the semantic tokens directly. Do not reintroduce
`gray-*` / `green-*` / `red-*` utilities, and never build a class name by
string interpolation — Tailwind's scanner only sees complete literal class
names, so `"bg-#{color}-500"` silently renders unstyled.
