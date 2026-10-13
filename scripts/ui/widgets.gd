extends RefCounted
## Drawn pieces of the Make-Believe Academy design system: Phosphor sticker icons, the
## Giggles coin, cut paper, washi tape, stamps, skill bars, the term and trust meters,
## placement marks, toggles. Each mirrors a component in the design system bundle.

const Style := preload("res://scripts/ui/ui_style.gd")
const ICONS_PATH := "res://ui/icons/phosphor.json"
const BADGE_PATH := "res://ui/art/badge-felt-star.png"

static var _svg := {}
static var _tex := {}


## The SVG of a Phosphor icon, white-filled so it can take any color.
static func icon_svg(icon: String, weight: String) -> String:
	if _svg.is_empty():
		var res = load(ICONS_PATH)
		var data = res.data if res is JSON else JSON.parse_string(FileAccess.get_file_as_string(ICONS_PATH))
		if data is Dictionary:
			_svg = data
	return _svg.get("%s-%s" % [icon, weight], "")


## A Phosphor icon rendered at twice `px` for crisp scaling, cached.
static func icon_texture(icon: String, px: int, weight := "fill") -> Texture2D:
	var key := "%s-%s-%d" % [icon, weight, px]
	if _tex.has(key):
		return _tex[key]
	var svg := icon_svg(icon, weight)
	if svg == "":
		return null
	var img := Image.new()
	if img.load_svg_from_string(svg, px * 2.0 / 256.0) != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex


## The slider knob: a paper circle with a 3px ink rim on a wood under-edge.
static func knob_texture(px := 30) -> Texture2D:
	var key := "knob%d" % px
	if _tex.has(key):
		return _tex[key]
	var h := px + 3
	var img := Image.create(px, h, false, Image.FORMAT_RGBA8)
	var c := Vector2(px, px) / 2.0
	var r := px / 2.0 - 0.5
	for y in h:
		for x in px:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(c)
			var du := p.distance_to(c + Vector2(0, 3))
			var col := Color(0, 0, 0, 0)
			if du <= r:
				col = Style.WOOD
				col.a = clampf(r - du + 0.5, 0.0, 1.0)
			if d <= r:
				var face := Style.INK if d > r - 3.0 else Style.PAPER
				face.a = clampf(r - d + 0.5, 0.0, 1.0)
				col = col.blend(face) if col.a > 0 else face
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex


## A Phosphor icon (components/core/Icon.jsx). `outlined` = the sticker look: an ink
## die-cut outline around a filled glyph.
class Icon extends Control:
	var shape := ""
	var color := Style.INK
	var weight := "fill"
	var outlined := false
	var px := 24

	func _init(icon_name: String, size_px := 24.0, ink := Style.INK, icon_weight := "fill", sticker := false) -> void:
		shape = icon_name
		color = ink
		weight = icon_weight
		outlined = sticker
		px = int(size_px)
		custom_minimum_size = Vector2(size_px, size_px)
		size = custom_minimum_size
		pivot_offset = size / 2.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_icon(icon_name: String, ink := Color(-1, 0, 0)) -> void:
		shape = icon_name
		if ink.r >= 0:
			color = ink
		queue_redraw()

	func _draw() -> void:
		var tex: Texture2D = load("res://scripts/ui/widgets.gd").icon_texture(shape, px, weight)
		if tex == null:
			return
		var s := minf(size.x, size.y)
		var r := Rect2((size - Vector2(s, s)) / 2.0, Vector2(s, s))
		if outlined:
			var o := maxf(1.5, s / 28.0)
			for i in 8:
				var a := i * TAU / 8.0
				draw_texture_rect(tex, Rect2(r.position + Vector2(cos(a), sin(a)) * o, r.size), false, Style.INK)
		draw_texture_rect(tex, r, false, color)


