---
name: ticketmaster-pricing
description: Weekly Ticketmaster pricing research for MADR Tickets (Duggan and Mark's Thunder season seats, Section 101 Row DD) — read the resale listings in sections 101, 102 and 120 for every upcoming Thunder home game in the logged-out "MADR Research" Chromium profile, the way Kate did on 2026-11-16, and post them to madrtickets.com, which prices our seats. Trigger Monday mornings (systemd timer) or whenever Duggan asks to refresh ticket prices.
---

# Ticketmaster pricing research

Each week, read what Ticketmaster buyers can see for every upcoming Thunder home game near our seats, and hand it to MADR Tickets. **The app does all the analysis** (comparables, outliers, fees, recommendations). Your job is to read the listings faithfully, slowly, and to stop cleanly if Ticketmaster pushes back. Slow is fine; a run of ~35 games takes about an hour.

## Standing context

- Our seats: **Section 101, Row DD, seats 1–3** at Paycom Center. Comparables: sections **101, 102, 120**.
- Ticketmaster's default quantity is **2**, which is what we price. Prices on the page are **all-in per ticket** (fees in, tax out). Don't change the quantity or the fee display.
- Results: https://madrtickets.com/pricing · run log: https://madrtickets.com/import_runs
- Files in this skill folder (`~/.claude/skills/ticketmaster-pricing/`):
  - `bin/madr-api METHOD PATH [BODY_FILE]` — the only way to talk to the app. It reads the token from `~/.config/madrtickets/market-research.header`.
  - `extract_listings.js` — the page reader. Run it in the event tab with `javascript_tool`.
- Work folder for this run: `W=$(mktemp -d /tmp/madr-research-$(date +%F)-XXXX)`. Save every body you POST there.

## Hard rules

1. **Read only.** Never sign in, never type credentials, never click Buy, Sell, Checkout, Find Tickets with a purchase intent, or My Account. The only button you click is the "Accept & Continue" policy dialog (the reader does that).
2. **Logged out, research profile only.** Use the connected browser named **MADR Research**. If Ticketmaster shows anyone signed in ("My Account", a first name in the header) instead of "Sign In/Register", stop and tell Duggan to sign out of Ticketmaster in that profile.
3. **Never get past a block.** CAPTCHA, "Pardon the Interruption", "Your browsing activity has been paused", a queue or waiting room, access denied: stop the whole run. Don't retry, reload repeatedly, or switch profiles to get around it.
4. **Never show the token.** Don't `cat` the header file, echo it, or put it anywhere but `bin/madr-api`.
5. **One game at a time, about 30 seconds apart.** At most two scheduled runs a week: Monday's full run and, if Duggan enables it, Thursday's rescan of the next week's games.
6. **Advisory only.** Never change a listing or price anywhere. MADR's recommendations are for Duggan and Mark to act on.

## Before you start

1. **Targets.** `bin/madr-api GET /api/v1/research_targets > $W/targets.json`. It holds `start_url`, `sections`, and `games` (`id`, `date`, `opponent`, `ticketmaster_url`, `seats_to_sell`, `last_scanned_at`). If it fails with 401 or "no token header", stop and tell Duggan (see Setup).
2. **Browser.** `list_connected_browsers`, then `select_browser` the one named **MADR Research**. If it isn't connected:
   - start it with `systemd-run --user --quiet --collect /usr/bin/chromium --profile-directory="$MADR_RESEARCH_PROFILE"`; the value is in `~/.config/madrtickets/research.env`
   - wait ~10 seconds and retry once
   - if it's still missing, stop and notify (see Report).
   Never fall back to another browser.
3. **Start or resume the run.**
   - Make `$W/client_id` once with `echo "$(hostname)-$(date +%s)" > $W/client_id`. If you're resuming after a crash, reuse the old work folder's client id.
   - The key is the ISO week: `tm-$(date +%G-W%V)`.
   - POST `/api/v1/import_runs` with `{"kind":"market_research","source":"ticketmaster_browser","key":KEY,"client_id":ID,"agent_version":"ticketmaster-pricing/1"}`.
   - **201** is a new run. **200** is a resumed run: skip every game in `scanned_game_ids`. **409** means another run holds it, or this week's run already completed: stop and report, don't start a second one.

## Mid-week rescan (`/ticketmaster-pricing soon`)

If you were started with the argument `soon`, rescan only the games in the next seven days. Prices move fastest then.
- **Targets:** `bin/madr-api GET "/api/v1/research_targets?within_days=7"`. If it lists no games, report "nothing in the next week" and stop.
- **Run key:** `tm-$(date +%G-W%V)-soon`, so it doesn't collide with Monday's run.
- **Report:** in the vault Log line, write "mid-week rescan" in place of the seat value, because only some games were scanned.
- Everything else is the same: the hard rules, the routine and block handling.

## The routine

### 1. Find the games
- Open `start_url` in a new tab. Let it load, and accept the policy dialog if it shows.
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
2. Run `window.__madrSections = ["101","102","120"]`, then run the contents of `extract_listings.js` with `javascript_tool`. It returns `"started"`.
3. Poll `JSON.stringify({status: window.__madr?.status, read: window.__madr?.read})` every ~10 seconds, for up to 3 minutes. Each tool call must finish within 45 seconds.
4. Act on the status:
   - **blocked**: go straight to *When Ticketmaster blocks you*.
   - **no_list**: look at the page. Sold out, no listings, or an error page means note it for this game and move on. Anything else that looks like a block is rule 3.
   - **error**: note it and move on. If 3 games end in errors, finish the run as partial.
   - **done**: read `JSON.stringify(window.__madr)` and write `$W/scan-<game id>.json`:

     ```json
     {"client_id": ID, "game_id": GAME_ID, "event_id": "<id from URL>", "event_url": "<URL without query>",
      "event_title": TITLE, "event_date": "YYYY-MM-DD", "event_total_listings": N, "scroll_complete": true,
      "captured_at": "<now, ISO 8601>", "quantity_filter": 2, "listings": [ ...from __madr... ]}
     ```
5. `bin/madr-api POST /api/v1/import_runs/<run id>/market_scans $W/scan-<game id>.json`:
   - **201** means saved; **200** with `"replayed": true` means already saved.
   - **422** (for example, the event date doesn't match the game) or **409**: note the message and move on. Never edit listings to make a post go through.
6. Wait about 30 seconds before the next game.

### 3. Finish
- PATCH `/api/v1/import_runs/<run id>` with `{"client_id": ID, "status": "completed", "targeted": <games attempted>, "notes": "...", "errors": ["Jan 30: no event on Ticketmaster", ...]}`. Use `"partial"` if you stopped early for errors. The app downgrades "completed" to "partial" if fewer games were scanned than targeted.
- `bin/madr-api GET /api/v1/import_runs/<run id> > $W/run.json` for the results: each game's market value, recommended list price, strategy, assessment and confidence.

## When Ticketmaster blocks you

1. Stop. Post nothing more.
2. PATCH the run with `"status": "blocked"` and a note of the page title, the game you were on, and the time. Everything already posted is kept.
3. `notify-send -u critical "MADR: Ticketmaster research blocked" "<n> of <m> games saved. Run again later, or add listings by hand on each game's page."`
4. `hermes send -t telegram "MADR Ticketmaster research was blocked after <n> of <m> games. Partial results are saved: madrtickets.com/import_runs"`
5. Don't retry this session. The app shows a "research was blocked" item on Home.

## Report

- **Vault note:** `~/Documents/Obsidian Vault/10 Projects/madrtickets/MADR Pricing Research.md`.
  - If it doesn't exist, create it with frontmatter (`type: note`, `status: active`, `created: <date>`), a one-line purpose, and a `## Log` heading.
  - Otherwise copy it into `$W` first, re-read it right before writing, and edit it with Python, asserting `## Log` appears exactly once.
  - Add at the top of the Log:
    `- <YYYY-MM-DD> — <n>/<m> games scanned (<status>). Seats worth about $<all-in total> all-in. Act on: <games within 3 weeks that are over/underpriced, unlisted or unconfirmed — date, opponent, list-at price>. [Pricing](https://madrtickets.com/pricing)`
  - **No secrets in notes.**
- **Desktop:** `notify-send "MADR: Ticketmaster prices updated" "<n> games scanned · <k> need action"`.
- **Terminal:** a short table of each game with market value (all-in), recommended list price and strategy, and assessment, then the run link.
- **Cleanup:** close the tabs you opened. Leave the research browser running.

## Setup (one time, Duggan)

1. **Profile.** In Chromium, add a profile named **MADR Research**. Never sign in to Ticketmaster in it. Install the Claude extension in that profile, sign in to Claude there, and give the browser the name "MADR Research" so `list_connected_browsers` can find it.
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
5. **Schedule.** After a supervised first run: `systemctl --user enable --now madr-ticketmaster-pricing.timer`.
