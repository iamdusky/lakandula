# LAKANDULA — Development Plan
## Warcraft-Style RTS · Pre-Colonial Philippines · Battle of Mactan, 1521

> *"If you wish to be served and obeyed, you must show good sense."*
> — Lapu-Lapu, to Magellan's messenger

**Engine:** Godot 4.6  
**Genre:** Single-player RTS with hero units, resource economy, base building  
**Setting:** The Visayan archipelago, April 1521 — the days leading to and including the Battle of Mactan  
**Player faction:** Indigenous coalition led by Lapu-Lapu  
**Enemy factions:** Spain (Magellan), and the collaborator faction (Rajah Humabon of Cebu)

> **Status (2026-07-03):** Milestones 0–12 complete — full game loop from
> main menu to seven distinct endings, verified by a 166-check headless smoke
> test. Procedural art v2 (pixel-art sprites with walk cycles, composed
> kulintang music) shipped; v0.1.0 tester builds released on GitHub
> (macOS/Windows/Linux). Next up: Milestones 13–16 below.

> **▶ NEXT BUILD ORDER (locked with owner 2026-07-07 — follow this when
> writing code, not milestone number order):**
> 1. ~~**Village re-flip bug**~~ ✅ done 2026-07-07
> 2. ~~**M17 — Campaign Objectives**~~ ✅ done 2026-07-07
> 3. ~~**M18 — Attrition & Persistent Threat**~~ ✅ done 2026-07-14
> 4. **M19 — Base Building & Placement** ← next
>
> Milestones 0–14 + 17 + 18 are ✅ done. M15 (asset integration) is blocked
> on artist delivery — do NOT start it until real sprite sheets arrive. M16
> is CI-done, public-release items pending.

---

## Core Concept

Unlike a pure conquest RTS, LAKANDULA is a **survival and resistance** game. The player is outnumbered and outgunned. Victory comes not from crushing Spain militarily but from:

- Holding Mactan Island long enough for Magellan to make a fatal mistake
- Breaking Humabon's alliance with Spain through diplomacy or force
- Preserving enough warriors and allied barangays to survive the Spanish withdrawal

The **Utang mechanic** from the board game translates here as a **diplomacy resource** — calling in debts from neutral datus to gain allied fighters, intel, or supplies mid-battle.

---

## Heroes & Villains

### Player Heroes

| Hero | Role | Signature Ability |
|------|------|-------------------|
| **Lapu-Lapu** | Warrior-king of Mactan | *Daluyong* (Surge) — charges through enemy formation, staggering all hit units; passive aura boosts warrior attack speed |
| **Rajah Sulayman** | Ally hero, Maynila | *Sunugin* — scorched earth retreat; burns nearest structure to deny Spain; aura rallies nearby units |

### Enemy Heroes / Villains

| Character | Faction | Role |
|-----------|---------|------|
| **Ferdinand Magellan** | Spain | Conquistador hero; arquebuse kills at range; mounted cavalry charge; must be killed to win |
| **Rajah Humabon** | Cebu Collaborators | Diplomatic villain; converts neutral datus to Spain's side; can be flipped by player if approached with enough Utang |
| **Enrique de Malacca** | Spain (interpreter) | Support unit; accelerates Humabon's conversion; priority target for assassination |

---

## Factions

### Mactan Warriors (Player)
- **Strength:** Speed, jungle terrain, naval agility, Utang diplomacy
- **Weakness:** No gunpowder; smaller army; cannot win a straight fight on open beach
- **Resources:** Rice (unit upkeep), Copper (lantaka cannons + weapons), Honor (hero abilities + Utang calls), Allies (multiplies income)
- **Win condition:** Kill Magellan before day 40, or outlast Spain's resupply until monsoon

### Spain (Primary Enemy AI)
- **Strength:** Arquebuses, armor, galleons, cannonfire
- **Weakness:** Slow movement on land; can't enter jungle; ships beached at low tide
- **Resources:** Gold (tribute from Humabon), Powder (finite — resupply every 20 min), Faith (conversion rate)
- **AI behavior:** Land-and-convert → build beachhead → coordinate galleon bombardment + land assault

### Cebu Collaborators (Secondary Enemy AI)
- **Strength:** Local knowledge, diplomatic reach, can reveal Mactan player positions
- **Weakness:** Low combat strength; dependent on Spain for military backing
- **Flip condition:** If player accumulates 3+ Utang tokens on Humabon, a diplomacy event fires — Humabon can defect and become neutral or even allied

---

## Milestone 0 — Project Setup
**Status:** ✅ Complete (2026-07-02, Godot 4.6.1)  
**Goal:** Godot project opens, F5 runs, camera moves, no errors

- [x] Create Godot 4 project at `/Users/ejs/Documents/projects/lakandula/`
- [x] `project.godot` — input map (WASD scroll, left/right click, Q ability, Space stop; plus zoom wheel actions)
- [x] Register autoloads: `EventBus`, `ResourceManager`, `TerrainManager`, `SelectionManager`, `VictoryManager`, `DiplomacyManager`
- [x] `MainMap.tscn` — scene tree skeleton (`scenes/maps/main_map.tscn` — placeholder Mactan/Cebu polygons, Terrain/Buildings/Units containers, HUD layer)
- [x] `CameraController.gd` — WASD + edge scroll + zoom (`scripts/camera_controller.gd`)
- [x] `CLAUDE.md` — project context for Claude Code sessions
- [x] `PLAN.md` — this file

---

## Milestone 1 — Prototype Loop
**Status:** ✅ Complete (2026-07-02)  
**Goal:** One Mactan warrior on screen. Click to select, right-click to move, right-click enemy to attack. Resources tick.

> Implementation notes: map is painted at runtime from an ASCII definition
> (`scripts/map/map_data.gd`, 40×25 cells @ 64 px) instead of editor-painted
> tiles — easier to iterate in code. Both nav regions get their meshes built
> at runtime by `MapBuilder` from the painted cells. Placeholder textures are
> generated by `tools/gen_assets.gd`. Headless regression test:
> `Godot --headless --path . -- --smoke-test` (tools/smoke_test.gd).

