extends Node
## Autoload "Stacks": builds every slice sheet at startup (procedural, or a PNG
## override from res://assets/stacks/<name>.png), packs them into one shared
## atlas, and owns the shared materials. Also builds the facade/roof atlas used
## by collapsed building stacks and the ground tile atlas.

const ATLAS_W := 1024
const PAD := 1
const OVERRIDE_DIR := "res://assets/stacks/"

const FACADE_W := 256
const FACADE_H := 128
const ROOF_ROW := 48 # roofs start at this pixel row in the facade atlas

class Sheet:
	var name := ""
	var w := 8
	var h := 8
	var n := 1
	var v := 1
	var spacing := 1.0
	var cols := 1
	var origin := Vector2i.ZERO
	var block := Vector2i.ZERO
	var vstride := Vector2i.ZERO
	var overridden := false
	var uv_rects: Array[Rect2] = []

	func uv(s: int, variant: int) -> Rect2:
		return uv_rects[variant * n + s]

	func cell(s: int, variant: int) -> Vector2i:
		return origin + vstride * variant + Vector2i((s % cols) * (w + 1), (s / cols) * (h + 1))


var sheets := {}
var atlas_size := Vector2i(ATLAS_W, 256)
var atlas_tex: ImageTexture
var emit_tex: ImageTexture
var facade_tex: ImageTexture
var facade_emit_tex: ImageTexture
var ground_tex: ImageTexture
var jet_shadow_tex: ImageTexture
var cloud_tex: ImageTexture

var static_mat: ShaderMaterial
var building_mat: ShaderMaterial
var ground_mat: ShaderMaterial
var glow_mat: ShaderMaterial
var fx_mat: ShaderMaterial
var beam_mat: ShaderMaterial
var _batch_mats := {}
var build_ms := 0


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_build_sheets()
	_build_facades()
	_build_ground()
	_build_globals()
	_build_materials()
	build_ms = Time.get_ticks_msec() - t0
	print("Stacks: %d sheets, atlas %dx%d, built in %d ms" % [sheets.size(), atlas_size.x, atlas_size.y, build_ms])


# ------------------------------------------------------------------ sheets

