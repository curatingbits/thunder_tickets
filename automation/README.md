# MADR Tickets automation

Weekly jobs that run on Duggan's workstation and send results to
madrtickets.com. Each one is a Claude Code skill launched by a systemd user
timer, the same pattern as the fantasy-football skills. Everything here is
**read-only toward outside accounts**: no job signs in anywhere, changes a
Ticketmaster listing, or moves money.

| Job | What it does | Proposed schedule | Status |
|---|---|---|---|
| `/ticketmaster-pricing` | Reads resale listings in sections 101, 102 and 120 for every upcoming home game (logged out, "MADR Research" profile) and posts them; the app prices our seats | Mondays 6:30am Central | Installed, **not enabled** |
| `/venmo-settlement` | Reads Mark's Venmo payments from financial.dar.haus (read-only) and posts them; the app matches them to sold games | Mondays 7:30am Central | Coming in a later milestone |

## Install

```bash
automation/install.sh
```

The script links each skill into `~/.claude/skills/` and installs the units in
`~/.config/systemd/user/`. It never enables a timer. One-time setup for each
skill (browser profile, token file) is in its `SKILL.md` under **Setup**.

## Run by hand

- **From a Claude Code session in this repo:** type `/ticketmaster-pricing`.
- **Exactly as the timer would:** `systemctl --user start madr-ticketmaster-pricing.service`. That opens the research browser and a Claude window.
- **Rehearsal against a local server:** `MADR_API_BASE=http://localhost:3000 MADR_API_HEADER=<dev header file>` before running the skill.

## Review the results

- **Pricing tab** (https://madrtickets.com/pricing): market value, recommended list prices, and what needs action.
- **Research runs** (https://madrtickets.com/import_runs): each run's status, games scanned and any errors.
- **Vault:** `10 Projects/madrtickets/MADR Pricing Research.md` gets a dated Log line per run.
- **Desktop:** a `notify-send` summary when a run finishes.

## When something fails

| What happened | What you'll see | What to do |
|---|---|---|
| Ticketmaster shows a CAPTCHA, block page or queue | Run marked **blocked**; critical desktop notification + Telegram; "research was blocked" first on Home. Partial results are kept. | Let it be. Run again later, or add a game's listings by hand from its page. Never bypass the block. |
| A game has no event or no listings | Noted in the run's errors; the game is skipped | Usually a TBD date (NBA Cup knockout). Nothing to do. |
| The skill crashes or the window is closed mid-run | Run stays **running** until its 20-minute lease lapses | Run it again: same week's key, so it resumes and skips games already saved. |
| The unit can't start (Chromium missing, env file missing) | Telegram: "MADR automation … failed to start" | `journalctl --user -u madr-ticketmaster-pricing` |
| Token revoked or missing | The skill stops at its first API call and says so | Create a new one (skill Setup, step 3) |
| Data goes stale (no run for 8+ days) | "Market data is over 8 days old" on Home | Run it by hand |

## Change or disable

```bash
systemctl --user list-timers 'madr-*'                         # what's scheduled
systemctl --user edit madr-ticketmaster-pricing.timer          # change OnCalendar
systemctl --user disable --now madr-ticketmaster-pricing.timer # stop it
```

To revoke a job's access to the app, go to Settings → Workstation access →
**Revoke**.
