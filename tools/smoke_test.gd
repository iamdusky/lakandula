extends Node
## Headless verification for Milestones 1–2. Run with:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -- --smoke-test
## Exits 0 on pass, 1 on failure. Takes ~25 s (real-time physics).

const MANDIRIGMA := preload("res://scenes/units/mandirigma.tscn")
const SOLDADO := preload("res://scenes/units/soldado_tercio.tscn")
const FRAILE := preload("res://scenes/units/fraile.tscn")
const MAMAMANA := preload("res://scenes/units/mamamana.tscn")
const SULAYMAN := preload("res://scenes/units/rajah_sulayman.tscn")
const JURAMENTADO := preload("res://scenes/units/juramentado.tscn")
const BABAYLAN := preload("res://scenes/units/babaylan.tscn")
const KARAKOA := preload("res://scenes/units/karakoa.tscn")
const BALANGAY := preload("res://scenes/units/balangay.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _wait(0.6)
	# Difficulty persists across runs — pin it so scripted counts (landing
	# size, starting powder) are deterministic.
	GameSettings.set_difficulty("normal")

	# --- Milestone 1: core loop ---
	var warrior := get_tree().get_first_node_in_group("faction_mactan") as Unit
	var dummy := get_tree().current_scene.get_node("Units/TrainingDummy") as Unit
	_check(warrior != null, "Mandirigma present in scene")
	_check(dummy != null, "Training dummy present in scene")
	if warrior == null or dummy == null:
		_finish()
		return

	var terrain := TerrainManager.get_terrain_type(warrior.global_position)
	_check(terrain == "land", "terrain at warrior spawn is land (got '%s')" % terrain)
	_check(TerrainManager.get_terrain_type(Vector2(-800, 0)) == "open_water", "strait is open_water")

	SelectionManager.select_units([warrior])
	_check(SelectionManager.selected_units.size() == 1, "unit selectable via SelectionManager")

	var start := warrior.global_position
	warrior.command_move(start + Vector2(200, 120))
	await _wait(3.0)
	_check(warrior.global_position.distance_to(start) > 120.0,
		"unit moved via navigation (traveled %.0f px)" % warrior.global_position.distance_to(start))

	var dummy_health := dummy.health
	warrior.command_attack(dummy)
	await _wait(5.0)
	_check(dummy.health < dummy_health,
		"melee attack damaged dummy (%.0f -> %.0f)" % [dummy_health, dummy.health])
	warrior.stop()

	# --- Milestone 2: hero aura (warrior parked near Lapu-Lapu after chase) ---
	var lapu := get_tree().get_first_node_in_group("heroes") as LapuLapu
	_check(lapu != null, "Lapu-Lapu present and in heroes group")
	await _wait(1.0)
	if lapu != null:
		_check(warrior._aura_attack_speed > 1.0,
			"rally aura reached warrior (x%.2f attack speed)" % warrior._aura_attack_speed)

	# --- Milestone 2: Daluyong charge staggers ---
	if lapu != null:
		_check(lapu.use_ability(), "Daluyong fires")
		await _wait(0.8)
		_check(dummy.is_stunned(), "charge staggered the dummy")

	# --- Milestone 2: spawner + economy gate ---
	ResourceManager.add("mactan", {"rice": 500, "copper": 200, "honor": 50})
	var rice_before := ResourceManager.get_amount("mactan", "rice")
	var archer := UnitSpawner.spawn(MAMAMANA, Vector2(-32, 0), "mactan") as Mamamana
	_check(archer != null, "UnitSpawner spawned Mamamana")
	_check(ResourceManager.get_amount("mactan", "rice") == rice_before - 60,
		"spawn spent rice (%d -> %d)" % [rice_before, ResourceManager.get_amount("mactan", "rice")])
	_check(UnitSpawner.spawn(KARAKOA, Vector2(-608, 0), "spain") == null,
		"spawner refuses unaffordable spawn (Spain has no rice)")

	var honor_before := ResourceManager.get_amount("mactan", "honor")
	var berserker := UnitSpawner.spawn(JURAMENTADO, Vector2(-32, 64), "mactan") as Juramentado
	_check(berserker != null, "Juramentado spawned")
	_check(ResourceManager.get_amount("mactan", "honor") == honor_before - 15,
		"Juramentado cost Honor, not Rice")

	# --- Milestone 2: poison arrows ---
	if archer != null:
		var before := dummy.health
		archer.command_attack(dummy)
		await _wait(3.0)
		archer.stop()
		_check(dummy.health < before, "arrow damaged dummy (%.0f -> %.0f)" % [before, dummy.health])
		_check(dummy.poison_dps > 0.0, "dummy is poisoned (%.1f dps)" % dummy.poison_dps)

	# --- Milestone 2: naval movement on water navmesh ---
	var galley := UnitSpawner.spawn(KARAKOA, Vector2(-608, 0), "mactan") as Karakoa
	_check(galley != null, "Karakoa spawned on water")
	if galley != null:
		_check(galley.is_in_group("naval_units"), "Karakoa in naval_units group")
		var anchor := galley.global_position
		galley.command_move(anchor + Vector2(0, 280))
		await _wait(3.0)
		_check(galley.global_position.distance_to(anchor) > 120.0,
			"Karakoa sailed (traveled %.0f px)" % galley.global_position.distance_to(anchor))
		galley.stop()

	# --- Milestone 2: Balangay boarding ---
	var raider := UnitSpawner.spawn(BALANGAY, Vector2(-672, -128), "mactan") as Balangay
	var prize: Unit = KARAKOA.instantiate()
	prize.faction = "spain"
	prize.position = Vector2(-544, -64)
	get_tree().current_scene.get_node("Units").add_child(prize)
	prize.health = prize.data.max_health * 0.2
	_check(raider != null, "Balangay spawned")
	if raider != null:
		raider.command_attack(prize)
		await _wait(3.0)
		_check(prize.faction == "mactan", "boarding captured the crippled ship (faction: %s)" % prize.faction)

	# M13 stabilization: with auto-retaliation live, idle ships parked near
	# the Spanish anchorage would brawl with the fleet once its grace period
	# ends. Park the flotilla out of everyone's aggro range.
	galley.global_position = Vector2(-672, 440)
	raider.global_position = Vector2(-704, 500)
	prize.global_position = Vector2(-672, 560)

	# --- Milestone 2: Babaylan healing ---
	var healer := UnitSpawner.spawn(BABAYLAN, warrior.global_position + Vector2(40, 0), "mactan") as Babaylan
	_check(healer != null, "Babaylan spawned")
	warrior.take_damage(30.0)
	var wounded := warrior.health
	await _wait(2.5)
	_check(warrior.health > wounded, "Babaylan healed warrior (%.0f -> %.0f)" % [wounded, warrior.health])
	_check(healer == null or healer.use_ability(), "Ritwal fires")

	# --- Milestone 3: buildings placed ---
	var buildings := get_tree().current_scene.get_node("Buildings")
	var barracks := buildings.get_node("Barracks") as Building
	var kuta := get_tree().get_first_node_in_group("kuta") as Building
	_check(barracks != null, "Barracks placed")
	_check(kuta != null, "Kuta present and in 'kuta' group")
	_check(get_tree().get_nodes_in_group("buildings_spain").size() == 2,
		"Spanish beachhead + camp placed")

	# --- Milestone 3: production queue ---
	var units_before := get_tree().get_nodes_in_group("faction_mactan").size()
	var rice_at_queue := ResourceManager.get_amount("mactan", "rice")
	_check(barracks.queue_unit(MANDIRIGMA), "queued Mandirigma at Barracks")
	_check(ResourceManager.get_amount("mactan", "rice") == rice_at_queue - 50,
		"queue charged rice up front")
	await _wait(5.6)
	_check(get_tree().get_nodes_in_group("faction_mactan").size() == units_before + 1,
		"trained unit emerged at the gate")

	# --- Milestone 3: units can attack buildings ---
	var beachhead := buildings.get_node("SpanishBeachhead") as Building
	warrior.command_attack(beachhead)
	await _wait(4.5)
	_check(beachhead.health < beachhead.max_health,
		"warrior damaged Spanish beachhead (%.0f/%.0f)" % [beachhead.health, beachhead.max_health])
	warrior.stop()

	# --- Milestone 3: datu villages & ally income multiplier ---
	var villages := get_tree().get_nodes_in_group("datu_villages")
	_check(villages.size() == 6, "6 datu villages placed (found %d)" % villages.size())
	var village_a := villages[0] as DatuVillage
	var village_b := villages[1] as DatuVillage
	village_a.ally("mactan")
	_check(ResourceManager.get_amount("mactan", "allies") == 1, "allied village raised ally count")
	village_b.ally("spain")
	_check(ResourceManager.get_amount("mactan", "allies") == 1,
		"Spanish-allied village doesn't count for Mactan")

	# --- Milestone 3: Humabon's palace untouchable early ---
	var palace := buildings.get_node("HumabonPalace") as Building
	palace.take_damage(50.0)
	_check(palace.health == palace.max_health, "Humabon's palace invulnerable before day 20")

	# --- Milestone 3: Shrine generates Honor ---
	var honor_watch := ResourceManager.get_amount("mactan", "honor")
	await _wait(6.5)
	_check(ResourceManager.get_amount("mactan", "honor") > honor_watch,
		"Shrine ticked Honor (%d -> %d)" % [honor_watch, ResourceManager.get_amount("mactan", "honor")])

	# --- Milestone 3: Sunugin burns a structure ---
	var sulayman := UnitSpawner.spawn(SULAYMAN, barracks.global_position + Vector2(-56, 0), "mactan") as RajahSulayman
	_check(sulayman != null, "Rajah Sulayman spawned")
	if sulayman != null:
		_check(sulayman.use_ability(), "Sunugin fires")
		await _wait(0.2)
		_check(not is_instance_valid(barracks), "Sunugin burned the nearest structure (Barracks)")

	# --- Milestone 4: Utang diplomacy ---
	ResourceManager.add("mactan", {"rice": 1000, "copper": 400, "honor": 40})
	var stages: Array[String] = []
	EventBus.humabon_flip_stage.connect(func(stage: String) -> void: stages.append(stage))
	var defaulted := [false]
	EventBus.utang_defaulted.connect(func(_d: String, _f: String) -> void: defaulted[0] = true)

	# Gifts obligate a neutral datu; 2 tokens win the village over.
	var village_c := villages[2] as DatuVillage
	var datu_c := village_c.datu_name
	var rice_gift := ResourceManager.get_amount("mactan", "rice")
	_check(DiplomacyManager.give_gift("mactan", datu_c), "gift sent to neutral datu")
	_check(ResourceManager.get_amount("mactan", "rice") == rice_gift - 40, "gift cost rice")
	_check(DiplomacyManager.get_tokens(datu_c, "mactan") == 1, "Utang token recorded")
	DiplomacyManager.give_gift("mactan", datu_c)
	_check(village_c.alignment == DatuVillage.Alignment.ALLIED_MACTAN,
		"2 tokens flipped the village to Mactan")
	_check(ResourceManager.get_amount("mactan", "allies") == 2, "ally count rose to 2")

	# Calling in debts: supplies, then fighters.
	var rice_call := ResourceManager.get_amount("mactan", "rice")
	_check(DiplomacyManager.call_utang("mactan", datu_c, "supplies"), "utang called for supplies")
	_check(ResourceManager.get_amount("mactan", "rice") == rice_call + 60, "supplies delivered")
	var mactan_count := get_tree().get_nodes_in_group("faction_mactan").size()
	_check(DiplomacyManager.call_utang("mactan", datu_c, "fighters"), "utang called for fighters")
	_check(get_tree().get_nodes_in_group("faction_mactan").size() == mactan_count + 2,
		"datu sent 2 fighters")
	_check(DiplomacyManager.get_tokens(datu_c, "mactan") == 0, "tokens consumed by calls")

	# A Spain-allied datu refuses: default + Disgrace.
	DiplomacyManager.give_gift("mactan", village_b.datu_name)
	_check(not DiplomacyManager.call_utang("mactan", village_b.datu_name, "supplies"),
		"Spain-allied datu refuses the call")
	_check(defaulted[0], "utang_defaulted emitted")
	_check(DiplomacyManager.disgrace.get("mactan", 0) == 1, "Disgrace token applied")

	# Humabon ladder: 3 = Enrique, 5 = Katipunan Offer.
	for i in 5:
		DiplomacyManager.give_gift("mactan", DiplomacyManager.HUMABON)
	_check("enrique" in stages, "Enrique event fired at 3 tokens")
	_check("katipunan_offer" in stages, "Katipunan Offer fired at 5 tokens")

	var honor_k := ResourceManager.get_amount("mactan", "honor")
	_check(DiplomacyManager.accept_katipunan_offer(), "Katipunan Offer accepted")
	_check(ResourceManager.get_amount("mactan", "honor") == honor_k - 20, "Katipunan cost Honor")
	_check(DiplomacyManager.humabon_state == DiplomacyManager.HumabonState.NEUTRAL,
		"Humabon is neutral")

	# Spain's tribute income stops.
	var spain_gold := ResourceManager.get_amount("spain", "gold")
	await _wait(5.5)
	_check(ResourceManager.get_amount("spain", "gold") == spain_gold,
		"Spain tribute ceased (gold frozen at %d)" % spain_gold)

	# Full flip at 7 tokens: 10 Cebu warriors arrive.
	var before_flip := get_tree().get_nodes_in_group("faction_mactan").size()
	DiplomacyManager.give_gift("mactan", DiplomacyManager.HUMABON)
	DiplomacyManager.give_gift("mactan", DiplomacyManager.HUMABON)
	_check("allied" in stages, "full flip fired at 7 tokens")
	_check(get_tree().get_nodes_in_group("faction_mactan").size() == before_flip + 10,
		"10 Cebu warriors arrived at the Kuta")

	# --- Milestone 5: Spanish AI ---
	_check(SpanishAI.state == SpanishAI.State.SAIL_IN, "AI began SAIL_IN at game start")
	var galleons := get_tree().get_nodes_in_group("galleons")
	_check(galleons.size() == 2, "2 galleons sighted off Cebu")
	var galleon := galleons[0] as Unit
	var galleon_health := galleon.health
	galleon.take_damage(50.0)
	_check(galleon.health == galleon_health, "fleet invulnerable during grace period")

	# M13 stabilization: park every Mactan land unit in the northern
	# clearing before Spain lands — otherwise auto-retaliation drags them
	# (including Lapu-Lapu) into the scripted push, breaking later checks.
	var park_index := 0
	for park_node in get_tree().get_nodes_in_group("faction_mactan"):
		var park_unit := park_node as Unit
		if park_unit == null or park_unit.is_in_group("naval_units"):
			continue
		park_unit.stop()
		park_unit.global_position = Vector2(
			-160 + 48 * (park_index % 8), -480 + 40 * int(park_index / 8.0))
		park_index += 1

	var spain_count := get_tree().get_nodes_in_group("faction_spain").size()
	EventBus.day_advanced.emit(5)
	_check(SpanishAI.state == SpanishAI.State.ESTABLISH, "day 5 -> ESTABLISH")
	_check(get_tree().get_nodes_in_group("faction_spain").size() == spain_count + 7,
		"4 Soldados + 3 Arcabuceros landed")
	galleon.take_damage(50.0)
	_check(galleon.health < galleon_health, "grace period over — fleet vulnerable")
	_check(not ResourceManager._spain_tribute_active,
		"tribute stayed off (Humabon already flipped)")

	EventBus.day_advanced.emit(8)
	_check(SpanishAI.state == SpanishAI.State.CONVERT, "day 8 -> CONVERT")
	var frailes: Array[Fraile] = []
	for node in get_tree().get_nodes_in_group("faction_spain"):
		if node is Fraile:
			frailes.append(node)
	_check(frailes.size() == 2, "2 Frailes preaching")

	# Fraile conversion (fast-forwarded to the final second)
	var neutral_village: DatuVillage = null
	for node in villages:
		var candidate := node as DatuVillage
		if candidate.alignment == DatuVillage.Alignment.NEUTRAL:
			neutral_village = candidate
			break
	var fraile := frailes[0]
	fraile.stop()
	fraile.global_position = neutral_village.global_position + Vector2(70, 30)
	fraile._progress = 14.0
	await _wait(1.5)
	_check(neutral_village.alignment == DatuVillage.Alignment.ALLIED_SPAIN,
		"Fraile converted %s" % neutral_village.datu_name)

	EventBus.day_advanced.emit(15)
	_check(SpanishAI.state == SpanishAI.State.ASSAULT, "day 15 -> ASSAULT")
	var magellan: Magellan = null
	for node in get_tree().get_nodes_in_group("heroes"):
		if node is Magellan:
			magellan = node
	_check(magellan != null, "Magellan leads the assault")

	# Baptism converts a neutral village instantly
	var second_neutral: DatuVillage = null
	for node in villages:
		var candidate := node as DatuVillage
		if candidate.alignment == DatuVillage.Alignment.NEUTRAL:
			second_neutral = candidate
			break
	if magellan != null and second_neutral != null:
		magellan.global_position = second_neutral.global_position + Vector2(80, 0)
		_check(magellan.use_ability(), "Baptism fires")
		_check(second_neutral.alignment == DatuVillage.Alignment.ALLIED_SPAIN,
			"Baptism converted %s" % second_neutral.datu_name)

	# Arquebus fire consumes powder
	var arcabucero: Arcabucero = null
	for node in get_tree().get_nodes_in_group("faction_spain"):
		if node is Arcabucero:
			arcabucero = node
			break
	var powder_before := ResourceManager.get_amount("spain", "powder")
	arcabucero.global_position = dummy.global_position + Vector2(150, 0)
	arcabucero.command_attack(dummy)
	var dummy_before_shot := dummy.health
	await _wait(3.0)
	arcabucero.stop()
	_check(ResourceManager.get_amount("spain", "powder") < powder_before,
		"arquebus fire consumed powder (%d -> %d)" % [powder_before, ResourceManager.get_amount("spain", "powder")])
	_check(dummy.health < dummy_before_shot, "musket ball hit the dummy")

	# Low powder triggers DESPERATE + warning
	var powder_warning := [false]
	EventBus.powder_critically_low.connect(func() -> void: powder_warning[0] = true)
	ResourceManager.spend("spain", {"powder": ResourceManager.get_amount("spain", "powder") - 10})
	await _wait(2.5)
	_check(SpanishAI.state == SpanishAI.State.DESPERATE, "low powder -> DESPERATE")
	_check(powder_warning[0], "powder_critically_low emitted")

	# Shield the Kuta from the ongoing AI assault so later checks control
	# exactly when it falls.
	kuta.max_health = 999999.0
	kuta.health = 999999.0

	# --- Milestone 6: tide cycle ---
	_check(TideManager.phase == TideManager.Phase.HIGH, "tide starts HIGH")
	var beached := [false]
	var freed := [false]
	EventBus.galleons_beached.connect(func() -> void: beached[0] = true)
	EventBus.galleons_freed.connect(func() -> void: freed[0] = true)

	TideManager.force_phase(TideManager.Phase.LOW)
	_check(beached[0], "galleons_beached emitted at low tide")
	_check(galleon.current_speed() == 0.0, "galleon beached (speed 0)")
	_check(galley.current_speed() > galley.data.speed,
		"Karakoa rides the low tide (%.0f > %.0f)" % [galley.current_speed(), galley.data.speed])
	var shallows_region := get_tree().get_first_node_in_group("tide_shallows_region") as NavigationRegion2D
	_check(shallows_region.navigation_layers == 3, "shallows open to land units at low tide")

	# A land path can now cross onto the shallows.
	await _wait(0.4)
	var nav_map: RID = warrior.nav_agent.get_navigation_map()
	var shallow_point := Vector2(-416, 256)  # shallows cell west of the beach
	var low_path := NavigationServer2D.map_get_path(
		nav_map, warrior.global_position, shallow_point, true, 1)
	_check(low_path.size() > 0 and low_path[low_path.size() - 1].distance_to(shallow_point) < 24.0,
		"land path reaches the shallows at low tide")

	# Warning fires 60 s before the turn.
	TideManager._time_left = 60.2
	await _wait(0.5)
	_check(TideManager._warned, "tide warning fired 60 s before the shift")

	TideManager.force_phase(TideManager.Phase.HIGH)
	_check(freed[0], "galleons_freed emitted")
	_check(galleon.current_speed() > 0.0, "galleon refloated at high tide")
	_check(shallows_region.navigation_layers == 2, "shallows naval-only again")
	await _wait(0.4)
	var high_path := NavigationServer2D.map_get_path(
		nav_map, warrior.global_position, shallow_point, true, 1)
	_check(high_path.is_empty() or high_path[high_path.size() - 1].distance_to(shallow_point) > 24.0,
		"shallows unreachable for land units at high tide")

	# --- Milestone 1: economy still ticking ---
	_check(ResourceManager.get_amount("mactan", "rice") > 200, "rice income ticked")

	# --- Milestone 8: fog of war & minimap ---
	var fog := get_tree().current_scene.get_node("Fog") as FogOfWar
	_check(fog != null, "fog overlay present")
	var scout := UnitSpawner.spawn(SOLDADO, Vector2(800, 0), "spain", true)
	await _wait(0.5)
	_check(not scout.visible, "enemy hidden in unexplored fog")
	_check(not fog.is_world_visible(Vector2(800, 0)), "far jungle not visible")
	_check(fog.is_world_visible(kuta.global_position), "base area visible")
	_check(dummy.visible, "enemy near base is visible")

	EventBus.ritual_reveal.emit(1.2)
	await _wait(0.4)
	_check(scout.visible, "Ritwal reveal exposes hidden enemies")
	await _wait(1.6)
	_check(not scout.visible, "reveal expires, fog returns")
	# The scout slowly wanders toward the Kuta for the rest of the run and
	# would stumble into the M13/M14 skirmish arenas — retire it.
	scout.take_damage(999999.0, null, true)

	var minimap := get_tree().current_scene.get_node("HUD/Minimap")
	_check(minimap != null, "minimap present")
	EventBus.minimap_ping.emit(Vector2.ZERO)
	_check(minimap._pings.size() == 1, "minimap ping registered")
	var camera := get_viewport().get_camera_2d()
	minimap._pan_camera(Vector2(0.9, 0.5))
	_check(camera.position.x > 800.0,
		"minimap click pans camera (x = %.0f)" % camera.position.x)
	_check(minimap._collect_utang_lines().size() >= 6,
		"Utang overlay lines present (%d)" % minimap._collect_utang_lines().size())

	# --- Milestone 9: training UI & building selection ---
	var shipyard := buildings.get_node("Shipyard") as Building
	var training_panel := get_tree().current_scene.get_node("HUD/TrainingPanel") as PanelContainer
	SelectionManager.select_building(shipyard)
	_check(SelectionManager.selected_building == shipyard, "building selectable")
	await _wait(0.1)
	_check(training_panel.visible, "training panel appears for selected building")

	var rice_before_queue := ResourceManager.get_amount("mactan", "rice")
	var copper_before_queue := ResourceManager.get_amount("mactan", "copper")
	_check(shipyard.queue_unit(BALANGAY), "queued Balangay at Shipyard")
	_check(shipyard.cancel_queued(), "cancelled queued unit")
	_check(ResourceManager.get_amount("mactan", "rice") == rice_before_queue - 30
		and ResourceManager.get_amount("mactan", "copper") == copper_before_queue - 8,
		"cancel refunded 50%% (net -30 rice, -8 copper)")
	SelectionManager.clear_selection()
	_check(not training_panel.visible, "training panel hides on deselect")

	# --- Milestone 9: tech tree ---
	ResourceManager.add("mactan", {"rice": 2000, "copper": 1000, "honor": 100})
	var tech_panel := get_tree().current_scene.get_node("HUD/TechPanel")
	_check(tech_panel._rows.size() == 11, "tech panel lists 11 techs")
	_check(TechTree.current_age("mactan") == 1, "starts in Age I")
	_check(not TechTree.can_research("mactan", "kris_forging"), "Age II tech locked in Age I")

	var rice_before_tech := ResourceManager.get_amount("mactan", "rice")
	_check(TechTree.research("mactan", "poison_arrows"), "researched Poison Arrows")
	_check(ResourceManager.get_amount("mactan", "rice") == rice_before_tech - 60, "tech cost spent")
	_check(TechTree.research("mactan", "karakoa_rigging"), "researched Karakoa Rigging")
	_check(TechTree.current_age("mactan") == 2, "2 Age I techs unlock Age II")
	_check(is_equal_approx(galley.current_speed(), galley.data.speed * 1.15),
		"Karakoa Rigging: naval speed x1.15 (%.0f)" % galley.current_speed())

	# Poison Arrows: next arrow applies 3 dps instead of 2.
	# (Archer was parked in the north clearing — bring it into range.)
	var archer_park := archer.global_position
	archer.global_position = dummy.global_position + Vector2(150, 0)
	archer.command_attack(dummy)
	await _wait(2.5)
	archer.stop()
	archer.global_position = archer_park
	_check(is_equal_approx(dummy.poison_dps, 3.0),
		"Poison Arrows: venom at %.1f dps" % dummy.poison_dps)

	var damage_before_kris := warrior.current_damage()
	_check(TechTree.research("mactan", "kris_forging"), "researched Kris Forging")
	_check(is_equal_approx(warrior.current_damage(), damage_before_kris * 1.15),
		"Kris Forging: melee damage x1.15")
	_check(TechTree.research("mactan", "babaylan_network"), "researched Babaylan Network")
	_check(TechTree.current_age("mactan") == 3, "2 Age II techs unlock Age III")

	var kuta_armor := kuta.armor
	_check(TechTree.research("mactan", "kuta_reinforcement"), "researched Kuta Reinforcement")
	_check(kuta.armor == kuta_armor + 2.0, "Kuta Reinforcement: +2 armor")
	_check(TechTree.research("mactan", "monsoon_timing"), "researched Monsoon Timing")
	_check(VictoryManager.monsoon_day == 50, "Monsoon Timing: monsoon at day 50")

	var mactan_before_fleet := get_tree().get_nodes_in_group("faction_mactan").size()
	_check(TechTree.research("mactan", "war_fleet_assembly"), "researched War Fleet Assembly")
	_check(get_tree().get_nodes_in_group("faction_mactan").size() == mactan_before_fleet + 3,
		"war fleet mustered (+3 ships)")

	var silyo := villages[5] as DatuVillage
	var silyo_tokens := DiplomacyManager.get_tokens(silyo.datu_name, "mactan")
	_check(TechTree.research("mactan", "great_alliance_pact"), "researched Great Alliance Pact")
	_check(DiplomacyManager.get_tokens(silyo.datu_name, "mactan") == silyo_tokens + 1,
		"pact placed a token on every datu")

	# --- Milestone 10: audio ---
	_check(AudioManager._calm.playing and AudioManager._battle.playing,
		"both music layers running")
	# Deterministic battle proximity: a Spaniard within earshot (<=400 px)
	# of the parked army but outside its aggro radius (>260 px).
	var noise_maker := UnitSpawner.spawn(SOLDADO, Vector2(526, -480), "spain", true)
	await _wait(0.6)  # let a battle-detection tick run
	_check(AudioManager.battle_mode, "battle music state triggered by nearby combat")
	await _wait(2.2)
	_check(AudioManager._battle.volume_db > AudioManager._calm.volume_db,
		"crossfaded to battle layer")
	noise_maker.take_damage(999999.0, null, true)
	EventBus.tide_changed.emit("LOW")
	_check(AudioManager.last_sfx == "tide", "tide shift audio cue")
	SelectionManager.select_units([lapu])
	_check(AudioManager.last_sfx == "voice_lapu", "Lapu-Lapu voice line on select")
	AudioManager._hit_cooldown = 0.0
	warrior.take_damage(1.0)
	_check(AudioManager.last_sfx == "hit", "attack hit sound")
	SelectionManager.clear_selection()

	# --- Milestone 11: polish ---
	# Building footprints carved from the land navmesh: a path across the
	# Kuta detours around it.
	var kuta_detour := NavigationServer2D.map_get_path(
		nav_map, Vector2(-288, -128), Vector2(-32, -128), true, 1)
	var min_distance := INF
	for point in kuta_detour:
		min_distance = minf(min_distance, point.distance_to(Vector2(-160, -128)))
	_check(kuta_detour.size() > 0 and min_distance > 40.0,
		"path detours around Kuta footprint (closest %.0f px)" % min_distance)

	# Particle effects spawn and self-clean.
	var burst := Effects.death_burst(Vector2.ZERO)
	_check(burst != null and burst.emitting, "particle burst spawns")

	# Portraits + selection info card.
	_check(ResourceLoader.exists("res://assets/gen/portrait_mandirigma.png")
		and ResourceLoader.exists("res://assets/gen/portrait_magellan.png"),
		"unit portraits generated")
	var info := get_tree().current_scene.get_node("HUD/SelectionInfo") as PanelContainer
	SelectionManager.select_units([warrior])
	_check(info.visible, "selection info card shows for a unit")
	SelectionManager.clear_selection()
	_check(not info.visible, "selection info card hides on deselect")

	# Historical codex unlocked by this run's events.
	var codex := get_tree().current_scene.get_node("HUD/CodexPanel")
	_check(codex.unlocked.size() >= 6,
		"codex entries unlocked by events (%d)" % codex.unlocked.size())
	_check("battle_of_mactan" in codex.unlocked, "assault unlocked the Battle of Mactan entry")
	_check("tide" in codex.unlocked, "low tide unlocked the tide entry")

	# --- Milestone 12: campaign shell ---
	_check(get_tree().current_scene.name == "MainMap",
		"main menu redirected to battle map for tests")
	for scene_path: String in [
		"res://scenes/ui/main_menu.tscn",
		"res://scenes/ui/mission_briefing.tscn",
		"res://scenes/ui/settings_menu.tscn",
		"res://scenes/ui/historical_codex.tscn",
	]:
		var packed := load(scene_path) as PackedScene
		_check(packed != null and packed.can_instantiate(), "scene loads: " + scene_path)
	_check(SceneFlow._rect != null, "scene fader ready")
	_check(MapData.build_preview_texture() != null, "briefing map preview builds")
	_check(MapData.terrain_color("land") != Color.BLACK
		and MapData.terrain_color("land") != MapData.terrain_color("open_water"),
		"terrain palette sampled from atlas art")

	var previous_music := GameSettings.music_volume
	GameSettings.set_music_volume(0.5)
	var config := ConfigFile.new()
	_check(config.load("user://settings.cfg") == OK
		and is_equal_approx(config.get_value("audio", "music_volume", -1.0), 0.5),
		"settings persist via ConfigFile")
	GameSettings.set_music_volume(previous_music)
	_check(GameSettings.codex_unlocked.size() >= 6,
		"codex unlocks persisted (%d)" % GameSettings.codex_unlocked.size())

	# --- Milestone 13: combat QoL ---
	# Micro-skirmishes need deterministic states: stop the Spanish AI from
	# re-tasking idle test units mid-check. Re-enabled after M14.
	SpanishAI.set_process(false)

	# Auto-acquire: an idle unit engages a hostile that appears in range.
	# (Staged far from the parked army — chasing toward it would trigger a
	# legitimate 3:1 morale rout and clear the intruder's target.)
	var sentry := UnitSpawner.spawn(MANDIRIGMA, Vector2(600, -200), "mactan", true)
	var intruder := UnitSpawner.spawn(SOLDADO, Vector2(730, -200), "spain", true)
	await _wait(0.9)  # fog update + aggro scan
	_check(sentry.state == Unit.State.ATTACKING and sentry.attack_target == intruder,
		"idle unit auto-acquires nearby enemy")
	if intruder.state == Unit.State.IDLE:
		intruder._aggro_scan()  # don't race the randomized scan stagger
	_check(intruder.attack_target == sentry, "enemy retaliates in kind")
	intruder.take_damage(999999.0, null, true)
	await _wait(0.2)

	# Passive units are not auto-acquired (friars must be hunted deliberately).
	var monk := UnitSpawner.spawn(FRAILE, Vector2(600, -120), "spain", true)
	await _wait(0.9)
	_check(sentry.state == Unit.State.IDLE, "passive friar is not auto-acquired")
	_check(monk.attack_target == null, "passive friar never attacks")
	monk.take_damage(999999.0, null, true)

	# Retaliation against an attacker beyond aggro range.
	var sniper := UnitSpawner.spawn(SOLDADO, Vector2(960, -200), "spain", true)
	sentry.take_damage(2.0, sniper)
	_check(sentry.attack_target == sniper, "damaged idle unit retaliates against attacker")
	sniper.take_damage(999999.0, null, true)
	await _wait(0.2)

	# Attack-move: engage en route, then resume the sweep.
	var blocker := UnitSpawner.spawn(SOLDADO, Vector2(500, -200), "spain", true)
	blocker.health = 10.0
	sentry.stop()
	sentry.global_position = Vector2(380, -200)
	# Distant destination so the sweep is still in progress at check time.
	sentry.command_attack_move(Vector2(1000, -200))
	await _wait(1.4)
	_check(sentry.attack_target == blocker or not is_instance_valid(blocker),
		"attack-move engages enemies on the way")
	await _wait(2.2)
	_check(not is_instance_valid(blocker) or blocker.is_dead(), "attack-move kill confirmed")
	_check(sentry._attack_move_dest != Vector2.INF and sentry.state == Unit.State.MOVING,
		"attack-move resumes toward its destination")
	sentry.stop()

	# Control groups.
	SelectionManager.select_units([sentry])
	SelectionManager.assign_control_group(3)
	SelectionManager.clear_selection()
	SelectionManager.recall_control_group(3)
	_check(SelectionManager.selected_units.size() == 1
		and SelectionManager.selected_units[0] == sentry, "control group assign/recall")

	# Select-all-military + idle cycling.
	SelectionManager.select_all_military()
	_check(SelectionManager.selected_units.size() >= 10,
		"Ctrl+A selects the army (%d units)" % SelectionManager.selected_units.size())
	SelectionManager.clear_selection()
	SelectionManager.cycle_idle_unit()
	_check(SelectionManager.selected_units.size() == 1
		and SelectionManager.selected_units[0].state == Unit.State.IDLE,
		"Tab cycles to an idle unit")
	SelectionManager.clear_selection()

	# Rally point: trained unit marches from the gate to the flag.
	var shrine_building := buildings.get_node("Shrine") as Building
	shrine_building.set_rally_point(Vector2(320, -220))
	_check(shrine_building.rally_point == Vector2(320, -220), "rally point set on building")
	var rally_spawns: Array = []
	var rally_watcher := func(unit: Node) -> void: rally_spawns.append(unit)
	EventBus.unit_spawned.connect(rally_watcher)
	_check(shrine_building.queue_unit(BABAYLAN), "queued unit for rally test")
	shrine_building.queue[0]["remaining"] = 0.05
	await _wait(0.3)
	EventBus.unit_spawned.disconnect(rally_watcher)
	_check(rally_spawns.size() == 1 and (rally_spawns[0] as Unit).state == Unit.State.MOVING,
		"trained unit heads to the rally point")

	# Health bars always-on setting.
	GameSettings.set_health_bars_always(true)
	_check(GameSettings.health_bars_always, "health bars always-on toggle")
	GameSettings.set_health_bars_always(false)
	# The sentry parked near the M14 morale arena would skew ally counts.
	sentry.take_damage(999999.0, null, true)

	# --- Milestone 14: difficulty, morale, save/load, stats ---
	GameSettings.set_difficulty("hard")
	_check(int(GameSettings.difficulty_value("start_powder")) == 130
		and is_equal_approx(float(GameSettings.difficulty_value("wave_interval")), 40.0),
		"difficulty table (hard) plumbed")
	GameSettings.set_difficulty("normal")

	# Morale: outnumbered 3:1 in combat -> rout, uncontrollable, recovers.
	var brave := UnitSpawner.spawn(MANDIRIGMA, Vector2(500, -80), "mactan", true)
	brave.health = 400.0
	var mob: Array = []
	for i in 4:
		mob.append(UnitSpawner.spawn(SOLDADO, Vector2(460 + 30 * i, -40), "spain", true))
	await _wait(0.5)  # fog reveal
	brave.command_attack(mob[0])
	await _wait(1.6)  # morale tick
	if brave.state == Unit.State.ATTACKING:
		brave._morale_scan()  # don't race the randomized scan stagger
	_check(brave.state == Unit.State.ROUTING, "outnumbered 3:1 -> unit routs")
	brave.command_move(Vector2(700, -300))
	_check(brave.state == Unit.State.ROUTING, "routing units ignore commands")
	for soldier in mob:
		soldier.take_damage(999999.0, null, true)
	await _wait(5.8)
	_check(brave.state != Unit.State.ROUTING, "rout ends, unit recovers")

	# Morale: a friendly hero falling nearby breaks the line.
	var fallen_hero := UnitSpawner.spawn(SULAYMAN, brave.global_position + Vector2(60, 0), "mactan", true)
	await _wait(0.3)
	fallen_hero.take_damage(999999.0, null, true)
	_check(brave.state == Unit.State.ROUTING, "hero death routs nearby allies")

	# Mid-game save: file written, world snapshot inside.
	_check(SaveGame.save() and SaveGame.has_save(), "mid-game save written")
	var save_file := FileAccess.open("user://save.json", FileAccess.READ)
	var save_data: Dictionary = JSON.parse_string(save_file.get_as_text())
	save_file.close()
	_check(save_data.get("units", []).size() > 10
		and int(save_data["victory"]["current_day"]) == VictoryManager.current_day,
		"save contains world snapshot (%d units)" % save_data.get("units", []).size())
	# Manager state survives the save format round-trip.
	var diplo_state := DiplomacyManager.save_state()
	DiplomacyManager.humabon_state = DiplomacyManager.HumabonState.SPAIN_ALLY
	DiplomacyManager.load_state(diplo_state)
	_check(DiplomacyManager.humabon_state == DiplomacyManager.HumabonState.ALLIED_MACTAN,
		"manager state round-trips through save format")

	# Stats tracking.
	var kills_before: int = GameStats.stats["units_killed"]
	var victim := UnitSpawner.spawn(SOLDADO, Vector2(900, -300), "spain", true)
	victim.take_damage(999999.0, null, true)
	_check(GameStats.stats["units_killed"] == kills_before + 1, "kill counted in stats")
	_check(GameStats.stats["villages_allied"] >= 1 and GameStats.stats["units_lost"] >= 1,
		"session stats accumulated")
	_check(GameStats.summary().contains("Warriors lost"), "stats summary renders")
	brave.take_damage(999999.0, null, true)  # cleanup
	SpanishAI.set_process(true)

	# --- Milestone 7: victory & loss conditions ---
	var results: Array = []
	EventBus.game_over.connect(func(w: String, c: String) -> void: results.append([w, c]))
	var screen := get_tree().current_scene.get_node("HUD/GameOverScreen") as ColorRect

	# Powder starvation clock accumulates at 0 powder, resets when resupplied.
	var powder_left := ResourceManager.get_amount("spain", "powder")
	if powder_left > 0:
		ResourceManager.spend("spain", {"powder": powder_left})
	await _wait(2.0)
	_check(VictoryManager._powder_zero_time > 1.0,
		"powder starvation clock ticking (%.1f s)" % VictoryManager._powder_zero_time)
	ResourceManager.add("spain", {"powder": 50})
	await _wait(0.3)
	_check(VictoryManager._powder_zero_time == 0.0, "starvation clock resets on resupply")

	# Full conversion: all 6 villages Spanish before day 30 -> Spain wins.
	for node in villages:
		(node as DatuVillage).ally("spain")
	_check(results.size() == 1 and results[0] == ["spain", "full_conversion"],
		"full conversion -> Spain victory")
	_check(screen.visible and screen.get_node("Center/Box/TitleLabel").text == "DEFEAT",
		"defeat screen shown")
	_check(screen.get_node("Center/Box/StatsLabel").text.contains("Warriors lost"),
		"post-game stats shown")
	_check(AudioManager.last_sfx == "defeat", "defeat sting played")
	_check(get_tree().paused, "game paused on game over")
	_reset_game_over(screen)

	# Great Alliance: all 6 datus + Humabon (allied since M4) -> Mactan wins.
	for node in villages:
		(node as DatuVillage).ally("mactan")
	_check(results.size() == 2 and results[1] == ["mactan", "great_alliance"],
		"Great Alliance -> Mactan victory")
	_reset_game_over(screen)

	# Monsoon: day 60 with the Kuta standing -> Mactan wins.
	EventBus.day_advanced.emit(60)
	_check(results.size() == 3 and results[2] == ["mactan", "monsoon"],
		"monsoon survival -> Mactan victory")
	_reset_game_over(screen)

	# Kill Magellan -> Mactan wins.
	magellan.take_damage(999999.0, null, true)
	_check(results.size() == 4 and results[3] == ["mactan", "magellan_killed"],
		"Magellan killed -> Mactan victory")
	_check(screen.get_node("Center/Box/TitleLabel").text == "VICTORY", "victory screen shown")
	_check(AudioManager.last_sfx == "victory", "victory fanfare played")
	_reset_game_over(screen)

	# Lapu-Lapu falls -> Spain wins.
	lapu.take_damage(999999.0, null, true)
	_check(results.size() == 5 and results[4] == ["spain", "lapu_lapu_killed"],
		"Lapu-Lapu killed -> Spain victory")
	_reset_game_over(screen)

	# Kuta razed -> Spain wins.
	kuta.sunugin()
	_check(results.size() == 6 and results[5] == ["spain", "kuta_razed"],
		"Kuta razed -> Spain victory")

	_finish()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Re-arm the game after a game_over so the next condition can fire.
func _reset_game_over(screen: ColorRect) -> void:
	get_tree().paused = false
	VictoryManager.game_active = true
	screen.visible = false


func _check(condition: bool, label: String) -> void:
	print("  [%s] %s" % ["PASS" if condition else "FAIL", label])
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE TEST: ALL PASS")
	else:
		print("SMOKE TEST: %d FAILURE(S)" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)
