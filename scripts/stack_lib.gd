extends Node
## Autoload "Stacks": builds every slice sheet at startup (procedural, or a PNG
## override from res://assets/stacks/<name>.png), packs them into one shared
## atlas, and owns the shared materials. Also builds the facade/roof atlas used
## by collapsed building stacks and the ground tile atlas.

const ATLAS_W := 1024
const PAD := 1
const OVERRIDE_DIR := "res://assets/stacks/"

const FACADE_W := 512
const FACADE_H := 256
const ROOF_ROW := 96 # roofs start at this pixel row in the facade atlas
const FT := 64 # facade tile width (4 window bays x 16 px)
const FH := 48 # facade tile height (4 floors x 12 px)

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
	var atlas := 0 # 0 = main atlas, 1 = plane atlas
	var uv_rects: Array[Rect2] = []

	func uv(s: int, variant: int) -> Rect2:
		return uv_rects[variant * n + s]

	func cell(s: int, variant: int) -> Vector2i:
		return origin + vstride * variant + Vector2i((s % cols) * (w + 1), (s / cols) * (h + 1))


var sheets := {}
var atlas_size := Vector2i(ATLAS_W, 256)
## Second atlas: one sheet per plane of the aircraft tree, skins = variants.
const PLANE_ATLAS := Vector2i(1024, 2048)
var plane_atlas_tex: ImageTexture
var plane_emit_tex: ImageTexture
var plane_albedo := {} # plane index -> Image (factory skin strip, for shadows)
var atlas_tex: ImageTexture
var emit_tex: ImageTexture
var facade_tex: ImageTexture
var facade_emit_tex: ImageTexture
var ground_tex: ImageTexture
var jet_shadow_tex: ImageTexture
var cloud_tex: ImageTexture
var cloud_img: Image
var island_img: Image
var island_tex: ImageTexture

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
	var tp := Time.get_ticks_msec()
	_build_plane_sheets()
	print("Stacks: plane sheets in %d ms" % (Time.get_ticks_msec() - tp))
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


## The 12 planes of the aircraft tree: 40x40, 11 slices, 8 skins each.
## Sheet i sits at ((i % 2) * 452, (i / 2) * 328) of the plane atlas; the 8
## skins are stacked vertically (variant stride 41 px).
func _build_plane_sheets() -> void:
	var atlas := Image.create(PLANE_ATLAS.x, PLANE_ATLAS.y, false, Image.FORMAT_RGBA8)
	var eatlas := Image.create(PLANE_ATLAS.x, PLANE_ATLAS.y, false, Image.FORMAT_RGBA8)
	var W := Planes.SHEET_W
	var N := Planes.SLICES
	var V := Planes.SKINS.size()
	for pi in Planes.LIST.size():
		var sh := Sheet.new()
		sh.name = Planes.sheet_of(pi)
		sh.w = W
		sh.h = W
		sh.n = N
		sh.v = V
		sh.atlas = 1
		sh.cols = N
		sh.block = Vector2i(N * (W + PAD), W + PAD)
		sh.vstride = Vector2i(0, W + PAD)
		sh.origin = Vector2i((pi % 2) * (sh.block.x + 1), (pi / 2) * sh.block.y * V)
		for vi in V:
			var a := Image.create(W * N, W, false, Image.FORMAT_RGBA8)
			var e := Image.create(W * N, W, false, Image.FORMAT_RGBA8)
			var p := Painter.new(a, e, W, W)
			for s in N:
				p.ox = s * W
				Planes.paint(p, s, pi, vi)
			if vi == 0:
				plane_albedo[pi] = a
			for s in N:
				var dst := sh.cell(s, vi)
				atlas.blit_rect(a, Rect2i(s * W, 0, W, W), dst)
				eatlas.blit_rect(e, Rect2i(s * W, 0, W, W), dst)
		for vi in V:
			for s in N:
				sh.uv_rects.append(slice_uv(sh, s, vi))
		sheets[sh.name] = sh
	plane_atlas_tex = ImageTexture.create_from_image(atlas)
	plane_emit_tex = ImageTexture.create_from_image(eatlas)


