extends RefCounted
## The Make-Believe Academy design system in one place: colors, fonts, cardboard buttons,
## paper boxes, tabs, sliders, toggles, chips, and small helpers. Every screen builds from
## these, so a later art pass changes only this file and widgets.gd.
## (Look: the "Make-Believe Academy" design system and Game_Menus mockups 01-10.)

# --- Palette ------------------------------------------------------------------------
const PAPER := Color("FFF8E7")            # cream paper sheets and cream buttons
const PAPER_EDGE := Color("DBCBB2")
const PAPER_DARK := Color("F2E6CF")       # a sheet behind a sheet
const DESK := Color("F3E9D6")             # full-screen menus (Settings, Load School)
const NOTEBOOK := Color("FFFDF5")         # lined notebook paper
const NOTEBOOK_LINE := Color("BCD0EA")
const MARGIN_LINE := Color("F0A8AE")
const TAB_TAN := Color("EBBF8E")          # cardboard buttons and tiles
const TAN_DEEP := Color("D9A673")
const LIP := Color("8E603F")              # the cardboard lip under tan buttons
const LIP_DARK := Color("5A3A2B")         # the lip under cream buttons
const TAPE := Color(0.91, 0.72, 0.53, 0.75)
const INK := Color("3B2A22")
const INK_SOFT := Color(0.231, 0.165, 0.133, 0.68)
const CRAYON_BLUE := Color("2A3D7A")
const CRAYON_PURPLE := Color("634E89")
const HEART := Color("E05A68")
const HONEY := Color("F6DA74")
const HONEY_DEEP := Color("E2B83E")
const OK_GREEN := Color("47C46E")
const OK_DEEP := Color("2E8F4E")
const CARDBOARD := Color("C48F65")
const WOOD := Color("6B4332")
const NIGHT := Color("2A2A44")
const NAVY := Color("2B2D4E")             # the bottom tab bar and the loading screen
const FORM := Color("F7EEDD")
const FORM_LINE := Color("C9B796")
const TRACK := Color("DCCFB9")            # empty slider and dot tracks
const BAR_DARK := Color("5B3A2C")         # the clock and trust bar tracks
const LAVENDER := Color("D3CFF3")         # personality chips
const PINK := Color("F7CDD0")             # quirk chips
const MINT := Color("D9F2DF")             # effect chips
const PIN_BLUE := Color("6F9AC6")
const WASHI_BLUE := Color("9DB8DC")
const WASHI_PINK := Color("EFA3A8")
const SKY := Color("C9DDF0")              # portrait circles

## Tile colors for the five bottom tabs (Build, Timetable, Students, Staff, Requests).
const TAB_COLORS := {
	"build": Color("E05A68"), "timetable": Color("6F9AC6"), "students": Color("7F7FB0"),
	"staff": Color("6B4332"), "requests": Color("C48F65"),
}

# --- Fonts --------------------------------------------------------------------------
const FREDOKA_PATH := "res://ui/fonts/Fredoka.ttf"
const HAND_PATH := "res://ui/fonts/PatrickHand-Regular.ttf"
const READABLE_PATH := "res://ui/fonts/AtkinsonHyperlegible-Regular.ttf"
const READABLE_BOLD_PATH := "res://ui/fonts/AtkinsonHyperlegible-Bold.ttf"

## Accessibility setting from the design doc: swap every font for Atkinson Hyperlegible.
static var readable_font := false
static var _fonts := {}
static var _textures := {}


## UI font at a weight (400 regular, 500 medium, 600 semibold, 700 bold). Fredoka is variable.
static func font(weight := 400) -> Font:
	var key := "ui%d%s" % [weight, "r" if readable_font else ""]
	if _fonts.has(key):
		return _fonts[key]
	var f: Font
	if readable_font:
		f = load(READABLE_BOLD_PATH if weight >= 600 else READABLE_PATH)
	else:
		var v := FontVariation.new()
		v.base_font = load(FREDOKA_PATH)
		var ts := TextServerManager.get_primary_interface()
		v.variation_opentype = {ts.name_to_tag("wght"): weight, ts.name_to_tag("wdth"): 100}
		f = v
	_fonts[key] = f
	return f