func _try_load_png(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _build_sheets() -> void:
	var gen := SheetGen.new()
	var albedo_imgs := {} # name -> Array[Image] per variant
	var emit_imgs := {}
	for sheet_name in SheetGen.DEFS:
		var d: Array = SheetGen.DEFS[sheet_name]
		var sh := Sheet.new()
		sh.name = sheet_name
		sh.w = d[0]
		sh.h = d[1]
		sh.n = d[2]
		sh.v = d[3]
		var alb: Array[Image] = []
		var emi: Array[Image] = []
		var base := _try_load_png(OVERRIDE_DIR + sheet_name + ".png")
		if base != null and base.get_height() > 0 and base.get_width() >= base.get_height():
			# Override: square slices side by side, bottom first.
			sh.overridden = true
			sh.h = base.get_height()
			sh.w = sh.h
			sh.n = base.get_width() / sh.h
			var base_emit := _try_load_png(OVERRIDE_DIR + sheet_name + "_emit.png")
			for vi in sh.v:
				var vimg := _try_load_png(OVERRIDE_DIR + "%s_%d.png" % [sheet_name, vi])
				if vimg == null or vimg.get_size() != base.get_size():
					vimg = base
				alb.append(vimg)
				var e := Image.create(base.get_width(), base.get_height(), false, Image.FORMAT_RGBA8)
				if base_emit != null and base_emit.get_size() == base.get_size():
					# any non-black emission pixel is "always lit"
					for y in base.get_height():
						for x in base.get_width():
							var c := base_emit.get_pixel(x, y)
							if c.a > 0.5 and (c.r + c.g + c.b) > 0.05:
								e.set_pixel(x, y, Color(c.r, c.g, c.b, Painter.EM_ALWAYS))
				emi.append(e)
		else:
			for vi in sh.v:
				var a := Image.create(sh.w * sh.n, sh.h, false, Image.FORMAT_RGBA8)
				var e := Image.create(sh.w * sh.n, sh.h, false, Image.FORMAT_RGBA8)
				var p := Painter.new(a, e, sh.w, sh.h)
				for s in sh.n:
					p.ox = s * sh.w
					gen.call(d[4], p, s, vi)
				alb.append(a)
				emi.append(e)
		albedo_imgs[sheet_name] = alb
		emit_imgs[sheet_name] = emi
		sheets[sheet_name] = sh
	_pack()
	for sheet_name in sheets:
		var sh: Sheet = sheets[sheet_name]
		sh.uv_rects.clear()
		for vi in sh.v:
			for s in sh.n:
				sh.uv_rects.append(slice_uv(sh, s, vi))
	var atlas := Image.create(atlas_size.x, atlas_size.y, false, Image.FORMAT_RGBA8)
	var eatlas := Image.create(atlas_size.x, atlas_size.y, false, Image.FORMAT_RGBA8)
	for sheet_name in sheets:
		var sh: Sheet = sheets[sheet_name]
		for vi in sh.v:
			var a: Image = albedo_imgs[sheet_name][vi]
			var e: Image = emit_imgs[sheet_name][vi]
			for s in sh.n:
				var src := Rect2i(s * sh.w, 0, sh.w, sh.h)
				var dst := sh.cell(s, vi)
				atlas.blit_rect(a, src, dst)
				eatlas.blit_rect(e, src, dst)
	atlas_tex = ImageTexture.create_from_image(atlas)
	emit_tex = ImageTexture.create_from_image(eatlas)
	_build_jet_shadow(albedo_imgs["jet"][0], sheets["jet"])


func _pack() -> void:
	var list: Array = sheets.values()
	for sh: Sheet in list:
		sh.cols = clampi(ATLAS_W / (sh.w + PAD), 1, sh.n)
		var rows := int(ceil(float(sh.n) / sh.cols))
		sh.block = Vector2i(sh.cols * (sh.w + PAD), rows * (sh.h + PAD))
		if sh.block.x * sh.v <= ATLAS_W:
			sh.vstride = Vector2i(sh.block.x, 0)
		else:
			sh.vstride = Vector2i(0, sh.block.y)
	list.sort_custom(func(a: Sheet, b: Sheet) -> bool: return _total(a).y > _total(b).y)
	var x := 0
	var y := 0
	var shelf_h := 0
	for sh: Sheet in list:
		var t := _total(sh)
		if x + t.x > ATLAS_W:
			x = 0
			y += shelf_h
			shelf_h = 0
		sh.origin = Vector2i(x, y)
		x += t.x
		shelf_h = maxi(shelf_h, t.y)
	var hh := y + shelf_h
	var p2 := 64
	while p2 < hh:
		p2 *= 2
	atlas_size = Vector2i(ATLAS_W, p2)


func _total(sh: Sheet) -> Vector2i:
	if sh.vstride.y == 0:
		return Vector2i(sh.block.x * sh.v, sh.block.y)
	return Vector2i(sh.block.x, sh.block.y * sh.v)


func _build_jet_shadow(img: Image, sh: Sheet) -> void:
	var s := Image.create(sh.w, sh.h, false, Image.FORMAT_RGBA8)
	for i in sh.n:
		for y in sh.h:
			for x in sh.w:
				if img.get_pixel(i * sh.w + x, y).a > 0.5:
					s.set_pixel(x, y, Color(0, 0, 0, 1))
	jet_shadow_tex = ImageTexture.create_from_image(s)


func get_sheet(sheet_name: String) -> Sheet:
	return sheets[sheet_name]


## UV rect (in 0..1 atlas space) of one slice, slightly inset against bleeding.
func slice_uv(sh: Sheet, s: int, variant: int) -> Rect2:
	var c := sh.cell(s, variant)
	var inv := Vector2(1.0 / atlas_size.x, 1.0 / atlas_size.y)
	var eps := 0.02
	return Rect2((Vector2(c) + Vector2(eps, eps)) * inv, (Vector2(sh.w, sh.h) - Vector2(eps, eps) * 2.0) * inv)


## Builds a mesh with one horizontal quad per slice (variant 0 UVs). Used by
## dynamic StackBatch renderers; the shader rotates it and picks the variant.
func make_stack_mesh(sheet_name: String) -> ArrayMesh:
	var sh := get_sheet(sheet_name)
	var mb := MeshBuf.new()
	mb.add_stack(sh, 0, Vector3.ZERO, 0.0, 1.0, Color.WHITE)
	return mb.commit()


func batch_material(sheet_name: String) -> ShaderMaterial:
	if _batch_mats.has(sheet_name):
		return _batch_mats[sheet_name]
	var sh := get_sheet(sheet_name)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/stack.gdshader")
	m.set_shader_parameter("albedo_tex", atlas_tex)
	m.set_shader_parameter("emit_tex", emit_tex)
	m.set_shader_parameter("dynamic", true)
	m.set_shader_parameter("fadeable", false)
	m.set_shader_parameter("variant_stride", Vector2(sh.vstride) / Vector2(atlas_size))
	_batch_mats[sheet_name] = m
	return m


# ------------------------------------------------------------------ facades

## Facade styles (32x24 tile = 4 window bays x 4 floors). index -> atlas pos.
const F_GLASS := 0
const F_GLASS_DARK := 1
const F_OFFICE := 2
const F_BRICK := 3
const F_WHITE := 4
const F_WAREHOUSE := 5
const F_FACTORY := 6
const F_BEIGE := 7
const F_STADIUM := 8
const F_HANGAR := 9
const F_TERMINAL := 10
const F_WOOD := 11
const F_LUX := 12
const F_MODERN := 13
const F_RUBBLE := 14
const F_GREEN := 15

const R_GRAVEL := 0
const R_TAR := 1
const R_GREEN := 2
const R_TILES := 3
const R_METAL := 4
const R_CONCRETE := 5
const R_FIELD := 6
const R_RUBBLE := 7


func facade_uv(style: int) -> Vector2:
	return Vector2(float((style % 8) * 32) / FACADE_W, float((style / 8) * 24) / FACADE_H)


func roof_uv(style: int) -> Vector2:
	return Vector2(float(style * 32) / FACADE_W, float(ROOF_ROW) / FACADE_H)


func _build_facades() -> void:
	var img := Image.create(FACADE_W, FACADE_H, false, Image.FORMAT_RGBA8)
	var em := Image.create(FACADE_W, FACADE_H, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# [wall, window, win_x, win_y, win_w, win_h, frame]
	var styles := [
		[Pal.STEEL, Pal.SKY, 1, 1, 6, 4, Pal.BLUE_GRAY],
		[Pal.NAVY, Pal.OCEAN, 0, 1, 8, 4, Pal.NAVY_D],
		[Pal.LGRAY, Pal.NAVY, 2, 1, 4, 3, Pal.GRAY],
		[Pal.BROWN, Pal.BLUE_GRAY, 2, 1, 3, 3, Pal.TAN],
		[Pal.BEIGE, Pal.STEEL, 2, 2, 3, 2, Pal.WHITE],
		[Pal.GRAY, -1, 0, 0, 0, 0, Pal.DGRAY],
		[Pal.RED_D, Pal.NAVY, 1, 1, 6, 2, Pal.BROWN_D],
		[Pal.TAN, Pal.CHAR, 2, 1, 4, 3, Pal.BEIGE],
		[Pal.LGRAY, -1, 0, 0, 0, 0, Pal.GRAY],
		[Pal.DGRAY, -1, 0, 0, 0, 0, Pal.CHAR],
		[Pal.LGRAY, Pal.PALE, 0, 1, 8, 4, Pal.GRAY],
		[Pal.BROWN, Pal.STEEL, 3, 2, 2, 2, Pal.TAN],
		[Pal.CHAR, Pal.BROWN, 1, 1, 6, 4, Pal.AMBER],
		[Pal.BLUE_GRAY, Pal.PALE, 1, 1, 6, 4, Pal.STEEL],
		[Pal.DGRAY, -1, 0, 0, 0, 0, Pal.BROWN_D],
		[Pal.GREEN_D, Pal.GREEN_L, 1, 1, 6, 4, Pal.GREEN],
	]
	for si in styles.size():
		var st: Array = styles[si]
		var ox := (si % 8) * 32
		var oy := (si / 8) * 24
		img.fill_rect(Rect2i(ox, oy, 32, 24), Pal.c(st[0]))
		match si:
			F_WAREHOUSE, F_HANGAR:
				for x in range(0, 32, 2):
					img.fill_rect(Rect2i(ox + x, oy, 1, 24), Pal.c(st[6]))
				if si == F_WAREHOUSE:
					for x in range(2, 32, 8):
						img.fill_rect(Rect2i(ox + x, oy + 1, 4, 2), Pal.c(Pal.STEEL))
						em.fill_rect(Rect2i(ox + x, oy + 1, 4, 2), Color(1, 0, 0, 1))
			F_STADIUM:
				for x in range(0, 32, 8):
					img.fill_rect(Rect2i(ox + x, oy, 2, 24), Pal.c(Pal.GRAY))
				img.fill_rect(Rect2i(ox, oy, 32, 2), Pal.c(Pal.RED))
				img.fill_rect(Rect2i(ox, oy + 12, 32, 1), Pal.c(Pal.GRAY))
			F_RUBBLE:
				for i in 90:
					img.set_pixel(ox + rng.randi_range(0, 31), oy + rng.randi_range(0, 23), Pal.c([Pal.BROWN_D, Pal.CHAR, Pal.GRAY][i % 3]))
			_:
				for fy in 4:
					for bx in 4:
						var cx := ox + bx * 8
						var cy := oy + fy * 6
						img.fill_rect(Rect2i(cx + st[2], cy + st[3], st[4], st[5]), Pal.c(st[1]))
						em.fill_rect(Rect2i(cx + st[2], cy + st[3], st[4], st[5]), Color(1, 0, 0, 1))
						# reflection highlight
						img.set_pixel(cx + st[2], cy + st[3], Pal.c(st[1]).lightened(0.25))
					img.fill_rect(Rect2i(ox, oy + fy * 6 + 5, 32, 1), Pal.c(st[6]))
		# small noise for texture
		for i in 12:
			var x := ox + rng.randi_range(0, 31)
			var y := oy + rng.randi_range(0, 23)
			img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.12))
	# roofs (32x32 each) starting at ROOF_ROW
	var roofs := [Pal.GRAY, Pal.CHAR, Pal.GREEN, Pal.RED_D, Pal.LGRAY, Pal.LGRAY, Pal.GREEN, Pal.DGRAY]
	for ri in roofs.size():
		var ox := ri * 32
		var oy := ROOF_ROW
		var base := Pal.c(roofs[ri])
		img.fill_rect(Rect2i(ox, oy, 32, 32), base)
		match ri:
			R_TILES:
				for y in range(0, 32, 3):
					img.fill_rect(Rect2i(ox, oy + y, 32, 1), base.darkened(0.25))
			R_METAL:
				for x in range(0, 32, 3):
					img.fill_rect(Rect2i(ox + x, oy, 1, 32), base.darkened(0.2))
			R_FIELD:
				for x in range(0, 32, 8):
					img.fill_rect(Rect2i(ox + x, oy, 4, 32), Pal.c(Pal.GREEN_L))
			R_CONCRETE:
				for x in range(0, 32, 16):
					img.fill_rect(Rect2i(ox + x, oy, 1, 32), base.darkened(0.15))
					img.fill_rect(Rect2i(ox, oy + x, 32, 1), base.darkened(0.15))
		for i in 60:
			var x := ox + rng.randi_range(0, 31)
			var y := oy + rng.randi_range(0, 31)
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, c.darkened(0.15) if i % 2 == 0 else c.lightened(0.1))
	facade_tex = ImageTexture.create_from_image(img)
	facade_emit_tex = ImageTexture.create_from_image(em)


