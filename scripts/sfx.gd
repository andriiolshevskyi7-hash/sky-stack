extends Node
## Autoload "Sfx": every sound is synthesized at startup into AudioStreamWAV
## buffers (no audio files). play(name) uses a small player pool;
## play_at(name, pos) attenuates and delays by distance from the listener and
## swaps in a muffled far variant for distant blasts.
## Buses: "World" (outside sounds - low-passed and quieter in the cockpit)
## and "Cockpit" (instruments, warnings, the pilot - always dry).
## The longer engine / wind / breathing loops are rendered on a worker
## thread (SoundScape plays them once ready).

const RATE := 22050
const MIN_GAP := {"shot": 0.05, "enemy_shot": 0.06, "hit": 0.04, "explode": 0.05, "flak": 0.08}

var streams := {}
var players: Array[AudioStreamPlayer] = []
var engine: AudioStreamPlayer
var _last := {}
var _rr := 0
var _rng := RandomNumberGenerator.new()
var muted := false
## Listener position (the camera) for play_at().
var listener := Vector3.ZERO
var _delayed: Array = [] # [time, name, vol_db, pitch]
var _task := -1
var _pending := {}
var _mutex := Mutex.new()
var loops_ready := false
const DRY := ["beep", "tone", "warn", "alarm", "ui", "clear", "gameover", "grunt", "stall"]
## Sounds with a muffled far variant.
const FAR := {"explode": "explode_far", "big_explode": "explode_far", "flak": "explode_far"}


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
	streams["flare"] = _wav(_flare())
	_make_buses()
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "World"
		add_child(p)
		players.append(p)
	engine = AudioStreamPlayer.new()
	engine.stream = streams["engine"]
	engine.volume_db = -60.0
	add_child(engine)
	print("Sfx: %d sounds synthesized in %d ms" % [streams.size(), Time.get_ticks_msec() - t0])
	_task = WorkerThreadPool.add_task(_render_loops, false, "sfx loops")


func _make_buses() -> void:
	# engine + burner + wind + music together must never clip the output
	if AudioServer.get_bus_effect_count(0) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.5
		AudioServer.add_bus_effect(0, lim)
	for bn in ["World", "Cockpit"]:
		if AudioServer.get_bus_index(bn) >= 0:
			continue
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bn)
		AudioServer.set_bus_send(i, "Master")
		if bn == "World":
			var lp := AudioEffectLowPassFilter.new()
			lp.cutoff_hz = 20000.0
			AudioServer.add_bus_effect(i, lp)


## Cockpit view (0..1): outside sounds get muffled and a bit quieter.
func set_cockpit(k: float) -> void:
	var i := AudioServer.get_bus_index("World")
	if i < 0:
		return
	var lp := AudioServer.get_bus_effect(i, 0) as AudioEffectLowPassFilter
	if lp != null:
		lp.cutoff_hz = lerpf(20000.0, 1400.0, clampf(k, 0.0, 1.0))
	AudioServer.set_bus_volume_db(i, lerpf(0.0, -4.0, clampf(k, 0.0, 1.0)))