## Ground shadow of the player's plane (silhouette of every slice).
func set_player_shadow(plane: int) -> void:
	if plane_albedo.has(plane):
		_build_jet_shadow(plane_albedo[plane], get_sheet(Planes.sheet_of(plane)))
		RenderingServer.global_shader_parameter_set("jet_shadow_tex", jet_shadow_tex)


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
	var asz := Vector2(PLANE_ATLAS) if sh.atlas == 1 else Vector2(atlas_size)
	var inv := Vector2(1.0 / asz.x, 1.0 / asz.y)
	var eps := 0.02
	return Rect2((Vector2(c) + Vector2(eps, eps)) * inv, (Vector2(sh.w, sh.h) - Vector2(eps, eps) * 2.0) * inv)


## Builds a mesh with one horizontal quad per slice (variant 0 UVs). Used by
## dynamic StackBatch renderers; the shader rotates it and picks the variant.
func make_stack_mesh(sheet_name: String, copies: int = 1) -> ArrayMesh:
	var sh := get_sheet(sheet_name)
	var mb := MeshBuf.new()
	# Each slice is drawn `copies` times between its height and the next one so
	# no gaps open up when a perspective camera looks at a stack up close.
	mb.add_stack(sh, 0, Vector3.ZERO, 0.0, 1.0, Color.WHITE, copies)
	return mb.commit()


func batch_material(sheet_name: String) -> ShaderMaterial:
	if _batch_mats.has(sheet_name):
		return _batch_mats[sheet_name]
	var sh := get_sheet(sheet_name)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/stack.gdshader")
	var planes := sh.atlas == 1
	m.set_shader_parameter("albedo_tex", plane_atlas_tex if planes else atlas_tex)
	m.set_shader_parameter("emit_tex", plane_emit_tex if planes else emit_tex)
	m.set_shader_parameter("dynamic", true)
	m.set_shader_parameter("fadeable", false)
	m.set_shader_parameter("variant_stride", Vector2(sh.vstride) / Vector2(PLANE_ATLAS if planes else atlas_size))
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
	return Vector2(float((style % 8) * FT) / FACADE_W, float((style / 8) * FH) / FACADE_H)


func roof_uv(style: int) -> Vector2:
	return Vector2(float(style * FT) / FACADE_W, float(ROOF_ROW) / FACADE_H)