## The Giggles coin (components/core/Coin.jsx): honey, a honey-deep rim, a pale inner
## ring, a wood under-edge, and a star.
class Coin extends Control:
	var big_shadow := false

	func _init(px := 24.0, with_star := true, tilt_deg := 0.0) -> void:
		custom_minimum_size = Vector2(px, px)
		size = custom_minimum_size
		pivot_offset = size / 2.0
		rotation_degrees = tilt_deg
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var star := Icon.new("star", roundi(px * 0.52), Style.HONEY_DEEP, "fill", px >= 40)
		star.position = (custom_minimum_size - star.size) / 2.0
		star.visible = with_star
		add_child(star)

	func _draw() -> void:
		var r := minf(size.x, size.y) / 2.0
		var c := size / 2.0
		var b := maxf(2.0, roundf(r * 2.0 / 16.0))
		if big_shadow:
			draw_circle(c + Vector2(0, 8), r, Color(Style.INK, 0.18))
		draw_circle(c + Vector2(0, maxf(1.0, roundf(r / 10.0))), r, Style.WOOD)
		draw_circle(c, r, Style.HONEY_DEEP)
		draw_circle(c, r - b, Style.COIN_RING)
		draw_circle(c, r - b - maxf(1.0, roundf(r * 2.0 / 14.0)), Style.HONEY)


