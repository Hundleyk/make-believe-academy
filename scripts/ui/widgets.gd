extends RefCounted
## Small drawn pieces of the stationery UI (UI System doc, "Building blocks").
## Each is a Control that draws itself, so nothing depends on an emoji or a font glyph.

const Style := preload("res://scripts/ui/ui_style.gd")


## The Giggles coin: a gold coin with a star (mockups' Giggles tag). `star` false = a plain
## small coin for prices.
class Coin extends Control:
	var star := true

	func _init(px := 30.0, with_star := true) -> void:
		star = with_star
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := minf(size.x, size.y) / 2.0
		var c := size / 2.0
		draw_circle(c + Vector2(0, r * 0.08), r - 1, Style.HONEY_DEEP.darkened(0.25))
		draw_circle(c, r - 1, Style.HONEY_DEEP)
		draw_circle(c, r * 0.78, Style.HONEY)
		draw_arc(c, r - 1, 0, TAU, 32, Style.INK if r < 14 else Style.HONEY_DEEP.darkened(0.35), maxf(1.4, r * 0.08), true)
		if star:
			draw_colored_polygon(Icon.star_points(c, r * 0.5, r * 0.22), Style.HONEY_DEEP)
			draw_polyline(Icon.star_points(c, r * 0.5, r * 0.22, true), Style.HONEY_DEEP.darkened(0.3), maxf(1.2, r * 0.05), true)


## One heart of the Kids' Trust meter: filled or just an outline (shape, not only color).
class Heart extends Control:
	var filled := true

	func _init(is_filled := true) -> void:
		filled = is_filled
		custom_minimum_size = Vector2(20, 18)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var pts := PackedVector2Array()
		for i in 33:
			var t := TAU * i / 32.0
			var x := 16.0 * pow(sin(t), 3)
			var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
			var k := size.x / 20.0
			pts.append((Vector2(10, 8) + Vector2(x, y) * 0.55) * k + Vector2(0, (size.y - 18.0 * k) / 2.0))
		if filled:
			draw_colored_polygon(pts, Style.HEART)
		draw_polyline(pts, Style.INK, maxf(1.6, size.x / 14.0), true)


## Check (ok) or cross (not ok) badge, drawn as a shape.
class Badge extends Control:
	var ok := true

	func _init(is_ok := true, px := 18.0) -> void:
		ok = is_ok
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := size.x / 2.0
		var c := size / 2.0
		draw_circle(c, r - 1, Style.OK_GREEN if ok else Style.HEART)
		draw_arc(c, r - 1, 0, TAU, 24, Style.INK, 1.4, true)
		var s := r * 0.5
		if ok:
			draw_polyline(PackedVector2Array([c + Vector2(-s, 0), c + Vector2(-s * 0.2, s * 0.7), c + Vector2(s, -s * 0.6)]), Style.PAPER, 2.2, true)
		else:
			draw_line(c + Vector2(-s, -s), c + Vector2(s, s), Style.PAPER, 2.2, true)
			draw_line(c + Vector2(s, -s), c + Vector2(-s, s), Style.PAPER, 2.2, true)


## A "warning" badge: a honey circle with an exclamation mark.
class Note extends Control:
	func _init(px := 18.0) -> void:
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := size.x / 2.0
		var c := size / 2.0
		draw_circle(c, r - 1, Style.HONEY)
		draw_arc(c, r - 1, 0, TAU, 24, Style.INK, 1.4, true)
		draw_line(c + Vector2(0, -r * 0.5), c + Vector2(0, r * 0.15), Style.INK, 2.2, true)
		draw_circle(c + Vector2(0, r * 0.45), 1.4, Style.INK)


