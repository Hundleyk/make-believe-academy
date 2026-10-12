extends CanvasLayer
## Placeholder HUD: Giggles counter, students panel, Build menu, hint line, combo popup.
## Styled as plain paper cards for now; the stationery look and fonts come later.

const BuildMenu := preload("res://scripts/build_menu.gd")

const PAPER := Color("FFF8E7")
const PAPER_EDGE := Color("DBCBB2")
const TAB_TAN := Color("E8B887")
const INK := Color("3B2C24")
const HEART := Color("E05A68")
const LOW_NEED := 3

var build_mode: Node3D
var _giggles_label: Label
var _hint_label: Label
var _toast: PanelContainer
var _toast_title: Label
var _toast_body: Label
var _toast_tween: Tween
var build_menu: PanelContainer
var _root: Control
var _students: Node3D
var _period_label: Label
var _rows := []      # [{student, bars: {need: ProgressBar}, values: {need: Label}, status: Label}]
var _refresh := 0.0


func setup(mode: Node3D) -> void:
	build_mode = mode
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_root = root

	# Giggles, top left.
	var gig_panel := _paper_panel()
	gig_panel.position = Vector2(16, 16)
	root.add_child(gig_panel)
	_giggles_label = _label(26)
	gig_panel.add_child(_giggles_label)

	# Controls reminder, top right.
	var help := _label(15)
	help.text = "WASD pan  ·  Wheel zoom  ·  Q/E turn view  ·  Hover a student to see their needs"
	help.add_theme_color_override("font_color", PAPER)
	help.add_theme_color_override("font_outline_color", INK)
	help.add_theme_constant_override("outline_size", 6)
	help.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	help.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(help)

	# Build menu, bottom right: one tab per room plus Anywhere.
	build_menu = BuildMenu.new()
	build_menu.name = "BuildMenu"
	root.add_child(build_menu)
	build_menu.setup(self, build_mode)

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
	GameState.giggles_changed.connect(_on_giggles_changed)
	_on_giggles_changed(GameState.giggles)


## Students panel under the Giggles counter: each student's needs and what they're doing.
func setup_students(students: Node3D) -> void:
	_students = students
	var panel := _paper_panel()
	panel.position = Vector2(16, 76)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var title := _label(18)
	title.text = "Students"
	col.add_child(title)
	_period_label = _label(13)
	col.add_child(_period_label)
	for st in students.students:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 1)
		col.add_child(box)
		var name_row := HBoxContainer.new()
		box.add_child(name_row)
		var name_label := _label(16)
		name_label.text = st.data.display_name
		name_row.add_child(name_label)
		var kind := _label(13)
		kind.text = "  " + st.data.kind
		kind.add_theme_color_override("font_color", Color(INK, 0.6))
		name_row.add_child(kind)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		var entry := {"student": st, "bars": {}, "values": {}}
		for need in st.NEEDS:
			var tag := _label(13)
			tag.text = st.NEED_NAMES[need]
			tag.mouse_filter = Control.MOUSE_FILTER_PASS
			tag.mouse_default_cursor_shape = Control.CURSOR_HELP
			tag.tooltip_text = what_raises(need, st.NEED_NAMES[need])
			row.add_child(tag)
			var bar := ProgressBar.new()
			bar.max_value = st.MAX_NEED
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(46, 12)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.mouse_filter = Control.MOUSE_FILTER_PASS
			bar.tooltip_text = tag.tooltip_text
			row.add_child(bar)
			var value := _label(13)
			value.custom_minimum_size.x = 26
			row.add_child(value)
			entry.bars[need] = bar
			entry.values[need] = value
		var status := _label(13)
		status.add_theme_color_override("font_color", Color(INK, 0.75))
		box.add_child(status)
		entry["status"] = status
		_rows.append(entry)
	_update_students()


## Tooltip for a need: every item and combo that raises it, best first.
func what_raises(need: String, need_name: String) -> String:
	var rows := []
	for d in build_mode.catalog:
		var amount := int(d.need_mods.get(need, 0))
		if amount > 0:
			var where: String = d.room_rule_text()
			var note: String = "  (research first)" if d.research_ideas > 0 else ""
			rows.append([amount, "  %s  +%d  ·  %d Giggles  ·  %s%s" % [d.display_name, amount, d.cost, where, note]])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	var lines := ["What raises %s (students standing in the item's ring get it each period):" % need_name]
	for r in rows:
		lines.append(r[1])
	if rows.is_empty():
		lines.append("  Nothing yet")
	var combo_lines := []
	for c in build_mode.combos:
		var amount := int(c.need_mods.get(need, 0))
		if amount > 0:
			combo_lines.append("  %s  +%d" % [c.display_name, amount] if GameState.discovered_combos.has(c.id) else "  A combo you haven't found yet  +%d" % amount)
	if not combo_lines.is_empty():
		lines.append("Combos:")
		lines.append_array(combo_lines)
	return "\n".join(lines)


func _process(delta: float) -> void:
	if _students == null:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.2
		_update_students()


func _update_students() -> void:
	_period_label.text = "Period %d  ·  needs change in %ds" % [_students.period, ceili(maxf(_students.period_left, 0.0))]
	for entry in _rows:
		var st = entry.student
		for need in st.NEEDS:
			var v: int = st.needs[need]
			var low := v < LOW_NEED
			var bar: ProgressBar = entry.bars[need]
			bar.value = v
			_style_bar(bar, low)
			# Low needs get a "!" as well as the coral bar, so it never relies on color alone.
			entry.values[need].text = ("%d!" % v) if low else str(v)
		entry.status.text = st.activity


func _style_bar(bar: ProgressBar, low: bool) -> void:
	if bar.has_meta("low") and bar.get_meta("low") == low:
		return
	bar.set_meta("low", low)
	var bg := StyleBoxFlat.new()
	bg.bg_color = PAPER_EDGE
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = HEART if low else TAB_TAN.darkened(0.15)
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)


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


func _on_giggles_changed(amount: int) -> void:
	_giggles_label.text = "Giggles  %d" % amount


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