## Cut paper (components/core/PaperCard.jsx): a hand-cut edge (cut a, b, c, or none), a
## crisp paper-shadow under-edge plus a soft cast shadow. Tones: paper, tan, lined, night,
## board. `edge` adds the 4px cardboard inset of a Department form.
class Paper extends PanelContainer:
	const CUTS := {
		"a": [[0.8, 1.6], [24, 0.4], [51, 1.2], [77, 0], [99.3, 1], [100, 34], [99.1, 67], [99.6, 98.6], [73, 100], [47, 98.9], [22, 100], [0.4, 99], [0, 64], [0.9, 31]],
		"b": [[0, 0.6], [31, 1.4], [62, 0], [100, 1.2], [99.2, 29], [100, 58], [99.4, 100], [66, 98.8], [35, 100], [1, 99.2], [0.4, 70], [1, 38]],
		"c": [[1.2, 0], [40, 1], [72, 0.2], [98.8, 1.4], [100, 46], [98.9, 99], [58, 100], [26, 98.7], [0, 99.6], [0.7, 52]],
	}
	var tone := "paper"
	var cut := "a"
	var edge := false
	var line_offset := 26.0

	func _init(paper_tone := "paper", margin: Variant = 18, cut_name := "a", tilt := 0.0, inset_edge := false) -> void:
		tone = paper_tone
		cut = cut_name
		edge = inset_edge
		var sb := StyleBoxEmpty.new()
		if margin is Vector4:
			sb.content_margin_top = margin.x
			sb.content_margin_right = margin.y
			sb.content_margin_bottom = margin.z
			sb.content_margin_left = margin.w
		else:
			sb.set_content_margin_all(float(margin))
		add_theme_stylebox_override("panel", sb)
		rotation_degrees = tilt
		resized.connect(func(): pivot_offset = size / 2.0)

	func _outline() -> PackedVector2Array:
		if cut == "none" or not CUTS.has(cut):
			return PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
		var pts := PackedVector2Array()
		for p in CUTS[cut]:
			pts.append(Vector2(size.x * p[0] / 100.0, size.y * p[1] / 100.0))
		return pts

	func _shifted(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
		var out := PackedVector2Array()
		for q in pts:
			out.append(q + by)
		return out

	func _draw() -> void:
		if size.x < 4 or size.y < 4:
			return
		var pts := _outline()
		var fill := Style.PAPER
		match tone:
			"tan":
				fill = Style.TAB_TAN_LIGHT
			"night":
				fill = Style.INDIGO
			"board":
				fill = Style.BOARD
		# Soft cast shadow, then the crisp under-edge (--drop-paper).
		draw_colored_polygon(_shifted(pts, Vector2(0, 7)), Color(Style.INK, 0.07))
		draw_colored_polygon(_shifted(pts, Vector2(0, 5)), Color(Style.INK, 0.07))
		draw_colored_polygon(_shifted(pts, Vector2(0, 2)), Style.PAPER_SHADOW)
		draw_colored_polygon(pts, fill)
		if tone == "lined":
			var y := line_offset + 31.0
			while y < size.y - 6:
				draw_line(Vector2(3, y + 1), Vector2(size.x - 3, y + 1), Style.PAPER_LINE, 2.0)
				y += 33.0
			draw_line(Vector2(35, 2), Vector2(35, size.y - 2), Style.PAPER_MARGIN, 2.0)
		if edge:
			var e := PackedVector2Array()
			var c := size / 2.0
			for q in pts:
				e.append(q + (c - q).normalized() * 2.0)
			e.append(e[0])
			draw_polyline(e, Style.CARDBOARD, 4.0, true)


## Washi tape (components/core/WashiTape.jsx): 86% opacity, zigzag torn ends, stripes or dots.
class Washi extends Control:
	const SHAPE := [[2, 0], [98, 0], [100, 20], [97, 40], [100, 60], [97, 80], [99, 100], [1, 100], [3, 80], [0, 60], [3, 40], [0, 20]]
	var color := Style.HONEY
	var pattern := "stripes"

	func _init(c: Color, px := Vector2(96, 26), pat := "stripes") -> void:
		color = c
		pattern = pat
		custom_minimum_size = px
		size = px
		pivot_offset = px / 2.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var poly := PackedVector2Array()
		for p in SHAPE:
			poly.append(Vector2(size.x * p[0] / 100.0, size.y * p[1] / 100.0))
		draw_colored_polygon(poly, Color(color, 0.86))
		if pattern == "stripes":
			var x := -size.y
			while x < size.x:
				var band := PackedVector2Array([Vector2(x, size.y), Vector2(x + 5.0, size.y), Vector2(x + 5.0 + size.y, 0), Vector2(x + size.y, 0)])
				for part in Geometry2D.intersect_polygons(band, poly):
					draw_colored_polygon(part, Color(Style.PAPER, 0.4))
				x += 10.0
		elif pattern == "dots":
			var yy := 5.0
			while yy < size.y:
				var xx := 5.0
				while xx < size.x - 3:
					draw_circle(Vector2(xx, yy), 2.0, Color(Style.PAPER, 0.62))
					xx += 10.0
				yy += 10.0


## A rubber stamp (components/paper/Stamp.jsx): uppercase, wide-spaced, a double rim,
## at 88% so the paper shows through, with an optional sub line ("TERM 1 · DAY 8").
class Stamp extends PanelContainer:
	var color := Style.HEART_DEEP

	func _init(text: String, c := Style.HEART_DEEP, size_px := 28, angle := -12.0, sub := "") -> void:
		color = c
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = 19
		sb.content_margin_right = 19
		sb.content_margin_top = 10
		sb.content_margin_bottom = 11
		add_theme_stylebox_override("panel", sb)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(col)
		var l := Label.new()
		l.text = text.to_upper()
		l.add_theme_font_override("font", Style.font(700, roundi(size_px * 0.14)))
		l.add_theme_font_size_override("font_size", size_px)
		l.add_theme_color_override("font_color", c)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		if sub != "":
			var line := ColorRect.new()
			line.color = c
			line.custom_minimum_size = Vector2(0, 2)
			col.add_child(line)
			var s := Label.new()
			s.text = sub.to_upper()
			s.add_theme_font_override("font", Style.font(700, maxi(1, roundi(size_px * 0.04))))
			s.add_theme_font_size_override("font_size", roundi(size_px * 0.42))
			s.add_theme_color_override("font_color", c)
			s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(s)
		rotation_degrees = angle
		modulate.a = 0.88
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(func(): pivot_offset = size / 2.0)

	func _draw() -> void:
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = color
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		draw_style_box(sb, r)
		sb.set_corner_radius_all(5)
		draw_style_box(sb, r.grow(-3.5))


## A skill meter (components/meters/SkillBar.jsx): segments, solid dark (wood), fresh
## striped tan with a wood rim (can fade), the rest sand. A coral tick marks a request's
## level; an ink notch marks the teacher's cap.
class DotBar extends Control:
	var solid := 0.0
	var fresh := 0.0
	var dots := 10
	var cap := -1.0
	var target := -1.0

	func _init(count := 10, px := Vector2(150, 10)) -> void:
		dots = count
		custom_minimum_size = px
		mouse_filter = Control.MOUSE_FILTER_PASS

	func set_values(s: float, f: float, cap_level := -1.0, target_level := -1.0) -> void:
		solid = s
		fresh = f
		cap = cap_level
		target = target_level
		queue_redraw()

	func _draw() -> void:
		var gap := 3.0
		var w := (size.x - gap * (dots - 1)) / dots
		var h := size.y
		var ns := floori(solid + 0.0001)
		var nf := floori(solid + fresh + 0.0001) - ns
		for i in dots:
			var r := Rect2(Vector2(i * (w + gap), 0), Vector2(w, h))
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(3)
			if i == 0:
				sb.corner_radius_top_left = 6
				sb.corner_radius_bottom_left = 6
			if i == dots - 1:
				sb.corner_radius_top_right = 6
				sb.corner_radius_bottom_right = 6
			var kind := "solid" if i < ns else ("fresh" if i < ns + nf else "empty")
			match kind:
				"solid":
					sb.bg_color = Style.WOOD
				"fresh":
					sb.bg_color = Style.TAB_TAN
					sb.border_color = Style.WOOD
					sb.set_border_width_all(2)
				_:
					sb.bg_color = Style.PAPER_SHADOW
			draw_style_box(sb, r)
			if kind == "fresh":
				var x := r.position.x - h
				while x < r.end.x:
					var band := PackedVector2Array([Vector2(x, h), Vector2(x + 3, h), Vector2(x + 3 + h, 0), Vector2(x + h, 0)])
					var box := PackedVector2Array([r.position + Vector2(2, 2), Vector2(r.end.x - 2, r.position.y + 2), r.end - Vector2(2, 2), Vector2(r.position.x + 2, r.end.y - 2)])
					for part in Geometry2D.intersect_polygons(band, box):
						draw_colored_polygon(part, Color(Style.PAPER, 0.6))
					x += 6.0
			elif kind == "empty":
				draw_line(r.position + Vector2(2, 1), Vector2(r.end.x - 2, r.position.y + 1), Color(Style.INK, 0.15), 2.0)
		if cap >= 0.0 and cap < dots:
			var cx := cap * (w + gap) - gap / 2.0
			draw_line(Vector2(cx, -3), Vector2(cx, h + 3), Style.INK, 2.0)
		if target > 0.0:
			var tx := target * (w + gap) - gap / 2.0
			draw_line(Vector2(tx, -4), Vector2(tx, h + 4), Style.HEART, 3.0)


## The Term clock bar (TermClock): a 16px wood track, a green fill inset 3px with a light
## top, and a peach-rose marker with an ink rim.
class ClockBar extends Control:
	var value := 0.5

	func _init(px := Vector2(280, 16)) -> void:
		custom_minimum_size = px
		mouse_filter = Control.MOUSE_FILTER_PASS

	func set_value(v: float) -> void:
		value = clampf(v, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var h := size.y
		var track := StyleBoxFlat.new()
		track.bg_color = Style.WOOD
		track.set_corner_radius_all(int(h / 2.0))
		draw_style_box(track, Rect2(Vector2.ZERO, size))
		var fw := size.x * value - 6.0
		if fw > 2.0:
			var f := StyleBoxFlat.new()
			f.bg_color = Style.GREEN
			f.set_corner_radius_all(int((h - 6) / 2.0))
			draw_style_box(f, Rect2(Vector2(3, 3), Vector2(fw, h - 6)))
			if fw > 10:
				draw_line(Vector2(7, 4.5), Vector2(fw - 2, 4.5), Color(Style.PAPER, 0.35), 3.0)
		var k := StyleBoxFlat.new()
		k.bg_color = Style.PEACH
		k.border_color = Style.INK
		k.set_border_width_all(2)
		k.set_corner_radius_all(6)
		draw_style_box(k, Rect2(Vector2(size.x * value - 6, -5), Vector2(12, 26)))


## The Kids' Trust bar (TrustMeter): a 24px wood track, a coral fill with paler ticks every
## 20px, and a green "gain" piece showing what's coming.
class TrustBar extends Control:
	var value := 0.5
	var gain := 0.0

	func _init(px := Vector2(220, 24)) -> void:
		custom_minimum_size = px
		mouse_filter = Control.MOUSE_FILTER_PASS

	func set_values(v: float, g := 0.0) -> void:
		value = clampf(v, 0.0, 1.0)
		gain = clampf(g, 0.0, 1.0 - value)
		queue_redraw()

	func _draw() -> void:
		var h := size.y
		var track := StyleBoxFlat.new()
		track.bg_color = Style.WOOD
		track.set_corner_radius_all(int(h / 2.0))
		draw_style_box(track, Rect2(Vector2.ZERO, size))
		var fw := size.x * value - 4.0
		if fw > 2.0:
			var f := StyleBoxFlat.new()
			f.bg_color = Style.HEART
			f.corner_radius_top_left = int((h - 8) / 2.0)
			f.corner_radius_bottom_left = int((h - 8) / 2.0)
			draw_style_box(f, Rect2(Vector2(4, 4), Vector2(fw, h - 8)))
			var x := 22.0
			while x < fw:
				draw_line(Vector2(x, 4), Vector2(x, h - 4), Color("E9707C"), 2.0)
				x += 20.0
			draw_line(Vector2(10, 5.5), Vector2(fw, 5.5), Color(Style.PAPER, 0.3), 3.0)
		if gain > 0.0:
			draw_rect(Rect2(Vector2(size.x * value, 4), Vector2(size.x * gain, h - 8)), Style.GREEN)


## The loading bar (mockup 06): a wood track with a 3px paper rim and a green fill under
## washi stripes that slide along.
class LoadBar extends Control:
	var value := 0.0
	var offset := 0.0

	func _init(px := Vector2(520, 22)) -> void:
		custom_minimum_size = px
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if not Settings.reduce_motion:
			offset = fmod(offset + delta * 24.0, 10.0)
		queue_redraw()

	func _draw() -> void:
		var h := size.y
		var sb := StyleBoxFlat.new()
		sb.bg_color = Style.WOOD
		sb.border_color = Style.PAPER
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(int(h / 2.0))
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var inner := Rect2(Vector2(3, 3), Vector2((size.x - 6) * clampf(value, 0.0, 1.0), h - 6))
		if inner.size.x < 4:
			return
		var f := StyleBoxFlat.new()
		f.bg_color = Style.GREEN
		f.set_corner_radius_all(int(inner.size.y / 2.0))
		draw_style_box(f, inner)
		var box := PackedVector2Array([inner.position + Vector2(4, 0), Vector2(inner.end.x - 4, inner.position.y), inner.end - Vector2(4, 0), Vector2(inner.position.x + 4, inner.end.y)])
		var x := inner.position.x - inner.size.y + offset - 10.0
		while x < inner.end.x:
			var band := PackedVector2Array([Vector2(x, inner.end.y), Vector2(x + 5, inner.end.y), Vector2(x + 5 + inner.size.y, inner.position.y), Vector2(x + inner.size.y, inner.position.y)])
			for part in Geometry2D.intersect_polygons(band, box):
				draw_colored_polygon(part, Color(Style.PAPER, 0.45))
			x += 10.0


## Valid or invalid (components/feedback/PlacementMark.jsx): a green circle with a check,
## or a coral square tilted -6° with an X. Shape, not only color.
class PlacementMark extends Control:
	var valid := true

	func _init(ok := true, px := 32.0) -> void:
		valid = ok
		custom_minimum_size = Vector2(px, px + 3)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := Icon.new("check-fat" if ok else "x", roundi(px * 0.56), Style.PAPER, "fill" if ok else "bold")
		ic.position = Vector2(px, px) / 2.0 - ic.size / 2.0
		add_child(ic)

	func _draw() -> void:
		var s := custom_minimum_size.x
		var sb := StyleBoxFlat.new()
		sb.bg_color = Style.GREEN if valid else Style.HEART
		sb.border_color = Style.INK
		sb.set_border_width_all(3 if s >= 24 else 2)
		sb.set_corner_radius_all(int(s / 2.0) if valid else roundi(s * 0.22))
		sb.shadow_color = Style.INK
		sb.shadow_size = 1
		sb.shadow_offset = Vector2(0, 3 if s >= 24 else 2)
		if not valid:
			draw_set_transform(Vector2(s, s) / 2.0, deg_to_rad(-6), Vector2.ONE)
			draw_style_box(sb, Rect2(-Vector2(s, s) / 2.0, Vector2(s, s)))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_style_box(sb, Rect2(Vector2.ZERO, Vector2(s, s)))


## Badge kept for older callers: the PlacementMark at a small size.
class Badge extends PlacementMark:
	func _init(is_ok := true, px := 18.0) -> void:
		super(is_ok, px)


## A "note" badge: a honey circle with an exclamation mark (a warning reason).
class Note extends Control:
	func _init(px := 18.0) -> void:
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := size.x / 2.0
		var c := size / 2.0
		draw_circle(c, r - 1, Style.HONEY)
		draw_arc(c, r - 1, 0, TAU, 24, Style.INK, 2.0, true)
		draw_line(c + Vector2(0, -r * 0.5), c + Vector2(0, r * 0.15), Style.INK, 2.4, true)
		draw_circle(c + Vector2(0, r * 0.45), 1.6, Style.INK)


## A form checkbox (RequestForm): an 18px square with an ink rim, ticked or empty.
class CheckSquare extends Control:
	var ticked := false

	func _init(on := false, px := 18.0) -> void:
		ticked = on
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = Style.INK
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if ticked:
			var s := size.x
			draw_polyline(PackedVector2Array([Vector2(s * 0.2, s * 0.5), Vector2(s * 0.42, s * 0.74), Vector2(s * 0.86, s * 0.18)]), Style.GREEN_DEEP, 3.0, true)


## The settings toggle (mockup 03): a 68x36 pill with a 3px ink rim, green when on and
## sand when off, and a paper knob holding a check or an X.
class Toggle extends Control:
	signal toggled(on: bool)
	var on := false
	var _icon: Icon

	func _init(start := false) -> void:
		on = start
		custom_minimum_size = Vector2(68, 36)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_icon = Icon.new("check" if on else "x", 12, Style.INK, "bold")
		add_child(_icon)
		_place()

	func _knob_x() -> float:
		return 37.0 if on else 6.0

	func _place() -> void:
		_icon.set_icon("check" if on else "x")
		_icon.position = Vector2(_knob_x() + 6, 12)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			on = not on
			_place()
			queue_redraw()
			toggled.emit(on)
			accept_event()

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Style.GREEN if on else Style.PAPER_SHADOW
		sb.border_color = Style.INK
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(18)
		draw_style_box(sb, Rect2(Vector2.ZERO, Vector2(68, 36)))
		var k := StyleBoxFlat.new()
		k.bg_color = Style.PAPER
		k.border_color = Style.INK
		k.set_border_width_all(2)
		k.set_corner_radius_all(12)
		draw_style_box(k, Rect2(Vector2(_knob_x(), 6), Vector2(24, 24)))


## The Academy badge (logo A, felt patch) from the design system's assets.
class Seal extends TextureRect:
	func _init(px := 96.0) -> void:
		texture = load(BADGE_PATH)
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE


## The portrait slot (StudentCard): sky-light with paper stripes at 135° and an inset rim.
class Stripes extends Control:
	var color := Style.SKY_LIGHT

	func _init(c := Style.SKY_LIGHT) -> void:
		color = c
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(10)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var box := PackedVector2Array([Vector2(3, 3), Vector2(size.x - 3, 3), size - Vector2(3, 3), Vector2(3, size.y - 3)])
		var x := -size.y
		while x < size.x:
			var band := PackedVector2Array([Vector2(x, size.y), Vector2(x + 14, size.y), Vector2(x + 14 + size.y, 0), Vector2(x + size.y, 0)])
			for part in Geometry2D.intersect_polygons(band, box):
				draw_colored_polygon(part, Color(Style.PAPER, 0.35))
			x += 28.0
		var rim := StyleBoxFlat.new()
		rim.draw_center = false
		rim.border_color = Color(Style.WOOD, 0.18)
		rim.set_border_width_all(3)
		rim.set_corner_radius_all(10)
		draw_style_box(rim, Rect2(Vector2.ZERO, size))


## A dashed outline (Empty Cubby, "Not discovered yet") or a dashed rule (height ≤ width).
class Dashed extends Control:
	var color := Style.CARDBOARD
	var width := 3.0
	var dash := 9.0

	func _init(c := Style.CARDBOARD, w := 3.0) -> void:
		color = c
		width = w
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if size.y <= width + 1:
			_dashes(Vector2(0, size.y / 2.0), Vector2(size.x, size.y / 2.0))
			return
		var r := Rect2(Vector2(width / 2.0, width / 2.0), size - Vector2(width, width))
		_dashes(r.position, Vector2(r.end.x, r.position.y))
		_dashes(Vector2(r.end.x, r.position.y), r.end)
		_dashes(r.end, Vector2(r.position.x, r.end.y))
		_dashes(Vector2(r.position.x, r.end.y), r.position)

	func _dashes(a: Vector2, b: Vector2) -> void:
		var n := maxi(1, int(a.distance_to(b) / dash))
		for i in n:
			if i % 2 == 0:
				draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), color, width)