func _process(_d: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_mutex.lock()
		for k in _pending:
			var item: Array = _pending[k]
			streams[k] = _wav(item[0], item[1])
		_pending.clear()
		_mutex.unlock()
		loops_ready = true
	if not _delayed.is_empty():
		var now := Time.get_ticks_msec() * 0.001
		for i in range(_delayed.size() - 1, -1, -1):
			var e: Array = _delayed[i]
			if now >= float(e[0]):
				play(e[1], e[2], e[3])
				_delayed.remove_at(i)


## A sound at a world position: quieter with distance (and arriving a bit
## later); distant blasts use the muffled far variant.
func play_at(sound: String, pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	var d := pos.distance_to(listener)
	if d > 3200.0:
		return
	var snd := sound
	if d > 650.0 and FAR.has(sound) and streams.has(FAR[sound]):
		snd = FAR[sound]
	var v := vol_db - 20.0 * log(1.0 + d / 140.0) / log(10.0)
	if v < -42.0:
		return
	var delay := d / 1100.0 if d > 250.0 else 0.0
	if delay > 0.02:
		_delayed.append([Time.get_ticks_msec() * 0.001 + delay, snd, v, pitch * (0.9 if d > 650.0 else 1.0)])
	else:
		play(snd, v, pitch)


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
	p.bus = "Cockpit" if DRY.has(sound) else "World"
	p.volume_db = vol_db
	p.pitch_scale = pitch * _rng.randf_range(0.96, 1.04)
	p.play()


## Old single engine hum: now only a fallback until SoundScape's loops are
## rendered.
func set_engine(on: bool, speed_ratio: float) -> void:
	on = on and not loops_ready
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


## Flare salvo: a quick string of dull pops from the dispensers, then the
## hiss of the burning flares.
func _flare() -> PackedFloat32Array:
	var b := _buf(0.7)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var pop := 0.0
		for k in 4:
			var tk := t - k * 0.07
			if tk >= 0.0:
				pop += exp(-tk * 60.0) * sin(tk * TAU * (140.0 - k * 10.0))
		lp += (_rng.randf_range(-1, 1) - lp) * 0.45
		var hiss := lp * 0.35 * minf(1.0, t * 6.0) * exp(-t * 3.5)
		b[i] = pop * 0.9 + hiss
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


# ------------------------------------------------------------------ loops (thread)

## Make a noise loop seamless: crossfade its last `fade` samples into the start.
static func _loopify(b: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n := b.size() - fade
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = b[i]
	for i in fade:
		var k := float(i) / fade
		out[i] = b[n + i] * (1.0 - k) + b[i] * k
	return out


func _render_loops() -> void:
	var t0 := Time.get_ticks_msec()
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var res := {
		"eng_rumble": [_eng_rumble(r), true], "eng_whine": [_eng_whine(r), true], "burner": [_burner(r), true],
		"wind": [_wind(r), true], "breath": [_breath(r), true], "gun": [_gun(r), true], "seek": [_seek(), true],
		"lock": [_lock(), true], "stall": [_stall(), true], "gun_tail": [_gun_tail(r), false], "launch": [_launch(r), false],
		"explode_far": [_explode_far(r), false], "flyby": [_flyby(r), false], "grunt": [_grunt(r), false],
	}
	_mutex.lock()
	_pending = res
	_mutex.unlock()
	print("Sfx: %d flight sounds rendered in %d ms" % [res.size(), Time.get_ticks_msec() - t0])


## Low rumble of the engine core: filtered noise + two harmonics that loop.
func _eng_rumble(r: RandomNumberGenerator) -> PackedFloat32Array:
	var sec := 2.0
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE) + 2000)
	var lp := 0.0
	var lp2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (r.randf_range(-1, 1) - lp) * 0.04
		lp2 += (lp - lp2) * 0.2
		var hum := sin(t * TAU * 48.0) * 0.22 + sin(t * TAU * 96.0) * 0.12 + sin(t * TAU * 144.0) * 0.05
		b[i] = lp2 * 1.6 + hum * (0.8 + 0.2 * sin(t * TAU * 3.0))
	return _loopify(b, 2000)


## Turbine whine: a high tone with harmonics and a slight flutter.
func _eng_whine(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(RATE)
	for i in b.size():
		var t := float(i) / RATE
		var f := sin(t * TAU * 900.0) * 0.18 + sin(t * TAU * 1800.0) * 0.07 + sin(t * TAU * 2700.0) * 0.03
		b[i] = f * (0.85 + 0.15 * sin(t * TAU * 7.0)) + r.randf_range(-1, 1) * 0.02
	return b


## Afterburner: broad roaring noise with crackle.
func _burner(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(2.0 * RATE) + 2000)
	var lp := 0.0
	var lp2 := 0.0
	var crack := 0.0
	for i in b.size():
		lp += (r.randf_range(-1, 1) - lp) * 0.18
		lp2 += (lp - lp2) * 0.35
		if r.randf() < 0.0025:
			crack = r.randf_range(0.4, 0.9)
		crack *= 0.993
		b[i] = lp2 * 1.3 + r.randf_range(-1, 1) * crack * 0.4
	return _loopify(b, 2000)


## Wind: band-passed noise with a slow swell.
func _wind(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(2.0 * RATE) + 2000)
	var a := 0.0
	var c := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var n := r.randf_range(-1, 1)
		a += (n - a) * 0.3
		c += (n - c) * 0.03
		b[i] = (a - c) * 1.2 * (0.8 + 0.2 * sin(t * TAU * 0.5))
	return _loopify(b, 2000)


## Pilot breathing through the mask: inhale, pause, exhale (one breath per
## loop; pitch_scale sets the rate).
func _breath(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(3.0 * RATE))
	var a := 0.0
	var c := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var n := r.randf_range(-1, 1)
		var inhale := sin(clampf(t / 1.1, 0.0, 1.0) * PI) if t < 1.1 else 0.0
		var exhale := sin(clampf((t - 1.5) / 1.2, 0.0, 1.0) * PI) if t > 1.5 and t < 2.7 else 0.0
		a += (n - a) * (0.35 if inhale > 0.0 else 0.18)
		c += (n - c) * 0.04
		b[i] = (a - c) * (inhale * 0.5 + exhale * 0.6) + sin(t * TAU * 140.0) * exhale * 0.03
	return b


## Cannon: five rounds per loop (20 per second): thump + crack.
func _gun(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(0.25 * RATE))
	var per := b.size() / 5
	var lp := 0.0
	for i in b.size():
		var k := float(i % per) / RATE
		lp += (r.randf_range(-1, 1) - lp) * 0.5
		var att := minf(1.0, k * 1500.0) # 0.7 ms attack: each round starts at zero
		b[i] = (lp * 0.6 * exp(-k * 70.0) + sin(k * TAU * 85.0) * 0.5 * exp(-k * 45.0)) * 0.9 * att
	return b


func _gun_tail(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(0.45 * RATE))
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (r.randf_range(-1, 1) - lp) * 0.12
		b[i] = lp * 0.6 * exp(-t * 9.0) + sin(t * TAU * 85.0) * 0.35 * exp(-t * 40.0)
	return b


## Missile seeker searching: a growling, warbling tone.
func _seek() -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(RATE)
	for i in b.size():
		var t := float(i) / RATE
		var sq := 1.0 if fmod(t * 420.0, 1.0) < 0.5 else -1.0
		b[i] = sq * 0.12 * (0.55 + 0.45 * sin(t * TAU * 18.0))
	return b


## Missile lock: a steady high tone.
func _lock() -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(RATE / 2)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = (sin(t * TAU * 1240.0) * 0.16 + (1.0 if fmod(t * 1240.0, 1.0) < 0.5 else -1.0) * 0.05) * (0.9 + 0.1 * sin(t * TAU * 10.0))
	return b


## Stall horn: two alternating tones.
func _stall() -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(RATE / 2)
	for i in b.size():
		var t := float(i) / RATE
		var f := 700.0 if int(t * 8.0) % 2 == 0 else 920.0
		b[i] = (1.0 if fmod(t * f, 1.0) < 0.5 else -1.0) * 0.12
	return b


## Missile launch: a thunk, then the rocket motor hissing away.
func _launch(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(1.4 * RATE))
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (r.randf_range(-1, 1) - lp) * lerpf(0.5, 0.08, minf(1.0, t / 1.2))
		var env := minf(1.0, t * 30.0) * exp(-t * 2.2)
		b[i] = lp * env * 1.3 + sin(t * TAU * 60.0) * exp(-t * 18.0) * 0.6
	return b


## Distant explosion: muffled, long rumble.
func _explode_far(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(1.6 * RATE))
	var lp := 0.0
	var lp2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (r.randf_range(-1, 1) - lp) * 0.06
		lp2 += (lp - lp2) * 0.1
		b[i] = lp2 * 3.2 * minf(1.0, t * 25.0) * exp(-t * 2.4)
	return b


## Another plane flashing past: a rising-then-falling whoosh with a Doppler
## drop in the engine tone.
func _flyby(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(1.6 * RATE))
	var lp := 0.0
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (r.randf_range(-1, 1) - lp) * 0.2
		var env := exp(-pow((t - 0.55) / 0.3, 2.0))
		ph += lerpf(520.0, 300.0, smoothstep(0.4, 0.75, t)) / RATE
		b[i] = (lp * 0.9 + sin(ph * TAU) * 0.25) * env
	return b


## Anti-G straining grunt: a short voiced "hick".
func _grunt(r: RandomNumberGenerator) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(0.45 * RATE))
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (r.randf_range(-1, 1) - lp) * 0.25
		var voice := (fmod(t * 115.0, 1.0) * 2.0 - 1.0) * 0.25
		var env := minf(1.0, t * 40.0) * exp(-t * 7.0)
		b[i] = (voice + lp * 0.35) * env
	return b
