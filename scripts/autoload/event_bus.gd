extends Node
## Global signal hub. All cross-system communication goes through here.
## Design rule: managers never call each other directly — they emit/connect via EventBus.

# --- Economy ---
@warning_ignore_start("unused_signal")
signal resources_changed(faction: String, resources: Dictionary)
signal resource_spend_failed(faction: String, cost: Dictionary)

# --- Time ---
signal day_advanced(day: int)

# --- Selection & commands ---
signal selection_changed(units: Array)
signal building_selected(building: Node)
signal command_issued(command: String, target)

# --- Tech ---
signal tech_researched(faction: String, tech_id: String)

# --- Diplomacy (Utang) ---
signal datu_obligated(datu: String, faction: String, tokens: int)
signal datu_allied(datu: String, faction: String)
signal utang_called(datu: String, faction: String)
signal utang_defaulted(datu: String, faction: String)
signal humabon_flip_stage(stage: String)

# --- Spanish AI ---
signal spanish_state_changed(state: String)
signal powder_critically_low

# --- Tide (Milestone 6) ---
signal tide_changed(phase: String)
signal galleons_beached
signal galleons_freed

# --- Combat & units ---
signal combat_hit(target: Node)
signal unit_spawned(unit: Node)
signal unit_died(unit: Node)
signal unit_captured(unit: Node, new_faction: String)
signal unit_routed(unit: Node)
signal hero_died(hero: Node)
signal hero_respawned(hero: Node)
signal building_destroyed(building: Node)

# --- Abilities ---
signal ritual_reveal(duration: float)

# --- Game flow ---
signal game_started
signal game_over(winner: String, condition: String)

# --- UI ---
signal hud_notification(text: String)
signal minimap_ping(world_pos: Vector2)
signal settings_changed
@warning_ignore_restore("unused_signal")
