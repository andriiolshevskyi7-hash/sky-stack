class_name PlaneDraw
extends Node2D
## Draws plane sprite stacks in 2D screens with the palette shader (the plane
## atlas holds material indices, see PlaneArt). The owner queues items while
## it draws (stack(), icon()) and calls flush(); this child node draws them
## on top with its own material.

var xf := Transform2D.IDENTITY
var _items: Array = []


func _ready() -> void:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/plane_canvas.gdshader")
	m.set_shader_parameter("palette_tex", Stacks.plane_palette_tex)
	material = m
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func begin() -> void:
	_items.clear()


## Rotating 3/4 view: every slice rotated, squashed and lifted one layer.
func stack(pi: int, skin: int, c: Vector2, sc: float, yaw: float) -> void:
	_items.append([0, pi, skin, c, sc, yaw, xf])


## Top-down icon: all slices on top of each other.
func icon(pi: int, skin: int, c: Vector2, sc: float) -> void:
	_items.append([1, pi, skin, c, sc, 0.0, xf])


func flush() -> void:
	queue_redraw()


func _draw() -> void:
	var tex: Texture2D = Stacks.plane_atlas_tex
	for it: Array in _items:
		var sh = Stacks.get_sheet(Planes.sheet_of(it[1]))
		var skin: int = it[2]
		var c: Vector2 = it[3]
		var sc: float = it[4] * sh.world_scale
		var yaw: float = it[5]
		var t: Transform2D = it[6]
		if it[0] == 1:
			draw_set_transform_matrix(t)
			for i in sh.n:
				var src := Rect2(Vector2(sh.cell(i, 0)), Vector2(sh.w, sh.h))
				var shade: float = 0.72 + 0.28 * float(i) / (sh.n - 1)
				draw_texture_rect_region(tex, Rect2(c - Vector2(sh.w, sh.h) * 0.5 * sc, Vector2(sh.w, sh.h) * sc), src, Color(skin / 255.0, shade, 0, 1))
			continue
		var squash := 0.62
		var xa := Vector2(cos(yaw), sin(yaw) * squash) * sc
		var ya := Vector2(-sin(yaw), cos(yaw) * squash) * sc
		var lift := sc * 0.95
		for i in sh.n:
			var src := Rect2(Vector2(sh.cell(i, 0)), Vector2(sh.w, sh.h))
			var shade: float = 0.72 + 0.28 * float(i) / (sh.n - 1)
			var copies := maxi(1, int(ceil(lift)))
			for k in copies:
				var o := c - Vector2(0, i * lift + k * lift / copies)
				draw_set_transform_matrix(t * Transform2D(xa, ya, o))
				draw_texture_rect_region(tex, Rect2(-sh.w * 0.5, -sh.h * 0.5, sh.w, sh.h), src, Color(skin / 255.0, shade, 0, 1))
	draw_set_transform_matrix(Transform2D.IDENTITY)
