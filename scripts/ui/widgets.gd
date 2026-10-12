extends RefCounted
## Small drawn pieces of the stationery UI (UI System doc, "Building blocks").
## Each is a Control that draws itself, so nothing depends on an emoji or a font glyph.

const Style := preload("res://scripts/ui/ui_style.gd")


## The Giggles coin: a little smiling face.
class Coin extends Control:
	func _init(px := 30.0) -> void:
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := size.x / 2.0
		var c := size / 2.0
		draw_circle(c, r - 1, Style.HONEY)
		draw_arc(c, r - 1, 0, TAU, 32, Style.INK, 2.0, true)
		draw_circle(c + Vector2(-r * 0.32, -r * 0.18), r * 0.13, Style.INK)
		draw_circle(c + Vector2(r * 0.32, -r * 0.18), r * 0.13, Style.INK)
		draw_arc(c + Vector2(0, r * 0.05), r * 0.45, 0.35, PI - 0.35, 12, Style.INK, 2.2, true)


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
			pts.append(Vector2(10, 8) + Vector2(x, y) * 0.55)
		if filled:
			draw_colored_polygon(pts, Style.HEART)
		draw_polyline(pts, Style.INK, 1.6, true)


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
		var col := data.gray_color
		match data.gray_shape:
			"sphere":
				draw_circle(c, 11, col)
				draw_arc(c, 11, 0, TAU, 24, Style.INK, 1.6, true)
			"cylinder":
				var r := Rect2(c - Vector2(11, 6), Vector2(22, 14))
				draw_rect(r, col, true)
				draw_rect(r, Style.INK, false, 1.6)
			_:
				var sz := Vector2(22, 18)
				if data.gray_size != Vector3.ZERO:
					var gs := Vector2(data.gray_size.x, maxf(data.gray_size.y, data.gray_size.z))
					sz = gs / maxf(gs.x, gs.y) * 24.0
					sz = sz.max(Vector2(6, 6))
				var r := Rect2(c - sz / 2.0, sz)
				draw_rect(r, col, true)
				draw_rect(r, Style.INK, false, 1.6)