### Terrain
- [x] TileSet with `terrain_type` custom data layer (`land`, `jungle`, `beach`, `river`, `open_water`, `shallows`) — `assets/tiles/terrain_tileset.tres`
- [x] Paint TerrainLayer and WaterLayer for Mactan Island map (runtime-painted from `MapData.ROWS`)
- [x] NavigationRegion2D for land units (navigation_layers = 1)
- [x] NavRegionNaval for naval units (navigation_layers = 2)
- [x] `TerrainManager.register_terrain_map()` called from map `_ready()`

### First Unit
- [x] `UnitData.gd` resource class (health, speed, damage, costs, terrain modifiers, ability)
- [x] `Unit.gd` base class — state machine (IDLE, MOVING, ATTACKING, ABILITY, DEAD), navigation, combat
- [x] `Mandirigma.gd` — Mactan warrior, jungle attack bonus (terrain_damage ×1.3), Sigaw ability (aoe speed/damage buff)
- [x] `scenes/units/mandirigma.tscn` — CharacterBody2D + Sprite + CollisionShape + NavAgent + HealthBar + SelectionRing
- [x] `resources/units/mandirigma.tres` — tuned stats
- [x] Place 1 Mandirigma in scene at game start (plus a Spanish training dummy for attack testing)

### Selection & Commands
- [x] `SelectionManager.gd` — click select, drag-box, right-click move, right-click attack
- [x] Drag-box visual (ColorRect on a CanvasLayer created by SelectionManager)
- [x] Formation move (grid offset for multi-unit commands)

### Economy
- [x] `ResourceManager.gd` — tracks Rice, Copper, Honor, Allies (Mactan) and Gold, Powder, Faith (Spain)
- [x] Passive income every 5s; ally count multiplies Mactan income (+15%/ally)
- [x] `HUD.gd` — resource readout, day counter (30 s/day, driven by VictoryManager), fading notifications

### Verification
- [x] Click-select, right-click move works (smoke test drives the same command path; manual F5 check recommended for feel)
- [x] Right-click on dummy enemy triggers attack-move (smoke test: dummy 200 → 164 HP)
- [x] Terrain type affects speed (TerrainManager lookup verified for land + open_water; multipliers in UnitData)
- [x] Resources tick and display in HUD (smoke test: rice 200 → 210)

---

## Milestone 2 — Mactan Full Roster
**Status:** ✅ Complete (2026-07-02)  
**Goal:** All Mactan units playable with abilities. Naval units on water.

> Implementation notes: Unit base gained armor (flat reduction, min 1 dmg;
> poison bypasses it), poison DoT, stun, heal, hero auras (short pulses
> refreshed every 0.5 s), capture(), and a `_perform_attack()` override hook
> for ranged units. Heroes respawn at spawn point after 20 s instead of dying
> (per design rule — real loss condition lands in M7; `EventBus.hero_died`
> already fires for it). Lapu-Lapu is placed in MainMap; Rajah Sulayman's
> scene/stats exist but he isn't placed (arrives via later scripting).
> Smoke test now covers the full roster (27 checks).

### Projectile System
- [x] `Projectile.gd` — homing, flies to last known position if target dies, calls `take_damage()` on hit
- [x] `setup(target, damage, source, options)` method (speed, splash_radius, poison_dps/duration, ignore_armor)
- [x] Poison arrow variant (DoT effect, bypasses armor)
- [x] Lantaka shot variant (heavier, 40 px splash)
- [x] `scenes/projectiles/arrow.tscn`
- [x] `scenes/projectiles/lantaka.tscn`

### Land Units
- [x] `Mamamana.gd` — archer, poison arrows, Lason ability (double poison for 6 s)
- [x] `Juramentado.gd` — elite berserker, costs Honor not Rice, Matay ability (ignore armor 5 s)
- [x] `Babaylan.gd` — healer aura (4 HP/s, 140 px) + Ritwal reveal (emits `EventBus.ritual_reveal`; fog hooks in at M8)
- [x] Scenes + `.tres` resources for all above

### Naval Units
- [x] `Karakoa.gd` — war galley, lantaka cannon, Salvo ability (up to 4 targets)
- [x] `Balangay.gd` — fast raider, boarding mechanic (captures ships <30% HP via `Unit.capture()`)
- [x] Both add to `"naval_units"` group
- [x] Scenes + `.tres` resources

### Heroes
- [x] `LapuLapu.gd` — Daluyong charge (220 px dash, 20 dmg + 1.5 s stagger), passive rally aura 180px (+25% attack speed)
- [x] `RajahSulayman.gd` — Sunugin burn ability (needs M3 buildings; fizzles with notice until then), passive attack aura (+15% dmg)
- [x] Scenes + `.tres` resources
- [x] Hero death triggers loss condition check (`EventBus.hero_died` fires; hero respawns in 20 s until M7 wires real loss)

