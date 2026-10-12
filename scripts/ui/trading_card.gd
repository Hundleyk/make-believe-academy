extends PanelContainer
## A student's trading card (UI System doc, "Building blocks"): portrait, personality,
## two-shade skill bars with the teacher's cap, quirk, needs, and which request they could help.

const Style := preload("res://scripts/ui/ui_style.gd")
const W := preload("res://scripts/ui/widgets.gd")
const Student := preload("res://scripts/student.gd")
const Readiness := preload("res://scripts/readiness.gd")

## The paper dragon's skill levels cap what students can learn (Systems doc, Teachers).
## Until teachers exist (M2) the starting teacher's caps are shown here.
const TEACHER_CAPS := {"bravery": 6, "listening": 4, "silliness": 2}
const TEACHER_NAME := "the paper dragon"

var hud: CanvasLayer
var student: Node3D
var _bars := {}
var _values := {}
var _needs_label: Label
var _help_box: VBoxContainer
var _refresh := 0.0


func setup(the_hud: CanvasLayer) -> void:
	hud = the_hud
	name = "TradingCard"
	var sb := Style.paper_box(10, 16)
	sb.border_color = Style.INK
	sb.set_border_width_all(3)
	add_theme_stylebox_override("panel", sb)
	position = Vector2(484, 96)
	custom_minimum_size = Vector2(380, 0)
	rotation_degrees = 1.0
	visible = false


func show_student(s: Node3D) -> void:
	student = s
	for c in get_children():
		c.queue_free()
	_bars.clear()
	_values.clear()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)

	# Portrait with personality and pace chips.
	var art := Control.new()
	art.custom_minimum_size = Vector2(356, 150)
	art.clip_contents = true
	col.add_child(art)
	var portrait := W.Portrait.new(s.data.gray_color, Vector2(356, 150), true, s.data.horns)
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.add_child(portrait)
	art.add_child(_chip(s.data.personality, Vector2(8, 8), true))
	art.add_child(_chip(s.data.learning_pace + " learner", Vector2(-1, 8), false))

	var head := HBoxContainer.new()
	col.add_child(head)
	var n := Style.label(s.data.display_name, 26, 600)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	var close := Style.button("Close", 13)
	close.tooltip_text = "Close the card  (Esc)"
	close.pressed.connect(UI.close_card)
	head.add_child(close)
	col.add_child(Style.label(s.data.kind, 14, 400, Style.INK_SOFT))

	# Skills.
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for skill in Student.SKILLS:
		var l := Style.label(skill.capitalize(), 14, 600)
		l.custom_minimum_size.x = 80
		grid.add_child(l)
		var bar := W.TwoShadeBar.new()
		bar.custom_minimum_size = Vector2(200, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(bar)
		var v := Style.label("", 14)
		v.custom_minimum_size.x = 34
		grid.add_child(v)
		_bars[skill] = bar
		_values[skill] = v
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 12)
	col.add_child(legend)
	legend.add_child(_swatch(Style.WOOD, "solid"))
	legend.add_child(_swatch(Style.CARDBOARD, "fresh (fades)"))
	var cap := Style.label("dotted line: %s's cap" % TEACHER_NAME, 12, 400, Style.INK_SOFT)
	cap.tooltip_text = "Students can't learn past their teacher's level in a skill."
	cap.mouse_filter = Control.MOUSE_FILTER_PASS
	legend.add_child(cap)

	# Quirk.
	var quirk := PanelContainer.new()
	quirk.add_theme_stylebox_override("panel", Style.flat_box(Style.PAPER_DARK, Color(0, 0, 0, 0), 0, 10, 10))
	col.add_child(quirk)
	var qcol := VBoxContainer.new()
	qcol.add_theme_constant_override("separation", 2)
	quirk.add_child(qcol)
	qcol.add_child(Style.label("Quirk: " + s.data.quirk, 14, 600))
	var qt := Style.label(s.data.quirk_text, 13)
	qt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	qt.custom_minimum_size.x = 330
	qcol.add_child(qt)
	qcol.add_child(Style.label("Loves: ?   Dislikes: ?   (found after 2 lessons each)", 12, 400, Style.INK_SOFT))

	_needs_label = Style.label("", 13)
	col.add_child(_needs_label)

	_help_box = VBoxContainer.new()
	_help_box.add_theme_constant_override("separation", 6)
	col.add_child(_help_box)
	refresh()


func refresh() -> void:
	if student == null:
		return
	for skill in Student.SKILLS:
		_bars[skill].set_values(student.solid(skill), student.fresh(skill), TEACHER_CAPS.get(skill, -1))
		_values[skill].text = "%.1f" % student.total(skill)
		_bars[skill].tooltip_text = "%s: %.1f solid + %.1f fresh.\nFresh points fade 10%% a day and count half in a Dream Test." % [
			skill.capitalize(), student.solid(skill), student.fresh(skill)]
	var parts := []
	for need in Student.NEEDS:
		parts.append("%s %d%s" % [Student.NEED_NAMES[need], student.needs[need], "!" if student.needs[need] < Student.LOW_NEED else ""])
	_needs_label.text = "  ·  ".join(parts) + "   —   " + student.activity
	for c in _help_box.get_children():
		c.queue_free()
	for letter in GameState.accepted_letters:
		var r := Readiness.check(student, letter)
		var box := PanelContainer.new()
		var sb := Style.flat_box(Color(0, 0, 0, 0), Style.CRAYON_PURPLE, 2, 10, 10)
		sb.border_blend = false
		box.add_theme_stylebox_override("panel", sb)
		_help_box.add_child(box)
		var bc := VBoxContainer.new()
		bc.add_theme_constant_override("separation", 2)
		box.add_child(bc)
		bc.add_child(Style.label("Could help %s?" % letter.child, 14, 600, Style.CRAYON_PURPLE))
		bc.add_child(Style.label("Needs %s %d and a %s friend." % [letter.skill_name(), letter.level, letter.best_trait], 13))
		bc.add_child(Style.hand_label("Readiness: " + r.word, 18, Style.INK))


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.3
		refresh()


func _chip(text: String, at: Vector2, left: bool) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Style.flat_box(Style.PAPER, Style.INK, 2, 8, 4))
	p.add_child(Style.label(text, 13, 600))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if left:
		p.position = at
	else:
		p.anchor_left = 1.0
		p.anchor_right = 1.0
		p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		p.offset_right = -8
		p.offset_top = at.y
	return p


func _swatch(color: Color, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var c := ColorRect.new()
	c.color = color
	c.custom_minimum_size = Vector2(14, 10)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(c)
	row.add_child(Style.label(text, 12, 400, Style.INK_SOFT))
	return row
