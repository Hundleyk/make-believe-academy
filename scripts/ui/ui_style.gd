extends RefCounted
## The Make-Believe Academy design system in Godot: tokens (colors, type, spacing, radii,
## shadows) from the design system's tokens/*.css, and builders for its core pieces
## (PaperButton, ToyButton, chips, tabs, sliders, toggles). Drawn pieces live in widgets.gd.
## The UI's base size is the mockups' 1280x720; Godot scales it to the window.
## (Source: "Make-Believe Academy — Design System" README, tokens and components.)

# --- Colors (tokens/colors.css) -----------------------------------------------------
const CARDBOARD := Color("C48F65")        # --cardboard-tan: card edges, rims
const WOOD := Color("6B4332")             # --wood-trim: the under-edge of tabs, skill solid
const LAVENDER := Color("7A789B")         # --pillow-lavender
const SKY := Color("7096BA")              # --fort-sky-blue
const PEACH := Color("D97971")            # --peach-rose
const INDIGO := Color("2A2A44")           # --deep-indigo: dock bar, night rooms, loading
const HONEY := Color("F6DA74")            # --honey-glow: Giggles
const LIME := Color("E2F89C")             # --star-lime: highlight, active toy buttons
const GREEN := Color("42C872")            # --grid-green: progress, valid
const PAPER := Color("FFF8E7")            # --paper-white
const PAPER_SHADOW := Color("DBCBB2")     # --paper-shadow
const TAB_TAN := Color("E8B887")          # --tab-tan
const HEART := Color("E05A68")            # --heart-coral: Trust, invalid
const INK := Color("3B2C24")              # --ink-brown: all text on paper
const BOARD := Color("F5EBD6")            # --board-cream: full-screen menus
const PAPER_LINE := Color("B9CBE0")
const PAPER_MARGIN := Color("E9A3A0")
const INK_SOFT := Color("6A574B")
const GREEN_DEEP := Color("2A9A54")
const HEART_DEEP := Color("B83B4A")       # --stamp-red
const HONEY_DEEP := Color("D9A93A")
const TAB_TAN_LIGHT := Color("F3D3AE")
const LAVENDER_LIGHT := Color("C9C6DE")
const SKY_LIGHT := Color("C4D6E8")
const PEACH_LIGHT := Color("F2C3BC")
const LIME_LIGHT := Color("F1FCCD")
const COIN_RING := Color("FBE9A6")
const SHADOW := Color(0.231, 0.173, 0.141, 0.18)   # rgba(59,44,36,.18)

## Older names kept so every screen reads the same tokens.
const PAPER_EDGE := PAPER_SHADOW
const PAPER_DARK := BOARD
const DESK := BOARD
const NOTEBOOK := PAPER
const NOTEBOOK_LINE := PAPER_LINE
const MARGIN_LINE := PAPER_MARGIN
const NIGHT := INDIGO
const NAVY := INDIGO
const OK_GREEN := GREEN
const OK_DEEP := GREEN_DEEP
const CRAYON_BLUE := INK
const CRAYON_PURPLE := LAVENDER
const FORM := PAPER
const FORM_LINE := PAPER_LINE
const TRACK := PAPER_SHADOW
const MINT := LIME_LIGHT
const PINK := PEACH_LIGHT
const PIN_BLUE := SKY
const WASHI_BLUE := SKY
const WASHI_PINK := PEACH

## ItemCard tints (components/cards/ItemCard.jsx).
const TINTS := {"honey": HONEY, "lime": LIME, "sky": SKY_LIGHT, "lavender": LAVENDER_LIGHT, "peach": PEACH_LIGHT, "tan": TAB_TAN_LIGHT}
## WashiTape colors (components/core/WashiTape.jsx).
const TAPE_COLORS := {"honey": HONEY, "lavender": LAVENDER, "sky": SKY, "peach": PEACH, "lime": LIME, "coral": HEART, "tan": TAB_TAN}

## The bottom menu's five tabs: icon and sticker color (components/navigation/BottomMenu.jsx).
const TAB_ICONS := {
	"build": ["house", HEART], "timetable": ["calendar", SKY], "students": ["ghost", LAVENDER],
	"staff": ["eyeglasses", WOOD], "requests": ["clipboard-text", CARDBOARD],
}

