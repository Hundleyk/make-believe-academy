extends CanvasLayer
## Placeholder build-mode HUD: Giggles counter, catalog bar, hint line, combo popup.
## Styled as plain paper cards for now; the stationery look and fonts come later.

const PAPER := Color("FFF8E7")
const PAPER_EDGE := Color("DBCBB2")
const TAB_TAN := Color("E8B887")
const INK := Color("3B2C24")

var build_mode: Node3D
var _giggles_label: Label
var _hint_label: Label
var _toast: PanelContainer
var _toast_title: Label
var _toast_body: Label
var _toast_tween: Tween
var _buttons := {}   # ItemData -> Button


func setup(mode: Node3D) -> void:
	build_mode = mode
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Giggles, top left.
	var gig_panel := _paper_panel()
	gig_panel.position = Vector2(16, 16)
	root.add_child(gig_panel)
	_giggles_label = _label(26)
	gig_panel.add_child(_giggles_label)

	# Controls reminder, top right.
	var help := _label(15)
	help.text = "WASD pan  ·  Wheel zoom  ·  Q/E turn view"
	help.add_theme_color_override("font_color", PAPER)
	help.add_theme_color_override("font_outline_color", INK)
	help.add_theme_constant_override("outline_size", 6)
	help.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	help.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(help)

	# Catalog bar, bottom right.
	var catalog := _paper_panel()
	catalog.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	catalog.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	catalog.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(catalog)
	var col := VBoxContainer.new()
	catalog.add_child(col)
	var title := _label(18)
	title.text = "Build"
	col.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	for i in build_mode.catalog.size():
		var data: ItemData = build_mode.catalog[i]
		var b := Button.new()
		b.text = "%d  %s\n%d Giggles" % [i + 1, data.display_name, data.cost]
		b.tooltip_text = "%s\nGoes in %s." % [data.effect_text, data.room_rule_text()]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(118, 58)
		_style_button(b)
		b.pressed.connect(_on_item_pressed.bind(data))
		row.add_child(b)
		_buttons[data] = b

	# Hint line, bottom left.
	var hint_panel := _paper_panel()
	hint_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 16)
	hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint_panel)
	_hint_label = _label(16)
	_hint_label.custom_minimum_size.x = 470
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_panel.add_child(_hint_label)

	# Combo popup, top center.
	_toast = _paper_panel()
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 70)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	root.add_child(_toast)
	var tcol := VBoxContainer.new()
	_toast.add_child(tcol)
	_toast_title = _label(24)
	_toast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tcol.add_child(_toast_title)
	_toast_body = _label(16)
	_toast_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tcol.add_child(_toast_body)

	build_mode.hint_changed.connect(func(t: String): _hint_label.text = t)
	build_mode.toast_requested.connect(show_toast)
	build_mode.holding_changed.connect(_on_holding_changed)
	GameState.giggles_changed.connect(_on_giggles_changed)
	_on_giggles_changed(GameState.giggles)


func show_toast(title: String, body: String) -> void:
	_toast_title.text = title
	_toast_body.text = body
	_toast.visible = true
	_toast.modulate.a = 0.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(3.5)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(func(): _toast.visible = false)


func _on_item_pressed(data: ItemData) -> void:
	if build_mode.holding == data:
		build_mode.stop_holding()
	else:
		build_mode.start_holding(data)


func _on_holding_changed(data: ItemData) -> void:
	for d in _buttons:
		_buttons[d].set_pressed_no_signal(d == data)


func _on_giggles_changed(amount: int) -> void:
	_giggles_label.text = "Giggles  %d" % amount
	for d in _buttons:
		_buttons[d].disabled = amount < d.cost


# --- Little style helpers -------------------------------------------------------

func _paper_panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = PAPER_EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	return l


func _style_button(b: Button) -> void:
	var states := {
		"normal": PAPER, "hover": PAPER.darkened(0.06), "pressed": TAB_TAN,
		"hover_pressed": TAB_TAN.darkened(0.05), "disabled": PAPER.darkened(0.12),
	}
	for state in states:
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[state]
		sb.border_color = INK if state.contains("pressed") else PAPER_EDGE
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(6)
		b.add_theme_stylebox_override(state, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, INK)
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.45))
	b.add_theme_font_size_override("font_size", 14)
