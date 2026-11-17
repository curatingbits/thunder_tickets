---
name: venmo-settlement
description: Sync Mark's Venmo payments into MADR Tickets and say what he still owes — reads the posted Venmo transactions between Duggan and Mark Augspurger from financial.dar.haus (read-only), posts them to madrtickets.com, which matches them to sold Thunder ticket games, then explains anything waiting for review. Trigger when Duggan asks whether Mark has paid, what Mark owes, or to sync Venmo, and after the Monday sync if something needs review.
---

# Venmo settlement sync

Mark pays Duggan half of each sold game's payout over Venmo, and madrtickets.com tracks it on the **Money** tab. This skill pulls in the latest payments and tells Duggan where things stand. **The app does the matching.** You run the sync, then explain the result in plain words.

The weekly timer runs the same script without you (no AI needed). You're here when Duggan asks, or to walk him through payments that need review.

## Hard rules

1. **Read-only toward Venmo and the bank.** Never send, request, or suggest initiating a payment.
2. **Never decide for Duggan.** Applying a suggestion, allocating, undoing an allocation, and ignoring a payment are his calls on the Money tab. The API can't do them, and you shouldn't try another way.
3. **Never show a token.** Don't `cat` or echo the header files. Only `bin/venmo-sync` reads them.
4. **Quote, don't estimate.** Every amount you report comes from the app's response.

## Run

1. Run `~/.claude/skills/venmo-settlement/bin/venmo-sync`. It prints a summary and the path of its work folder.
   - **Exit 2:** a token file is missing or not chmod 600. Point to Setup and stop.
   - **Any other failure:** show the error line (it never contains a token) and stop. A 401 from financial.dar.haus means the finance token was rotated; a 401 from madrtickets.com means the MADR token was revoked.
2. Read `result.json` in that folder: `settlement.games` (each sold game's owed, paid and status) and `settlement.needs_review` (each payment's memo, the app's reasons, and its suggestion as `[{game_id, cents}]`).

## Report

- **Terminal:**
  - the balance sentence ("Mark owes Duggan $263.63" or "All square");
  - each game not fully paid: date, opponent, owed, paid;
  - each payment to review: amount, date and memo, then the app's reasons and its suggestion in words, for example "looks like the Mavericks 11/3 game: $50.00 of the $127.50 owed". Link the payment: https://madrtickets.com/partner_payments/<id>.
  - End with https://madrtickets.com/money.
- **Vault:** `~/Documents/Obsidian Vault/10 Projects/madrtickets/MADR Settlements.md`.
  - If it doesn't exist, create it with frontmatter (`type: note`, `status: active`, `created: <date>`), a one-line purpose, and a `## Log` heading.
  - Otherwise re-read it right before writing, and edit it with Python, asserting `## Log` appears exactly once.
  - Add at the top of the Log: `- <YYYY-MM-DD> — <balance sentence>. <n> new payments, <k> to review. [Money](https://madrtickets.com/money)`
  - No tokens, and no memos beyond what the log line needs.
- If Duggan wants a review item fixed, link him to that payment's page and say which button does it ("Apply the suggestion", "Apply it to a game yourself", "Ignore it"). Don't do it for him.

## Setup (one time, Duggan)

1. **Finance token.** `~/.config/madrtickets/finance.header` (chmod 600) was created with the finance app's endpoint.
   - To rotate it: write a new random token to that file as `Authorization: Bearer <token>`, put the token's SHA-256 in finance_advisor's `.kamal/secrets` as `PARTNER_PAYMENTS_TOKEN_SHA256`, and redeploy the finance app.
2. **MADR token.** From the thunder_tickets repo:

   ```
   bin/kamal app exec 'bin/rails api_tokens:create NAME=venmo-settlement SCOPES=settlements:write'
   ```

   Save the token as the only line of `~/.config/madrtickets/settlements.header` (`Authorization: Bearer madr_…`) and `chmod 600` it. Revoke it any time under Settings → Workstation access.
3. **Schedule.** Run `automation/install.sh`. After a supervised run: `systemctl --user enable --now madr-venmo-settlement.timer`.
