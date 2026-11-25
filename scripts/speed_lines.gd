class_name SpeedLines
extends Node2D
## Low-res pixel speed lines drawn inside the post viewport while boosting.

const N := 26
var strength := 0.0
var size := Vector2(400, 224)
var ang := PackedFloat32Array()
var dist := PackedFloat32Array()
var spd := PackedFloat32Array()
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	for i in N:
		ang.append(rng.randf() * TAU)
		dist.append(rng.randf())
		spd.append(rng.randf_range(0.8, 1.6))


func _process(delta: float) -> void:
	if strength <= 0.01:
		visible = false
		return
	visible = true
	for i in N:
		dist[i] += delta * spd[i] * 1.6
		if dist[i] > 1.0:
			dist[i] = rng.randf_range(0.15, 0.3)
			ang[i] = rng.randf() * TAU
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := size.length() * 0.5
	for i in N:
		var d := Vector2(cos(ang[i]), sin(ang[i]))
		var a := c + d * r * dist[i]
		var b := a + d * r * 0.12 * strength
		draw_line(a.round(), b.round(), Color(1, 1, 1, 0.55 * strength), 1.0)
