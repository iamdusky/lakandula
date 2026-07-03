extends Node
## The Utang system: gift goods to datus to place Utang tokens, call them in
## for fighters / intel / supplies. A datu allied with Spain refuses the call
## (default -> Disgrace). Humabon flips in stages: 3 tokens = Enrique event,
## 5 = Katipunan Offer (spend Honor -> neutral, Spain loses tribute),
## 7 while neutral = full alliance (10 Cebu warriors sail for Mactan).

enum HumabonState { SPAIN_ALLY, NEUTRAL, ALLIED_MACTAN }

const HUMABON := "humabon"
const FACTION_MACTAN := "mactan"

const DATU_GIFT_COST := {"rice": 40, "copper": 10}
const HUMABON_GIFT_COST := {"rice": 60, "copper": 20}
const KATIPUNAN_HONOR_COST := 20

## A neutral (or wavering) datu allies with the gifting faction at this many tokens.
const VILLAGE_ALLY_THRESHOLD := 2
const ENRIQUE_THRESHOLD := 3
const KATIPUNAN_THRESHOLD := 5
const FULL_FLIP_THRESHOLD := 7
const FULL_FLIP_WARRIORS := 10

const CALL_SUPPLIES := {"rice": 60, "copper": 15}
const CALL_FIGHTER_COUNT := 2
const CALL_INTEL_DURATION := 8.0

const FIGHTER_SCENE := preload("res://scenes/units/mandirigma.tscn")

## Utang tokens held ON a datu BY a faction: { datu_name: { faction: tokens } }
var utang_ledger := {}
## Disgrace tokens per faction (accumulated from defaults).
var disgrace := {}
var humabon_state: HumabonState = HumabonState.SPAIN_ALLY
var enrique_fired := false
var katipunan_offered := false


func _ready() -> void:
	EventBus.game_started.connect(_on_game_started)


## Fresh ledger on every game start (retry reloads the scene, not autoloads).
func _on_game_started() -> void:
	utang_ledger.clear()
	disgrace.clear()
	humabon_state = HumabonState.SPAIN_ALLY
	enrique_fired = false
	katipunan_offered = false


func get_tokens(datu: String, faction: String) -> int:
	return utang_ledger.get(datu, {}).get(faction, 0)


func add_token(datu: String, faction: String) -> void:
	if not utang_ledger.has(datu):
		utang_ledger[datu] = {}
	utang_ledger[datu][faction] = utang_ledger[datu].get(faction, 0) + 1
	EventBus.datu_obligated.emit(datu, faction, utang_ledger[datu][faction])


## Send goods to a datu (or Humabon), placing one Utang token.
## Empty gift = the standard gift for that recipient.
func give_gift(from_faction: String, to_datu: String, gift: Dictionary = {}) -> bool:
	var cost := gift
	if cost.is_empty():
		cost = HUMABON_GIFT_COST if to_datu == HUMABON else DATU_GIFT_COST
	if not ResourceManager.spend(from_faction, cost):
		return false
	add_token(to_datu, from_faction)
	EventBus.hud_notification.emit("A gift reaches %s — an utang is owed." % _title(to_datu))
	if to_datu == HUMABON:
		_advance_humabon(from_faction)
	else:
		_maybe_ally_village(to_datu, from_faction)
	return true


## Collect on a debt: the datu grants one action ("supplies", "fighters",
## "intel"). A datu bound to Spain refuses instead (default + Disgrace).
func call_utang(from_faction: String, to_datu: String, action := "supplies") -> bool:
	if get_tokens(to_datu, from_faction) <= 0:
		return false
	var village := _find_village(to_datu)
	if village != null and village.alignment == DatuVillage.Alignment.ALLIED_SPAIN:
		default_utang(to_datu, from_faction)
		return false
	utang_ledger[to_datu][from_faction] -= 1
	EventBus.utang_called.emit(to_datu, from_faction)
	match action:
		"supplies":
			ResourceManager.add(from_faction, CALL_SUPPLIES)
			EventBus.hud_notification.emit("%s sends rice and copper." % _title(to_datu))
		"fighters":
			var anchor := village.global_position if village != null else _kuta_anchor()
			for i in CALL_FIGHTER_COUNT:
				UnitSpawner.spawn(FIGHTER_SCENE, anchor + Vector2(30 + 26 * i, 40), from_faction, true)
			EventBus.hud_notification.emit("%s sends warriors to the cause." % _title(to_datu))
		"intel":
			EventBus.ritual_reveal.emit(CALL_INTEL_DURATION)
			EventBus.hud_notification.emit("%s shares word of enemy movements." % _title(to_datu))
	return true


