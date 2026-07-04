# LAKANDULA — Tester Guide (v0.3.0)

A Warcraft-style RTS set at the Battle of Mactan, April 1521. You lead
Lapu-Lapu's coalition against Magellan's expedition. **Art and audio are
generated placeholders** (pixel-art sprites, synthesized kulintang music) —
you're testing gameplay, balance, and stability, not final visuals.

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
| WASD / screen edge / minimap click | Camera |
| Mouse wheel | Zoom |
| LMB / drag | Select units or your buildings |
| RMB | Move / attack (on a selected building: set rally point) |
| **F then click, or Ctrl/Cmd+RMB** | Attack-move (engage everything en route) |
| **Ctrl/Cmd+1–9 / 1–9** | Assign / recall control groups (double-tap centers) |
| **Ctrl/Cmd+A** | Select whole army · **Tab** cycle idle units |
| Q | Selected unit's ability · **Space** stop |
| T / R / C | Diplomacy · Research · Codex |
| **F5 / F9** | Save / load mid-battle |

## New since v0.2.0

- **Units fight back on their own** — idle units engage enemies in range,
  retaliate when shot, and chase on a leash. Friars must still be hunted
  deliberately.
- **Morale** — troops rout when a hero falls nearby or when outnumbered
  3:1 up close. Keep heroes alive and close: their auras steady the line.
- **Difficulty** (Easy/Normal/Hard) on the briefing screen — scales the
  Spanish landing, wave tempo, powder, and tribute.
- **Save/load** (F5/F9, or Continue on the main menu) and a **post-game
  stats screen**.

## What to try

- Pick Hard and survive the day-15 assault; pick Easy and hunt Magellan.
- Set a Barracks rally point behind your line; attack-move (F) a control
  group into the landing beach.
- Break a Spanish push by killing... no — by keeping Lapu-Lapu's aura
  amid your line while they take 3:1 losses. Watch them rout.
- Save before the day-15 assault, lose on purpose, F9 and try again.
- Watch the tide (top center): at LOW the galleons ground and the
  shallows open. A day is 30 seconds; the monsoon ends it at day 60.

## Reporting

File issues at https://github.com/iamdusky/lakandula/issues with what you
did, what happened, and (if it crashed) console output. Balance
impressions especially welcome — difficulty tuning is brand new.
