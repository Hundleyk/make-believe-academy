extends PanelContainer
## Students drawer (left): one row per student with needs, best skill, and what they're doing.
## Click a row to open their trading card. Hover a need to see what raises it.

const Style := preload("res://scripts/ui/ui_style.gd")
const W := preload("res://scripts/ui/widgets.gd")
const Student := preload("res://scripts/student.gd")

var hud: CanvasLayer
var _rows := []          # [{student, button, needs: {need: Label}, status: Label, skill: Label}]
var _refresh := 0.0


func setup(the_hud: CanvasLayer) -> void:
	hud = the_hud
	name = "StudentsPanel"
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	position = Vector2(Style.HUD_INSET, 118)
	custom_minimum_size = Vector2(420, 0)
	visible = false
	var paper := W.Paper.new("paper", Vector4(20, 22, 22, 22), "a")
	add_child(paper)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	paper.add_child(col)
	paper.add_child(Style.tape(160, -3, "sky"))
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Style.label("Students", 26, 600)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var enrolled := Style.chip("%d enrolled" % hud.students.students.size(), Style.TAB_TAN, Color(0, 0, 0, 0), 12, 600)
	enrolled.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(enrolled)
	for s in hud.students.students:
		col.add_child(_row(s))
	var tip := Style.label("Click a student for their card. Hover a need to see what raises it.", 14, 500, Style.INK_SOFT)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size.x = 370
	col.add_child(tip)


func _row(s: Node3D) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(376, 84)
	b.add_theme_stylebox_override("normal", Style.card_box(false, true, 0))
	b.add_theme_stylebox_override("hover", Style.card_box(false, false, 0))
	b.add_theme_stylebox_override("pressed", Style.card_box(true, false, 0))
	b.add_theme_stylebox_override("hover_pressed", Style.card_box(true, false, 0))
	b.pressed.connect(func():
		if UI.card_student == s:
			UI.close_card()
		else:
			UI.open_card(s))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	b.add_child(row)
	var face := PanelContainer.new()
	face.add_theme_stylebox_override("panel", Style.flat_box(Style.SKY_LIGHT, Style.PAPER_SHADOW, 2, 28, 4))
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face.clip_contents = true
	face.add_child(W.Portrait.new(s.data.gray_color, Vector2(44, 48), false, s.data.horns))
	row.add_child(face)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var name_label := Style.label(s.data.display_name, 18, 600)
	top.add_child(name_label)
	var kind := Style.hand_label("  %s" % s.data.kind.capitalize(), 18, Style.INK_SOFT)
	kind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(kind)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", Style.flat_box(Style.TAB_TAN, Color(0, 0, 0, 0), 0, 6, 3))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skill_label := Style.label("", 12, 600)
	chip.add_child(skill_label)
	top.add_child(chip)
	var needs := HBoxContainer.new()
	needs.add_theme_constant_override("separation", 10)
	needs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(needs)
	var labels := {}
	for need in Student.NEEDS:
		var l := Style.label("", 14, 500)
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		l.mouse_default_cursor_shape = Control.CURSOR_HELP
		l.tooltip_text = hud.students.what_raises(need)
		needs.add_child(l)
		labels[need] = l
	var status := Style.label("", 14, 500, Style.INK_SOFT)
	status.clip_text = true
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.custom_minimum_size.x = 260
	col.add_child(status)
	_rows.append({"student": s, "button": b, "needs": labels, "status": status, "skill": skill_label})
	return b


func refresh() -> void:
	for r in _rows:
		var s: Node3D = r.student
		for need in Student.NEEDS:
			var v: int = s.needs[need]
			var l: Label = r.needs[need]
			# Low needs get a "!" and coral, never color alone.
			l.text = "%s %d%s" % [Student.NEED_NAMES[need], v, "!" if v < Student.LOW_NEED else ""]
			l.add_theme_color_override("font_color", Style.INK)
			l.add_theme_font_override("font", Style.font(700 if v < Student.LOW_NEED else 500))
		var best: String = s.best_skill()
		r.skill.text = "%s %.1f" % [best.capitalize(), s.total(best)]
		r.status.text = s.activity
		r.button.set_pressed_no_signal(UI.card_student == s)


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.25
		refresh()