# ------------------------------------------------------------------ ground

const G_ASPHALT := 0
const G_DASH := 1
const G_SIDEWALK := 2
const G_GRASS := 3
const G_PLAZA := 4
const G_WATER := 5
const G_SAND := 6
const G_RUNWAY := 7
const G_CROSS := 8
const G_RAILS := 9
const G_DIRT := 10
const G_PARKING := 11
const G_FIELD := 12
const G_PATH := 13
const G_DEEP := 14
const G_SLABS := 15


func _build_ground() -> void:
	var img := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for t in 16:
		var ox := (t % 8) * 16
		var oy := (t / 8) * 16
		var base: Color
		var speck: Array = []
		match t:
			G_ASPHALT, G_DASH, G_CROSS, G_PARKING:
				base = Pal.c(Pal.CHAR)
				speck = [Pal.DGRAY, Pal.BLACK]
			G_SIDEWALK:
				base = Pal.c(Pal.GRAY)
				speck = [Pal.LGRAY, Pal.DGRAY]
			G_GRASS:
				base = Pal.c(Pal.GREEN)
				speck = [Pal.GREEN_L, Pal.GREEN_D]
			G_PLAZA:
				base = Pal.c(Pal.BEIGE)
				speck = [Pal.TAN]
			G_WATER:
				base = Pal.c(Pal.OCEAN)
				speck = [Pal.SKY, Pal.DEEP]
			G_SAND:
				base = Pal.c(Pal.BEIGE)
				speck = [Pal.TAN, Pal.WHITE]
			G_RUNWAY:
				base = Pal.c(Pal.DGRAY)
				speck = [Pal.CHAR]
			G_RAILS:
				base = Pal.c(Pal.BROWN_D)
				speck = [Pal.DGRAY]
			G_DIRT:
				base = Pal.c(Pal.BROWN)
				speck = [Pal.BROWN_D, Pal.TAN]
			G_FIELD:
				base = Pal.c(Pal.GREEN)
				speck = []
			G_PATH:
				base = Pal.c(Pal.TAN)
				speck = [Pal.BEIGE, Pal.BROWN]
			G_DEEP:
				base = Pal.c(Pal.DEEP)
				speck = [Pal.OCEAN, Pal.NAVY]
			G_SLABS:
				base = Pal.c(Pal.GRAY)
				speck = [Pal.DGRAY]
		img.fill_rect(Rect2i(ox, oy, 16, 16), base)
		for i in 14:
			if speck.is_empty():
				break
			img.set_pixel(ox + rng.randi_range(0, 15), oy + rng.randi_range(0, 15), Pal.c(speck[i % speck.size()]))
		match t:
			G_DASH:
				img.fill_rect(Rect2i(ox, oy + 7, 8, 2), Pal.c(Pal.YELLOW))
			G_SIDEWALK:
				img.fill_rect(Rect2i(ox, oy + 7, 16, 1), Pal.c(Pal.DGRAY))
				img.fill_rect(Rect2i(ox + 7, oy, 1, 16), Pal.c(Pal.DGRAY))
			G_PLAZA:
				img.fill_rect(Rect2i(ox, oy, 8, 8), Pal.c(Pal.LGRAY))
				img.fill_rect(Rect2i(ox + 8, oy + 8, 8, 8), Pal.c(Pal.LGRAY))
			G_RUNWAY:
				img.fill_rect(Rect2i(ox, oy + 7, 10, 2), Pal.c(Pal.WHITE))
			G_CROSS:
				img.fill_rect(Rect2i(ox + 1, oy, 2, 16), Pal.c(Pal.LGRAY))
				img.fill_rect(Rect2i(ox + 9, oy, 2, 16), Pal.c(Pal.LGRAY))
			G_RAILS:
				for x in range(1, 16, 4):
					img.fill_rect(Rect2i(ox + x, oy + 2, 2, 12), Pal.c(Pal.BROWN))
				img.fill_rect(Rect2i(ox, oy + 4, 16, 1), Pal.c(Pal.LGRAY))
				img.fill_rect(Rect2i(ox, oy + 11, 16, 1), Pal.c(Pal.LGRAY))
			G_PARKING:
				img.fill_rect(Rect2i(ox, oy, 1, 7), Pal.c(Pal.WHITE))
				img.fill_rect(Rect2i(ox + 8, oy, 1, 7), Pal.c(Pal.WHITE))
			G_FIELD:
				img.fill_rect(Rect2i(ox, oy, 8, 16), Pal.c(Pal.GREEN_L))
			G_SLABS:
				img.fill_rect(Rect2i(ox, oy, 16, 1), Pal.c(Pal.DGRAY))
				img.fill_rect(Rect2i(ox, oy, 1, 16), Pal.c(Pal.DGRAY))
	ground_tex = ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ globals & materials