## A student's graybox portrait: their capsule with eyes and a smile (until the art pass).
class Portrait extends Control:
	var body_color := Color.GRAY
	var horns := false

	func _init(color: Color, px := Vector2(40, 48), _on_card := false, with_horns := false) -> void:
		body_color = color
		horns = with_horns
		custom_minimum_size = px
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var bw := size.x * 0.5
		var bh := size.y * 0.85
		var rect := Rect2(Vector2((size.x - bw) / 2.0, size.y - bh), Vector2(bw, bh + bw))
		var sb := StyleBoxFlat.new()
		sb.bg_color = body_color
		sb.border_color = Style.INK
		sb.set_border_width_all(maxi(2, int(bw / 20.0)))
		sb.set_corner_radius_all(int(bw / 2.0))
		if horns:
			var hx := rect.position.x + bw * 0.2
			var hy := rect.position.y + bw * 0.12
			draw_colored_polygon(PackedVector2Array([Vector2(hx, hy + bw * 0.1), Vector2(hx - bw * 0.1, hy - bw * 0.3), Vector2(hx + bw * 0.22, hy)]), body_color)
			draw_colored_polygon(PackedVector2Array([Vector2(hx + bw * 0.6, hy + bw * 0.1), Vector2(hx + bw * 0.7, hy - bw * 0.3), Vector2(hx + bw * 0.38, hy)]), body_color)
		draw_style_box(sb, rect)
		var eye_y := rect.position.y + bw * 0.55
		var er := maxf(2.0, bw * 0.08)
		draw_circle(Vector2(size.x / 2.0 - bw * 0.18, eye_y), er, Style.INK)
		draw_circle(Vector2(size.x / 2.0 + bw * 0.18, eye_y), er, Style.INK)
		draw_arc(Vector2(size.x / 2.0, eye_y + bw * 0.14), bw * 0.16, 0.4, PI - 0.4, 12, Style.INK, maxf(2.0, bw / 24.0), true)


