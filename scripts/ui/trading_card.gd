extends Control
## A student's trading card (mockup 08, "Checking on a student"): the card on the right with
## name, species, portrait, dot skill bars, personality and quirk chips; a "Today" diary
## note and action buttons beside it. Shows which request they could help and how ready
## they are.

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
var _card: PanelContainer
var _side: VBoxContainer
var _bars := {}
var _values := {}
var _fresh := {}
var _today: VBoxContainer
var _help_box: VBoxContainer
var _refresh := 0.0


func setup(the_hud: CanvasLayer) -> void:
	hud = the_hud
	name = "TradingCard"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func show_student(s: Node3D) -> void:
	student = s
	for c in get_children():
		c.queue_free()
	_bars.clear()
	_values.clear()
	_fresh.clear()

	_card = PanelContainer.new()
	var sb := Style.flat_box(Style.PAPER, Style.CARDBOARD, 8, 18, 16)
	sb.shadow_color = Color(Style.NIGHT, 0.35)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(3, 6)
	_card.add_theme_stylebox_override("panel", sb)
	_card.custom_minimum_size = Vector2(390, 0)
	_card.anchor_left = 1.0
	_card.anchor_right = 1.0
	_card.offset_left = -410
	_card.offset_right = -20
	_card.offset_top = 132
	_card.rotation_degrees = 0.6
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_card.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -6)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(Style.label(s.data.display_name, 30, 700))
	names.add_child(Style.hand_label(s.data.kind.capitalize(), 22, Style.INK_SOFT))
	var year := Style.chip("Year 1", Style.TAB_TAN, Color(0, 0, 0, 0), 13, 700)
	year.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(year)
	var close := Button.new()
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(34, 34)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.tooltip_text = "Close the card  (Esc)"
	close.add_theme_stylebox_override("normal", Style.lip_box(Style.PAPER, false, false, false, false, 8))
	close.add_theme_stylebox_override("hover", Style.lip_box(Style.PAPER_DARK, false, false, false, false, 8))
	close.add_theme_stylebox_override("pressed", Style.lip_box(Style.PAPER, false, true, true, false, 8))
	var x := W.Icon.new("close", 16)
	x.position = Vector2(9, 7)
	close.add_child(x)
	close.pressed.connect(UI.close_card)
	head.add_child(close)

	# Portrait on blue stripes.
	var art := Control.new()
	art.custom_minimum_size = Vector2(0, 138)
	art.clip_contents = true
	col.add_child(art)
	var stripes := W.Stripes.new()
	stripes.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.add_child(stripes)
	var portrait := W.Portrait.new(s.data.gray_color, Vector2(120, 118), false, s.data.horns)
	portrait.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	portrait.offset_left = -60
	portrait.offset_right = 60
	portrait.offset_top = -118
	art.add_child(portrait)

	# Skills as dot bars.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	for skill in Student.SKILLS:
		var l := Style.label(skill.capitalize(), 16, 600)
		l.custom_minimum_size.x = 84
		grid.add_child(l)
		var bar := W.DotBar.new(10, Vector2(160, 14))
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(bar)
		var v := Style.label("", 16, 700)
		v.custom_minimum_size.x = 30
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(v)
		var f := Style.chip("", Style.HONEY, Color(0, 0, 0, 0), 12, 700)
		f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		f.tooltip_text = "Fresh points: they fade 10% a day unless practiced, and count half in a Dream Test."
		f.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(f)
		_bars[skill] = bar
		_values[skill] = v
		_fresh[skill] = f
	var legend := Style.label("Dark dots solid · outlined dots fresh · line: %s's cap" % TEACHER_NAME, 12, 400, Style.INK_SOFT)
	legend.tooltip_text = "Students can't learn past their teacher's level in a skill."
	legend.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(legend)

	var rule := W.Dashed.new(Style.PAPER_EDGE)
	rule.custom_minimum_size = Vector2(0, 2)
	col.add_child(rule)

	var traits := GridContainer.new()
	traits.columns = 2
	traits.add_theme_constant_override("h_separation", 14)
	traits.add_theme_constant_override("v_separation", 6)
	col.add_child(traits)
	_trait(traits, "Personality", Style.chip(s.data.personality, Style.LAVENDER, Color(0, 0, 0, 0), 15, 600))
	var q := Style.chip(s.data.quirk, Style.PINK, Color(0, 0, 0, 0), 15, 600)
	q.tooltip_text = s.data.quirk_text
	q.mouse_filter = Control.MOUSE_FILTER_PASS
	_trait(traits, "Quirk", q)
	_trait(traits, "Learns", Style.chip(s.data.learning_pace, Style.MINT, Color(0, 0, 0, 0), 15, 600))
	_trait(traits, "Loves", _undiscovered())
	var qt := Style.label(s.data.quirk_text, 13, 400, Style.INK_SOFT)
	qt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	qt.custom_minimum_size.x = 340
	col.add_child(qt)

	_help_box = VBoxContainer.new()
	_help_box.add_theme_constant_override("separation", 6)
	col.add_child(_help_box)

	# Beside the card: today's diary and the actions.
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 12)
	_side.anchor_left = 1.0
	_side.anchor_right = 1.0
	_side.offset_left = -790
	_side.offset_right = -430
	_side.offset_top = 150
	add_child(_side)
	var note := W.Notebook.new(32, 52, 26)
	note.rotation_degrees = 1.2
	_side.add_child(note)
	_today = VBoxContainer.new()
	_today.add_theme_constant_override("separation", 0)
	note.add_child(_today)
	note.add_child(Style.tape(230, -3, Style.WASHI_PINK))
	var follow := Style.button("Follow %s" % s.data.display_name, 19, true, "eye")
	follow.custom_minimum_size = Vector2(0, 54)
	follow.tooltip_text = "Glide the camera to %s." % s.data.display_name
	follow.pressed.connect(func():
		if hud.main.camera_rig != null:
			hud.main.camera_rig.focus_on(s.global_position))
	_side.add_child(follow)
	var tt := Style.button("Edit Timetable", 19, true, "calendar")
	tt.custom_minimum_size = Vector2(0, 54)
	tt.disabled = true
	tt.tooltip_text = "The Timetable arrives with the day clock (M1 week 4)."
	_side.add_child(tt)
	var nap := Style.button("Send to Nap Room", 19, true, "moon")
	nap.custom_minimum_size = Vector2(0, 54)
	nap.disabled = true
	nap.tooltip_text = "Sending students to rooms arrives with the Timetable (M1 week 4)."
	_side.add_child(nap)
	refresh()


