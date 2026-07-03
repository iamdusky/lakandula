extends Node
## Adaptive audio: calm and battle music layers both loop continuously; the
## mix crossfades (2 s) when enemies come within BATTLE_RADIUS of Mactan
## units. SFX are event-driven via EventBus. Runs while paused so the
## victory/defeat sting plays over the game-over screen.
## last_sfx exists for tests (the headless audio driver is silent).

const AUDIO_DIR := "res://assets/gen/audio/"
const SFX_FILES := {
	"select": "sfx_select.wav",
	"move": "sfx_move.wav",
	"hit": "sfx_hit.wav",
	"unit_death": "sfx_unit_death.wav",
	"building_destroyed": "sfx_building_destroyed.wav",
	"tide": "sfx_tide.wav",
	"victory": "sfx_victory.wav",
	"defeat": "sfx_defeat.wav",
	"voice_lapu": "voice_lapu.wav",
}

const BATTLE_RADIUS := 400.0
const CHECK_INTERVAL := 0.5
const CROSSFADE := 2.0
const MUSIC_DB := -8.0
const SILENT_DB := -60.0
const HIT_SFX_COOLDOWN := 0.09
const VOICE_COOLDOWN := 3.0
const SFX_POOL_SIZE := 6

var battle_mode := false
var last_sfx := ""

var _calm: AudioStreamPlayer
var _battle: AudioStreamPlayer
var _sfx_streams := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index := 0
var _accumulator := 0.0
var _hit_cooldown := 0.0
var _voice_cooldown := 0.0
var _game_running := false
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_calm = _make_music_player("music_calm.wav", _music_db())
	_battle = _make_music_player("music_battle.wav", SILENT_DB)
	EventBus.settings_changed.connect(_on_settings_changed)
	for name in SFX_FILES:
		_sfx_streams[name] = load(AUDIO_DIR + SFX_FILES[name])
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_sfx_players.append(player)

	EventBus.game_started.connect(_on_game_started)
	EventBus.game_over.connect(_on_game_over)
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.command_issued.connect(_on_command_issued)
	EventBus.combat_hit.connect(_on_combat_hit)
	EventBus.unit_died.connect(func(_unit: Node) -> void: play_sfx("unit_death", -10.0))
	EventBus.building_destroyed.connect(func(_b: Node) -> void: play_sfx("building_destroyed", -6.0))
	EventBus.tide_changed.connect(func(_phase: String) -> void: play_sfx("tide", -8.0))


func _process(delta: float) -> void:
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	_voice_cooldown = maxf(0.0, _voice_cooldown - delta)
	_accumulator += delta
	if _accumulator >= CHECK_INTERVAL:
		_accumulator = 0.0
		_update_music_state()


func play_sfx(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _sfx_streams.has(name):
		return
	last_sfx = name
	var player := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_players.size()
	player.stream = _sfx_streams[name]
	player.volume_db = volume_db + GameSettings.sfx_offset_db()
	player.pitch_scale = pitch
	player.play()


# --- Music state ---

func _update_music_state() -> void:
	var battle := _game_running and _detect_battle()
	if battle == battle_mode:
		return
	battle_mode = battle
	if _music_tween != null:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(_calm, "volume_db", SILENT_DB if battle else _music_db(), CROSSFADE)
	_music_tween.tween_property(_battle, "volume_db", _music_db() if battle else SILENT_DB, CROSSFADE)


func _detect_battle() -> bool:
	var mactan_units := get_tree().get_nodes_in_group("faction_mactan")
	for node in get_tree().get_nodes_in_group("units"):
		var enemy := node as Unit
		if enemy == null or enemy.faction == "mactan" or enemy.state == Unit.State.DEAD:
			continue
		for ally_node in mactan_units:
			var ally := ally_node as Unit
			if ally != null and ally.state != Unit.State.DEAD \
					and enemy.global_position.distance_to(ally.global_position) <= BATTLE_RADIUS:
				return true
	return false


# --- Event handlers ---

func _on_game_started() -> void:
	_game_running = true
	battle_mode = false
	_calm.volume_db = _music_db()
	_battle.volume_db = SILENT_DB


func _music_db() -> float:
	return MUSIC_DB + GameSettings.music_offset_db()


func _on_settings_changed() -> void:
	if _music_tween == null or not _music_tween.is_running():
		if battle_mode:
			_battle.volume_db = _music_db()
		else:
			_calm.volume_db = _music_db()


func _on_game_over(winner: String, _condition: String) -> void:
	_game_running = false
	play_sfx("victory" if winner == "mactan" else "defeat", -4.0)


func _on_selection_changed(units: Array) -> void:
	if units.is_empty():
		return
	play_sfx("select", -12.0, randf_range(0.95, 1.05))
	if _voice_cooldown <= 0.0:
		for unit in units:
			if is_instance_valid(unit) and unit.data.display_name == "Lapu-Lapu":
				_voice_cooldown = VOICE_COOLDOWN
				play_sfx("voice_lapu", -6.0)
				break


func _on_command_issued(command: String, _target: Variant) -> void:
	play_sfx("move", -12.0, 1.0 if command == "move" else 0.85)


func _on_combat_hit(_target: Node) -> void:
	if _hit_cooldown > 0.0:
		return
	_hit_cooldown = HIT_SFX_COOLDOWN
	play_sfx("hit", -14.0, randf_range(0.9, 1.1))


func _make_music_player(file: String, volume_db: float) -> AudioStreamPlayer:
	var stream: AudioStreamWAV = load(AUDIO_DIR + file)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2  # frames (16-bit mono)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.play()
	return player
