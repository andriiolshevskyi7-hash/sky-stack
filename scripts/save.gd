extends Node
## Autoload "Save": high score + all settings in user://save.cfg

const PATH := "user://save.cfg"
const VERSION := 3
var high_score := 0
var settings := {}

var sprite_snap: bool:
	get:
		return bool(settings.get("sprite_snap", false))
	set(v):
		settings["sprite_snap"] = v
var cam_mode: int:
	get:
		return int(settings.get("view", 1))
	set(v):
		settings["view"] = v
var day_cycle: bool:
	get:
		return bool(settings.get("day_cycle", false))
	set(v):
		settings["day_cycle"] = v
var invert_pitch: bool:
	get:
		return bool(settings.get("invert", false))
	set(v):
		settings["invert"] = v


func _ready() -> void:
	settings = SettingsScreen.defaults()
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		high_score = cf.get_value("game", "high_score", 0)
		var saved: Dictionary = cf.get_value("settings", "values", {})
		var ver: int = cf.get_value("settings", "version", 1)
		for k in saved:
			if settings.has(k) or k in ["map", "last_mode", "last_duel"]:
				settings[k] = saved[k]
		if ver < 2:
			# world became 2x bigger: altitudes/speed defaults changed
			for k in ["speed", "cruise", "ceiling", "clearance"]:
				settings[k] = SettingsScreen.defaults()[k]
		if ver < 3:
			# calmer look for long sessions
			for k in ["glow", "contrast", "vignette", "grain"]:
				settings[k] = SettingsScreen.defaults()[k]
	apply()


func apply() -> void:
	RenderingServer.global_shader_parameter_set("sprite_snap", 64.0 if sprite_snap else 0.0)
	apply_language()


## Languages in the "lang" setting (index 0 = follow the device).
const LANGS := ["", "en", "uk"]


## Set the UI language: chosen one, else the device language if we have it,
## else English. Strings come from locale/strings.csv (one column per language).
func apply_language() -> void:
	var code: String = LANGS[clampi(int(settings.get("lang", 0)), 0, LANGS.size() - 1)]
	if code == "":
		var dev := OS.get_locale_language()
		code = dev if dev in LANGS else "en"
	TranslationServer.set_locale(code)


func store() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "high_score", high_score)
	cf.set_value("settings", "values", settings)
	cf.set_value("settings", "version", VERSION)
	cf.save(PATH)


func reset_defaults() -> void:
	settings = SettingsScreen.defaults()
	store()


## Returns true if this is a new record.
func submit_score(score: int) -> bool:
	if score > high_score:
		high_score = score
		store()
		return true
	return false