func _trait(grid: GridContainer, title: String, value: Control) -> void:
	var l := Style.caps(title, 13)
	l.custom_minimum_size.x = 110
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(l)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(value)


## A dashed "? Not discovered yet" box (loves and dislikes show up after 2 lessons each).
func _undiscovered() -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", Style.flat_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 10, 5))
	box.tooltip_text = "Loves and dislikes show up after 2 lessons each."
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var d := W.Dashed.new(Style.CRAYON_PURPLE)
	box.add_child(d)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var dot := Style.chip("?", Style.CRAYON_PURPLE, Color(0, 0, 0, 0), 12, 700, Style.PAPER)
	row.add_child(dot)
	row.add_child(Style.label("Not discovered yet", 14, 600))
	return box


func refresh() -> void:
	if student == null or not is_instance_valid(_today):
		return
	for skill in Student.SKILLS:
		_bars[skill].set_values(student.solid(skill), student.fresh(skill), TEACHER_CAPS.get(skill, -1))
		_values[skill].text = "%.0f" % floorf(student.total(skill)) if is_equal_approx(student.total(skill), roundf(student.total(skill))) else "%.1f" % student.total(skill)
		var f: float = student.fresh(skill)
		_fresh[skill].get_child(0).text = "+%.1f" % f
		_fresh[skill].modulate.a = 1.0 if f > 0.05 else 0.0
		_bars[skill].tooltip_text = "%s: %.1f solid + %.1f fresh.\nFresh points fade 10%% a day and count half in a Dream Test." % [
			skill.capitalize(), student.solid(skill), student.fresh(skill)]
	# Today's diary: what they're doing, their needs, and why those changed.
	for c in _today.get_children():
		c.queue_free()
	_today.add_child(Style.caps("Today", 14))
	_today_line("now: " + student.activity.to_lower())
	var parts := []
	for need in Student.NEEDS:
		parts.append("%s %d%s" % [Student.NEED_NAMES[need].to_lower(), student.needs[need], "!" if student.needs[need] < Student.LOW_NEED else ""])
	_today_line(" · ".join(parts))
	var shown := 0
	for need in Student.NEEDS:
		for ch in student.last_changes.get(need, []):
			if int(ch[1]) != 0 and shown < 3:
				_today_line("%s%d %s, %s" % ["+" if ch[1] > 0 else "", ch[1], Student.NEED_NAMES[need].to_lower(), ch[0]])
				shown += 1
	if shown == 0:
		_today_line("nothing much yet...")
	for c in _help_box.get_children():
		c.queue_free()
	for letter in GameState.accepted_letters:
		var r := Readiness.check(student, letter)
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", Style.flat_box(Style.PAPER_DARK, Color(0, 0, 0, 0), 0, 10, 8))
		_help_box.add_child(box)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var t := Style.label("Could help %s? Needs %s %d." % [letter.child, letter.skill_name(), letter.level], 14, 600)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		row.add_child(Style.hand_label(r.word, 22, Style.CRAYON_PURPLE))


func _today_line(text: String) -> void:
	var l := Style.hand_label(text, 22, Style.CRAYON_BLUE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(290, 32)
	_today.add_child(l)


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.5
		refresh()
