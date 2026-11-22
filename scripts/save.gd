extends Node
## Autoload "Save": high score + all settings in user://save.cfg

const PATH := "user://save.cfg"
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
		for k in saved:
			if settings.has(k):
				settings[k] = saved[k]
	apply()


func apply() -> void:
	RenderingServer.global_shader_parameter_set("sprite_snap", 64.0 if sprite_snap else 0.0)


func store() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "high_score", high_score)
	cf.set_value("settings", "values", settings)
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