## A skill bar with two shades: solid points (dark) and fresh points (light, fading),
## plus the teacher's cap as a dotted line (Systems doc, learning model).
class TwoShadeBar extends Control:
	var solid := 0.0
	var fresh := 0.0
	var max_level := 6.0
	var cap := -1.0          # teacher's skill level; below 0 hides it
	var target := -1.0       # a request's level, drawn as a coral tick

	func _init() -> void:
		custom_minimum_size = Vector2(140, 12)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func set_values(s: float, f: float, cap_level := -1.0, target_level := -1.0) -> void:
		solid = s
		fresh = f
		cap = cap_level
		target = target_level
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var r := Rect2(Vector2.ZERO, Vector2(w, h))
		draw_rect(r, Color("E9DCC4"), true)
		var sw := w * clampf(solid / max_level, 0.0, 1.0)
		var fw := w * clampf(fresh / max_level, 0.0, 1.0 - solid / max_level)
		draw_rect(Rect2(0, 0, sw, h), Style.WOOD, true)
		draw_rect(Rect2(sw, 0, fw, h), Style.CARDBOARD, true)
		if cap >= 0.0:
			var x := w * clampf(cap / max_level, 0.0, 1.0) - 1.0
			var y := -2.0
			while y < h + 2.0:
				draw_line(Vector2(x, y), Vector2(x, minf(y + 2.5, h + 2.0)), Style.INK, 2.0)
				y += 5.0
		if target >= 0.0:
			var tx := w * clampf(target / max_level, 0.0, 1.0)
			draw_line(Vector2(tx, -3), Vector2(tx, h + 3), Style.HEART, 3.0)


## A student's portrait: their capsule with eyes and a small smile on a colored card.
class Portrait extends Control:
	var body_color := Color.GRAY
	var card := false
	var horns := false

	func _init(color: Color, px := Vector2(40, 48), on_card := false, with_horns := false) -> void:
		body_color = color
		card = on_card
		horns = with_horns
		custom_minimum_size = px
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if card:
			draw_rect(Rect2(Vector2.ZERO, size), body_color.darkened(0.15), true)
		var bw := size.x * (0.42 if card else 0.6)
		var bh := size.y * (0.92 if card else 0.86)
		var rect := Rect2(Vector2((size.x - bw) / 2.0, size.y - bh), Vector2(bw, bh + bw))
		var sb := StyleBoxFlat.new()
		sb.bg_color = body_color.lightened(0.15) if card else body_color
		sb.border_color = Style.INK
		sb.set_border_width_all(3 if card else 2)
		sb.set_corner_radius_all(int(bw / 2.0))
		if horns:
			var hx := rect.position.x + bw * 0.2
			var hy := rect.position.y + bw * 0.12
			draw_colored_polygon(PackedVector2Array([Vector2(hx, hy + bw * 0.1), Vector2(hx - bw * 0.1, hy - bw * 0.3), Vector2(hx + bw * 0.22, hy)]), sb.bg_color)
			draw_colored_polygon(PackedVector2Array([Vector2(hx + bw * 0.6, hy + bw * 0.1), Vector2(hx + bw * 0.7, hy - bw * 0.3), Vector2(hx + bw * 0.38, hy)]), sb.bg_color)
		draw_style_box(sb, rect)
		var eye_y := rect.position.y + bw * 0.55
		var er := maxf(2.0, bw * 0.08)
		draw_circle(Vector2(size.x / 2.0 - bw * 0.18, eye_y), er, Style.INK)
		draw_circle(Vector2(size.x / 2.0 + bw * 0.18, eye_y), er, Style.INK)
		if card:
			draw_arc(Vector2(size.x / 2.0, eye_y + bw * 0.15), bw * 0.18, 0.4, PI - 0.4, 12, Style.INK, 3.0, true)


## Lined notebook paper drawn behind its children (letters and crayon notes).
class Notebook extends PanelContainer:
	var line_gap := 26.0
	var top_pad := 40.0
	var margin_x := 22.0

	func _init(gap := 26.0, first_line := 40.0, margin_line_x := 22.0) -> void:
		line_gap = gap
		top_pad = first_line
		margin_x = margin_line_x
		var sb := StyleBoxFlat.new()
		sb.bg_color = Style.NOTEBOOK
		sb.set_corner_radius_all(4)
		sb.shadow_color = Color(Style.NIGHT, 0.3)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, 4)
		sb.content_margin_left = margin_x + 12
		sb.content_margin_right = 16
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		add_theme_stylebox_override("panel", sb)

	func _draw() -> void:
		var y := top_pad
		while y < size.y - 4:
			draw_line(Vector2(4, y), Vector2(size.x - 4, y), Style.NOTEBOOK_LINE, 1.2)
			y += line_gap
		draw_line(Vector2(margin_x, 0), Vector2(margin_x, size.y), Style.MARGIN_LINE, 2.0)