func _build_facades() -> void:
	# 64x48 tiles = 4 window bays x 4 floors, 16x12 px per window cell:
	# frames, sills, floor ledges, brick courses, corrugated sheet...
	var img := Image.create(FACADE_W, FACADE_H, false, Image.FORMAT_RGBA8)
	var em := Image.create(FACADE_W, FACADE_H, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# [wall, glass, win_x, win_y, win_w, win_h, frame, kind]  kind: 0 punched, 1 curtain wall, 2 brick
	var styles := [
		[Pal.STEEL, Pal.SKY, 1, 1, 14, 9, Pal.BLUE_GRAY, 1],
		[Pal.NAVY, Pal.OCEAN, 0, 1, 16, 9, Pal.NAVY_D, 1],
		[Pal.LGRAY, Pal.NAVY, 3, 2, 10, 7, Pal.GRAY, 0],
		[Pal.BROWN, Pal.BLUE_GRAY, 4, 2, 8, 7, Pal.TAN, 2],
		[Pal.BEIGE, Pal.STEEL, 4, 3, 8, 6, Pal.WHITE, 0],
		[Pal.GRAY, -1, 0, 0, 0, 0, Pal.DGRAY, 3],
		[Pal.RED_D, Pal.NAVY, 2, 2, 12, 5, Pal.BROWN_D, 2],
		[Pal.TAN, Pal.CHAR, 3, 2, 10, 7, Pal.BEIGE, 0],
		[Pal.LGRAY, -1, 0, 0, 0, 0, Pal.GRAY, 4],
		[Pal.DGRAY, -1, 0, 0, 0, 0, Pal.CHAR, 3],
		[Pal.LGRAY, Pal.PALE, 0, 1, 16, 10, Pal.GRAY, 1],
		[Pal.BROWN, Pal.STEEL, 5, 3, 6, 6, Pal.TAN, 0],
		[Pal.CHAR, Pal.BROWN, 1, 1, 14, 9, Pal.AMBER, 1],
		[Pal.BLUE_GRAY, Pal.PALE, 2, 1, 12, 9, Pal.STEEL, 1],
		[Pal.DGRAY, -1, 0, 0, 0, 0, Pal.BROWN_D, 5],
		[Pal.GREEN_D, Pal.GREEN_L, 1, 1, 14, 9, Pal.GREEN, 1],
	]
	for si in styles.size():
		var st: Array = styles[si]
		var ox := (si % 8) * FT
		var oy := (si / 8) * FH
		var wall := Pal.c(st[0])
		# calm facades: frames sit close to the wall colour, low contrast
		var frame := Pal.c(st[6]).lerp(wall, 0.55)
		img.fill_rect(Rect2i(ox, oy, FT, FH), wall)
		var kind: int = st[7]
		match kind:
			2:
				# brick courses
				for y in range(0, FH, 3):
					img.fill_rect(Rect2i(ox, oy + y, FT, 1), wall.darkened(0.06))
			3:
				# corrugated sheet
				for x in range(0, FT, 8):
					img.fill_rect(Rect2i(ox + x, oy, 1, FH), wall.darkened(0.08))
					img.fill_rect(Rect2i(ox + x + 1, oy, 1, FH), wall.lightened(0.05))
				if si == 5:
					for x in range(4, FT, 16):
						img.fill_rect(Rect2i(ox + x, oy + 2, 8, 4), Pal.c(Pal.STEEL))
						em.fill_rect(Rect2i(ox + x, oy + 2, 8, 4), Color(1, 0, 0, 1))
			4:
				# stadium: pillars + red band
				for x in range(0, FT, 16):
					img.fill_rect(Rect2i(ox + x, oy, 4, FH), Pal.c(Pal.GRAY))
					img.fill_rect(Rect2i(ox + x, oy, 1, FH), Pal.c(Pal.WHITE))
				img.fill_rect(Rect2i(ox, oy, FT, 4), Pal.c(Pal.RED))
				img.fill_rect(Rect2i(ox, oy + 24, FT, 2), Pal.c(Pal.GRAY))
			5:
				for i in 300:
					img.set_pixel(ox + rng.randi_range(0, FT - 1), oy + rng.randi_range(0, FH - 1), Pal.c([Pal.BROWN_D, Pal.CHAR, Pal.GRAY][i % 3]))
		if st[1] != -1:
			var glass := Pal.c(st[1]).lerp(wall, 0.3)
			for fy in 4:
				for bx in 4:
					var cx := ox + bx * 16
					var cy := oy + fy * 12
					var r := Rect2i(cx + st[2], cy + st[3], st[4], st[5])
					if kind != 1:
						img.fill_rect(r.grow(1), frame)
					img.fill_rect(r, glass)
					em.fill_rect(r, Color(1, 0, 0, 1))
					# one soft sky reflection on the upper part of the pane
					img.fill_rect(Rect2i(r.position.x, r.position.y, r.size.x, maxi(1, r.size.y / 3)), glass.lightened(0.06))
				# floor ledge
				img.fill_rect(Rect2i(ox, oy + fy * 12 + 11, FT, 1), wall.darkened(0.08))
				if kind == 1:
					img.fill_rect(Rect2i(ox, oy + fy * 12, FT, 1), frame)
	# roofs (64x64): gravel, tar, green, tiles, metal, concrete, field, rubble
	var roofs := [Pal.GRAY, Pal.CHAR, Pal.GREEN, Pal.RED_D, Pal.LGRAY, Pal.LGRAY, Pal.GREEN, Pal.DGRAY]
	for ri in roofs.size():
		var ox := ri * FT
		var oy := ROOF_ROW
		var base := Pal.c(roofs[ri])
		img.fill_rect(Rect2i(ox, oy, FT, FT), base)
		match ri:
			R_TAR:
				for y in range(0, FT, 16):
					img.fill_rect(Rect2i(ox, oy + y, FT, 1), base.lightened(0.12))
			R_GREEN:
				for i in 60:
					img.fill_rect(Rect2i(ox + rng.randi_range(0, FT - 4), oy + rng.randi_range(0, FT - 4), 3, 3), Pal.c(Pal.GREEN_L) if i % 2 == 0 else Pal.c(Pal.GREEN_D))
			R_TILES:
				for y in range(0, FT, 4):
					img.fill_rect(Rect2i(ox, oy + y, FT, 1), base.darkened(0.3))
					var sh := 0 if (y / 4) % 2 == 0 else 3
					for x in range(sh, FT, 6):
						img.fill_rect(Rect2i(ox + x, oy + y + 1, 1, 3), base.darkened(0.18))
			R_METAL:
				for x in range(0, FT, 6):
					img.fill_rect(Rect2i(ox + x, oy, 1, FT), base.darkened(0.2))
					img.fill_rect(Rect2i(ox + x + 1, oy, 1, FT), base.lightened(0.1))
			R_FIELD:
				for x in range(0, FT, 16):
					img.fill_rect(Rect2i(ox + x, oy, 8, FT), Pal.c(Pal.GREEN_L))
			R_CONCRETE:
				for x in range(0, FT, 32):
					img.fill_rect(Rect2i(ox + x, oy, 1, FT), base.darkened(0.15))
					img.fill_rect(Rect2i(ox, oy + x, FT, 1), base.darkened(0.15))
		var speck := 200 if ri == R_GRAVEL or ri == R_RUBBLE else 90
		for i in speck:
			var x := ox + rng.randi_range(0, FT - 1)
			var y := oy + rng.randi_range(0, FT - 1)
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, c.darkened(0.15) if i % 2 == 0 else c.lightened(0.1))
	_build_map_facades(img, em, rng)
	# mipmaps: distant facades average into calm colour (and distant lit
	# windows into a soft glow) instead of shimmering single pixels
	img.generate_mipmaps()
	em.generate_mipmaps()
	facade_tex = ImageTexture.create_from_image(img)
	facade_emit_tex = ImageTexture.create_from_image(em)


