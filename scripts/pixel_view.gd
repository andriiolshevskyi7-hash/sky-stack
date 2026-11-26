class_name PixelView
extends Node
## Renders the 3D world into a low-res SubViewport, post-processes it at
## that same resolution (bloom + palette), then shows it on screen scaled by
## a WHOLE number with nearest filtering, so every world pixel is the same
## size. HUD/menus are drawn on top at full resolution (project stretch mode
## stays "disabled"). The height cap follows the graphics quality: HD voxel
## (high) ~720 px (672 on a 1344 px phone), medium 540, low 400 (classic).

const MAX_H := 400
const MIN_H := 280
const QUALITY_MAX_H := [400, 540, 720]

var world_vp: SubViewport
var post_vp: SubViewport
var post_rect: ColorRect
var overlay: Node2D # low-res 2D overlay (speed lines)
var display: TextureRect
var post_mat: ShaderMaterial
var pixel_scale := 1
var low := Vector2i(400, 224)
var max_h := 720
## UI scale for overlays drawn in world pixels (cockpit HUD): 2 at HD.
var ui_k := 1


static func compute(screen: Vector2i, cap: int = MAX_H) -> Array:
	var s := maxi(1, int(ceil(float(screen.y) / cap)))
	var h := screen.y / s
	while h < MIN_H and s > 1:
		s -= 1
		h = mini(cap, screen.y / s)
	if s == 1:
		h = screen.y
	var w := int(ceil(float(screen.x) / s))
	return [s, Vector2i(w, h)]


func _ready() -> void:
	world_vp = SubViewport.new()
	world_vp.name = "WorldView"
	world_vp.own_world_3d = true
	world_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_vp.msaa_3d = Viewport.MSAA_DISABLED
	world_vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	world_vp.positional_shadow_atlas_size = 0
	world_vp.audio_listener_enable_3d = false
	world_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(world_vp)

	post_vp = SubViewport.new()
	post_vp.name = "PostView"
	post_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	post_vp.disable_3d = true
	post_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(post_vp)
	post_rect = ColorRect.new()
	post_mat = ShaderMaterial.new()
	post_mat.shader = preload("res://shaders/post.gdshader")
	post_mat.set_shader_parameter("src", world_vp.get_texture())
	post_mat.set_shader_parameter("src_lin", world_vp.get_texture())
	post_mat.set_shader_parameter("palette", Pal.make_texture())
	# bright clean look: no palette snapping / ordered dither, soft bloom
	post_mat.set_shader_parameter("palette_mix", 0.0)
	post_mat.set_shader_parameter("dither_amount", 0.0)
	post_mat.set_shader_parameter("bloom", 0.4)
	post_mat.set_shader_parameter("threshold", 0.975)
	post_rect.material = post_mat
	post_vp.add_child(post_rect)
	overlay = Node2D.new()
	overlay.name = "Overlay"
	post_vp.add_child(overlay)

	display = TextureRect.new()
	display.name = "Display"
	display.texture = post_vp.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	get_viewport().size_changed.connect(_relayout)
	_relayout()


func _relayout() -> void:
	var screen := Vector2i(get_viewport().get_visible_rect().size)
	var r := compute(screen, max_h)
	pixel_scale = r[0]
	low = r[1]
	ui_k = maxi(1, low.y / 300)
	post_mat.set_shader_parameter("res_k", float(low.y) / 336.0)
	world_vp.size = low
	post_vp.size = low
	post_rect.size = Vector2(low)
	display.size = Vector2(low * pixel_scale)
	display.position = Vector2((screen - low * pixel_scale) / 2)


## Graphics quality -> render resolution (0 low, 1 medium, 2 high).
func set_quality(q: int) -> void:
	var h: int = QUALITY_MAX_H[clampi(q, 0, 2)]
	if h != max_h:
		max_h = h
		_relayout()


func set_post(param: String, value: Variant) -> void:
	post_mat.set_shader_parameter(param, value)