## A rubber stamp: bordered capital letters at an angle.
class Stamp extends PanelContainer:
	func _init(text: String, color: Color, size_px := 30, angle := -12.0) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = color
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		add_theme_stylebox_override("panel", sb)
		var l := Style.label(text, size_px, 600, color)
		add_child(l)
		rotation_degrees = angle
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate.a = 0.85


## A tiny drawing of an item for its Build menu card: its gray shape in its color.
class ItemIcon extends Control:
	var data: ItemData

	func _init(d: ItemData) -> void:
		data = d
		custom_minimum_size = Vector2(30, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var k := minf(size.x, size.y) / 30.0
		var col := data.gray_color
		var line := maxf(1.6, k * 1.4)
		match data.gray_shape:
			"sphere":
				draw_circle(c, 11 * k, col)
				draw_arc(c, 11 * k, 0, TAU, 32, Style.INK, line, true)
			"cylinder":
				var r := Rect2(c - Vector2(11, 6) * k, Vector2(22, 14) * k)
				draw_rect(r, col, true)
				draw_rect(r, Style.INK, false, line)
			_:
				var sz := Vector2(22, 18)
				if data.gray_size != Vector3.ZERO:
					var gs := Vector2(data.gray_size.x, maxf(data.gray_size.y, data.gray_size.z))
					sz = gs / maxf(gs.x, gs.y) * 24.0
					sz = sz.max(Vector2(6, 6))
				sz *= k
				var r := Rect2(c - sz / 2.0, sz)
				draw_rect(r, col, true)
				draw_rect(r, Style.INK, false, line)
		if data.gray_glow:
			draw_circle(c + Vector2(0, -2) * k, 4.0 * k, Color(Style.HONEY, 0.9))


## Small drawn icons for buttons and tiles. Each is a few strokes in ink, so nothing depends
## on an emoji or an icon font. Names: play, plus, folder, gear, star, door, pause, fast,
## save, home, back, reset, check, trash, close, hammer, calendar, students, staff,
## requests, eye, moon, letter, sell, clock, credits.
class Icon extends Control:
	var shape := ""
	var color := Style.INK

	func _init(icon_name: String, px := 22.0, ink := Style.INK) -> void:
		shape = icon_name
		color = ink
		custom_minimum_size = Vector2(px, px)
		size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	static func star_points(c: Vector2, outer: float, inner: float, closed := false) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI / 2.0 + i * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * (outer if i % 2 == 0 else inner))
		if closed:
			pts.append(pts[0])
		return pts

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var o := (size - Vector2(s, s)) / 2.0
		var w := maxf(1.8, s * 0.11)
		var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
		var col := color
		match shape:
			"play":
				draw_colored_polygon(PackedVector2Array([p.call(0.3, 0.18), p.call(0.82, 0.5), p.call(0.3, 0.82)]), col)
			"plus":
				draw_line(p.call(0.5, 0.15), p.call(0.5, 0.85), col, w * 1.3, true)
				draw_line(p.call(0.15, 0.5), p.call(0.85, 0.5), col, w * 1.3, true)
			"folder":
				draw_colored_polygon(PackedVector2Array([p.call(0.08, 0.22), p.call(0.4, 0.22), p.call(0.48, 0.32), p.call(0.92, 0.32), p.call(0.92, 0.82), p.call(0.08, 0.82)]), col)
				draw_line(p.call(0.14, 0.44), p.call(0.86, 0.44), Style.PAPER, w * 0.6)
			"gear":
				var c: Vector2 = p.call(0.5, 0.5)
				for i in 8:
					var a := i * TAU / 8.0
					draw_line(c + Vector2(cos(a), sin(a)) * s * 0.22, c + Vector2(cos(a), sin(a)) * s * 0.44, col, s * 0.15)
				draw_circle(c, s * 0.3, col)
				draw_circle(c, s * 0.12, Style.PAPER)
			"star":
				draw_colored_polygon(star_points(p.call(0.5, 0.53), s * 0.46, s * 0.2), col)
			"door":
				draw_rect(Rect2(p.call(0.22, 0.1), Vector2(s * 0.56, s * 0.82)), col, false, w)
				draw_circle(p.call(0.64, 0.54), s * 0.06, col)
				draw_line(p.call(0.1, 0.92), p.call(0.9, 0.92), col, w)
			"pause":
				draw_rect(Rect2(p.call(0.2, 0.15), Vector2(s * 0.2, s * 0.7)), col)
				draw_rect(Rect2(p.call(0.6, 0.15), Vector2(s * 0.2, s * 0.7)), col)
			"fast":
				draw_colored_polygon(PackedVector2Array([p.call(0.08, 0.2), p.call(0.5, 0.5), p.call(0.08, 0.8)]), col)
				draw_colored_polygon(PackedVector2Array([p.call(0.48, 0.2), p.call(0.92, 0.5), p.call(0.48, 0.8)]), col)
			"save":
				draw_colored_polygon(PackedVector2Array([p.call(0.12, 0.12), p.call(0.72, 0.12), p.call(0.88, 0.28), p.call(0.88, 0.88), p.call(0.12, 0.88)]), col)
				draw_rect(Rect2(p.call(0.28, 0.12), Vector2(s * 0.36, s * 0.22)), Style.PAPER)
				draw_rect(Rect2(p.call(0.26, 0.55), Vector2(s * 0.48, s * 0.25)), Style.PAPER)
			"home":
				draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.1), p.call(0.92, 0.48), p.call(0.08, 0.48)]), col)
				draw_rect(Rect2(p.call(0.2, 0.46), Vector2(s * 0.6, s * 0.42)), col)
				draw_rect(Rect2(p.call(0.43, 0.62), Vector2(s * 0.16, s * 0.26)), Style.PAPER)
			"back":
				draw_line(p.call(0.85, 0.5), p.call(0.2, 0.5), col, w * 1.2, true)
				draw_polyline(PackedVector2Array([p.call(0.48, 0.2), p.call(0.16, 0.5), p.call(0.48, 0.8)]), col, w * 1.2, true)
			"reset":
				draw_arc(p.call(0.5, 0.52), s * 0.32, -PI * 0.4, PI * 1.35, 20, col, w, true)
				draw_colored_polygon(PackedVector2Array([p.call(0.62, 0.05), p.call(0.86, 0.26), p.call(0.56, 0.36)]), col)
			"check":
				draw_polyline(PackedVector2Array([p.call(0.15, 0.52), p.call(0.4, 0.78), p.call(0.86, 0.22)]), col, w * 1.4, true)
			"trash":
				draw_rect(Rect2(p.call(0.24, 0.3), Vector2(s * 0.52, s * 0.6)), col)
				draw_line(p.call(0.14, 0.22), p.call(0.86, 0.22), col, w)
				draw_rect(Rect2(p.call(0.4, 0.1), Vector2(s * 0.2, s * 0.1)), col)
			"close":
				draw_line(p.call(0.2, 0.2), p.call(0.8, 0.8), col, w * 1.4, true)
				draw_line(p.call(0.8, 0.2), p.call(0.2, 0.8), col, w * 1.4, true)
			"hammer":
				draw_line(p.call(0.3, 0.88), p.call(0.6, 0.38), col, w * 1.2, true)
				draw_colored_polygon(PackedVector2Array([p.call(0.36, 0.22), p.call(0.66, 0.08), p.call(0.9, 0.42), p.call(0.62, 0.56)]), col)
			"calendar":
				draw_rect(Rect2(p.call(0.12, 0.2), Vector2(s * 0.76, s * 0.7)), col, false, w)
				draw_rect(Rect2(p.call(0.12, 0.2), Vector2(s * 0.76, s * 0.18)), col)
				for i in 3:
					for j in 2:
						draw_rect(Rect2(p.call(0.24 + i * 0.2, 0.5 + j * 0.18), Vector2(s * 0.11, s * 0.1)), col)
				draw_line(p.call(0.32, 0.08), p.call(0.32, 0.26), col, w)
				draw_line(p.call(0.68, 0.08), p.call(0.68, 0.26), col, w)
			"students":
				draw_circle(p.call(0.33, 0.36), s * 0.15, col)
				draw_circle(p.call(0.68, 0.4), s * 0.13, col)
				draw_colored_polygon(PackedVector2Array([p.call(0.08, 0.9), p.call(0.14, 0.6), p.call(0.52, 0.6), p.call(0.58, 0.9)]), col)
				draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.9), p.call(0.54, 0.62), p.call(0.86, 0.62), p.call(0.92, 0.9)]), col)
			"staff":
				draw_colored_polygon(PackedVector2Array([p.call(0.1, 0.38), p.call(0.5, 0.18), p.call(0.9, 0.38), p.call(0.5, 0.58)]), col)
				draw_rect(Rect2(p.call(0.28, 0.46), Vector2(s * 0.44, s * 0.26)), col)
				draw_line(p.call(0.82, 0.4), p.call(0.82, 0.74), col, w * 0.8)
			"requests":
				draw_rect(Rect2(p.call(0.18, 0.14), Vector2(s * 0.64, s * 0.78)), col, false, w)
				draw_rect(Rect2(p.call(0.36, 0.06), Vector2(s * 0.28, s * 0.14)), col)
				for i in 3:
					draw_line(p.call(0.32, 0.42 + i * 0.16), p.call(0.68, 0.42 + i * 0.16), col, w * 0.7)
			"eye":
				var pts := PackedVector2Array()
				for i in 17:
					var t := i / 16.0
					pts.append(p.call(0.08 + t * 0.84, 0.5 - sin(t * PI) * 0.28))
				for i in 17:
					var t := 1.0 - i / 16.0
					pts.append(p.call(0.08 + t * 0.84, 0.5 + sin(t * PI) * 0.28))
				draw_polyline(pts, col, w, true)
				draw_circle(p.call(0.5, 0.5), s * 0.13, col)
			"moon":
				draw_arc(p.call(0.52, 0.5), s * 0.27, PI * 0.45, PI * 1.55, 20, col, s * 0.2, true)
			"letter":
				draw_rect(Rect2(p.call(0.1, 0.24), Vector2(s * 0.8, s * 0.56)), col, false, w)
				draw_polyline(PackedVector2Array([p.call(0.1, 0.26), p.call(0.5, 0.56), p.call(0.9, 0.26)]), col, w, true)
			"sell":
				draw_colored_polygon(PackedVector2Array([p.call(0.1, 0.5), p.call(0.4, 0.16), p.call(0.88, 0.16), p.call(0.88, 0.84), p.call(0.4, 0.84)]), col)
				draw_circle(p.call(0.38, 0.5), s * 0.07, Style.PAPER)
			"clock":
				draw_arc(p.call(0.5, 0.5), s * 0.38, 0, TAU, 24, col, w, true)
				draw_line(p.call(0.5, 0.5), p.call(0.5, 0.26), col, w, true)
				draw_line(p.call(0.5, 0.5), p.call(0.68, 0.58), col, w, true)
			"credits":
				draw_colored_polygon(star_points(p.call(0.36, 0.42), s * 0.26, s * 0.11), col)
				draw_colored_polygon(star_points(p.call(0.7, 0.68), s * 0.2, s * 0.08), col)
			_:
				draw_rect(Rect2(p.call(0.12, 0.12), Vector2(s * 0.76, s * 0.76)), col)