## Map terrain styles. Facades 16..19 live at pixel row 160 (sandstone strata,
## granite with snow streaks, ship hull, neon); roofs 8..11 at row 208 are
## 64x48 (sand, snow, carrier deck, rock).
func _build_map_facades(img: Image, em: Image, rng: RandomNumberGenerator) -> void:
	var oy := 160
	# 16 sandstone: horizontal strata in warm oranges, ragged
	var ox := 0
	var strata := [Color(0.86, 0.52, 0.32), Color(0.93, 0.64, 0.40), Color(0.78, 0.44, 0.28), Color(0.95, 0.72, 0.48), Color(0.83, 0.50, 0.34)]
	var y := 0
	var si := 0
	while y < FH:
		var hgt := rng.randi_range(4, 11)
		img.fill_rect(Rect2i(ox, oy + y, FT, mini(hgt, FH - y)), strata[si % strata.size()])
		img.fill_rect(Rect2i(ox, oy + y, FT, 1), (strata[si % strata.size()] as Color).darkened(0.18))
		y += hgt
		si += 1
	for i in 140:
		var x := ox + rng.randi_range(0, FT - 1)
		var yy := oy + rng.randi_range(0, FH - 1)
		img.set_pixel(x, yy, img.get_pixel(x, yy).darkened(0.12) if i % 3 else img.get_pixel(x, yy).lightened(0.1))
	for x in range(0, FT, rng.randi_range(9, 15)):
		img.fill_rect(Rect2i(ox + x, oy, 1, FH), Color(0.6, 0.34, 0.22, 0.9)) # vertical cracks
	# 17 granite with snow streaks
	ox = FT
	img.fill_rect(Rect2i(ox, oy, FT, FH), Color(0.46, 0.49, 0.55))
	for i in 260:
		var x := ox + rng.randi_range(0, FT - 1)
		var yy := oy + rng.randi_range(0, FH - 1)
		img.set_pixel(x, yy, Color(0.36, 0.38, 0.44) if i % 2 else Color(0.56, 0.59, 0.64))
	for k in 7:
		var x := ox + rng.randi_range(0, FT - 4)
		var yy := oy + rng.randi_range(0, FH - 12)
		var l := rng.randi_range(5, 14)
		for j in l:
			img.fill_rect(Rect2i(x + (j % 3) - 1, yy + j, 2, 1), Color(0.92, 0.95, 1.0))
	img.fill_rect(Rect2i(ox, oy, FT, 3), Color(0.95, 0.97, 1.0)) # snow ledge
	# 18 ship hull: grey plates, portholes, dark boot stripe
	ox = FT * 2
	img.fill_rect(Rect2i(ox, oy, FT, FH), Color(0.52, 0.56, 0.6))
	for x in range(0, FT, 16):
		img.fill_rect(Rect2i(ox + x, oy, 1, FH), Color(0.44, 0.47, 0.52))
	for yy in [12, 36]:
		img.fill_rect(Rect2i(ox, oy + yy, FT, 1), Color(0.44, 0.47, 0.52))
	for x in range(4, FT, 8):
		img.fill_rect(Rect2i(ox + x, oy + 6, 2, 2), Color(0.18, 0.2, 0.24))
		em.fill_rect(Rect2i(ox + x, oy + 6, 2, 2), Color(1, 0, 0, 1))
	img.fill_rect(Rect2i(ox, oy + FH - 6, FT, 6), Color(0.25, 0.22, 0.24))
	# 19 neon: dark tower, bright vertical/horizontal neon bands (glow at night)
	ox = FT * 3
	img.fill_rect(Rect2i(ox, oy, FT, FH), Color(0.13, 0.12, 0.2))
	for fy in 4:
		for bx in 4:
			var r := Rect2i(ox + bx * 16 + 2, oy + fy * 12 + 2, 12, 7)
			img.fill_rect(r, Color(0.2, 0.24, 0.4))
			em.fill_rect(r, Color(1, 0, 0, 1))
	# a single muted neon strip on the corner (subtle, glows at night)
	img.fill_rect(Rect2i(ox + 1, oy, 1, FH), Color(0.75, 0.3, 0.6))
	em.fill_rect(Rect2i(ox + 1, oy, 1, FH), Color(0, 1, 0, 1))
	# roofs (64x48) at row 208
	var ry := 208
	var rh := FACADE_H - ry
	var rcols := [Color(0.93, 0.68, 0.44), Color(0.95, 0.97, 1.0), Color(0.3, 0.32, 0.36), Color(0.5, 0.52, 0.56)]
	for ri in rcols.size():
		var rx := ri * FT
		var base: Color = rcols[ri]
		img.fill_rect(Rect2i(rx, ry, FT, rh), base)
		for i in 160:
			var x := rx + rng.randi_range(0, FT - 1)
			var yy := ry + rng.randi_range(0, rh - 1)
			var c := base.darkened(0.08) if i % 2 else base.lightened(0.06)
			if ri == 1:
				c = Color(0.82, 0.88, 0.96) if i % 3 == 0 else base
			img.set_pixel(x, yy, c)
		if ri == 2:
			# carrier deck: plating lines + yellow/white markings
			for yy in range(0, rh, 12):
				img.fill_rect(Rect2i(rx, ry + yy, FT, 1), base.darkened(0.25))
			img.fill_rect(Rect2i(rx + 30, ry, 2, rh), Color(0.95, 0.85, 0.3))
			for yy in range(0, rh, 12):
				img.fill_rect(Rect2i(rx + 8, ry + yy, 1, 6), Color(0.9, 0.9, 0.9))


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
	const F := 2 # 32 px tiles: 1 px = 1 world unit at world scale 2
	var img := Image.create(128 * F, 32 * F, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for t in 16:
		var ox := (t % 8) * 16 * F
		var oy := (t / 8) * 16 * F
		var base: Color
		var speck: Array = []
		match t:
			G_ASPHALT, G_DASH, G_CROSS, G_PARKING:
				base = Color("6b6e7a")
				speck = [Pal.DGRAY, Pal.BLACK]
			G_SIDEWALK:
				base = Color("c9cbd2")
				speck = [Pal.LGRAY, Pal.DGRAY]
			G_GRASS:
				base = Color("63c34e")
				speck = [Pal.GREEN_L, Pal.GREEN_D]
			G_PLAZA:
				base = Color("efe3c4")
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
				base = Color("e6cf96")
				speck = [Pal.BEIGE, Pal.BROWN]
			G_DEEP:
				base = Pal.c(Pal.DEEP)
				speck = [Pal.OCEAN, Pal.NAVY]
			G_SLABS:
				base = Color("aeb2bc")
				speck = [Pal.DGRAY]
		img.fill_rect(Rect2i(ox, oy, 16 * F, 16 * F), base)
		for i in 0:
			if speck.is_empty():
				break
			img.set_pixel(ox + rng.randi_range(0, 15), oy + rng.randi_range(0, 15), Pal.c(speck[i % speck.size()]))
		match t:
			G_DASH:
				img.fill_rect(Rect2i(ox, oy + (7) * F, (8) * F, (2) * F), Color("f5f5f5"))
			G_SIDEWALK:
				img.fill_rect(Rect2i(ox, oy + (7) * F, (16) * F, (1) * F), Color("b3b6bf"))
				img.fill_rect(Rect2i(ox + (7) * F, oy, (1) * F, (16) * F), Color("b3b6bf"))
			G_PLAZA:
				img.fill_rect(Rect2i(ox, oy, (8) * F, (8) * F), Color("e2d3ad"))
				img.fill_rect(Rect2i(ox + (8) * F, oy + (8) * F, (8) * F, (8) * F), Color("e2d3ad"))
			G_RUNWAY:
				img.fill_rect(Rect2i(ox, oy + (7) * F, (10) * F, (2) * F), Pal.c(Pal.WHITE))
			G_CROSS:
				img.fill_rect(Rect2i(ox + (1) * F, oy, (2) * F, (16) * F), Color("f2f2f2"))
				img.fill_rect(Rect2i(ox + (9) * F, oy, (2) * F, (16) * F), Color("f2f2f2"))
			G_RAILS:
				for x in range(1, 16, 4):
					img.fill_rect(Rect2i(ox + (x) * F, oy + (2) * F, (2) * F, (12) * F), Pal.c(Pal.BROWN))
				img.fill_rect(Rect2i(ox, oy + (4) * F, (16) * F, (1) * F), Pal.c(Pal.LGRAY))
				img.fill_rect(Rect2i(ox, oy + (11) * F, (16) * F, (1) * F), Pal.c(Pal.LGRAY))
			G_PARKING:
				img.fill_rect(Rect2i(ox, oy, (1) * F, (7) * F), Pal.c(Pal.WHITE))
				img.fill_rect(Rect2i(ox + (8) * F, oy, (1) * F, (7) * F), Pal.c(Pal.WHITE))
			G_FIELD:
				img.fill_rect(Rect2i(ox, oy, (8) * F, (16) * F), Pal.c(Pal.GREEN_L))
			G_SLABS:
				img.fill_rect(Rect2i(ox, oy, (16) * F, (1) * F), Pal.c(Pal.DGRAY))
				img.fill_rect(Rect2i(ox, oy, (1) * F, (16) * F), Pal.c(Pal.DGRAY))
	ground_tex = ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ globals & materials

func _build_globals() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 9
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	cloud_img = noise.get_seamless_image(128, 128)
	var nimg := cloud_img
	cloud_tex = ImageTexture.create_from_image(nimg)
	RenderingServer.global_shader_parameter_set("jet_shadow_tex", jet_shadow_tex)
	RenderingServer.global_shader_parameter_set("jet_shadow_size", float(get_sheet("jet").w))
	RenderingServer.global_shader_parameter_set("cloud_tex", cloud_tex)
	rebuild_islands(int(Save.settings.get("seed", 7)), float(Save.settings.get("islands", 0.33)))


func rebuild_islands(p_seed: int, land: float) -> void:
	_build_islands(p_seed, land)
	CityGen.set_maps(island_img, cloud_img)
	RenderingServer.global_shader_parameter_set("island_tex", island_tex)


## Tiling island heightmap: mostly ocean, a big main island at the origin and
## scattered smaller islands. ~30% land. Stored as L8, 0.5 = sea level.
func _build_islands(p_seed: int = 7, land: float = 0.33) -> void:
	var n := CityGen.ISL_N
	var noise := FastNoiseLite.new()
	noise.seed = p_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.022
	noise.fractal_octaves = 4
	var img := noise.get_seamless_image(n, n)
	img.convert(Image.FORMAT_L8)
	var data := img.get_data()
	var vals := PackedFloat32Array()
	vals.resize(n * n)
	var sigma := 22.0
	for y in n:
		for x in n:
			var dx := minf(x, n - x)
			var dy := minf(y, n - y)
			var bump := exp(-(dx * dx + dy * dy) / (2.0 * sigma * sigma))
			vals[y * n + x] = data[y * n + x] / 255.0 * (1.0 - 0.45 * bump) + bump * 0.75
	var sorted := vals.duplicate()
	sorted.sort()
	var sea_v := sorted[clampi(int(n * n * (1.0 - land)), 0, n * n - 1)] # share of ocean
	var hi := sorted[n * n - 1]
	var lo := sorted[0]
	for i in n * n:
		var v := vals[i]
		var o: float
		if v < sea_v:
			o = 0.5 * (v - lo) / maxf(0.001, sea_v - lo)
		else:
			o = 0.5 + 0.5 * (v - sea_v) / maxf(0.001, hi - sea_v)
		data[i] = clampi(int(o * 255.0), 0, 255)
	island_img = Image.create_from_data(n, n, false, Image.FORMAT_L8, data)
	island_tex = ImageTexture.create_from_image(island_img)


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