# --- Spacing, radii, borders (tokens/spacing.css, shapes.css) -----------------------
const SPACE := [0, 4, 6, 10, 14, 18, 24, 32, 44, 60]
const HUD_INSET := 18
const BORDER := 3
## Soft, uneven corners: 16px 12px 18px 11px (top-left, top-right, bottom-right, bottom-left).
const RADIUS := [16, 12, 18, 11]

# --- Type (tokens/typography.css) ---------------------------------------------------
const FREDOKA_PATH := "res://ui/fonts/Fredoka.ttf"
const HAND_PATH := "res://ui/fonts/PatrickHand-Regular.ttf"
const READABLE_PATH := "res://ui/fonts/AtkinsonHyperlegible-Regular.ttf"
const READABLE_BOLD_PATH := "res://ui/fonts/AtkinsonHyperlegible-Bold.ttf"
const TEXT_XS := 13
const TEXT_SM := 15
const TEXT_MD := 18
const TEXT_LG := 24
const TEXT_XL := 32
const TEXT_DISPLAY := 48
const HAND_SM := 18
const HAND_MD := 24
const HAND_LG := 34

## Accessibility setting from the design doc: swap every font for Atkinson Hyperlegible.
static var readable_font := false
static var _fonts := {}


## UI font (Fredoka) at a weight: 400, 500, 600, 700. `spacing` adds letter spacing in px
## (labels use 0.06em, stamps 0.14em).
static func font(weight := 400, spacing := 0) -> Font:
	var key := "ui%d_%d%s" % [weight, spacing, "r" if readable_font else ""]
	if _fonts.has(key):
		return _fonts[key]
	var v := FontVariation.new()
	if readable_font:
		v.base_font = load(READABLE_BOLD_PATH if weight >= 600 else READABLE_PATH)
	else:
		v.base_font = load(FREDOKA_PATH)
		var ts := TextServerManager.get_primary_interface()
		v.variation_opentype = {ts.name_to_tag("wght"): weight, ts.name_to_tag("wdth"): 100}
	v.spacing_glyph = spacing
	_fonts[key] = v
	return v


## Kid handwriting (Patrick Hand): letters, species names, form fill-ins only.
static func hand() -> Font:
	if readable_font:
		return font(400)
	if not _fonts.has("hand"):
		_fonts["hand"] = load(HAND_PATH)
	return _fonts["hand"]


## The theme every HUD control inherits.
static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(500)
	t.default_font_size = TEXT_MD
	for type in ["Label", "Button", "LinkButton", "CheckBox", "CheckButton", "RichTextLabel", "TooltipLabel", "OptionButton"]:
		t.set_color("font_color", type, INK)
	for type in ["Button", "OptionButton"]:
		for c in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			t.set_color(c, type, INK)
		t.set_color("font_disabled_color", type, INK_SOFT)
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_color("font_hover_color", "LinkButton", INK)
	t.set_color("font_pressed_color", "LinkButton", INK)
	var paper := button_box("paper")
	t.set_stylebox("normal", "Button", paper)
	t.set_stylebox("hover", "Button", button_box("paper", "hover"))
	t.set_stylebox("pressed", "Button", button_box("paper", "selected"))
	t.set_stylebox("hover_pressed", "Button", button_box("paper", "selected"))
	t.set_stylebox("disabled", "Button", button_box("paper", "disabled"))
	# Tooltip (components/cards/Tooltip.jsx): paper with an ink rim.
	var tip := flat_box(PAPER, INK, 3, 12, 10)
	tip.shadow_color = SHADOW
	tip.shadow_size = 6
	tip.shadow_offset = Vector2(0, 4)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font("font", "TooltipLabel", font(500))
	t.set_font_size("font_size", "TooltipLabel", TEXT_SM)
	t.set_stylebox("panel", "PanelContainer", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PopupMenu", flat_box(PAPER, CARDBOARD, 3, 12, 8))
	# Sliders (mockup 03): a sand pill track, honey fill, a paper knob with an ink rim.
	var track := flat_box(PAPER_SHADOW, Color(0, 0, 0, 0), 0, 8, 0)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	t.set_stylebox("slider", "HSlider", track)
	var fill := flat_box(HONEY, HONEY_DEEP, 2, 8, 0)
	fill.content_margin_top = 8
	fill.content_margin_bottom = 8
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var W = load("res://scripts/ui/widgets.gd")
	t.set_icon("grabber", "HSlider", W.knob_texture(30))
	t.set_icon("grabber_highlight", "HSlider", W.knob_texture(30))
	t.set_icon("grabber_disabled", "HSlider", W.knob_texture(30))
	t.set_stylebox("focus", "HSlider", StyleBoxEmpty.new())
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, flat_box(Color(PAPER_SHADOW, 0.6), Color(0, 0, 0, 0), 0, 6, 3))
		t.set_stylebox("grabber", bar, flat_box(CARDBOARD, Color(0, 0, 0, 0), 0, 6, 3))
		t.set_stylebox("grabber_highlight", bar, flat_box(WOOD, Color(0, 0, 0, 0), 0, 6, 3))
		t.set_stylebox("grabber_pressed", bar, flat_box(WOOD, Color(0, 0, 0, 0), 0, 6, 3))
	return t


