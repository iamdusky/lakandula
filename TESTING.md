# LAKANDULA — Tester Guide (v0.4.0)

A Warcraft-style RTS set at the Battle of Mactan, April 1521. You lead
Lapu-Lapu's coalition against Magellan's expedition. **This build debuts the
AI-generated art pass** (WC2-style pixel art across all units, buildings,
and terrain); audio remains synthesized placeholder. Visual feedback is
now welcome alongside gameplay, balance, and stability.

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

## New since v0.4.0 (continued — attrition update)

- **The campaign fights back**: telegraphed Spanish reinforcement fleets
  (watch for "sails on the horizon" — they alternate beaches, including a
  new northern landing), army upkeep (rice drain past 12 units — no free
  deathballs), a **Kuta garrison** (right-click the fort to shelter up to 6
  who fire from the walls; "Sally forth" to release), a **storm** during the
  Reprisal that cripples Spanish gun range, and **Babaylan liberation** —
  park her at a converted village to break the friars' hold.

## New since v0.4.0

- **Campaign mode** (Mode dropdown on the briefing screen) — the war no
  longer ends when Magellan falls. Weather the landing, break the assault,
  fell the conquistador, endure the leaderless **Reprisal**, then drive
  every last Spaniard into the sea. Objectives tracked top-left. Skirmish
  keeps the classic fast game.
- **Converted villages resist you** — winning back a barangay Spain has
  baptized now takes 5 gifts, not 2, and losing one wipes your utang
  investment. Watch the n/required readout in the diplomacy panel (T).

## New since v0.3.0

- **All-new art** — every unit, building, ship, portrait, and terrain tile
  replaced with AI-generated pixel art. Tell us what reads badly!

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
