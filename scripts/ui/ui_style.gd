extends RefCounted
## The stationery look in one place: colors, fonts, paper boxes, buttons, tabs, and small
## drawing helpers. Every screen builds from these, so the M4 art pass changes only this file.
## (Look: Game Design Doc, "Art, UI, and accessibility". Mechanics: the UI System doc.)

# --- Palette (sampled from render 3, Dev Log) --------------------------------------
const PAPER := Color("FFF8E7")
const PAPER_EDGE := Color("DBCBB2")
const PAPER_DARK := Color("F2E6CF")       # a sheet behind a sheet
const NOTEBOOK := Color("FFFDF5")         # lined notebook paper
const NOTEBOOK_LINE := Color("C9DAEC")
const MARGIN_LINE := Color("F0A8AE")
const TAB_TAN := Color("E8B887")
const TAPE := Color(0.91, 0.72, 0.53, 0.75)
const INK := Color("3B2C24")
const INK_SOFT := Color(0.231, 0.173, 0.141, 0.7)
const CRAYON_BLUE := Color("2A3D7A")
const CRAYON_PURPLE := Color("634E89")
const HEART := Color("E05A68")
const HONEY := Color("F6DA74")
const OK_GREEN := Color("42C872")
const CARDBOARD := Color("C48F65")
const WOOD := Color("6B4332")
const NIGHT := Color("2A2A44")
const FORM := Color("F4ECDC")
const FORM_LINE := Color("C9B796")

# --- Fonts --------------------------------------------------------------------------
const FREDOKA_PATH := "res://ui/fonts/Fredoka.ttf"
const HAND_PATH := "res://ui/fonts/PatrickHand-Regular.ttf"
const READABLE_PATH := "res://ui/fonts/AtkinsonHyperlegible-Regular.ttf"
const READABLE_BOLD_PATH := "res://ui/fonts/AtkinsonHyperlegible-Bold.ttf"

## Accessibility setting from the design doc: swap every font for Atkinson Hyperlegible.
static var readable_font := false
static var _fonts := {}


## UI font at a weight (400 regular, 500 medium, 600 semibold). Fredoka is a variable font.
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


## Children's handwriting (letters, crayon notes, P.S. lines).
static func hand() -> Font:
	if readable_font:
		return font(400)
	if not _fonts.has("hand"):
		_fonts["hand"] = load(HAND_PATH)
	return _fonts["hand"]


## The theme every HUD control inherits: Fredoka, ink text, paper buttons and tooltips.
static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font(400)
	t.default_font_size = 15
	for type in ["Label", "Button", "LinkButton", "CheckBox", "RichTextLabel", "TooltipLabel"]:
		t.set_color("font_color", type, INK)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_hover_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(INK, 0.45))
	t.set_color("font_hover_color", "LinkButton", INK)
	t.set_color("font_pressed_color", "LinkButton", INK)
	t.set_stylebox("normal", "Button", button_box(PAPER, PAPER_EDGE))
	t.set_stylebox("hover", "Button", button_box(PAPER.darkened(0.04), INK.lightened(0.35)))
	t.set_stylebox("pressed", "Button", button_box(TAB_TAN, INK))
	t.set_stylebox("hover_pressed", "Button", button_box(TAB_TAN.darkened(0.04), INK))
	t.set_stylebox("disabled", "Button", button_box(PAPER_DARK, PAPER_EDGE))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "TooltipPanel", paper_box(8, 8))
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font("font", "TooltipLabel", font(400))
	t.set_font_size("font_size", "TooltipLabel", 14)
	t.set_stylebox("panel", "PanelContainer", paper_box())
	t.set_stylebox("background", "ProgressBar", bar_box(Color("E9DCC4")))
	t.set_stylebox("fill", "ProgressBar", bar_box(TAB_TAN.darkened(0.15)))
	return t


# --- Boxes --------------------------------------------------------------------------

## A sheet of paper with a soft drop shadow.
static func paper_box(margin := 14, radius := 12, bg := PAPER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = PAPER_EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(NIGHT, 0.28)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb


static func button_box(bg: Color, border: Color, radius := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


## A paper tab that sticks up from the bottom edge (bottom corners square, no bottom border).
static func tab_box(active: bool) -> StyleBoxFlat:
	var sb := button_box(TAB_TAN if active else PAPER, INK if active else PAPER_EDGE, 12)
	sb.border_width_bottom = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.content_margin_top = 10 if active else 6
	return sb


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


static func paper_panel(margin := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", paper_box(margin))
	return p


static func button(text: String, size := 15, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font(600 if primary else 500))
	b.add_theme_font_size_override("font_size", size)
	if primary:
		b.add_theme_stylebox_override("normal", button_box(HONEY, INK))
		b.add_theme_stylebox_override("hover", button_box(HONEY.lightened(0.15), INK))
		b.add_theme_stylebox_override("pressed", button_box(HONEY.darkened(0.1), INK))
	return b


## A strip of tape stuck on a paper's top edge. Returns an overlay Control (containers
## stretch their children, so the strip itself sits inside it at a free position).
## Add it after the paper's content so it draws on top.
static func tape(at_x: float, angle_deg := -3.0) -> Control:
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := ColorRect.new()
	t.color = TAPE
	t.size = Vector2(64, 20)
	t.position = Vector2(at_x, -11)
	t.rotation_degrees = angle_deg
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(t)
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
