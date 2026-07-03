# LAKANDULA — Tester Guide (v0.1.0)

A Warcraft-style RTS set at the Battle of Mactan, April 1521. You lead
Lapu-Lapu's coalition against Magellan's expedition. **All art and audio are
generated placeholders** — units are colored dots, music is synthesized.
You're testing gameplay, balance, and stability, not visuals.

## Running it

- **macOS**: unzip, then **right-click the app → Open** the first time
  (it's unsigned, so Gatekeeper will warn). If it still refuses:
  `xattr -dr com.apple.quarantine LAKANDULA.app`
- **Windows**: unzip and run `LAKANDULA.exe`. SmartScreen may warn —
  "More info → Run anyway".
- **Linux**: unzip, `chmod +x lakandula.x86_64`, run it.

## Controls

| Input | Action |
|---|---|
| WASD / screen edge | Scroll camera |
| Mouse wheel | Zoom |
| LMB / drag | Select units or your buildings |
| RMB | Move / attack |
| Q | Selected unit's ability |
| Space | Stop |
| T | Diplomacy (Utang) panel |
| R | Research panel |
| C | Historical codex |

## What to try

- Train units from the Barracks/Shipyard/Shrine (click the building).
- Gift datus (T) — 2 gifts allies a village; work the Humabon ladder.
- Watch the tide (top center): at LOW the galleons ground and your
  warriors can wade the shallows.
- Spain lands around day 5, converts villages from day 8, assaults from
  day 15 (a day is 30 seconds).
- Win: kill Magellan / starve their powder / survive to day 60 / ally
  everyone. Lose: Kuta falls, Lapu-Lapu dies, or Spain converts all 6
  villages before day 30.

## Reporting

File issues at https://github.com/iamdusky/lakandula/issues with what you
did, what happened, and (if it crashed) the console output. Balance
impressions welcome — numbers are first-pass.