## A strip of washi tape: a translucent band with diagonal stripes and torn ends.
class Washi extends Control:
	var color := Style.WASHI_BLUE

	func _init(c: Color, px := Vector2(72, 22)) -> void:
		color = c
		custom_minimum_size = px
		size = px
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(color, 0.85))
		var x := -size.y
		while x < size.x + size.y:
			draw_line(Vector2(x, size.y), Vector2(x + size.y, 0), Color(1, 1, 1, 0.4), 4.0)
			x += 11.0
		# Torn ends: little notches in the paper color behind.
		for i in 4:
			var y := size.y * i / 4.0
			draw_colored_polygon(PackedVector2Array([Vector2(0, y), Vector2(3, y + size.y / 8.0), Vector2(0, y + size.y / 4.0)]), Color(1, 1, 1, 0.35))


## A blue square pin stuck in a corner, with a small shadow.
class Pin extends Control:
	var color := Style.PIN_BLUE

	func _init(c: Color, px := 30.0) -> void:
		color = c
		custom_minimum_size = Vector2(px, px)
		size = Vector2(px, px)
		rotation_degrees = 14
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2(2, 4), size), Color(Style.NIGHT, 0.25))
		draw_rect(Rect2(Vector2.ZERO, size), color)
		draw_rect(Rect2(Vector2.ZERO, size), color.darkened(0.35), false, 2.0)


