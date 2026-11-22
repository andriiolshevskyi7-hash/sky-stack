class_name PixelView
extends Node
## Renders the 3D world into a low-res SubViewport (height 180..224 px),
## post-processes it at that same low resolution (bloom + palette), then
## shows it on screen scaled by a WHOLE number with nearest filtering, so
## every world pixel is the same size. HUD/menus are drawn on top at full
## resolution (project stretch mode stays "disabled").

const MAX_H := 224
const MIN_H := 180

var world_vp: SubViewport
var post_vp: SubViewport
var post_rect: ColorRect
var overlay: Node2D # low-res 2D overlay (speed lines)
var display: TextureRect
var post_mat: ShaderMaterial
var pixel_scale := 1
var low := Vector2i(400, 224)


static func compute(screen: Vector2i) -> Array:
	var s := maxi(1, int(ceil(float(screen.y) / MAX_H)))
	var h := screen.y / s
	while h < MIN_H and s > 1:
		s -= 1
		h = mini(MAX_H, screen.y / s)
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
	var r := compute(screen)
	pixel_scale = r[0]
	low = r[1]
	world_vp.size = low
	post_vp.size = low
	post_rect.size = Vector2(low)
	display.size = Vector2(low * pixel_scale)
	display.position = Vector2((screen - low * pixel_scale) / 2)


func set_post(param: String, value: Variant) -> void:
	post_mat.set_shader_parameter(param, value)
