#!/usr/bin/env bash
# Links the MADR skills into Claude Code and installs their systemd user
# units. Never enables a timer: do that yourself after a supervised run.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)

mkdir -p "$HOME/.claude/skills" "$HOME/.config/systemd/user" "$HOME/.config/madrtickets"
chmod 700 "$HOME/.config/madrtickets"

for skill in "$here"/skills/*/; do
  name=$(basename "$skill")
  ln -sfn "${skill%/}" "$HOME/.claude/skills/$name"
  echo "linked skill /$name"
done

for unit in "$here"/systemd/*; do
  install -m 644 "$unit" "$HOME/.config/systemd/user/$(basename "$unit")"
  echo "installed $(basename "$unit")"
done
systemctl --user daemon-reload

cat <<'NEXT'

Timers are installed but NOT enabled. Before enabling:
  1. ~/.config/madrtickets/research.env       MADR_RESEARCH_PROFILE="Profile N"
  2. ~/.config/madrtickets/market-research.header   (chmod 600; see the skill's Setup)
  3. Run /ticketmaster-pricing once while watching.
Then: systemctl --user enable --now madr-ticketmaster-pricing.timer
NEXT