## The datu refuses the call. The token is lost and Disgrace accrues.
func default_utang(datu: String, faction: String) -> void:
	if utang_ledger.has(datu):
		utang_ledger[datu][faction] = maxi(0, utang_ledger[datu].get(faction, 0) - 1)
	disgrace[faction] = disgrace.get(faction, 0) + 1
	EventBus.utang_defaulted.emit(datu, faction)
	EventBus.hud_notification.emit("%s refuses the call! The debt dies in disgrace." % _title(datu))


## The Katipunan Offer: spend Honor to pull Humabon out of Spain's embrace.
func accept_katipunan_offer() -> bool:
	if not katipunan_offered or humabon_state != HumabonState.SPAIN_ALLY:
		return false
	if not ResourceManager.spend(FACTION_MACTAN, {"honor": KATIPUNAN_HONOR_COST}):
		return false
	humabon_state = HumabonState.NEUTRAL
	EventBus.humabon_flip_stage.emit("neutral")
	EventBus.hud_notification.emit("Humabon withdraws from Spain — the tribute ships stop sailing.")
	if get_tokens(HUMABON, FACTION_MACTAN) >= FULL_FLIP_THRESHOLD:
		_full_flip()
	return true


# --- Internals ---

func _advance_humabon(from_faction: String) -> void:
	if from_faction != FACTION_MACTAN:
		return
	var tokens := get_tokens(HUMABON, FACTION_MACTAN)
	if tokens >= ENRIQUE_THRESHOLD and not enrique_fired:
		enrique_fired = true
		EventBus.humabon_flip_stage.emit("enrique")
		EventBus.hud_notification.emit("Enrique of Malacca opens back-channel talks with Mactan.")
	if tokens >= KATIPUNAN_THRESHOLD and not katipunan_offered:
		katipunan_offered = true
		EventBus.humabon_flip_stage.emit("katipunan_offer")
		EventBus.hud_notification.emit(
			"Katipunan Offer: spend %d Honor to turn Humabon neutral." % KATIPUNAN_HONOR_COST)
	if tokens >= FULL_FLIP_THRESHOLD and humabon_state == HumabonState.NEUTRAL:
		_full_flip()


func _full_flip() -> void:
	humabon_state = HumabonState.ALLIED_MACTAN
	EventBus.humabon_flip_stage.emit("allied")
	EventBus.hud_notification.emit("Humabon joins the coalition! Cebu warriors sail for Mactan.")
	var anchor := _kuta_anchor()
	for i in FULL_FLIP_WARRIORS:
		var offset := Vector2(-90 + 40 * (i % 5), 110 + 36 * (i / 5))
		UnitSpawner.spawn(FIGHTER_SCENE, anchor + offset, FACTION_MACTAN, true)


func _maybe_ally_village(datu: String, faction: String) -> void:
	if get_tokens(datu, faction) < VILLAGE_ALLY_THRESHOLD:
		return
	var village := _find_village(datu)
	if village != null:
		village.ally(faction)


func _find_village(datu: String) -> DatuVillage:
	for node in get_tree().get_nodes_in_group("datu_villages"):
		var village := node as DatuVillage
		if village != null and village.datu_name == datu:
			return village
	return null


func _kuta_anchor() -> Vector2:
	var kuta := get_tree().get_first_node_in_group("kuta") as Node2D
	return kuta.global_position if kuta != null else Vector2.ZERO


func _title(datu: String) -> String:
	return "Rajah Humabon" if datu == HUMABON else datu