## A paperclip holding a note (Leo's letter in the HUD corner).
class Paperclip extends Control:
	func _init(px := Vector2(26, 56)) -> void:
		custom_minimum_size = px
		size = px
		rotation_degrees = -8
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var col := Color("5C6F8F")
		var r1 := w * 0.45
		var pts := PackedVector2Array()
		# Outer loop down the left, round the bottom, up the right, round the top, inner loop.
		pts.append(Vector2(w * 0.05, h * 0.75))
		pts.append(Vector2(w * 0.05, r1))
		for i in 9:
			var a := PI + i * PI / 8.0
			pts.append(Vector2(w * 0.5, r1) + Vector2(cos(a), sin(a)) * r1 * 1.0)
		pts.append(Vector2(w * 0.95, h * 0.82))
		for i in 9:
			var a := i * PI / 8.0
			pts.append(Vector2(w * 0.62, h * 0.82) + Vector2(cos(a), sin(a)) * w * 0.33)
		pts.append(Vector2(w * 0.29, h * 0.32))
		draw_polyline(pts, col, 3.0, true)


## A sheet of paper with slightly uneven edges (mockups: the main menu sheet, forms).
## Draws its own shadow and shape; children sit inside the margins.
class Paper extends PanelContainer:
	var color := Style.PAPER
	var wobble := 3.0
	var seed_i := 1
	var shadow := true

	func _init(bg := Style.PAPER, margin := 24, uneven := 3.0, seed_value := 1) -> void:
		color = bg
		wobble = uneven
		seed_i = seed_value
		var sb := StyleBoxEmpty.new()
		sb.set_content_margin_all(margin)
		add_theme_stylebox_override("panel", sb)

	func _outline() -> PackedVector2Array:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_i
		var pts := PackedVector2Array()
		var steps_x := maxi(3, int(size.x / 160.0))
		var steps_y := maxi(3, int(size.y / 160.0))
		for i in steps_x:
			pts.append(Vector2(size.x * i / steps_x, rng.randf_range(-wobble, wobble)))
		for i in steps_y:
			pts.append(Vector2(size.x + rng.randf_range(-wobble, wobble), size.y * i / steps_y))
		for i in steps_x:
			pts.append(Vector2(size.x * (steps_x - i) / steps_x, size.y + rng.randf_range(-wobble, wobble)))
		for i in steps_y:
			pts.append(Vector2(rng.randf_range(-wobble, wobble), size.y * (steps_y - i) / steps_y))
		return pts

	func _draw() -> void:
		var pts := _outline()
		if shadow:
			var sh := PackedVector2Array()
			for q in pts:
				sh.append(q + Vector2(3, 7))
			draw_colored_polygon(sh, Color(Style.NIGHT, 0.22))
		draw_colored_polygon(pts, color)
		var edge := pts.duplicate()
		edge.append(pts[0])
		draw_polyline(edge, Color(Style.PAPER_EDGE, 0.7), 1.0, true)


