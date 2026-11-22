extends Node
## Autoload "Save": high score + settings in user://save.cfg

const PATH := "user://save.cfg"
var high_score := 0
var sprite_snap := false
var cam_mode := 0


func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		high_score = cf.get_value("game", "high_score", 0)
		sprite_snap = cf.get_value("settings", "sprite_snap", false)
		cam_mode = cf.get_value("settings", "cam_mode", 0)
	apply()


func apply() -> void:
	RenderingServer.global_shader_parameter_set("sprite_snap", 64.0 if sprite_snap else 0.0)


func store() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "high_score", high_score)
	cf.set_value("settings", "sprite_snap", sprite_snap)
	cf.set_value("settings", "cam_mode", cam_mode)
	cf.save(PATH)


## Returns true if this is a new record.
func submit_score(score: int) -> bool:
	if score > high_score:
		high_score = score
		store()
		return true
	return false