## Children's handwriting (letters, crayon notes, school names, species).
static func hand() -> Font:
	if readable_font:
		return font(400)
	if not _fonts.has("hand"):
		_fonts["hand"] = load(HAND_PATH)
	return _fonts["hand"]


## The theme every HUD control inherits: Fredoka, ink text, cardboard buttons, honey
## sliders, green pill toggles, paper tooltips.
static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(400)
	t.default_font_size = 15
	for type in ["Label", "Button", "LinkButton", "CheckBox", "CheckButton", "RichTextLabel", "TooltipLabel", "OptionButton"]:
		t.set_color("font_color", type, INK)
	t.set_color("default_color", "RichTextLabel", INK)
	for type in ["Button", "OptionButton", "CheckButton"]:
		t.set_color("font_hover_color", type, INK)
		t.set_color("font_pressed_color", type, INK)
		t.set_color("font_hover_pressed_color", type, INK)
		t.set_color("font_focus_color", type, INK)
		t.set_color("font_disabled_color", type, Color(INK, 0.45))
	t.set_color("font_hover_color", "LinkButton", INK)
	t.set_color("font_pressed_color", "LinkButton", INK)
	_set_button_styles(t, "Button", false)
	_set_button_styles(t, "OptionButton", false)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PopupMenu", paper_box(8, 10))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_stylebox("hover", "PopupMenu", flat_box(HONEY, Color(0, 0, 0, 0), 0, 6, 4))
	t.set_stylebox("panel", "TooltipPanel", paper_box(8, 8))
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font("font", "TooltipLabel", font(400))
	t.set_font_size("font_size", "TooltipLabel", 14)
	t.set_stylebox("panel", "PanelContainer", paper_box())
	t.set_stylebox("background", "ProgressBar", bar_box(TRACK))
	t.set_stylebox("fill", "ProgressBar", bar_box(OK_GREEN))
	# Sliders: a honey fill on a sand track, a white round knob (mockup 03).
	var track := flat_box(TRACK, Color("C9B99E"), 2, 8, 0)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", track)
	var fill := flat_box(HONEY, HONEY_DEEP, 2, 8, 0)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", knob_texture(30))
	t.set_icon("grabber_highlight", "HSlider", knob_texture(30, true))
	t.set_icon("grabber_disabled", "HSlider", knob_texture(30))
	t.set_stylebox("focus", "HSlider", StyleBoxEmpty.new())
	# Toggles: a green pill with a white knob when on, a sand pill when off.
	for k in ["checked", "checked_mirrored", "checked_disabled", "checked_disabled_mirrored"]:
		t.set_icon(k, "CheckButton", pill_texture(true))
	for k in ["unchecked", "unchecked_mirrored", "unchecked_disabled", "unchecked_disabled_mirrored"]:
		t.set_icon(k, "CheckButton", pill_texture(false))
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		t.set_stylebox(st, "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("scroll", "VScrollBar", flat_box(Color(TRACK, 0.6), Color(0, 0, 0, 0), 0, 6, 3))
	t.set_stylebox("grabber", "VScrollBar", flat_box(TAN_DEEP, Color(0, 0, 0, 0), 0, 6, 3))
	t.set_stylebox("grabber_highlight", "VScrollBar", flat_box(CARDBOARD, Color(0, 0, 0, 0), 0, 6, 3))
	t.set_stylebox("grabber_pressed", "VScrollBar", flat_box(CARDBOARD, Color(0, 0, 0, 0), 0, 6, 3))
	t.set_stylebox("scroll", "HScrollBar", flat_box(Color(TRACK, 0.6), Color(0, 0, 0, 0), 0, 6, 3))
	t.set_stylebox("grabber", "HScrollBar", flat_box(TAN_DEEP, Color(0, 0, 0, 0), 0, 6, 3))
	t.set_stylebox("grabber_highlight", "HScrollBar", flat_box(CARDBOARD, Color(0, 0, 0, 0), 0, 6, 3))
	t.set_stylebox("grabber_pressed", "HScrollBar", flat_box(CARDBOARD, Color(0, 0, 0, 0), 0, 6, 3))
	return t


static func _set_button_styles(t: Theme, type: String, tan: bool) -> void:
	var bg := TAB_TAN if tan else PAPER
	t.set_stylebox("normal", type, lip_box(bg, tan))
	t.set_stylebox("hover", type, lip_box(bg.lightened(0.12), tan))
	t.set_stylebox("pressed", type, lip_box(PAPER, false, true, true))
	t.set_stylebox("hover_pressed", type, lip_box(PAPER, false, true, true))
	t.set_stylebox("disabled", type, lip_box(bg.lerp(DESK, 0.5), tan, false, false, true))


# --- Boxes --------------------------------------------------------------------------

## A sheet of paper with a soft drop shadow (no outline: paper, not a box).
static func paper_box(margin := 14, radius := 6, bg := PAPER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(PAPER_EDGE, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(NIGHT, 0.3)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(2, 5)
	return sb


## The cardboard button (mockups): a brown outline and a thick lip along the bottom edge.
## Tan is the main action; cream is secondary, and also marks the selected item.
## `down` presses the lip in; `selected` gives the heavy ink outline of a chosen item.
static func lip_box(bg: Color, tan := true, down := false, selected := false, dim := false, radius := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	var edge := LIP if tan else LIP_DARK
	if selected:
		edge = INK
	if dim:
		edge = Color(edge, 0.45)
	sb.border_color = edge
	var w := 3 if selected else 2
	sb.border_width_left = w
	sb.border_width_right = w
	sb.border_width_top = w
	sb.border_width_bottom = 3 if down else 7
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 9 if down else 6
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(NIGHT, 0.0 if dim else 0.14)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	return sb


## Kept for older callers: a flat button box.
static func button_box(bg: Color, border: Color, radius := 10) -> StyleBoxFlat:
	var sb := lip_box(bg, true, false, false, false, radius)
	sb.border_color = border
	return sb


## A tab (Settings, Build rooms): tan when idle, cream with an ink outline when open.
static func tab_box(active: bool) -> StyleBoxFlat:
	return lip_box(PAPER if active else TAB_TAN, not active, false, active)


static func bar_box(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(6)
	return sb


## A filled rounded box with no shadow (rows, chips, quirk boxes).
static func flat_box(bg: Color, border := Color(0, 0, 0, 0), width := 0, radius := 10, margin := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


## A cardboard card: cream or tan with an outline and a lip (slot cards, item cards, rows).
static func card_box(selected := false, tan := false, margin := 12) -> StyleBoxFlat:
	var sb := lip_box(PAPER if not tan else TAB_TAN, not selected, false, selected, false, 14)
	if not selected:
		sb.border_color = Color("C79A6E") if not tan else LIP
		sb.border_width_bottom = 6
	sb.set_content_margin_all(margin)
	return sb


## A dashed outline drawn by the caller; this is the empty fill behind it.
static func empty_box(margin := 12) -> StyleBoxFlat:
	return flat_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 14, margin)


# --- Widgets ------------------------------------------------------------------------

static func label(text := "", size := 15, weight := 400, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func hand_label(text := "", size := 20, color := CRAYON_BLUE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", hand())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Small caps over a form ("FORM 3-C: COMFORT PREFERENCES", "BUILDING IN").
static func caps(text: String, size := 12, color := INK_SOFT) -> Label:
	var l := label(text.to_upper(), size, 600, color)
	l.add_theme_constant_override("outline_size", 0)
	return l


static func paper_panel(margin := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", paper_box(margin))
	return p


## A cardboard button. `primary` makes it tan (the main action); otherwise it's cream.
## `icon` draws one of the widgets.gd Icon shapes at its left.
static func button(text: String, size := 15, primary := false, icon := "") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font(600))
	b.add_theme_font_size_override("font_size", size)
	var bg := TAB_TAN if primary else PAPER
	b.add_theme_stylebox_override("normal", lip_box(bg, primary))
	b.add_theme_stylebox_override("hover", lip_box(bg.lightened(0.12), primary))
	b.add_theme_stylebox_override("pressed", lip_box(PAPER, false, true, true))
	b.add_theme_stylebox_override("hover_pressed", lip_box(PAPER, false, true, true))
	b.add_theme_stylebox_override("disabled", lip_box(bg.lerp(DESK, 0.5), primary, false, false, true))
	if icon != "":
		add_icon(b, icon, size)
	return b


## Put a drawn icon at a button's left edge and make room for it.
static func add_icon(b: Button, icon: String, text_size := 15, color := INK) -> void:
	var W = load("res://scripts/ui/widgets.gd")
	var px := clampf(text_size * 1.25, 16.0, 30.0)
	var ic: Control = W.Icon.new(icon, px, color)
	ic.anchor_top = 0.5
	ic.anchor_bottom = 0.5
	ic.offset_left = 16
	ic.offset_right = 16 + px
	ic.offset_top = -px / 2.0 - 1.0
	ic.offset_bottom = px / 2.0 - 1.0
	b.add_child(ic)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb = b.get_theme_stylebox(st)
		if sb is StyleBoxFlat:
			var c: StyleBoxFlat = sb.duplicate()
			c.content_margin_left = 16 + px + 10
			b.add_theme_stylebox_override(st, c)


## Tan or cream as a toggle: tan while idle, cream with an ink outline while pressed (tabs).
static func tab_button(text: String, size := 15, icon := "") -> Button:
	var b := button(text, size, true, icon)
	b.toggle_mode = true
	return b


## A rounded chip: "Year 1", "2x2", "+2 Calm", personality and quirk tags.
static func chip(text: String, bg: Color, border := Color(0, 0, 0, 0), size := 13, weight := 600, fg := INK) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := flat_box(bg, border, 2 if border.a > 0 else 0, 10, 0)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(label(text, size, weight, fg))
	return p


## A strip of washi tape on a paper's top edge. Returns an overlay Control (containers
## stretch their children, so the strip itself sits inside it at a free position).
## Add it after the paper's content so it draws on top.
static func tape(at_x: float, angle_deg := -3.0, color := WASHI_BLUE, width := 72.0) -> Control:
	var W = load("res://scripts/ui/widgets.gd")
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t: Control = W.Washi.new(color, Vector2(width, 22))
	t.position = Vector2(at_x, -12)
	t.rotation_degrees = angle_deg
	overlay.add_child(t)
	return overlay


## A blue square pin in a paper's corner (an overlay, like tape).
static func pin(at: Vector2, color := PIN_BLUE, px := 30.0) -> Control:
	var W = load("res://scripts/ui/widgets.gd")
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p: Control = W.Pin.new(color, px)
	p.position = at
	overlay.add_child(p)
	return overlay


## A free-positioning layer inside a container (stamps on a form, tape on a note).
static func overlay() -> Control:
	var o := Control.new()
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return o


## Tween that keeps running while the game is paused (UI slides and pops).
static func ui_tween(node: Node) -> Tween:
	var tw := node.create_tween()
	tw.set_ignore_time_scale(true)
	return tw


# --- Drawn textures (slider knob, toggle pill) --------------------------------------

## A white round knob with an ink ring, drawn into a texture for HSlider.
static func knob_texture(px := 30, hot := false) -> Texture2D:
	var key := "knob%d%s" % [px, hot]
	if _textures.has(key):
		return _textures[key]
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var c := Vector2(px, px) / 2.0
	var r := px / 2.0 - 1.0
	for y in px:
		for x in px:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var col := Color(0, 0, 0, 0)
			if d <= r:
				col = INK if d > r - 3.0 else (Color("FFFDF5") if not hot else Color("FFF4C8"))
				col.a = clampf(r - d + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex


## The toggle pill: green with the knob right when on, sand with the knob left when off.
static func pill_texture(on: bool, w := 58, h := 32) -> Texture2D:
	var key := "pill%s" % on
	if _textures.has(key):
		return _textures[key]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := h / 2.0 - 1.0
	var a := Vector2(r + 1.0, h / 2.0)
	var b := Vector2(w - r - 1.0, h / 2.0)
	var knob := b if on else a
	var fill := OK_GREEN if on else TRACK
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var q := Vector2(clampf(p.x, a.x, b.x), a.y)
			var d := p.distance_to(q)
			var col := Color(0, 0, 0, 0)
			if d <= r:
				col = INK if d > r - 2.5 else fill
				var kd := p.distance_to(knob)
				if kd < r - 5.0:
					col = Color("FFFDF5")
				elif kd < r - 3.5:
					col = INK
				col.a = clampf(r - d + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex
