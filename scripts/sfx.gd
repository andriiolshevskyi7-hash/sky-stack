extends Node
## Autoload "Sfx": every sound is synthesized at startup into AudioStreamWAV
## buffers (no audio files). play(name) uses a small player pool.

const RATE := 22050
const MIN_GAP := {"shot": 0.05, "enemy_shot": 0.06, "hit": 0.04, "explode": 0.05, "flak": 0.08}

var streams := {}
var players: Array[AudioStreamPlayer] = []
var engine: AudioStreamPlayer
var _last := {}
var _rr := 0
var _rng := RandomNumberGenerator.new()
var muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1234
	var t0 := Time.get_ticks_msec()
	streams["shot"] = _wav(_shot())
	streams["enemy_shot"] = _wav(_enemy_shot())
	streams["explode"] = _wav(_explosion(0.7, 0.9))
	streams["big_explode"] = _wav(_explosion(1.5, 1.0))
	streams["hit"] = _wav(_hit())
	streams["hurt"] = _wav(_hurt())
	streams["alarm"] = _wav(_alarm())
	streams["clear"] = _wav(_arp([523.0, 659.0, 784.0, 1046.0]))
	streams["gameover"] = _wav(_arp([523.0, 415.0, 349.0, 262.0], 0.16))
	streams["boost"] = _wav(_boost())
	streams["flak"] = _wav(_flak())
	streams["bomb"] = _wav(_bomb())
	streams["ui"] = _wav(_blip())
	streams["engine"] = _wav(_engine(), true)
	streams["beep"] = _wav(_beep(1400.0, 0.05))
	streams["tone"] = _wav(_beep(2000.0, 0.12))
	streams["warn"] = _wav(_beep(900.0, 0.09))
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	engine = AudioStreamPlayer.new()
	engine.stream = streams["engine"]
	engine.volume_db = -60.0
	add_child(engine)
	print("Sfx: %d sounds synthesized in %d ms" % [streams.size(), Time.get_ticks_msec() - t0])


func play(sound: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if muted or not streams.has(sound):
		return
	var now := Time.get_ticks_msec() * 0.001
	var gap: float = MIN_GAP.get(sound, 0.0)
	if gap > 0.0 and now - float(_last.get(sound, -10.0)) < gap:
		return
	_last[sound] = now
	var p: AudioStreamPlayer = null
	for q in players:
		if not q.playing:
			p = q
			break
	if p == null:
		p = players[_rr]
		_rr = (_rr + 1) % players.size()
	p.stream = streams[sound]
	p.volume_db = vol_db
	p.pitch_scale = pitch * _rng.randf_range(0.96, 1.04)
	p.play()


## Continuous engine hum, pitch follows speed. vol 0..1
func set_engine(on: bool, speed_ratio: float) -> void:
	if on and not engine.playing:
		engine.play()
	elif not on and engine.playing:
		engine.stop()
	engine.pitch_scale = 0.8 + speed_ratio * 0.6
	engine.volume_db = -16.0 + speed_ratio * 5.0


# ------------------------------------------------------------------ synthesis

func _wav(s: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w


func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


func _sq(ph: float) -> float:
	return 1.0 if fmod(ph, 1.0) < 0.5 else -1.0


func _shot() -> PackedFloat32Array:
	var b := _buf(0.08)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 1100.0 * exp(-t * 28.0) + 180.0
		ph += f / RATE
		var env := exp(-t * 45.0)
		b[i] = (_sq(ph) * 0.35 + _rng.randf_range(-1, 1) * 0.25) * env
	return b


func _enemy_shot() -> PackedFloat32Array:
	var b := _buf(0.1)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += (520.0 * exp(-t * 18.0) + 140.0) / RATE
		b[i] = (fmod(ph, 1.0) * 2.0 - 1.0) * 0.3 * exp(-t * 30.0)
	return b


func _explosion(sec: float, vol: float) -> PackedFloat32Array:
	var b := _buf(sec)
	var lp := 0.0
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var cutoff := 0.35 * exp(-t * 3.0) + 0.02
		lp += (_rng.randf_range(-1, 1) - lp) * cutoff
		ph += (70.0 * exp(-t * 4.0) + 30.0) / RATE
		var env := exp(-t * (4.5 / sec))
		b[i] = (lp * 1.6 + sin(ph * TAU) * 0.6 * exp(-t * 6.0)) * env * vol
	return b


func _hit() -> PackedFloat32Array:
	var b := _buf(0.07)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (_rng.randf_range(-1, 1) * 0.5 + _sq(t * 1800.0) * 0.2) * exp(-t * 60.0)
	return b


func _hurt() -> PackedFloat32Array:
	var b := _buf(0.3)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += (140.0 - t * 200.0) / RATE
		b[i] = (_sq(ph) * 0.35 + _rng.randf_range(-1, 1) * 0.2) * exp(-t * 9.0)
	return b


func _alarm() -> PackedFloat32Array:
	var b := _buf(1.0)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 660.0 if int(t * 8.0) % 2 == 0 else 880.0
		ph += f / RATE
		b[i] = _sq(ph) * 0.18 * minf(1.0, (1.0 - t) * 4.0)
	return b


func _arp(notes: Array, step: float = 0.1) -> PackedFloat32Array:
	var b := _buf(step * notes.size() + 0.15)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var n := mini(int(t / step), notes.size() - 1)
		ph += float(notes[n]) / RATE
		var lt := t - n * step
		b[i] = (_sq(ph) * 0.15 + sin(ph * TAU) * 0.1) * exp(-lt * 6.0)
	return b


func _boost() -> PackedFloat32Array:
	var b := _buf(0.5)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1, 1) - lp) * (0.05 + t * 0.4)
		b[i] = lp * 1.4 * sin(PI * t / 0.5)
	return b


func _flak() -> PackedFloat32Array:
	var b := _buf(0.25)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1, 1) - lp) * 0.15
		b[i] = (lp * 1.5 + sin(t * TAU * 90.0) * 0.4) * exp(-t * 16.0)
	return b


func _bomb() -> PackedFloat32Array:
	var b := _buf(0.6)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		ph += (1300.0 - t * 1400.0) / RATE
		b[i] = sin(ph * TAU) * 0.15 * minf(1.0, t * 10.0)
	return b


func _blip() -> PackedFloat32Array:
	var b := _buf(0.05)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = _sq(t * 1000.0) * 0.15 * exp(-t * 50.0)
	return b


func _beep(f: float, sec: float) -> PackedFloat32Array:
	var b := _buf(sec)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = _sq(t * f) * 0.14 * minf(1.0, (sec - t) * 40.0)
	return b


func _engine() -> PackedFloat32Array:
	var b := _buf(1.0)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1, 1) - lp) * 0.08
		var saw := fmod(t * 55.0, 1.0) * 2.0 - 1.0
		b[i] = lp * 0.5 + saw * 0.12
	return b
