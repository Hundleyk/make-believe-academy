extends RefCounted
## Gray-box look for students: a capsule with eyes, mood icons, and act-out props.
## When sculpted characters arrive in M4, only make_body() needs to change.

const Visuals := preload("res://scripts/item_visuals.gd")

const PAPER := Color("FFF8E7")
const INK := Color("3B2C24")
const BLANKET := Color("7096BA")     # blanket fort sky blue

static var _icon_cache := {}


## Capsule body with two eyes on the front (+z) so you can see which way it faces.
static func make_body(data: StudentData) -> Node3D:
	var body := Node3D.new()
	body.name = "Body"
	var h := data.gray_height
	var radius := 0.27
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = h
	var mat := StandardMaterial3D.new()
	mat.albedo_color = data.gray_color
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.name = "Capsule"
	mi.mesh = capsule
	mi.material_override = mat
	mi.position.y = h / 2.0
	body.add_child(mi)

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = INK
	eye_mat.roughness = 0.4
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.05
		s.height = 0.1
		eye.mesh = s
		eye.material_override = eye_mat
		eye.position = Vector3(side * 0.1, h * 0.72, radius - 0.03)
		body.add_child(eye)
	return body


## A lumpy blanket that covers a hiding student.
static func make_blanket() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Blanket"
	var s := SphereMesh.new()
	s.radius = 0.45
	s.height = 0.7
	s.is_hemisphere = true
	mi.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = BLANKET
	mat.roughness = 1.0
	mi.material_override = mat
	return mi


## Floating "z z z" over a napping student.
static func make_zzz() -> Label3D:
	var l := Label3D.new()
	l.name = "Zzz"
	l.text = "z z z"
	l.font_size = 48
	l.pixel_size = 0.007
	l.outline_size = 12
	l.modulate = PAPER
	l.outline_modulate = INK
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	return l


## Mood icon for a low need. Each need has its own face shape (never color alone),
## following the Systems doc: shaky face (Calm), frown (Fun), yawn (Rest).
static func mood_icon(need: String) -> ImageTexture:
	if _icon_cache.has(need):
		return _icon_cache[need]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(n / 2.0, n / 2.0)
	Visuals._disc(img, c, 54.0, INK)
	Visuals._disc(img, c, 48.0, PAPER)
	match need:
		"calm":
			# Shaky face: wide round eyes, zigzag mouth, wobble lines either side.
			Visuals._disc(img, Vector2(48, 54), 8.0, INK)
			Visuals._disc(img, Vector2(80, 54), 8.0, INK)
			var pts := [Vector2(40, 86), Vector2(50, 78), Vector2(59, 86), Vector2(69, 78), Vector2(78, 86), Vector2(88, 78)]
			for i in pts.size() - 1:
				Visuals._thick_line(img, pts[i], pts[i + 1], 5.0, INK)
			for side in [-1.0, 1.0]:
				var x: float = c.x + side * 60.0
				Visuals._thick_line(img, Vector2(x, 44), Vector2(x - side * 4.0, 56), 4.0, INK)
				Visuals._thick_line(img, Vector2(x - side * 4.0, 56), Vector2(x, 68), 4.0, INK)
		"fun":
			# Frown: dot eyes, mouth curving down.
			Visuals._disc(img, Vector2(48, 54), 6.0, INK)
			Visuals._disc(img, Vector2(80, 54), 6.0, INK)
			var prev := Vector2.ZERO
			for i in 13:
				var t := float(i) / 12.0
				var p := Vector2(lerpf(42, 86, t), 92 - sin(t * PI) * 14.0)
				if i > 0:
					Visuals._thick_line(img, prev, p, 5.0, INK)
				prev = p
		"rest":
			# Yawn: closed-eye dashes, big round open mouth, a little z.
			Visuals._thick_line(img, Vector2(40, 54), Vector2(54, 54), 5.0, INK)
			Visuals._thick_line(img, Vector2(74, 54), Vector2(88, 54), 5.0, INK)
			Visuals._disc(img, Vector2(64, 84), 13.0, INK)
			Visuals._disc(img, Vector2(64, 84), 7.0, Color("E05A68"))
			Visuals._thick_line(img, Vector2(96, 16), Vector2(114, 16), 4.0, INK)
			Visuals._thick_line(img, Vector2(114, 16), Vector2(96, 32), 4.0, INK)
			Visuals._thick_line(img, Vector2(96, 32), Vector2(114, 32), 4.0, INK)
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[need] = tex
	return tex