func _build_globals() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 9
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	var nimg := noise.get_seamless_image(128, 128)
	cloud_tex = ImageTexture.create_from_image(nimg)
	RenderingServer.global_shader_parameter_set("jet_shadow_tex", jet_shadow_tex)
	RenderingServer.global_shader_parameter_set("jet_shadow_size", float(get_sheet("jet").w))
	RenderingServer.global_shader_parameter_set("cloud_tex", cloud_tex)


func _build_materials() -> void:
	static_mat = ShaderMaterial.new()
	static_mat.shader = preload("res://shaders/stack.gdshader")
	static_mat.set_shader_parameter("albedo_tex", atlas_tex)
	static_mat.set_shader_parameter("emit_tex", emit_tex)
	static_mat.set_shader_parameter("dynamic", false)
	static_mat.set_shader_parameter("fadeable", true)

	building_mat = ShaderMaterial.new()
	building_mat.shader = preload("res://shaders/building.gdshader")
	building_mat.set_shader_parameter("facade_tex", facade_tex)
	building_mat.set_shader_parameter("facade_emit", facade_emit_tex)

	ground_mat = ShaderMaterial.new()
	ground_mat.shader = preload("res://shaders/ground.gdshader")
	ground_mat.set_shader_parameter("ground_tex", ground_tex)

	glow_mat = ShaderMaterial.new()
	glow_mat.shader = preload("res://shaders/glow.gdshader")

	fx_mat = ShaderMaterial.new()
	fx_mat.shader = preload("res://shaders/fx.gdshader")

	beam_mat = ShaderMaterial.new()
	beam_mat.shader = preload("res://shaders/beam.gdshader")
