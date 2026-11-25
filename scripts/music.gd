class_name Music
extends Node
## Background music, synthesised in code (no audio files): a calm menu loop
## and a driving battle loop, crossfaded by game state. Rendered once on a
## worker thread and cached in user://cache, so later starts are instant.
##  menu   - 84 bpm, Am F C G: soft pad, sine bass, gentle square arpeggio,
##           light hats
##  battle - 132 bpm, Dm Bb C A: square bass in eighths, sixteenth-note
##           arpeggio lead, kick / snare / hats
## Volume: Save.settings["music"] (0..1); muted with the master sound.

const RATE := 16000
const VERSION := 1
const TRACKS := ["menu", "battle"]

var players := {}
var _want := "menu"
var _ready_tracks := {}
var _task := -1
var _data := {}
var _mutex := Mutex.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for t in TRACKS:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		players[t] = p
	var missing: Array = []
	for t in TRACKS:
		var bytes := _load_cache(t)
		if bytes.is_empty():
			missing.append(t)
		else:
			_install(t, bytes)
	if not missing.is_empty():
		_task = WorkerThreadPool.add_task(_render_all.bind(missing), false, "music")


## Which track should play: "menu", "battle" or "" (silence).
func set_mode(m: String) -> void:
	_want = m


func _process(delta: float) -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_mutex.lock()
		var d := _data.duplicate()
		_mutex.unlock()
		for t in d:
			_install(t, d[t])
			_save_cache(t, d[t])
	var vol := float(Save.settings.get("music", 0.45))
	var on := bool(Save.settings.get("sound", true)) and vol > 0.001
	var target_db := linear_to_db(maxf(0.0001, vol * 0.7)) if on else -80.0
	for t in TRACKS:
		var p: AudioStreamPlayer = players[t]
		if p.stream == null:
			continue
		var want: bool = t == _want and on
		if want and not p.playing:
			p.play()
		var goal := target_db if want else -60.0
		p.volume_db = move_toward(p.volume_db, goal, delta * 40.0)
		if not want and p.playing and p.volume_db <= -59.0:
			p.stop()


func _install(t: String, bytes: PackedByteArray) -> void:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = bytes.size() / 2
	(players[t] as AudioStreamPlayer).stream = s
	_ready_tracks[t] = true


func _path(t: String) -> String:
	return "user://cache/music_%s_v%d.raw" % [t, VERSION]


func _load_cache(t: String) -> PackedByteArray:
	if OS.get_cmdline_user_args().has("--no-music-cache") or not FileAccess.file_exists(_path(t)):
		return PackedByteArray()
	var f := FileAccess.open(_path(t), FileAccess.READ)
	if f == null:
		return PackedByteArray()
	return f.get_buffer(f.get_length())