## Lined paper (the Letter's stock): cut c, a pink margin line, blue rules every 33px.
class Notebook extends Paper:
	func _init(_gap := 33.0, _first_line := 26.0, _margin_line_x := 35.0) -> void:
		super("lined", Vector4(26, 24, 30, 50), "c")


## An item's sticker for its card: the Phosphor icon chosen for it, in wood.
class ItemIcon extends Control:
	var data: ItemData

	func _init(d: ItemData, px := 30.0) -> void:
		data = d
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := Icon.new(item_icon(d), px, Style.WOOD, "fill")
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(ic)

	static func item_icon(d: ItemData) -> String:
		match String(d.id):
			"toy_chest": return "treasure-chest"
			"nightlight": return "lamp"
			"pillow_bed": return "bed"
			"floor_cushion": return "couch"
			"cardboard_boxes": return "cube"
			"tamed_closet_monster": return "paw-print"
			"calm_down_corner": return "armchair"
			"teachers_armchair": return "armchair"
			"chalkboard_easel": return "chalkboard-simple"
			"dream_door": return "door"
			"fidget_box": return "puzzle-piece"
			"glow_stars": return "star-four"
			"milk_and_cookies_cart": return "cookie"
			"monster_costume_rack": return "mask-happy"
			"partition_wall": return "wall"
			"rubber_duck": return "bathtub"
			"small_group_table": return "table"
			"story_corner_rug": return "book-open"
			"tea_party_set": return "coffee"
			"thunder_in_a_jar": return "lightning"
			"whoopee_cushion": return "balloon"
			"graduate_keepsake": return "medal"
		return "cube"

	## The card tint for an item, by what kind of thing it is (ItemCard tints).
	static func item_tint(d: ItemData) -> Color:
		match d.type:
			"Light":
				return Style.HONEY
			"Comfort":
				return Style.LAVENDER_LIGHT
			"Fun":
				return Style.LIME
			"Structure":
				return Style.TAB_TAN_LIGHT
			"Regulation":
				return Style.SKY_LIGHT
			"Decor":
				return Style.PEACH_LIGHT
		return Style.SKY_LIGHT


## A heart sticker (kept for older callers).
class Heart extends Icon:
	func _init(_filled := true) -> void:
		super("heart", 20, Style.HEART, "fill", true)