### Unit Spawner
- [x] `UnitSpawner.gd` autoload — `spawn(scene, position, faction)` method
- [x] Checks `ResourceManager.can_afford()` before spawning (verified: Spain can't buy a Karakoa)
- [x] Calls `ResourceManager.spend()` on success

---

## Milestone 3 — Buildings & Map
**Status:** ✅ Complete (2026-07-02)  
**Goal:** Mactan fortress on the map. Barangay settlements claimable. Humabon's palace in Cebu visible across the strait.

> Implementation notes: combat targets generalized from Unit to Node2D —
> anything with `take_damage()` / `is_dead()` is attackable, and buildings
> expose `attack_radius` so attackers measure range to the edge. Right-click
> on enemy buildings works. Production pays cost at queue time; the trained
> unit spawns free via `UnitSpawner.spawn(..., free_of_charge = true)`.
> Group names are derived from faction ids: `buildings_spain` (not
> `buildings_spanish`), etc. Units currently walk through buildings
> (navmesh doesn't carve footprints) — revisit in M11 polish. Sunugin is now
> fully functional. Villages are named after datus (Zula, Mangal, Bulan,
> Sawili, Lambusan, Silyo).

### Building Base Class
- [x] `Building.gd` — health, armor, faction group, `take_damage()`, `sunugin()` (instant self-destruct)
- [x] Productions queue (up to 5 units, trains over time; cost charged at queue time)
- [x] Unit exits at building gate position on completion (`gate_offset`; Shipyard's gate faces the water)

### Mactan Structures
- [x] `KutaMactan.tscn` — main fortress, add to `"kuta"` group; destruction = loss (loss wiring in M7)
- [x] `Barracks.tscn` — trains Mandirigma + Mamamana + Juramentado
- [x] `Shipyard.tscn` — trains Karakoa + Balangay (gate on the shallows)
- [x] `Shrine.tscn` — trains Babaylan; passive Honor generation (+1 per 6 s)
- [x] Place all in MainMap

### Spanish Structures
- [x] `SpanishBeachhead.tscn` — Spanish landing zone; destruction slows reinforcement (hook = `EventBus.building_destroyed`, consumed by M5 AI)
- [x] `SpanishCamp.tscn` — main base; Magellan spawns here (M5)
- [x] Place in MainMap at beach landing zone (south beach)

### Humabon Faction
- [x] `HumabonPalace.tscn` — Cebu faction HQ; off-island (across strait)
- [x] Cannot be attacked early game (take_damage no-ops while `attackable == false`)
- [x] Becomes attackable if Humabon remains allied with Spain past day 20 (M4 flip can avert)

### Datu Villages (Utang targets)
- [x] `DatuVillage.gd` — neutral node, state: NEUTRAL / ALLIED_MACTAN / ALLIED_SPAIN
- [x] `ally(faction)` method — triggers `EventBus.datu_allied`
- [x] Visual state change (flag swap) on alignment (generated flag textures)
- [x] 6 villages placed around Mactan Island perimeter
- [x] Each allied village = +0.15× income multiplier (ResourceManager listens to `datu_allied`, recounts)

---

## Milestone 4 — Diplomacy System (Utang)
**Status:** ✅ Complete (2026-07-02)  
**Goal:** The Utang mechanic from the board game translated into the RTS. Give gifts to datus, call in debts for military support.

> Implementation notes: gifts cost {rice 40, copper 10} for datus, {rice 60,
> copper 20} for Humabon; a neutral village allies with the gifting faction
> at 2 tokens. Call-in actions: "supplies" (+60 rice/+15 copper), "fighters"
> (2 free Mandirigma at the village), "intel" (emits ritual_reveal — fog hook
> at M8). Katipunan costs 20 Honor. HumabonPalace becomes permanently
> protected once he flips. "Cebu datus become claimable" deferred — no Cebu
> datu villages exist yet (all 6 are on Mactan); revisit if/when a Cebu-side
> village is added.

### DiplomacyManager Autoload
- [x] Tracks Utang tokens per faction pair (who owes whom) + Disgrace per faction
- [x] `give_gift(from_faction, to_datu, good)` — places Utang token, generates `datu_obligated` event
- [x] `call_utang(from_faction, to_datu, action)` — collects on debt; datu provides 1 action (fighters / intel / supplies)
- [x] `default_utang(datu)` — datu refuses (auto when calling on a Spain-allied datu); Disgrace token applied; relationship damaged

### Humabon Flip Mechanic
- [x] Humabon starts with 0 Utang tokens
- [x] Player can gift goods to Humabon via a diplomatic action (costs Rice + Copper)
- [x] At 3 tokens: **Enrique event** fires — Humabon's interpreter opens back-channel talks
- [x] At 5 tokens: **Katipunan Offer** — player may spend Honor to flip Humabon to neutral
- [x] Flipped Humabon: Spain loses tribute income (ResourceManager listens to `humabon_flip_stage`); ~~Cebu datus claimable~~ (deferred, see note)
- [x] Full flip (7 tokens): Humabon becomes allied — sends 10 Cebu warriors to Mactan

### Utang UI
- [x] Minimap overlay shows Utang relationships (done in M8: lines drawn while the diplomacy panel is open)
- [x] HUD panel: tokens held per datu + Humabon stage, Gift/Call buttons, Katipunan button (toggle with T)
- [x] Notification on token placement, call-in, and default

---

## Milestone 5 — Spanish AI
**Status:** ✅ Complete (2026-07-02)  
**Goal:** Spain actively plays — lands, converts datus, assaults Mactan. Magellan leads the beach assault.

> Implementation notes: state ladder is forward-only, driven by
> `EventBus.day_advanced` (test can fast-forward by emitting days). Powder is
> live ammo: arquebus 1/shot, bergantín 1, galleon broadside 2 — no powder =
> silent guns. Resupply ship every 20 min (+60 powder) also de-escalates
> DESPERATE back to ASSAULT. Tribute now starts at ESTABLISH (contact), not
> game start, and never starts if Humabon flipped first. "Can't enter jungle"
> approximated as severe speed/damage penalties. Magellan does NOT respawn
> (unlike Mactan heroes) — his death emits `hero_died` for M7. Baptism
> adapted to convert the nearest neutral *village* (no neutral units exist).
> Spanish assault waves after the first are paid from Spain's gold.

### AI State Machine
- [x] `SpanishAI.gd` autoload — states: SAIL_IN → ESTABLISH → CONVERT → ASSAULT → DESPERATE
- [x] Transitions driven by day count (5/8/15/36) + powder supply (< 20 → DESPERATE)

### SAIL_IN (Days 1–5)
- [x] Galleons approach from west; Bergantín scouts ahead
- [x] Cannot be attacked until beachhead established (invulnerable flag; cleared at landing)
- [x] Notification: "The Spanish fleet has been sighted off Cebu"

### ESTABLISH (Days 5–12)
- [x] Land Soldados and Arcabuceros at beach (4 + 3, south beach)
- [x] Build SpanishBeachhead structure (pre-placed in M3; landing marks it established)
- [x] Contact Humabon — begin tribute relationship (gold income starts here unless he flipped)

### CONVERT (Days 8–20)
- [x] Spawn Fraile units; send toward neutral datu villages (AI re-tasks idle frailes every 2 s)
- [x] Fraile conversion takes 15s unchallenged in village radius (any Mactan unit within 160 px pauses it)
- [x] Each converted village = −1 from player's ally count (via datu_allied recount)

### ASSAULT (Days 15–40)
- [x] Magellan hero spawns; leads combined arms push on Kuta
- [x] Galleon broadside coordinates with land assault timing (fleet ordered against the Kuta with the wave)
- [x] Arquebuceros hang back and suppress (220 range + retreat-after-firing); Soldados push forward
- [x] Reinforcement waves every 60 s, paid from Spanish gold

### DESPERATE (Powder < 20 OR Day > 35)
- [x] Abandon datu conversion
- [x] All-in assault with whatever units remain
- [x] `EventBus.powder_critically_low` fires → HUD warning

### Spanish Unit Scripts
- [x] `SoldadoTercio.gd` — heavy, high armor, pike formation bonus (+25% with 2+ soldados near)
- [x] `Arcabucero.gd` — ranged, long reload (2.5s), retreats after firing, 1 powder/shot
- [x] `Jinete.gd` — cavalry, charge bonus (first strike ×1.8), useless in jungle
- [x] `Fraile.gd` — no combat, conversion aura, dies in 2 hits
- [x] `Galeon.gd` — capital ship, broadside (splash, 2 powder), beached at low tide (M6 hooks "galleons" group)
- [x] `Bergantin.gd` — medium ship, enters river approaches (galleon river speed ×0.05, bergantín ×1.0)
- [x] `Magellan.gd` — hero, mounted, long-range crossbow, Baptism ability (converts nearest neutral village)
- [x] All scenes + `.tres` resources

---

## Milestone 6 — Tide & Naval Systems
**Status:** ✅ Complete (2026-07-02)  
**Goal:** Tide cycle shifts naval dynamics. Low tide beaches galleons. Karakoa has free reign in shallows.

> Implementation notes: shallows have their own NavigationRegion2D (the
> naval mesh excludes those cells so regions never overlap). It is always
> naval (layer 2); low tide adds the land bit (layers = 3) so land units
> wade across. Units multiply speed by `TideManager.speed_multiplier(self)`
> — group-based: "galleons" ×0 at LOW / ×1.1 at HIGH, "karakoa" ×1.3 at LOW.
> Tide starts HIGH so the fleet can sail in. "Bay boundary expands" at high
> tide adapted to the galleon ×1.1 push (no mesh growth). HUD wheel graphic
> adapted to a colored swatch + phase countdown. `force_phase()` is the
> debug/test hook.

- [x] `TideManager.gd` autoload — 4 phases (LOW → RISING → HIGH → FALLING), 10 min each
- [x] Low tide: Galeon speed = 0 (beached); Karakoa speed ×1.3; shallows become passable by land units
- [x] High tide: Galleon pushes (×1.1); ~~bay boundary expands~~ (adapted, see note)
- [x] Tide indicator in HUD (colored swatch + countdown, top center)
- [x] Tide warning notification 60s before shift
- [x] `EventBus.galleons_beached` / `galleons_freed` signals
- [x] Historical note: Magellan's assault happened at low tide — he couldn't get his galleons close. This is the key mechanic.

---

## Milestone 7 — Victory & Loss Conditions
**Status:** ✅ Complete (2026-07-02)  
**Goal:** Game can be won and lost. Both factions have multiple paths.

> Implementation notes: mostly signal-driven (hero_died, building_destroyed,
> datu_allied, humabon_flip_stage, day_advanced) with the powder-starvation
> clock polled in _process. game_over pauses the tree; GameOverScreen (in the
> HUD) shows the historical note with Fight Again / Quit. Retry reloads the
> scene — ResourceManager / DiplomacyManager / SpanishAI / TideManager /
> VictoryManager all reset on EventBus.game_started. Lapu-Lapu: the M2
> respawn stays for Sulayman, but Lapu-Lapu's death now immediately triggers
> the loss (the respawn never completes) — the design-rule placeholder is
> superseded.

### VictoryManager Autoload
- [x] Conditions signal-driven + powder clock polled; emits `EventBus.game_over(winner, condition)` once, then pauses

### Mactan Victory Conditions
- [x] **Kill Magellan** — Magellan hero unit dies → Spain withdraws → Victory
- [x] **Powder starvation** — Spanish powder at 0 for 120 continuous seconds → Spain sails away → Victory (clock accumulation + resupply reset verified)
- [x] **Monsoon survival** — Kuta standing on Day 60 → monsoon grounds fleet → Victory
- [x] **Great Alliance** — All 6 datus + Humabon flipped → overwhelming counter-attack → Victory

### Spain Victory Conditions
- [x] **Kuta razed** — KutaMactan destroyed → Spain controls island → Loss
- [x] **Lapu-Lapu killed** — Hero unit dies → resistance collapses → Loss
- [x] **Full conversion** — All 6 datus converted to Spain before Day 30 → Loss

### Win/Loss Screens
- [x] Victory: short historical note about the real Battle of Mactan; date April 27, 1521
- [x] Loss: historical context on what would have changed; encouragement to retry ("Fight again")

---

## Milestone 8 — Fog of War & Minimap
**Status:** ✅ Complete (2026-07-03)

> Implementation notes: fog is a world-anchored Sprite2D (not a CanvasLayer)
> with an 80×50 alpha texture — three states: visible / explored (half-dark)
> / unexplored (dark). Enemy UNITS hide under fog (and can't be right-click
> targeted); buildings and villages stay visible as landmarks. Ritwal and
> Utang "intel" both lift the fog via ritual_reveal. Minimap draws terrain
> from MapData + faction dots (fog-aware), pings on village flips and the
> Spanish landing, and — with the diplomacy panel open (T) — the Utang
> relationship lines deferred from M4. "Humabon reveals Mactan positions to
> Spain" is N/A for now: the Spanish AI is omniscient (no AI vision model);
> revisit if the AI ever gets vision limits.

- [x] `FogOfWar.gd` — dark overlay (world-anchored sprite); unit sight_range punches holes
- [x] Update every 0.3s for performance
- [x] Babaylan Ritwal pierces fog for 10s (Utang intel too)
- [x] ~~Humabon reveals Mactan positions to Spain if fully allied with them~~ (N/A — AI is omniscient; see note)
- [x] `Minimap.gd` — terrain snapshot + faction dots (fog-aware), bottom-right of HUD
- [x] Click minimap → `CameraController.pan_to(world_pos)`
- [x] `EventBus.minimap_ping` shows flashing dot (emitted on village flips + Spanish landing)

---

## Milestone 9 — Tech Tree & Training UI
**Status:** ✅ Complete (2026-07-03)

> Implementation notes: TechTree is an autoload; techs defined in code as
> TechData instances (no .tres per tech). Age gate: 2 techs of the previous
> age unlock the next. Effects: passive multipliers queried by units
> (speed/damage/poison/heal) + one-shot effects (fleet muster, building
> reinforcement, pact tokens, monsoon day 60→50). "Great Alliance" tech
> renamed great_alliance_pact (places 1 Utang token on every datu) to avoid
> clashing with the victory condition. Research UI: TechPanel, toggle R.
> Building selection: LMB on your building opens the TrainingPanel.
> ⚠ Load-cycle rule: unit.gd references TechTree, so tech_tree.gd must not
> parse-time-reference unit classes or autoloads that preload unit scenes
> (groups / duck typing / get_node("/root/...") / load() only).

### Tech Tree
- [x] `TechTree.gd` — tracks unlocked researches per faction (autoload; resets on game_started)
- [x] `TechData.gd` resource — name, cost, prerequisites, effect id (callback via TechTree._apply_effect)
- [x] Mactan Age I: Poison Arrows (+50% venom), Karakoa Rigging (+15% naval speed), Barangay Alliance (ally income 15%→25%)
- [x] Mactan Age II: Lantaka Upgrades (+25% Karakoa dmg), Kris Forging (+15% melee dmg), Babaylan Network (+50% healing), River Traps (Spain −30% speed in river/shallows)
- [x] Mactan Age III: War Fleet Assembly (musters 2 Karakoa + 1 Balangay), Kuta Reinforcement (+50% HP, +2 armor, repair), Great Alliance Pact (token on every datu), Monsoon Timing (monsoon day 50)

### Training UI
- [x] Building selection panel shows unit queue (up to 5) — LMB selects your buildings, TrainingPanel appears
- [x] Training timer per unit (from `UnitData.train_time`) — live countdown on the first queue entry
- [x] Unit spawns at building exit point on completion (M3 gate_offset)
- [x] Cancel button refunds 50% of cost

---

## Milestone 10 — Audio
**Status:** ✅ Complete (2026-07-03)

> Implementation notes: all audio is SYNTHESIZED placeholder — regenerate
> with `Godot --headless --path . --script tools/gen_audio.gd` (deterministic
> WAVs in assets/gen/audio/). Calm = pentatonic kulintang-style gongs over a
> low-passed ocean swell; battle = drums + drone + faster gong riff (oud
> omitted — synth). Both layers loop continuously; the mix crossfades.
> Attack-hit SFX rides a new EventBus.combat_hit signal (throttled to one
> per 90 ms). AudioManager runs while paused so the victory/defeat sting
> plays over the game-over screen. `last_sfx` exists for headless tests.
> Voice line is a synthesized war-cry stand-in — real Cebuano/Visayan
> recordings still needed (M11 polish or later).

- [x] `AudioManager.gd` autoload — calm / battle states, adaptive music
- [x] Calm: kulintang percussion + ambient ocean (synthesized)
- [x] Battle: faster tempo + drums; triggered when enemies within 400px of Mactan units
- [x] Crossfade between states (2s blend)
- [x] SFX: unit selection, move order, attack hit, unit death, building destruction
- [x] Lapu-Lapu voice lines (synth war-cry placeholder; real Visayan/Cebuano recordings pending)
- [x] Tide shift audio cue
- [x] Victory fanfare (+ defeat sting)

---

## Milestone 11 — Polish & Balance
**Status:** ✅ Complete (2026-07-03) — within placeholder-art constraints

> Balance rationale: Mactan units gained HP (they fight outnumbered-by-
> quality: Mandirigma 70, Juramentado 85, Karakoa 180, Balangay 100);
> Lapu-Lapu 240 HP / 3 armor (his death = loss, must survive mistakes);
> Spanish damage trimmed (Soldado 13, Arcabucero 22, Galeon 28 — powder and
> pike bonuses still make them scary); Magellan 280 HP / 4 armor (killing
> him must be earned at low tide). Costs untouched. AI tuning: waves every
> 50 s and escalate (+1 Soldado per 3 waves, Jinete every 2nd), dead friars
> replaced (paid) while converting. Pathfinding: building collision rects
> are carved from the land navmesh at build time (fixes the M3 walk-through
> deferral). Perf: Fraile scans throttled to 0.25 s; fog/audio/minimap
> already interval-based — no hotspots at this unit count (off-screen
> culling left to Godot's renderer). Particles via the `Effects` autoload
> (CPUParticles2D one-shots): death bursts + fading corpse ghosts, building
> fire+smoke, cannon smoke on every powder shot, water splashes on wet
> impacts. Animations are procedural (walk bob / idle breath / attack
> lunge) — real frame art still wanted. Portraits are generated placeholder
> busts (SelectionInfo card, bottom-left). Codex: 8 entries, event-unlocked,
> toggle C (session-scoped until M12 adds persistence).

- [x] Unit stat balancing pass (health, damage, speed; costs stable — see rationale)
- [x] Spanish AI difficulty tuning (escalating waves, friar replacement, 50 s cadence)
- [x] Pathfinding edge cases (building footprints carved from navmesh; verified detour)
- [x] Performance pass — Fraile scan throttled; other scans already interval-based; rendering culling is Godot-native
- [x] Particle effects — fire, water splash, cannon smoke, death (Effects autoload)
- [x] Unit animations — procedural placeholder (walk bob, idle breath, attack lunge, death ghost); frame art pending real sprites
- [x] Portrait art for all units — generated placeholder portraits + SelectionInfo card; real art pending
- [x] Historical codex — 8 entries unlock as events trigger in-game (C)

---

## Milestone 12 — Campaign Shell
**Status:** ✅ Complete (2026-07-03)

> Implementation notes: main scene is now main_menu.tscn — it redirects
> straight to the battle map when launched with `--smoke-test` /
> `--screenshot` so headless tooling still works (`--screenshot-menu`
> captures the menu itself). Victory/Loss screens are the M7 GameOverScreen
> overlay (faction-specific historical notes; now with a Main Menu button) —
> separate scenes were unnecessary. `GameSettings` autoload (registered
> right after EventBus) persists audio volumes, resolution, fullscreen,
> scroll speed, and codex unlocks to user://settings.cfg. `SceneFlow`
> autoload provides fade-to-black transitions and unpauses before switching.
> Menu scenes are script-built Controls (placeholder-art era). Codex unlocks
> now persist across sessions and pre-populate the in-game panel.

- [x] `MainMenu.tscn` — title, Play, Codex, Settings, Quit
- [x] `MissionBriefing.tscn` — historical context + map preview (generated from MapData) + objectives
- [x] ~~`VictoryScreen.tscn`~~ — covered by the M7 GameOverScreen overlay (historical outcome notes per condition)
- [x] ~~`LossScreen.tscn`~~ — same overlay: context + Fight Again + Main Menu
- [x] `SettingsMenu.tscn` — audio volumes, resolution, fullscreen, scroll speed
- [x] `HistoricalCodex.tscn` — unlockable entries (8; locked show as "??? — undiscovered")
- [x] Scene transitions (fade to black via SceneFlow autoload)
- [x] Save/load settings via `ConfigFile` (user://settings.cfg, includes codex unlocks)

---

## Asset Track (post-milestone)

- [x] **Procedural art v2** (2026-07-03) — real pixel-art sprites: 4-frame walk
  cycles for all humanoids (Sprite2D hframes, frame 0 = idle), detailed ships
  (outriggers/sails/gunports), nipa-hut & coral-stone architecture, textured
  terrain (grass tufts, palm canopies, waves), upgraded portraits with
  headgear. Composed kulintang music (24 s calm with melody/agung/babandil,
  16 s battle). Still `tools/gen_assets.gd` / `gen_audio.gd` — regenerable.
- [ ] **Commissioned assets** — full spec in [ASSETS.md](ASSETS.md): sprite
  sheets, animated terrain, painted portraits, recorded kulintang music, SFX,
  and Cebuano voice lines (drafts included; need native-speaker verification).

## Milestone 13 — Combat QoL
**Status:** ✅ Complete (2026-07-03)  
**Goal:** The controls testers will expect from an RTS. Biggest known gap: units are passive unless ordered.

> Implementation notes: aggro radius = min(sight, 260 px), scan every 0.4 s
> (staggered per unit); auto-acquired targets have a 320 px leash back to the
> guard position. `UnitData.passive` (Fraile, Babaylan, dummy) opts units out
> of BOTH acquiring and being auto-acquired — friars must still be hunted
> deliberately, preserving the conversion-interception mechanic. Fog-hidden
> and grace-period-invulnerable enemies can't be acquired. Damaged idle units
> retaliate against their attacker even beyond aggro range. Attack-move is F
> (arms next click) or Ctrl/Cmd+RMB. The smoke test gained "stabilization"
> blocks: parked units + flotilla, since idle armies now join any nearby
> scripted fight.

- [x] Auto-retaliation — idle units acquire attackers/enemies within an aggro radius (respects fog + passive flags + leash)
- [x] Attack-move (F then click, or Ctrl/Cmd+RMB): move and engage anything hostile en route; resumes sweep after kills
- [x] Control groups — Ctrl/Cmd+1..9 assign, 1..9 recall, double-tap centers camera
- [x] Rally points on production buildings (RMB with building selected; flag drawn; trained units march there)
- [x] Idle-unit cycling (Tab) + select-all-military (Ctrl/Cmd+A)
- [x] Health bars always-on toggle (Settings; persisted)

## Milestone 14 — Difficulty & Replayability
**Status:** ✅ Complete (2026-07-04)  
**Goal:** More than one playthrough.

> Implementation notes: difficulty lives in GameSettings.DIFFICULTY (easy/
> normal/hard), chosen on the briefing screen, persisted; it scales wave
> interval (65/50/40 s), wave size (±1 soldado), landing force, starting
> powder (80/100/130), and tribute (4/5/7 gold). Morale: units rout 5-6 s
> (uncontrollable, pale tint, flee ~260 px) when a friendly hero dies within
> 400 px or when outnumbered 3:1 within 200 px while fighting; heroes and
> speed-0 units never rout; hero-aura'd units hold; passive units don't count
> toward the ratio. Save/load: user://save.json via SaveGame autoload —
> managers expose save_state()/load_state(); F5/F9 in battle, Continue on
> the menu. Not preserved (documented): projectiles in flight, fog
> exploration, capture tints, heroes mid-respawn. Stats via GameStats
> (kills approximated as any non-Mactan death). Testing this milestone
> surfaced two real fixes: combat_hit now fires before death processing
> (victory sting was being overwritten), and rout ends on its timer only.

- [x] Difficulty settings (Easy/Normal/Hard — scale Spanish wave size/cadence, landing, starting powder, tribute rate; briefing selector)
- [x] Morale system: units rout when a hero dies nearby or outnumbered 3:1 (leashed to timer; aura grants courage)
- [x] Mid-game save/load (F5/F9 + menu Continue; full manager + world snapshot; limits documented)
- [x] Post-game stats screen (day, losses, kills, villages, techs — on the game-over screen)

## Milestone 15 — Commissioned Asset Integration
**Status:** 🔲 Not started — spec ready in [ASSETS.md](ASSETS.md)  
**Goal:** Replace procedural assets with commissioned art/audio as it arrives.

- [ ] Sprite sheets (idle/walk/attack/death) — extend Unit animation beyond walk cycles
- [ ] Animated terrain (water shimmer, low-tide variant)
- [ ] Painted portraits + title banner
- [ ] Recorded kulintang music + full SFX set
- [ ] Cebuano voice lines (native-speaker verified) + Spanish barks
- [ ] Attribution/credits in codex screen

## Milestone 16 — Release Engineering
**Status:** 🟡 In progress — CI/CD done (2026-07-06); public-release items pending  
**Goal:** Public, repeatable releases.

> CI (.github/workflows/ci.yml): cached headless Godot 4.6.1 runs the
> 194-check smoke suite on every push/PR to main. Release
> (.github/workflows/release.yml): on v* tags — cached export templates,
> smoke gate, 3-platform export, zips with TESTING.md, gh release with
> generated notes; workflow_dispatch = dry run uploading workflow artifacts.
> Both validated green on real runners (dry run produced all 3 builds).
> Release flow now: bump export_presets version → tag v* → push tag.

- [x] GitHub Actions: smoke test on push/PR; tag-triggered 3-platform release builds (validated; issue #1 closed)
- [ ] Repo public + itch.io page
- [ ] Code signing / notarization decision (macOS Gatekeeper, Windows SmartScreen)
- [ ] Versioning & changelog discipline (CHANGELOG.md)

---

## Milestone 17 — Campaign Objectives (game length restructure)
**Status:** ✅ Complete (2026-07-07)  
**Goal:** Fix the core pacing problem: a skilled player rushes Magellan and
ends a ~30 min game in ~8 min, skipping the economy, tech, and diplomacy
layers entirely. Make killing Magellan a **turning point**, not the credits,
and gate the ending behind sequenced objectives — while preserving today's
fast game as an explicit "Skirmish" mode.

> **Design decisions (locked 2026-07-07):**
> - Magellan's death = **turning point**, not instant win. It ends Spain's
>   organized campaign and triggers a leaderless **Reprisal** phase.
> - **Two modes**, chosen at the briefing (reuse the difficulty-dropdown
>   pattern): **Skirmish** = current parallel-win-condition game (fast, good
>   for testers/quick sessions, and the default the smoke test pins);
>   **Campaign** = the full staged arc below.
> - No new art required — pure GDScript over existing systems. NOT blocked
>   on M15 asset delivery.
>
> **Implementation notes (2026-07-07):** phase machine lives inside
> VictoryManager (no new autoload); `GameSettings.game_mode` is read LIVE
> (`campaign_active()`), so the smoke test's early pin covers the whole
> suite. Monsoon / powder starvation / great alliance remain GLOBAL
> alternate victories in campaign (nature and diplomacy can still end the
> war early); the staged path adds the new "spain_expelled" ending — total
> elimination of Spanish units (friars included) and structures. Killing
> Magellan during ASSAULT skips ahead to REPRISAL. Assault "broken" = day 22
> or <3 non-passive Spanish land units east of x=-448. Reprisal endures 8
> days (or Spanish combat wipe-out). Campaign fields ride the existing
> save/load. Tracker panel top-left ("THE WAR FOR MACTAN"), campaign only.

### Game-mode framework
- [x] `GameSettings.game_mode` ("skirmish" | "campaign"), persisted; briefing-screen dropdown next to Difficulty
- [x] Smoke test pins "skirmish" at start (existing checks valid unchanged)
- [x] `VictoryManager` branches on mode: skirmish = parallel conditions; campaign = staged phases (VictoryManager-owned)

### Objective system (campaign mode)
- [x] Phase machine in VictoryManager — ordered phases with completion predicates; emits `EventBus.objective_changed(phase, title, state)`
- [x] Phases: Weather the Landing (day 15) → Break the Assault (day 22 / attackers thinned) → Fell the Conquistador → Endure the Reprisal (8 days) → Expel Spain (total elimination → "spain_expelled")
- [x] Loss conditions persist across all phases (Kuta razed / Lapu-Lapu dead)
- [x] HUD objectives tracker — ✓ completed / ▶ active / · upcoming, top-left, campaign only

### Reprisal AI phase
- [x] `SpanishAI.REPRISAL`, entered on `hero_died(Magellan)` in campaign mode (skirmish still instant-wins)
- [x] Abandons conversion; all units attack; final difficulty-scaled landing; powder resupply disabled
- [x] Ends on Spanish combat wipe-out OR the 8-day timer → "Expel Spain"
- [x] Notification beat: "Magellan is dead — the Spanish fight with nothing left to lose!"

### Verification
- [x] Smoke test: skirmish path unchanged (all prior checks green)
- [x] Smoke test: campaign path — phases 1→5 driven in order, Magellan death advances (not ends), REPRISAL entered + landing arrives, expel wins with ordered `objective_changed` log (212 checks total)
- [x] Historical codex beat on entering Reprisal — "The Feast of Cebu" (Humabon's betrayal of the survivors)

---

## Milestone 18 — Attrition & Persistent Threat (campaign depth)
**Status:** ✅ Complete (2026-07-14) — first milestone implemented via the `coder` subagent  
**Goal:** Make the economy, tech tree, and reclamation *necessary* rather than
optional during the longer campaign, so the back half is an active contest
instead of a mop-up. Layers onto M17's campaign mode.

> Depends on M17. Skirmish mode is unaffected — every M18 system gates on
> `GameSettings.game_mode == "campaign"` (read live).
>
> **Implementation notes (2026-07-14):** Babaylan liberation frees a
> converted village to NEUTRAL (12 s unchallenged within 110 px; any
> non-passive Spaniard within 160 px pauses the rite) — force clears
> Spain's grip, then normal gifting (2 tokens) wins the alliance, making
> the military path complement the 5-gift contested-diplomacy path.
> Reinforcement fleets every reinforce_interval (easy 220 s / normal 180 /
> hard 140) during ASSAULT/DESPERATE: telegraph (ping + escort bergantín +
> +15 powder) then troops ashore 20 s later, alternating the south beach
> and a NEW north beachhead (-352, -256); none during REPRISAL. Upkeep:
> each non-hero unit past 12 costs 1 rice per income tick (floor 0,
> throttled notification). Garrison: RMB the Kuta (campaign) → up to 6
> units shelter (hidden, invulnerable) while the walls fire arrows at 0.8×
> their damage, 220 px range, at non-passive visible Spaniards; "Sally
> forth" button releases at the gate; occupants die if the Kuta falls
> (accepted save/load limitation: a saved garrison reloads as regular
> units at the fort). Reprisal storm (in TideManager): Spanish
> powder_weapons group at 0.6× range from REPRISAL until EXPEL. 224-check
> suite green; skirmish path byte-identical.

### Reclamation loop
- [x] Spain keeps sending friars through CONVERT/ASSAULT (pre-existing behavior, confirmed) — converted villages are a standing objective, not a one-time loss
- [x] Babaylan liberates a Spanish-allied village (12 s unchallenged rite → NEUTRAL; mirror of the friar, inverted)
- [x] Objectives-tracker sub-goal: "⚑ Liberate the barangays — N under Spain" (auto-shows while any village is converted)

### Escalating siege
- [x] Reinforcement fleets during ASSAULT/DESPERATE — difficulty-scaled interval, second (northern) beachhead alternates in
- [x] Telegraphed: minimap ping + notification + escort ship, landing 20 s later — contestable on the beach

### Attrition economy
- [x] Army upkeep — non-hero units beyond 12 cost 1 rice per income tick (campaign only)
- [x] Honor/Rice sinks — covered: upkeep is the rice sink; the tech tree remains the honor sink (no extra mechanism needed)

### Promote from backlog (fold into campaign)
- [x] Garrison mechanic — up to 6 units inside the Kuta fire arrows from the walls; sally to release
- [x] Weather — the Reprisal storm cuts Spanish powder-weapon range to 0.6× until the final phase

---

## Milestone 19 — Base Building & Placement
**Status:** 🔲 Not started — planned 2026-07-07  
**Goal:** Buildings are currently pre-placed in `main_map.tscn` at fixed
spots, so base layout is never a decision. Let the player place their own
structures — a setup phase at game start and/or ongoing construction — so
positioning (chokepoints, coverage of villages, defense of the Kuta) becomes
strategic.

> **Key architectural constraint:** buildings aren't purely visual — the land
> navmesh is *carved* from their collision-rect footprints in a single
> `MapBuilder.build()` pass at map load (see `_carve_footprints`, called once
> from `main_map.gd`). Free placement therefore requires **re-carving the
> land navmesh at runtime** whenever a building is added or destroyed, not
> just spawning a sprite. This is the core of the work; the placement UI is
> the easy part.

### Runtime navmesh re-carve (foundation)
- [ ] Refactor `MapBuilder` so footprint carving can run on demand, not only at build: keep the base land-cell set, re-subtract *current* building footprints, rebuild `nav_land.navigation_polygon`
- [ ] `EventBus.buildings_changed` (or building placed/destroyed signals) triggers a re-carve; debounce so a burst of placements rebuilds once
- [ ] Verify pathing updates: a unit mid-route re-paths around a newly placed building; a razed building reopens its ground
- [ ] Decide performance budget — re-carve is O(cells × buildings); fine at current scale, but confirm no hitch on placement

### Placement mode & validation
- [ ] `BuildManager` (or SelectionManager mode) — enter placement, show a ghost/preview sprite following the cursor, LMB to confirm, RMB/Esc to cancel
- [ ] Validity rules: land terrain only (query TerrainManager), no overlap with existing footprints or units, inside map bounds, (optional) within build radius of the Kuta or an allied village
- [ ] Ghost tints green/red for valid/invalid; snap to the 64px cell grid (matches the navmesh cell size)
- [ ] Pay cost on confirm via `ResourceManager.spend()`; buildings get costs (they have none today — add to a Building stat or a build catalog)

### When can you build?
- [ ] **Setup phase** (recommended pairing with M17 Campaign): a pre-day-1 placement window with a starting build allowance — position your base before Spain arrives. Skirmish could keep a fixed default or offer a quick setup.
- [ ] **Ongoing construction** (optional / later): build new structures mid-game from gathered resources; enables expansion, forward bases, replacing razed buildings
- [ ] Build menu UI — pick a structure type, see cost, enter placement

### Data & save/load
- [ ] Move the fixed `Buildings` children out of `main_map.tscn` into a placement flow (or keep a minimal default set + player additions)
- [ ] `SaveGame` must serialize placed-building positions/types/health (currently they're scene-authored, so save/load assumes fixed layout — verify and extend)

### Verification
- [ ] Smoke test: place a building → navmesh re-carves → a unit paths around it; raze it → ground reopens
- [ ] Smoke test: placement validity (reject water, overlap, out-of-bounds); cost charged on confirm
- [ ] Save/load round-trips a custom base layout

---

## Bug — converted village can be cheaply re-flipped
**Status:** ✅ Fixed (2026-07-07)  
**Symptom:** After a Spanish friar converts a neutral village, the player can
give one gift and instantly flip it back to Mactan. Not intended — a
converted barangay should be sticky.

> **Root cause (confirmed in code):** `DiplomacyManager._maybe_ally_village`
> flips a village to whoever reaches `VILLAGE_ALLY_THRESHOLD` (2) tokens
> *without checking current alignment*, and `add_token` never clears tokens
> when a village changes hands. So the player's 2 tokens persist through a
> Spanish conversion, and a single fresh gift re-crosses the threshold and
> re-flips it — cheap and instant.

> **Resolution:** contested-threshold direction chosen (keeps diplomacy
> viable without M18): neutral village = 2 tokens, village held by the other
> faction = 5 (`VILLAGE_CONTEST_THRESHOLD`). On any alignment change, every
> other faction's tokens on that datu are wiped — so a conversion destroys
> the player's prior investment and the 5 must be earned fresh. Diplomacy
> panel shows "Utang n/required" per village.

- [x] Contested villages resist flipping: neutral = 2, contested = 5 (force-only reclamation deferred to M18 as a possible campaign-mode tightening)
- [x] Losing faction's tokens wiped when a village changes alignment
- [x] Notification ("breaks with the strangers and returns to the fold") + codex entry "The Contested Faith" on the first contested flip
- [x] M18 interaction decided: gift-reclamation stays legal at the steeper price; M18 may add force-reclamation as the cheaper *military* path (flag for playtest)

## Backlog / Future

- [ ] Second map — Battle of Maynila, 1571 (Rajah Sulayman vs Legazpi)
- [ ] Multiplayer — 1v1 via Steam
- [ ] Enrique de Malacca campaign — play as the interpreter navigating both sides
- [ ] (Morale — done in M14; Skirmish mode — folded into M17; Garrison/Weather — folded into M18)

---

## Architecture Notes

### Autoload Singletons (register in this order)
1. `EventBus` — global signal hub; all cross-system comms go here
2. `ResourceManager` — tracks both factions' resources; passive income
3. `TerrainManager` — terrain type by world position
4. `TideManager` — 10-min tide cycle; modifies naval speeds
5. `VictoryManager` — polls win conditions; emits `EventBus.game_over`
6. `SelectionManager` — click/drag select; right-click commands
7. `DiplomacyManager` — Utang token tracking; datu alignment

### Key Design Rules
- **Never call managers directly from each other** — use `EventBus` signals
- **Always use `ResourceManager.spend()`** — never subtract from resource dicts directly
- **Powder is finite** — Spain must win before Day 40 or run dry
- **Tide is public information** — both AI and player can see it coming
- **Lapu-Lapu cannot die** in early milestones; implement hero respawn timer first
- **Humabon is a pivot** — the player's best investment is diplomacy, not combat

### Unit Groups (derived from faction ids: mactan / spain / cebu)
- `"units"` — all units
- `"faction_mactan"` — Mactan player units
- `"faction_spain"` — Spanish AI units
- `"faction_cebu"` — Humabon's collaborators
- `"naval_units"` — all naval units (both factions)
- `"buildings_mactan"` / `"buildings_spain"` / `"buildings_cebu"` — structures per faction
- `"kuta"` — KutaMactan specifically (victory condition target)
- `"heroes"` — hero units (special death handling)
- `"datu_villages"` — the six Utang targets

---

*Last updated: 2026-07-03. Milestones 0–12 complete (plus procedural art v2); Milestones 13–16 defined above are the active roadmap. The smoke test (`Godot --headless --path . -- --smoke-test`) covers the full feature set.*