func _save_cache(t: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute("user://cache")
	var f := FileAccess.open(_path(t), FileAccess.WRITE)
	if f != null:
		f.store_buffer(bytes)


# ------------------------------------------------------------------ synth

func _render_all(list: Array) -> void:
	for t in list:
		var t0 := Time.get_ticks_msec()
		var b := render(t)
		print("Music: %s rendered in %d ms" % [t, Time.get_ticks_msec() - t0])
		_mutex.lock()
		_data[t] = b
		_mutex.unlock()


static func _midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


## Render one loop to 16-bit PCM.
static func render(t: String) -> PackedByteArray:
	var battle := t == "battle"
	var bpm := 132.0 if battle else 84.0
	var beat := 60.0 / bpm
	var bars := 8
	var n := int(bars * 4 * beat * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	buf.fill(0.0)
	# chords as MIDI roots + minor/major flag, 2 bars each... 1 bar each, twice
	var prog: Array = [[50, true], [46, false], [48, false], [45, false]] if battle else [[57, true], [53, false], [48, false], [55, false]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 if battle else 3
	for bar in bars:
		var ch: Array = prog[bar % 4] if battle else prog[(bar / 2) % 4]
		var root: int = ch[0]
		var third: int = 3 if ch[1] else 4
		var tones := [root, root + third, root + 7, root + 12]
		var t0 := bar * 4 * beat
		if battle:
			# bass: square eighths, octave jumps
			for e in 8:
				var bn := root - 12 + (12 if e % 4 == 3 else 0)
				_note(buf, t0 + e * beat * 0.5, beat * 0.45, _midi(bn), 0.16, 1)
			# lead arpeggio: sixteenths up and down the chord
			for e in 16:
				var idx: int = [0, 1, 2, 3, 2, 1, 0, 1][e % 8]
				_note(buf, t0 + e * beat * 0.25, beat * 0.2, _midi(tones[idx] + 12), 0.06, 2)
			# drums
			for b4 in 4:
				_kick(buf, t0 + b4 * beat, 0.5)
				if b4 % 2 == 1:
					_noise(buf, t0 + b4 * beat, 0.12, 0.22, rng)
				for h in 2:
					_noise(buf, t0 + b4 * beat + h * beat * 0.5 + beat * 0.25, 0.03, 0.06, rng)
		else:
			# pad: chord tones, slow swell
			for k in 3:
				_note(buf, t0, beat * 4.0, _midi(tones[k]), 0.05, 3)
				_note(buf, t0, beat * 4.0, _midi(tones[k]) * 1.004, 0.04, 3)
			# bass: sine half notes
			for h in 2:
				_note(buf, t0 + h * beat * 2.0, beat * 1.9, _midi(root - 12), 0.18, 0)
			# arpeggio: gentle square eighths
			for e in 8:
				var idx2: int = [0, 2, 1, 3, 2, 1, 3, 2][e]
				_note(buf, t0 + e * beat * 0.5, beat * 0.4, _midi(tones[idx2] + 12), 0.035, 2)
			for b4 in 4:
				_noise(buf, t0 + b4 * beat + beat * 0.5, 0.025, 0.03, rng)
	# soft limiter + 16-bit
	var out := PackedByteArray()
	out.resize(n * 2)
	for i in n:
		var v := buf[i]
		v = v / (1.0 + absf(v) * 0.6)
		out.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	return out


## One note: wave 0 sine, 1 square (bass), 2 square (lead, thinner), 3 soft
## triangle (pad); attack / release envelope.
static func _note(buf: PackedFloat32Array, t: float, dur: float, f: float, amp: float, wave: int) -> void:
	var i0 := int(t * RATE)
	var len := int(dur * RATE)
	var att := 0.01 if wave != 3 else dur * 0.35
	var rel := minf(0.08, dur * 0.4) if wave != 3 else dur * 0.4
	var ph := 0.0
	var dph := f / RATE
	for k in len:
		var i := i0 + k
		if i >= buf.size():
			i -= buf.size() # wrap: notes ring into the loop start
		var tt := float(k) / RATE
		var env := minf(1.0, tt / att) * minf(1.0, (dur - tt) / rel)
		var x := 0.0
		match wave:
			0:
				x = sin(ph * TAU)
			1:
				x = 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
			2:
				x = 1.0 if fmod(ph, 1.0) < 0.25 else -0.35
			_:
				x = 1.0 - 4.0 * absf(fmod(ph, 1.0) - 0.5)
		buf[i] += x * amp * env
		ph += dph


static func _kick(buf: PackedFloat32Array, t: float, amp: float) -> void:
	var i0 := int(t * RATE)
	var len := int(0.18 * RATE)
	var ph := 0.0
	for k in len:
		var i := i0 + k
		if i >= buf.size():
			break
		var tt := float(k) / RATE
		var f := lerpf(120.0, 45.0, minf(1.0, tt / 0.12))
		ph += f / RATE
		buf[i] += sin(ph * TAU) * amp * (1.0 - tt / 0.18)


static func _noise(buf: PackedFloat32Array, t: float, dur: float, amp: float, rng: RandomNumberGenerator) -> void:
	var i0 := int(t * RATE)
	var len := int(dur * RATE)
	for k in len:
		var i := i0 + k
		if i >= buf.size():
			break
		buf[i] += rng.randf_range(-1.0, 1.0) * amp * (1.0 - float(k) / len)
