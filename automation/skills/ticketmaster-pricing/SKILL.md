---
name: ticketmaster-pricing
description: Twice-weekly Ticketmaster pricing research for MADR Tickets (Duggan and Mark's Thunder season seats, Section 101 Row DD) — read the resale listings in sections 101, 102, 120 and 119 for every upcoming Thunder home game in the logged-out "MADR Research" Chromium profile, the way Kate did on 2026-11-16, and post them to madrtickets.com, which prices our seats and records whether our own seats are listed. Trigger Monday and Wednesday at 4am (systemd timer) or whenever Duggan asks to refresh ticket prices.
---

# Ticketmaster pricing research

Twice a week, read what Ticketmaster buyers can see for every upcoming Thunder home game near our seats, and hand it to MADR Tickets. **The app does all the analysis**: comparables, outliers, fees, recommendations, and whether our own seats are listed. Your job is to read the listings faithfully, slowly, and to stop cleanly if Ticketmaster pushes back. Slow is fine; a run of ~35 games takes about an hour.

## Standing context

- Our seats: **Section 101, Row DD, seats 1–3** at Paycom Center. Comparables: sections **101, 102, 120**. Section **119** is read for context only: the seat map shows it, and the app never prices with it. The targets' `sections` lists all four.
- **Seats near ours.** Listings in rows within 3 of DD in 101, 102 and 120 (the targets' `seat_rows`) can set the market value, so the reader opens each one's card for its seat numbers, about 3 a game. It always reads our row, and reads at most 20 others a page (`seat_reads_capped` in `__madrMeta()` counts any it skipped). Everything else is read from the list alone, by section and row.
- Ticketmaster's default quantity is **2**, which is what we price. Prices on the page are **all-in per ticket** (fees in, tax out). Don't change the quantity or the fee display yourself; the reader prices at 2 and only switches quantity for its second look at our row.
- **Our own listing.** Our exact seats are **Section 101, Row DD, Seats 1, 2 and 3**, and only those count.
  - The list doesn't show seat numbers, so the reader opens each Row DD listing in Section 101 and reads its panel ("You'll get 2 tickets together in Sec 101, Row DD, Seats 6-7."). Then it closes the panel.
  - Ticketmaster lists only what sells at the chosen quantity, and we price pairs (2). A listing of all three of our seats that only sells together is hidden at 2, as Dec 13 was on 2026-11-16. So when our open seats aren't 2, the reader switches the quantity to that number afterwards and reads our row again (`quantity_check` in `__madrMeta()`).
  - The app records our seats as listed at a price only if that listing has seats 1, 2 or 3. Someone else's Row DD seats, such as 6-7, don't count.
  - No listing with our seats means not listed, but only after a complete read at our seat count.
  - Each scan's response reports this as `our_listing.outcome`:
    - `listed`, `confirmed`, `repriced` or `not_listed`;
    - `unconfirmed`: a Row DD listing's seats couldn't be read, or the look at our seat count couldn't be done, so nothing changed;
    - `unclear`: our seats at two prices;
    - `incomplete` or `nothing_to_sell`.
  - Report it; never change anything on Ticketmaster.
- Results: https://madrtickets.com/pricing · run log: https://madrtickets.com/import_runs
- Files in this skill folder (`~/.claude/skills/ticketmaster-pricing/`):
  - `bin/madr-api METHOD PATH [BODY_FILE]` — the only way to talk to the app. It reads the token from `~/.config/madrtickets/market-research.header`.
  - `bin/research-browser-id DEVICE_ID...` — prints which connected browser is the research profile.
  - `bin/research-window open|front` — opens the research profile on its marker page (`research-window.html`, titled "MADR Research") in a window hidden on the `special:madr` workspace, then closes that marker tab so your tab is in front. To watch a run: `hyprctl dispatch 'hl.dsp.workspace.toggle_special("madr")'`.
  - `extract_listings.js` — the page reader. Run it in the event tab with `javascript_tool`.
  - `bin/build-scan` — turns the reader's chunks into a game's scan file.
- Work folder for this run: `W=$(mktemp -d /tmp/madr-research-$(date +%F)-XXXX)`. Save every body you POST there.

## Hard rules

1. **Read only.** Never sign in, never type credentials, never click Buy, Sell, Checkout, "Reserve Tickets", Next, Find Tickets with a purchase intent, or My Account. Only the reader clicks, and only these:
   - the "Accept & Continue" policy dialog;
   - the ticket quantity filter and one of its options, for the second look at our seat count;
   - in the rows near ours (`seat_rows`: our row Section 101 Row DD, and rows AA to GG in 101, 102 and 120), each listing's card, to read its seat numbers;
   - that panel's "Close Ticket Selection" button.

   You don't click anything yourself. The only other thing that touches the research browser is `bin/research-window`, which hides its window and closes the marker tab it opened.
2. **Logged out, research profile only.** Use the connected browser named **MADR Research**. If Ticketmaster shows anyone signed in ("My Account", a first name in the header) instead of "Sign In/Register", stop and tell Duggan to sign out of Ticketmaster in that profile.
3. **Never get past a block.** CAPTCHA, "Pardon the Interruption", "Your browsing activity has been paused", a queue or waiting room, access denied: stop the whole run. Don't retry, reload repeatedly, or switch profiles to get around it.
4. **Never show the token.** Don't `cat` the header file, echo it, or put it anywhere but `bin/madr-api`.
5. **One game at a time, about 30 seconds apart.** Scheduled runs: Monday and Wednesday at 4am. Anything else only when Duggan asks.
6. **Advisory only.** Never change a listing or price anywhere. MADR's recommendations are for Duggan and Mark to act on.

## Before you start

1. **Targets.** `bin/madr-api GET /api/v1/research_targets > $W/targets.json`. It holds `start_url`, `sections`, and `games` (`id`, `date`, `opponent`, `ticketmaster_url`, `seats_to_sell`, `last_scanned_at`). If it fails with 401 or "no token header", stop and tell Duggan (see Setup).
2. **Browser.** Chromium draws only the tab in front in each window, and Ticketmaster's list loads more listings only while its page is drawn. Your tab has to be in front; its window can stay hidden.
   - `bin/research-window open`. It opens the **MADR Research** profile on its marker page, in a window hidden on the `special:madr` workspace, or finds it if the timer already did. It prints the window's address.
   - `list_connected_browsers`, then pass every `deviceId` it lists to `bin/research-browser-id`, and `select_browser` the id it prints. The extension's display names ("Browser 1", "archdesktop") shuffle, so never choose by name. If it prints nothing, wait ~10 seconds, list the browsers again and retry once. If it's still missing, stop and notify (see Report). Never fall back to another browser. Duggan's everyday profile is connected too.
   - `tabs_context_mcp` with `createIfEmpty: true`. Claude in Chrome puts its tab behind the marker page, so run `bin/research-window front`: it closes the marker tab, and yours is in front.
   - Do the whole run in that one tab. Never add one with `tabs_create_mcp`: the extension opens new tabs behind the current one, where Chromium doesn't draw them.
   - Navigate the tab to `start_url`, then check that it's drawn. This returns the frames drawn in a second, about 60 for a tab in front:

     ```js
     await new Promise((done) => { let n = 0; const t0 = performance.now(); const f = () => (performance.now() - t0 < 1000 ? (n++, requestAnimationFrame(f)) : done(n)); requestAnimationFrame(f); setTimeout(() => done(n), 3000) })
     ```

     Under 20 means the tab is behind another one. Run `bin/research-window front` and check again. If it's still under 20, stop before starting the run, and notify as in *When the tab isn't drawn*.
3. **Start or resume the run.**
   - Make `$W/client_id` once with `echo "$(hostname)-$(date +%s)" > $W/client_id`. If you're resuming after a crash, reuse the old work folder's client id.
   - The key is the date: `tm-$(date +%F)`. Monday's and Wednesday's runs are separate, and a crashed run resumes the same day.
   - If you were started with the argument `again`, this is a second full run the same day, which Duggan asked for. Use `tm-$(date +%F)-again`.
   - POST `/api/v1/import_runs` with `{"kind":"market_research","source":"ticketmaster_browser","key":KEY,"client_id":ID,"agent_version":"ticketmaster-pricing/1"}`.
   - **201** is a new run. **200** is a resumed run: skip every game in `scanned_game_ids`. **409** means another run holds it, or today's run already completed: stop and report, don't start a second one.

## Mid-week rescan (`/ticketmaster-pricing soon`)

If you were started with the argument `soon`, rescan only the games in the next seven days. Prices move fastest then.
- **Targets:** `bin/madr-api GET "/api/v1/research_targets?within_days=7"`. If it lists no games, report "nothing in the next week" and stop.
- **Run key:** `tm-$(date +%F)-soon`, so it doesn't collide with a full run the same day.
- **Report:** in the vault Log line, write "mid-week rescan" in place of the seat value, because only some games were scanned.
- Everything else is the same: the hard rules, the routine and block handling.

## The routine

### 1. Find the games
- Your tab is on `start_url`. Let it load, and accept the policy dialog if it shows.
- Confirm the header says **Sign In/Register** (rule 2).
- Collect the event links with `javascript_tool`. Example:

  ```js
  [...document.querySelectorAll('a[href*="/event/"]')].map(a => [a.href.split("?")[0], a.innerText.replace(/\s+/g, " ").slice(0, 120)])
  ```

  Scroll or click "More events" until no new ones appear.
- Map each target to an event by the date in the URL (`...-MM-DD-YYYY/event/<id>`). When a target has a `ticketmaster_url`, prefer the link with the same event id.
- NBA Cup knockout games and dates that are still TBD may only appear as links on another event's page. Look there before giving up, and never guess an event for a date.
- Note any target with no event, and skip it.

### 2. Read each game (ascending date, skipping already-scanned games)
1. Navigate the tab to the event URL from the page. Wait ~8 seconds.
2. Run `window.__madrSections = S; window.__madrSeatRows = R; window.__madrOurs = {section: "101", row: "DD", quantity: N}`. S is the targets' `sections` array and R its `seat_rows` object, both pasted exactly as the targets give them. Take section and row from `our_seats`, and N from the game's `seats_to_sell`. Then run the contents of `extract_listings.js` with `javascript_tool`. It returns `"started"`.
3. Poll `JSON.stringify({status: window.__madr?.status, read: window.__madr?.read})` every ~10 seconds, for up to 3 minutes. Each tool call must finish within 45 seconds.
4. Act on the status:
   - **blocked**: go straight to *When Ticketmaster blocks you*.
   - **not_drawing**: Chromium isn't drawing the tab (`fps` in `__madrMeta()` is under 20), so the list can't load past its first listings. That's this computer, not Ticketmaster. Post nothing for this game. Run `bin/research-window front`, navigate to the event again and rerun the reader once. If it's still not drawing, go to *When the tab isn't drawn*.
   - **stalled**: the page was drawn, but the list stopped loading well short of Ticketmaster's own results count (`read` of `event_total_listings`). That's Ticketmaster holding back. Post nothing for this game, and treat it as a block: go to *When Ticketmaster blocks you*.
   - **no_list**: look at the page. Sold out, no listings, or an error page means note it for this game and move on. Anything else that looks like a block is rule 3.
   - **error**: note it and move on. If 3 games end in errors, finish the run as partial.
   - **done**: tool output is cut off at around a thousand characters, so read the result in pieces.
     - Read `window.__madrMeta()` for the title, `event_total_listings`, `scroll_complete` and `quantity_check`. Save it, exactly as returned, as `$W/meta-<game id>.json`.
     - Read `window.__madrChunk(0, 10)`, then `(10, 10)`, `(20, 10)` and so on, until one returns `[]`. Batch several in one `browser_batch`. Each row is `[position, section, row, price, "R"|"S", label, seats]`; seats are filled only in the rows near ours.
     - Append each chunk, exactly as returned, as one line of `$W/rows-<game id>.txt`.
     - Build the scan file: `bin/build-scan $W <game id> "<event URL>" <YYYY-MM-DD> <event_total_listings> <true|false> "<title>"`. It writes `$W/scan-<game id>.json` (with the second look from the meta file) and refuses duplicated rows.
5. `bin/madr-api POST /api/v1/import_runs/<run id>/market_scans $W/scan-<game id>.json`:
   - **201** means saved; **200** with `"replayed": true` means already saved.
   - Note `our_listing` from the response for the report (see Standing context).
   - **422** (for example, the event date doesn't match the game) or **409**: note the message and move on. Never edit listings to make a post go through.
6. Wait about 30 seconds before the next game.

### 3. Finish
- PATCH `/api/v1/import_runs/<run id>` with `{"client_id": ID, "status": "completed", "targeted": <games attempted>, "notes": "...", "errors": ["Jan 30: no event on Ticketmaster", ...]}`. Use `"partial"` if you stopped early for errors. The app downgrades "completed" to "partial" if fewer games were scanned than targeted.
- `bin/madr-api GET /api/v1/import_runs/<run id> > $W/run.json` for the results: each game's market value, recommended list price, strategy, assessment and confidence.

## When Ticketmaster blocks you

1. Stop. Post nothing more.
2. PATCH the run with `"status": "blocked"` and a note of the page title, the game you were on, the time, and what you saw (a block page, or the list stalling at N of M). Everything already posted is kept.
3. `notify-send -u critical "MADR: Ticketmaster research blocked" "<n> of <m> games saved. Run again later, or add listings by hand on each game's page."`
4. `hermes send -t telegram "MADR Ticketmaster research was blocked after <n> of <m> games. Partial results are saved: madrtickets.com/import_runs"`
5. Don't retry this session. The app shows a "research was blocked" item on Home.

## When the tab isn't drawn

1. Stop. Post nothing more.
2. PATCH the run with `"status": "partial"` and a note of the game you were on, the time, and the reader's `fps`. Everything already posted is kept. Don't mark it blocked: nothing happened on Ticketmaster.
3. `notify-send -u critical "MADR: research tab isn't being drawn" "<n> of <m> games saved. Chromium stopped drawing the research tab; run /ticketmaster-pricing again."`
4. `hermes send -t telegram "MADR pricing research stopped after <n> of <m> games: Chromium wasn't drawing the research tab (a problem on the desktop, not Ticketmaster). Partial results are saved: madrtickets.com/import_runs"`

## Report

- **Vault note:** `~/Documents/Obsidian Vault/10 Projects/madrtickets/MADR Pricing Research.md`.
  - If it doesn't exist, create it with frontmatter (`type: note`, `status: active`, `created: <date>`), a one-line purpose, and a `## Log` heading.
  - Otherwise copy it into `$W` first, re-read it right before writing, and edit it with Python, asserting `## Log` appears exactly once.
  - Add at the top of the Log:
    `- <YYYY-MM-DD> — <n>/<m> games scanned (<status>). Seats worth about $<all-in total> all-in. Our listings: <changes the app recorded — e.g. "Pelicans 11/20 listed at $194 all-in", "Lakers 12/9 no longer listed", or "no changes">. Act on: <games within 3 weeks that are over/underpriced, unlisted or unconfirmed — date, opponent, list-at price>. [Pricing](https://madrtickets.com/pricing)`
  - **No secrets in notes.**
- **Desktop:** `notify-send "MADR: Ticketmaster prices updated" "<n> games scanned · <k> need action"`.
- **Terminal:** a short table of each game with market value (all-in), recommended list price and strategy, our seats on Ticketmaster (the `our_listing` outcome and price), and assessment, then the run link. Call out any `unclear` game: Duggan should check which Row DD listing is ours.
- **Cleanup:** close your tab with `tabs_close_mcp`. Its hidden window closes with it, and the next run opens a fresh one.

## Setup (one time, Duggan)

1. **Profile.** In Chromium, add a profile named **MADR Research**. Never sign in to Ticketmaster in it. Install the Claude extension in that profile and sign in to Claude there. Its browser name doesn't matter: `bin/research-browser-id` recognizes it by the device id stored in the profile.
2. **Profile folder.** Find it under chrome://version → *Profile Path* (for example `Profile 1`), and put this in `~/.config/madrtickets/research.env`:

   ```
   MADR_RESEARCH_PROFILE="Profile 1"
   ```
3. **Token.** From the repo, run `bin/kamal app exec 'bin/rails api_tokens:create NAME=market-research SCOPES=market:write'`. Then, with no other text in the file:

   ```
   mkdir -p ~/.config/madrtickets
   echo 'Authorization: Bearer madr_…' > ~/.config/madrtickets/market-research.header
   chmod 600 ~/.config/madrtickets/market-research.header
   ```
   Revoke it any time under Settings → Workstation access.
4. **Install.** Run `automation/install.sh` from the repo. It links this skill and installs the systemd units without enabling them.
5. **Schedule.** `systemctl --user enable --now madr-ticketmaster-pricing.timer` (Mondays and Wednesdays, 4am Central).
