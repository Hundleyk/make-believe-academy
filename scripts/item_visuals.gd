extends RefCounted
## Builds the gray-box look for items, the ghost preview, rings, and the check/cross badges.
## When real GLB models arrive in M4, only make_body() needs to change.

const GHOST_ALPHA := 0.55
const OK_COLOR := Color("42C872")        # placement grid green
const BAD_COLOR := Color("E05A68")       # heart coral
const RING_COLOR := Color("F6DA74")      # nightlight honey glow
const WALL_ITEM_RAISE := 0.35            # how high wall items hang

static var _badge_cache := {}


## The item's gray shape. ghost = true makes it see-through.
static func make_body(data: ItemData, ghost := false) -> Node3D:
	var body := Node3D.new()
	body.name = "Body"
	var size := data.gray_size
	if size == Vector3.ZERO:
		size = Vector3(data.footprint.x - 0.2, data.gray_height, data.footprint.y - 0.2)

	var mesh: Mesh
	match data.gray_shape:
		"cylinder":
			var c := CylinderMesh.new()
			c.top_radius = minf(size.x, size.z) / 2.0
			c.bottom_radius = c.top_radius
			c.height = size.y
			c.radial_segments = 24
			mesh = c
		"sphere":
			var s := SphereMesh.new()
			s.radius = minf(size.x, size.z) / 2.0
			s.height = size.y
			mesh = s
		_:
			var b := BoxMesh.new()
			b.size = size
			mesh = b

	var mat := StandardMaterial3D.new()
	mat.albedo_color = data.gray_color
	mat.roughness = 1.0
	if ghost:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = GHOST_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if data.gray_glow:
		mat.emission_enabled = true
		mat.emission = data.gray_color
		mat.emission_energy_multiplier = 0.6

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position.y = size.y / 2.0
	if ghost:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if data.wall_item:
		# Wall items hang on a "Mount" that build mode turns to face away from the wall.
		var mount := Node3D.new()
		mount.name = "Mount"
		body.add_child(mount)
		mi.position.y += WALL_ITEM_RAISE
		mount.add_child(mi)
		return body
	body.add_child(mi)

	# A small nub on the front so you can tell which way an item faces.
	if data.footprint.x != data.footprint.y and size.y > 0.1:
		var nub := MeshInstance3D.new()
		var nb := BoxMesh.new()
		nb.size = Vector3(0.3, 0.12, 0.08)
		nub.mesh = nb
		var nub_mat := mat.duplicate() as StandardMaterial3D
		nub_mat.albedo_color = Color(data.gray_color.darkened(0.35), mat.albedo_color.a)
		nub.material_override = nub_mat
		nub.position = Vector3(0, size.y * 0.6, size.z / 2.0 + 0.04)
		body.add_child(nub)

	if data.gray_glow and not ghost:
		var light := OmniLight3D.new()
		light.light_color = RING_COLOR
		light.light_energy = 0.9
		light.omni_range = maxf(2.5, data.radius + 0.5)
		light.position.y = size.y + 0.2
		body.add_child(light)
	return body


## A flat ring on the floor showing how far an item's effect reaches.
static func make_ring(reach: float, color := RING_COLOR, fill_alpha := 0.12) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Ring"
	if reach <= 0.0:
		return holder
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.outer_radius = reach
	torus.inner_radius = reach - 0.09
	torus.rings = 64
	torus.ring_segments = 8
	ring.mesh = torus
	ring.scale = Vector3(1, 0.3, 1)
	ring.position.y = 0.04
	ring.material_override = _flat_material(color, 0.95)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(ring)

	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = reach
	cyl.bottom_radius = reach
	cyl.height = 0.01
	cyl.radial_segments = 64
	disc.mesh = cyl
	disc.position.y = 0.025
	disc.material_override = _flat_material(color, fill_alpha)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(disc)
	return holder


## A flat square marking one footprint tile.
static func make_tile_marker() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.92, 0.92)
	mi.mesh = plane
	mi.position.y = 0.03
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func tile_material(ok: bool) -> StandardMaterial3D:
	return _flat_material(OK_COLOR if ok else BAD_COLOR, 0.45)


## A round badge with a check mark (ok) or a cross (not ok), drawn in code so it
## never depends on a font having those symbols. Shape, not just color.
static func badge_texture(ok: bool) -> ImageTexture:
	if _badge_cache.has(ok):
		return _badge_cache[ok]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bg := OK_COLOR if ok else BAD_COLOR
	var ink := Color("FFF8E7")
	_disc(img, Vector2(n / 2.0, n / 2.0), n / 2.0 - 2.0, Color("3B2C24"))
	_disc(img, Vector2(n / 2.0, n / 2.0), n / 2.0 - 8.0, bg)
	if ok:
		_thick_line(img, Vector2(34, 66), Vector2(56, 88), 9.0, ink)
		_thick_line(img, Vector2(56, 88), Vector2(96, 42), 9.0, ink)
	else:
		_thick_line(img, Vector2(42, 42), Vector2(86, 86), 9.0, ink)
		_thick_line(img, Vector2(86, 42), Vector2(42, 86), 9.0, ink)
	var tex := ImageTexture.create_from_image(img)
	_badge_cache[ok] = tex
	return tex


static func _flat_material(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color, alpha)
	return m


static func _disc(img: Image, center: Vector2, r: float, color: Color) -> void:
	for y in range(int(center.y - r) - 1, int(center.y + r) + 2):
		for x in range(int(center.x - r) - 1, int(center.x + r) + 2):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			var a := clampf(r - d + 0.5, 0.0, 1.0)
			if a > 0.0:
				var under := img.get_pixel(x, y)
				img.set_pixel(x, y, under.blend(Color(color, color.a * a)))


static func _thick_line(img: Image, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var steps := int(a.distance_to(b))
	for i in steps + 1:
		_disc(img, a.lerp(b, float(i) / maxf(steps, 1)), width / 2.0, color)