# --- Boxes --------------------------------------------------------------------------

static func _uneven(sb: StyleBoxFlat, scale := 1.0) -> void:
	sb.corner_radius_top_left = int(RADIUS[0] * scale)
	sb.corner_radius_top_right = int(RADIUS[1] * scale)
	sb.corner_radius_bottom_right = int(RADIUS[2] * scale)
	sb.corner_radius_bottom_left = int(RADIUS[3] * scale)


## The PaperButton look (components/core/PaperButton.jsx). tone "tan" or "paper";
## state normal, hover, pressed, selected, disabled. A 3px cardboard rim sits on a
## wood under-edge (--shadow-tab); selected gets an ink rim and lifts.
static func button_box(tone := "tan", state := "normal", pad := Vector2(20, 10)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var base := PAPER if tone == "paper" else TAB_TAN
	sb.bg_color = base
	sb.border_color = CARDBOARD
	sb.set_border_width_all(BORDER)
	_uneven(sb)
	sb.shadow_color = WOOD
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = pad.x
	sb.content_margin_right = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_bottom = pad.y
	sb.anti_aliasing = true
	match state:
		"hover":
			sb.bg_color = LIME_LIGHT if tone == "paper" else TAB_TAN_LIGHT
			sb.shadow_offset = Vector2(0, 6)
			sb.expand_margin_top = 2
			sb.expand_margin_bottom = -2
		"pressed":
			sb.shadow_offset = Vector2(0, 1)
			sb.content_margin_top = pad.y + 3
			sb.content_margin_bottom = pad.y - 3
		"selected":
			sb.bg_color = PAPER
			sb.border_color = INK
			sb.shadow_offset = Vector2(0, 8)
			sb.expand_margin_top = 4
			sb.expand_margin_bottom = -4
		"disabled":
			sb.bg_color = PAPER_SHADOW
			sb.border_color = Color(CARDBOARD, 0.8)
			sb.shadow_size = 0
			sb.shadow_color = Color(0, 0, 0, 0)
	return sb


## Kept for older callers: tan when `tan`, paper otherwise; `selected` = ink rim.
static func lip_box(bg: Color, tan := true, down := false, selected := false, dim := false, _radius := 12) -> StyleBoxFlat:
	var state := "disabled" if dim else ("selected" if selected else ("pressed" if down else "normal"))
	var sb := button_box("tan" if tan else "paper", state)
	if not selected and not dim:
		sb.bg_color = bg
	return sb


## A cardboard-rimmed card on a wood under-edge (item cards, slot cards, helper rows).
## `selected`: paper face, ink rim, lifted. `tone` "paper" or "tan" (--tab-tan-light).
static func card_box(selected := false, tan := false, margin := 10) -> StyleBoxFlat:
	var sb := button_box("paper", "selected" if selected else "normal", Vector2(margin, margin))
	if not selected and tan:
		sb.bg_color = TAB_TAN_LIGHT
	if not selected:
		sb.shadow_offset = Vector2(0, 4)
	return sb


## A plain sheet of paper (a box version of PaperCard with no cut edge).
static func paper_box(margin := 14, radius := 6, bg := PAPER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.shadow_color = PAPER_SHADOW
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(0, 2)
	return sb


static func tab_box(active: bool) -> StyleBoxFlat:
	return button_box("tan", "selected" if active else "normal")


static func bar_box(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(999)
	return sb


## A filled rounded box with no shadow (chips, quirk boxes, rows).
static func flat_box(bg: Color, border := Color(0, 0, 0, 0), width := 0, radius := 10, margin := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


static func empty_box(margin := 12) -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	sb.set_content_margin_all(margin)
	return sb


# --- Text ---------------------------------------------------------------------------

static func label(text := "", size := TEXT_MD, weight := 500, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func hand_label(text := "", size := HAND_MD, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", hand())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Small caps over a form ("FORM 3-C: COMFORT PREFERENCES", "BUILDING IN"): 600, 0.06em.
static func caps(text: String, size := TEXT_XS, color := INK_SOFT) -> Label:
	var l := label(text.to_upper(), size, 600, color)
	l.add_theme_font_override("font", font(600, roundi(size * 0.06)))
	return l


static func paper_panel(margin := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", paper_box(margin))
	return p


# --- PaperButton --------------------------------------------------------------------

## Size presets (PaperButton): padding, font size, icon size.
const BUTTON_SIZES := {"sm": [Vector2(14, 6), 15, 16], "md": [Vector2(20, 10), 18, 20], "lg": [Vector2(28, 14), 22, 24]}


## A PaperButton. `size` is "sm" | "md" | "lg" (or a font size, mapped to the nearest);
## `primary` true = tan tone, false = paper tone; `icon` = a Phosphor name (bold).
static func button(text: String, size: Variant = "md", primary := false, icon := "") -> Button:
	var key: String = size if size is String else ("sm" if int(size) <= 15 else ("md" if int(size) <= 19 else "lg"))
	var spec: Array = BUTTON_SIZES[key]
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font(600))
	b.add_theme_font_size_override("font_size", spec[1])
	b.set_meta("tone", "tan" if primary else "paper")
	_style_button(b, "tan" if primary else "paper", spec[0])
	if icon != "":
		add_icon(b, icon, spec[2])
	return b


static func _style_button(b: Button, tone: String, pad: Vector2) -> void:
	b.add_theme_stylebox_override("normal", button_box(tone, "normal", pad))
	b.add_theme_stylebox_override("hover", button_box(tone, "hover", pad))
	b.add_theme_stylebox_override("pressed", button_box(tone, "selected", pad))
	b.add_theme_stylebox_override("hover_pressed", button_box(tone, "selected", pad))
	b.add_theme_stylebox_override("disabled", button_box(tone, "disabled", pad))
	b.add_theme_color_override("font_disabled_color", INK_SOFT)


## A PaperButton that starts selected (ink rim, lifted): the current choice in a menu.
static func select_button(b: Button, on := true) -> void:
	var pad := Vector2(b.get_theme_stylebox("normal").content_margin_left, b.get_theme_stylebox("normal").content_margin_top)
	var tone: String = b.get_meta("tone", "tan")
	for st in ["normal", "hover"]:
		var sb := button_box(tone, "selected" if on else st, pad)
		if b.has_meta("icon_room"):
			sb.content_margin_left = b.get_meta("icon_room")
		b.add_theme_stylebox_override(st, sb)


## Put a Phosphor icon (bold) at a button's left, before its text.
static func add_icon(b: Button, icon: String, px := 20, color := INK) -> void:
	var W = load("res://scripts/ui/widgets.gd")
	var ic: Control = W.Icon.new(icon, px, color, "bold")
	ic.anchor_top = 0.5
	ic.anchor_bottom = 0.5
	var left: float = b.get_theme_stylebox("normal").content_margin_left
	ic.offset_left = left
	ic.offset_right = left + px
	ic.offset_top = -px / 2.0 - 1.0
	ic.offset_bottom = px / 2.0 - 1.0
	ic.name = "Icon"
	b.add_child(ic)
	var room: float = left + px + 8
	b.set_meta("icon_room", room)
	if b.text == "":
		ic.anchor_left = 0.5
		ic.anchor_right = 0.5
		ic.offset_left = -px / 2.0
		ic.offset_right = px / 2.0
		return
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb = b.get_theme_stylebox(st)
		if sb is StyleBoxFlat:
			var c: StyleBoxFlat = sb.duplicate()
			c.content_margin_left = room
			b.add_theme_stylebox_override(st, c)


## Tabs: a toggle PaperButton (tan while idle, paper with an ink rim while open).
static func tab_button(text: String, size: Variant = "md", icon := "") -> Button:
	var b := button(text, size, true, icon)
	b.toggle_mode = true
	return b


## ToyButton (components/hud/ToyButton.jsx): a 56px tan-light tile with a sticker icon;
## active = pressed in with a lime face and an ink rim.
static func toy_box(active := false, hover := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = LIME if active else (PAPER if hover else TAB_TAN_LIGHT)
	sb.border_color = INK if active else CARDBOARD
	sb.set_border_width_all(BORDER)
	_uneven(sb)
	sb.shadow_color = WOOD
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(0, 1 if active else 5)
	if active:
		sb.expand_margin_top = -4
		sb.expand_margin_bottom = 4
	elif hover:
		sb.expand_margin_top = 2
		sb.expand_margin_bottom = -2
	return sb


## A rounded chip: "Year 1", "2×2", "+2 Calm", personality and quirk tags.
static func chip(text: String, bg: Color, border := Color(0, 0, 0, 0), size := TEXT_XS, weight := 600, fg := INK, radius := 6) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := flat_box(bg, border, 2 if border.a > 0 else 0, radius, 0)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(label(text, size, weight, fg))
	return p


## An effect chip (ItemCard): lime-light pill with a deep-green rim.
static func effect_chip(text: String) -> PanelContainer:
	return chip(text, LIME_LIGHT, GREEN_DEEP, TEXT_XS, 600, INK, 999)


# --- Decorations (overlays: add after the content so they draw on top) -------------

## A strip of washi tape on a paper's edge. Returns an overlay Control.
static func tape(at_x: float, angle_deg := -4.0, color: Variant = "honey", width := 96.0, pattern := "stripes", at_y := -12.0) -> Control:
	var W = load("res://scripts/ui/widgets.gd")
	var o := overlay()
	var c: Color = TAPE_COLORS.get(color, HONEY) if color is String else color
	var t: Control = W.Washi.new(c, Vector2(width, 26), pattern)
	t.position = Vector2(at_x, at_y)
	t.rotation_degrees = angle_deg
	o.add_child(t)
	return o


## Tape on both top corners (PaperCard tape="corners"); `w` = the paper's width.
static func tape_corners(w: float, color: Variant = "honey") -> Control:
	var W = load("res://scripts/ui/widgets.gd")
	var o := overlay()
	var c: Color = TAPE_COLORS.get(color, HONEY) if color is String else color
	var a: Control = W.Washi.new(c, Vector2(64, 26), "stripes")
	a.position = Vector2(-20, -2)
	a.rotation_degrees = -38
	o.add_child(a)
	var b: Control = W.Washi.new(c, Vector2(64, 26), "stripes")
	b.position = Vector2(w - 44, -2 - 40)
	b.rotation_degrees = 38
	o.add_child(b)
	return o


## The blue paperclip (PaperCard clip): top right of a paper, `w` = its width.
static func clip(w: float, right := 16.0) -> Control:
	var W = load("res://scripts/ui/widgets.gd")
	var o := overlay()
	var ic: Control = W.Icon.new("paperclip", 46, SKY, "bold", true)
	ic.position = Vector2(w - right - 46, -18)
	ic.rotation_degrees = 18
	o.add_child(ic)
	return o


static func pin(at: Vector2, _color := SKY, _px := 30.0) -> Control:
	var o := overlay()
	var W = load("res://scripts/ui/widgets.gd")
	var ic: Control = W.Icon.new("paperclip", 46, SKY, "bold", true)
	ic.position = at
	ic.rotation_degrees = 18
	o.add_child(ic)
	return o


static func overlay() -> Control:
	var o := Control.new()
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return o


## Tween that keeps running while the game is paused (UI slides and pops).
static func ui_tween(node: Node) -> Tween:
	var tw := node.create_tween()
	tw.set_ignore_time_scale(true)
	return tw


## The bouncy ease (--ease-bounce) for lifts and pops.
static func bounce(tw: Tween) -> Tween:
	return tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
