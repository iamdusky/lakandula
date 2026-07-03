extends SceneTree
## Placeholder audio synthesizer. Run with:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/gen_audio.gd
## Writes 16-bit mono WAVs to assets/gen/audio/. Deterministic output.
## Calm music = kulintang-style pentatonic gongs over an ocean bed;
## battle music = drums + faster gong riff. voice_lapu is a synthesized
## war-cry placeholder until real Cebuano voice lines are recorded.

const RATE := 22050


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/gen/audio")
	_save("music_calm", _gen_calm())
	_save("music_battle", _gen_battle())
	_save("sfx_select", _gen_select())
	_save("sfx_move", _gen_move())
	_save("sfx_hit", _gen_hit())
	_save("sfx_unit_death", _gen_unit_death())
	_save("sfx_building_destroyed", _gen_building_destroyed())
	_save("sfx_tide", _gen_tide())
	_save("sfx_victory", _gen_victory())
	_save("sfx_defeat", _gen_defeat())
	_save("voice_lapu", _gen_war_cry())
	print("gen_audio: done")
	quit()


func _save(name: String, samples: PackedFloat32Array) -> void:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	wav.data = bytes
	wav.save_to_wav("res://assets/gen/audio/%s.wav" % name)


# --- Music ---

func _gen_calm() -> PackedFloat32Array:
	var buf := _buffer(12.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1521
	# Ocean bed: low-passed noise with a slow swell.
	var prev := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		prev = lerpf(prev, rng.randf_range(-1.0, 1.0), 0.06)
		buf[i] += prev * (0.5 + 0.45 * sin(TAU * 0.09 * t)) * 0.09
	# Kulintang gongs, pentatonic.
	var scale := [262.0, 294.0, 330.0, 392.0, 440.0]
	for step in 16:
		if rng.randf() < 0.85:
			_add_gong(buf, step * 0.75, scale[rng.randi_range(0, 4)], 1.4, 0.2)
	return buf


func _gen_battle() -> PackedFloat32Array:
	var buf := _buffer(8.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 27
	for i in buf.size():
		buf[i] += sin(TAU * 110.0 * float(i) / RATE) * 0.04  # war drone
	for beat in 16:
		var t0 := beat * 0.5
		_add_tone(buf, t0, 70.0, 45.0, 0.22, 0.5)  # kick
		_add_noise(buf, t0, 0.03, 0.25, rng)
		if beat % 2 == 1:
			_add_noise(buf, t0 + 0.25, 0.09, 0.18, rng)  # offbeat rattle
	var scale := [523.0, 587.0, 659.0, 784.0, 880.0]
	for step in 32:
		if rng.randf() < 0.7:
			_add_gong(buf, step * 0.25, scale[rng.randi_range(0, 4)], 0.5, 0.13)
	return buf


# --- SFX ---

func _gen_select() -> PackedFloat32Array:
	var buf := _buffer(0.12)
	_add_tone(buf, 0.0, 880.0, 880.0, 0.1, 0.3, 0.005)
	return buf


func _gen_move() -> PackedFloat32Array:
	var buf := _buffer(0.2)
	_add_tone(buf, 0.0, 440.0, 440.0, 0.07, 0.3, 0.005)
	_add_tone(buf, 0.08, 554.0, 554.0, 0.09, 0.3, 0.005)
	return buf


func _gen_hit() -> PackedFloat32Array:
	var buf := _buffer(0.15)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_add_noise(buf, 0.0, 0.04, 0.35, rng)
	_add_tone(buf, 0.0, 160.0, 90.0, 0.12, 0.4)
	return buf


func _gen_unit_death() -> PackedFloat32Array:
	var buf := _buffer(0.45)
	_add_tone(buf, 0.0, 420.0, 140.0, 0.4, 0.35)
	return buf


func _gen_building_destroyed() -> PackedFloat32Array:
	var buf := _buffer(1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	_add_noise(buf, 0.0, 0.9, 0.4, rng, 0.85)
	_add_tone(buf, 0.0, 55.0, 35.0, 0.9, 0.4)
	return buf


func _gen_tide() -> PackedFloat32Array:
	var buf := _buffer(2.0)
	_add_tone(buf, 0.0, 240.0, 460.0, 1.8, 0.3, 0.4)
	return buf


func _gen_victory() -> PackedFloat32Array:
	var buf := _buffer(2.6)
	var notes := [392.0, 523.0, 659.0, 784.0]
	for i in notes.size():
		_add_gong(buf, i * 0.28, notes[i], 1.0, 0.32)
	for freq in notes:
		_add_gong(buf, 1.2, freq, 1.4, 0.22)
	return buf


func _gen_defeat() -> PackedFloat32Array:
	var buf := _buffer(2.4)
	var notes := [392.0, 330.0, 262.0]
	for i in notes.size():
		_add_gong(buf, i * 0.5, notes[i], 1.3, 0.3)
	return buf


func _gen_war_cry() -> PackedFloat32Array:
	var buf := _buffer(0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var phase := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		if t > 0.55:
			break
		var freq := 170.0 + 60.0 * sin(PI * t / 0.5)
		phase += TAU * freq / RATE
		var env := minf(t / 0.04, 1.0) * (1.0 if t < 0.35 else maxf(1.0 - (t - 0.35) / 0.2, 0.0))
		buf[i] += (sin(phase) + 0.4 * sin(phase * 2.0) + 0.2 * sin(phase * 3.0)) * env * 0.35
	_add_noise(buf, 0.0, 0.5, 0.06, rng, 0.7)
	return buf


# --- Synth primitives ---

func _buffer(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(seconds * RATE))
	return buf


func _add_gong(buf: PackedFloat32Array, start_s: float, freq: float, dur: float, vol: float) -> void:
	var start := int(start_s * RATE)
	var count := mini(int(dur * RATE), buf.size() - start)
	for i in count:
		var t := float(i) / RATE
		var env := exp(-4.0 * t / dur)
		buf[start + i] += (sin(TAU * freq * t)
			+ 0.35 * sin(TAU * freq * 2.76 * t) * exp(-8.0 * t / dur)) * env * vol


func _add_tone(buf: PackedFloat32Array, start_s: float, freq_from: float, freq_to: float,
		dur: float, vol: float, attack := 0.01) -> void:
	var start := int(start_s * RATE)
	var count := mini(int(dur * RATE), buf.size() - start)
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		phase += TAU * lerpf(freq_from, freq_to, t / dur) / RATE
		var env := minf(t / attack, 1.0) * (1.0 - t / dur)
		buf[start + i] += sin(phase) * env * vol


func _add_noise(buf: PackedFloat32Array, start_s: float, dur: float, vol: float,
		rng: RandomNumberGenerator, lowpass := 0.0) -> void:
	var start := int(start_s * RATE)
	var count := mini(int(dur * RATE), buf.size() - start)
	var prev := 0.0
	for i in count:
		var n := rng.randf_range(-1.0, 1.0)
		if lowpass > 0.0:
			prev = lerpf(n, prev, lowpass)
			n = prev
		buf[start + i] += n * (1.0 - float(i) / count) * vol