## The Academy seal: a scalloped badge with a star and MAKE-BELIEVE around the top.
class Seal extends Control:
	func _init(px := 120.0) -> void:
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := minf(size.x, size.y) / 2.0
		var c := size / 2.0
		var pts := PackedVector2Array()
		for i in 49:
			var a := i * TAU / 48.0
			pts.append(c + Vector2(cos(a), sin(a)) * (r - 2.0 + (2.5 if i % 2 == 0 else 0.0)))
		draw_colored_polygon(pts, Style.PIN_BLUE)
		draw_circle(c, r * 0.86, Style.PAPER)
		draw_arc(c, r * 0.86, 0, TAU, 48, Style.PIN_BLUE.darkened(0.3), 2.0, true)
		draw_arc(c, r * 0.58, 0, TAU, 48, Color(Style.PIN_BLUE, 0.7), 1.5, true)
		draw_colored_polygon(Icon.star_points(c + Vector2(0, -r * 0.04), r * 0.36, r * 0.15), Style.HONEY_DEEP)
		draw_polyline(Icon.star_points(c + Vector2(0, -r * 0.04), r * 0.36, r * 0.15, true), Style.INK, 1.6, true)
		# Ring text along the top arc.
		var f := Style.font(700)
		var fs := int(r * 0.17)
		var text := "MAKE-BELIEVE"
		var span := PI * 0.95
		for i in text.length():
			var a := -PI / 2.0 - span / 2.0 + span * (i + 0.5) / text.length()
			var at := c + Vector2(cos(a), sin(a)) * r * 0.66
			draw_set_transform(at, a + PI / 2.0, Vector2.ONE)
			draw_string(f, Vector2(-fs * 0.3, fs * 0.35), text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.INK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# The red ribbon with ACADEMY.
		var rw := r * 0.95
		var rect := Rect2(c + Vector2(-rw / 2.0, r * 0.38), Vector2(rw, r * 0.26))
		draw_rect(rect, Style.HEART)
		draw_rect(rect, Style.HEART.darkened(0.3), false, 1.5)
		var afs := int(r * 0.15)
		var tw := f.get_string_size("ACADEMY", HORIZONTAL_ALIGNMENT_LEFT, -1, afs).x
		draw_string(f, Vector2(c.x - tw / 2.0, rect.position.y + rect.size.y * 0.78), "ACADEMY", HORIZONTAL_ALIGNMENT_LEFT, -1, afs, Style.PAPER)


## A skill as a row of dots (mockups 08 and 10): solid points dark, fresh points as
## outlined tan dots, the rest sand. A coral tick marks a request's level; an ink notch
## marks the teacher's cap.
class DotBar extends Control:
	var solid := 0.0
	var fresh := 0.0
	var dots := 10
	var cap := -1.0
	var target := -1.0

	func _init(count := 10, px := Vector2(150, 14)) -> void:
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
		for i in dots:
			var r := Rect2(Vector2(i * (w + gap), 0), Vector2(w, h))
			var fill := Style.TRACK
			var outline := Color(0, 0, 0, 0)
			if i + 1 <= roundi(solid):
				fill = Style.WOOD
			elif i + 1 <= roundi(solid + fresh):
				fill = Style.TAB_TAN
				outline = Style.WOOD
			var sb := StyleBoxFlat.new()
			sb.bg_color = fill
			sb.set_corner_radius_all(int(minf(w, h) * 0.3))
			if outline.a > 0:
				sb.border_color = outline
				sb.set_border_width_all(2)
			draw_style_box(sb, r)
		if cap >= 0.0 and cap < dots:
			var x := cap * (w + gap) - gap / 2.0
			draw_line(Vector2(x, -3), Vector2(x, h + 3), Style.INK, 2.0)
		if target > 0.0:
			var tx := target * (w + gap) - gap / 2.0
			draw_line(Vector2(tx, -4), Vector2(tx, h + 4), Style.HEART, 3.0)


## A long rounded meter: a dark track, and a fill that runs coral -> honey -> green
## (the Kids' Trust meter), or one color (the clock bar). An optional knob marks the end.
class Meter extends Control:
	var value := 0.5
	var rainbow := true
	var fill_color := Style.OK_GREEN
	var knob := false

	func _init(px := Vector2(180, 18), multi := true, knob_mark := false) -> void:
		custom_minimum_size = px
		rainbow = multi
		knob = knob_mark
		mouse_filter = Control.MOUSE_FILTER_PASS

	func set_value(v: float) -> void:
		value = clampf(v, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var h := size.y
		var track := StyleBoxFlat.new()
		track.bg_color = Style.BAR_DARK
		track.set_corner_radius_all(int(h / 2.0))
		draw_style_box(track, Rect2(Vector2.ZERO, size))
		var inner := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		var fw := inner.size.x * value
		if fw > 1.0:
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(int(inner.size.y / 2.0))
			if rainbow:
				# Three bands so the color shows how full it is.
				var cols := [Style.HEART, Style.HONEY_DEEP, Style.OK_GREEN]
				var band := inner.size.x / 3.0
				for i in 3:
					var x0 := inner.position.x + band * i
					var bw := clampf(fw - band * i, 0.0, band)
					if bw <= 0.0:
						break
					sb.bg_color = cols[i]
					sb.corner_radius_top_left = int(inner.size.y / 2.0) if i == 0 else 0
					sb.corner_radius_bottom_left = sb.corner_radius_top_left
					var last := fw <= band * (i + 1)
					sb.corner_radius_top_right = int(inner.size.y / 2.0) if last else 0
					sb.corner_radius_bottom_right = sb.corner_radius_top_right
					draw_style_box(sb, Rect2(Vector2(x0, inner.position.y), Vector2(bw, inner.size.y)))
			else:
				sb.bg_color = fill_color
				draw_style_box(sb, Rect2(inner.position, Vector2(fw, inner.size.y)))
				draw_line(inner.position + Vector2(4, 2), inner.position + Vector2(fw - 4, 2), Color(1, 1, 1, 0.35), 2.0)
		if knob:
			var kx := inner.position.x + fw
			var kr := Rect2(Vector2(kx - 5, -3), Vector2(10, h + 6))
			var k := StyleBoxFlat.new()
			k.bg_color = Style.HEART
			k.border_color = Style.INK
			k.set_border_width_all(2)
			k.set_corner_radius_all(4)
			draw_style_box(k, kr)


## The striped loading bar (mockup 06): green candy stripes that slide along.
class LoadBar extends Control:
	var value := 0.0
	var offset := 0.0

	func _init(px := Vector2(420, 22)) -> void:
		custom_minimum_size = px
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if not Settings.reduce_motion:
			offset = fmod(offset + delta * 30.0, 16.0)
		queue_redraw()

	func _draw() -> void:
		var h := size.y
		var track := StyleBoxFlat.new()
		track.bg_color = Style.BAR_DARK
		track.set_corner_radius_all(int(h / 2.0))
		draw_style_box(track, Rect2(Vector2.ZERO, size))
		var fw := (size.x - 6.0) * clampf(value, 0.0, 1.0)
		if fw < 2.0:
			return
		var sb := StyleBoxFlat.new()
		sb.bg_color = Style.OK_GREEN
		sb.set_corner_radius_all(int((h - 6.0) / 2.0))
		var r := Rect2(Vector2(3, 3), Vector2(fw, h - 6.0))
		draw_style_box(sb, r)
		var x := -16.0 + offset
		while x < fw:
			var a := Vector2(clampf(x + 3.0, 3.0, 3.0 + fw), 3.0)
			var b := Vector2(clampf(x + 3.0 + (h - 6.0), 3.0, 3.0 + fw), h - 3.0)
			draw_line(a, b, Color(1, 1, 1, 0.3), 5.0)
			x += 16.0


## Diagonal stripes behind a portrait ("PORTRAIT" placeholder in mockup 08).
class Stripes extends Control:
	var color := Style.SKY

	func _init(c := Style.SKY) -> void:
		color = c
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(10)
		sb.border_color = color.darkened(0.2)
		sb.set_border_width_all(2)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var x := -size.y
		while x < size.x:
			var a := Vector2(x, size.y)
			var b := Vector2(x + size.y, 0)
			# Clip the stripe to the box.
			if a.x < 0:
				a = Vector2(0, size.y + x)
			if b.x > size.x:
				b = Vector2(size.x, size.y - (size.x - x))
			if a.x < b.x:
				draw_line(a, b, Color(1, 1, 1, 0.45), 6.0)
			x += 22.0


## A dashed rounded outline (the Empty Cubby slot, "Not discovered yet").
class Dashed extends Control:
	var color := Style.CARDBOARD

	func _init(c := Style.CARDBOARD) -> void:
		color = c
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		var edges := [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
			[r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]
		for e in edges:
			var a: Vector2 = e[0]
			var b: Vector2 = e[1]
			var n := int(a.distance_to(b) / 10.0)
			for i in n:
				if i % 2 == 0:
					draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), color, 2.5)


## A form checkbox: an ink square, ticked or empty (Approved / Denied, friend rows).
class CheckSquare extends Control:
	var ticked := false

	func _init(on := false, px := 24.0) -> void:
		ticked = on
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Style.PAPER
		sb.border_color = Style.INK
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(6)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if ticked:
			var s := size.x
			draw_polyline(PackedVector2Array([Vector2(s * 0.22, s * 0.52), Vector2(s * 0.42, s * 0.72), Vector2(s * 0.8, s * 0.26)]), Style.OK_DEEP, 3.5, true)
