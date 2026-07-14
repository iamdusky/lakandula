# LAKANDULA — Claude Code Context

Warcraft-style single-player RTS in **Godot 4.6** (GDScript). Pre-colonial Philippines, Battle of Mactan, April 1521. Player leads Lapu-Lapu's Mactan coalition against Spain (Magellan) and the Cebu collaborators (Rajah Humabon).

**Full design + milestone checklist: [PLAN.md](PLAN.md).** Update its checkboxes and status lines as work completes.

## Running & verifying

- Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot`
- Open editor: `/Applications/Godot.app/Contents/MacOS/Godot --path . -e`
- Headless error check (imports assets, runs main scene a few frames, exits):
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 10`
- Smoke test (movement, combat, selection, economy — exits 0/1, takes ~10 s):
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --smoke-test`
- ⚠ Textures in `assets/gen/` are AI-generated art (WC2 pixel-art style), NOT
  regenerable. The old procedural generator (`tools/gen_assets.gd`) is retired
  and deleted — do not recreate or run it; it would clobber the art. It remains
  in git history (pre-`ai-generated-assets` branch) if the placeholder pipeline
  is ever needed again. New/changed sprites must keep the same filenames and
  sheet layouts (humanoids: 4-frame horizontal strips; see ASSETS.md).
- Regenerate placeholder audio (`assets/gen/audio/`, synthesized WAVs — audio
  IS still generated):
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/gen_audio.gd`
- Main scene: `scenes/ui/main_menu.tscn` (menu → briefing → `scenes/maps/main_map.tscn`).
  With `--smoke-test` / `--screenshot` user args the menu redirects straight to
  the battle map, so headless tooling behaves as if the map were the main scene.
  `--screenshot-menu <path>` captures the menu itself.

## Layout

- `scripts/autoload/` — singleton managers (see order below)
- `scripts/units/` — `Unit` base class + subclasses, `UnitData` resource class
- `scripts/map/` — `MapData` (ASCII map definition) + `MapBuilder` (paints tiles, builds navmeshes at runtime)
- `scripts/ui/` — HUD, diplomacy panel, minimap, game-over screen
- `scripts/map/fog_of_war.gd` — fog overlay; hides enemy units (`unit.visible`), `is_world_visible()`; lifted by `EventBus.ritual_reveal`
- `scenes/maps/`, `scenes/units/`, `scenes/buildings/`, `scenes/projectiles/`, `scenes/ui/` — scenes
- `resources/units/` — `.tres` stat resources
- `assets/gen/` — AI-generated textures (fixed filenames/layouts; not regenerable) + synthesized audio
- `tools/` — audio generator, smoke test, screenshot capture

## Map & navigation

The map is NOT editor-painted: edit `scripts/map/map_data.gd` (ASCII rows, one
char per 64 px cell, legend in the file; every row must be exactly 40 chars).
`MapBuilder.build()` paints both TileMapLayers and constructs the land, naval,
and shallows NavigationRegion2D meshes from the cells (shallows cells live
ONLY in the shallows region — never overlap regions). Land units use
navigation_layers 1, naval units 2; the shallows region is layer 2 normally,
3 at low tide (land units can wade). Terrain speed/damage modifiers come from `UnitData.terrain_speed`
/ `terrain_damage` dictionaries keyed by terrain type.

## Autoload order (registered in project.godot)

1. `EventBus` — global signal hub
2. `GameSettings` — persisted settings + codex unlocks (user://settings.cfg); registered early so others read it at _ready
3. `ResourceManager` — both factions' resources
4. `TerrainManager` — terrain type by world position
5. `TideManager` — tide cycle (LOW/RISING/HIGH/FALLING, 10 min each, starts HIGH); `speed_multiplier(unit)` beaches "galleons" at LOW (×0), boosts "karakoa" (×1.3); toggles the shallows region's land layer; `force_phase()` for tests
6. `VictoryManager` — polls win conditions
7. `SelectionManager` — selection state + commands
8. `DiplomacyManager` — Utang token ledger
9. `UnitSpawner` — affordability-checked unit creation (all spawning funnels through it)
10. `SpanishAI` — Spain's campaign state machine (SAIL_IN → ESTABLISH → CONVERT → ASSAULT → DESPERATE)
11. `TechTree` — research per faction (11 Mactan techs, 3 ages, gate = 2 techs of previous age); units query `speed_multiplier`/`damage_multiplier`/`poison_multiplier`/`heal_multiplier`. ⚠ unit.gd references TechTree — tech_tree.gd must never parse-time-reference unit classes or autoloads that preload unit scenes (circular load). Use groups/duck typing/`get_node("/root/…")`/`load()`.
12. `AudioManager` — adaptive music (calm/battle crossfade on 400 px proximity) + event-driven SFX (`combat_hit` signal, throttled); `play_sfx(name)`; `last_sfx` for tests; runs while paused.
13. `Effects` — one-shot particles (death_burst/fire_burst/cannon_smoke/water_splash) + death_ghost; pure visuals, references no game classes (cycle-safe).
14. `SceneFlow` — fade-to-black scene router (`goto(path)`, `reload()`); unpauses before switching; used by menus and the game-over screen.

## Hard rules

- **Managers never call each other directly** — communicate via `EventBus` signals only.
- **Never mutate resource dicts directly** — always `ResourceManager.spend()` / `.add()`.
- Spanish powder is finite; tide state is public information; Humabon is a diplomacy pivot, not a combat target.
- Game over: Lapu-Lapu's death = instant loss (his respawn never completes); Magellan's death = instant win **in skirmish only**. `VictoryManager.end_game()` pauses the tree; managers reset on `EventBus.game_started` (retry reloads the scene only).
- Game modes (`GameSettings.game_mode`, read LIVE via `VictoryManager.campaign_active()`): "skirmish" = parallel win conditions; "campaign" (M17) = staged phases in VictoryManager (LANDING day 15 → ASSAULT day 22/attackers<3 → CONQUISTADOR → REPRISAL 8 days → EXPEL = total Spanish elimination → "spain_expelled"). In campaign, Magellan's death triggers `SpanishAI.REPRISAL` (final landing, no more resupply) instead of victory; monsoon/powder/great-alliance stay global. Phases emit `EventBus.objective_changed`; the HUD ObjectivesPanel tracks them. Smoke test pins skirmish at start and drives campaign in its final section.
- Campaign-only attrition (M18, all gated on game_mode): Babaylan liberates a Spain-held village to NEUTRAL (`_liberate_progress`, 12 s rite, mirror of Fraile); reinforcement fleets during ASSAULT/DESPERATE (`_do_reinforcement_landing`, alternating south + NORTH_LANDING beachheads, +15 powder each, difficulty `reinforce_interval`); army upkeep (`ResourceManager.army_upkeep()` — non-hero units past 12 cost rice per tick); Kuta garrison (`garrison_unit`/`release_garrison`, ≤6 hidden invulnerable units, wall arrows, RMB-on-Kuta command; occupants die with the fort); Reprisal storm (`TideManager.storm`, "powder_weapons" group ×0.6 range, phases 3→4 by literal int).
- Unit/building groups are the lookup mechanism and are derived from faction ids: `"units"`, `"faction_mactan"`, `"faction_spain"`, `"faction_cebu"`, `"naval_units"`, `"buildings_mactan"`, `"buildings_spain"`, `"buildings_cebu"`, `"kuta"`, `"heroes"`, `"datu_villages"`. `Unit`/`Building` `_ready()` handles this — call `super()` when overriding.

## Input actions (project.godot)

`camera_up/left/down/right` (WASD), `camera_zoom_in/out` (wheel), `select` (LMB — units and own buildings), `command` (RMB; Ctrl/Cmd+RMB = attack-move; on a selected building = rally point), `attack_move` (F, arms next click), `cycle_idle` (Tab), `ability` (Q), `stop` (Space), `toggle_diplomacy` (T), `toggle_tech` (R), `toggle_codex` (C). Raw keys in SelectionManager: Ctrl/Cmd+1-9 assign control groups, 1-9 recall (double-tap centers), Ctrl/Cmd+A select army.

Building footprints are carved from the land navmesh at map build (MapBuilder
reads `Buildings` children's collision rects) — units path around structures.

## Diplomacy (Utang)

`DiplomacyManager.give_gift(faction, datu)` places tokens (Humabon = the
`HUMABON` const); 2 tokens ally a NEUTRAL village, but a village held by the
other faction costs 5 (`VILLAGE_CONTEST_THRESHOLD`) — and any alignment
change wipes the losing faction's tokens on that datu, so a Spanish
conversion destroys the player's prior investment (emits `village_contested`
on a contested win). `call_utang(faction, datu,
"supplies"|"fighters"|"intel")` cashes one in; Spain-allied datus default and
apply Disgrace. Humabon ladder: 3 tokens = Enrique event, 5 = Katipunan Offer
(`accept_katipunan_offer()`, 20 Honor, ends Spain's tribute), 7 while neutral
= full alliance (+10 warriors). All stages emit `EventBus.humabon_flip_stage`.
UI: DiplomacyPanel in the HUD, toggled with T.

## Unit system

`Unit` (scripts/units/unit.gd) owns the state machine, nav movement, armor
(flat reduction, min 1; poison and Matay bypass it), poison DoT, stun, heal,
short-pulse hero auras, and `capture()` (boarding/defection). Auto-combat
(M13): idle units scan every 0.4 s and acquire non-passive, visible,
non-invulnerable enemies within min(sight, 260) px, with a 320 px leash;
damaged idle units retaliate against their attacker; `command_attack_move()`
sweeps. `UnitData.passive` (Fraile/Babaylan/dummy) opts out of auto-combat
both ways — smoke-test scenarios must park idle armies away from scripted
fights or they will join them. Morale (M14): non-hero units rout
(uncontrollable ~5 s) on nearby friendly hero death (400 px) or 3:1 local
odds while fighting (200 px, passive units excluded from counts); test
skirmishes must be staged >400 px from bystander armies AND stray walkers
must be cleaned up (see the M8 scout) or checks get photobombed.

Save/load: `SaveGame` autoload (user://save.json), F5/F9 in battle, Continue
in the menu; managers expose `save_state()`/`load_state()`. `GameStats`
tracks session stats for the game-over screen. Difficulty:
`GameSettings.DIFFICULTY` table, `difficulty_value(key)` — scales Spanish
waves/landing/powder/tribute; smoke test pins "normal" at start. Subclass hooks:
`_perform_attack(target)` for ranged/special attacks, `use_ability()` (Q),
`_on_died()`. `Hero` adds a 0.5 s aura pulse (`_apply_aura()`) and respawn
(20 s) instead of permadeath. Roster: Mandirigma, Mamamana (poison arrows),
Juramentado (Honor cost, armor-piercing Matay), Babaylan (heal aura, Ritwal),
Karakoa (lantaka + Salvo), Balangay (boards ships <30% HP), heroes LapuLapu
(Daluyong charge + rally aura) and RajahSulayman (Sunugin + war aura).
Projectiles: `Projectile.setup(target, damage, source, options)` — options:
speed, splash_radius, poison_dps/poison_duration, ignore_armor.

Spanish roster: SoldadoTercio (pike formation bonus, group "soldados"),
Arcabucero (1 powder/shot, kites), Jinete (first-strike charge), Fraile
(converts neutral villages, 15 s unchallenged), Galeon (broadside, 2 powder,
group "galleons" for M6 tide), Bergantin (river-capable), Magellan (hero, NO
respawn, Baptism converts nearest neutral village, death emits hero_died).
Powder is consumed per shot — empty magazines mean silent guns. SpanishAI
transitions on EventBus.day_advanced (5/8/15/36) and powder < 20 → DESPERATE;
tests fast-forward by emitting day_advanced directly.

## Conventions

- GDScript with static typing where practical; snake_case files matching class purpose.
- Data-driven units: behavior in `scripts/`, stats in `resources/**/*.tres` (`UnitData` etc.).
- Faction id strings: `"mactan"`, `"spain"`, `"cebu"` (constants on `ResourceManager` / `DiplomacyManager`).
