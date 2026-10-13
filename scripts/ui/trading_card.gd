extends Control
## Checking on a student (mockup 08): the StudentCard (components/cards/StudentCard.jsx) on
## the right, and beside it a lined "Today" note and Follow / Edit Timetable / Send to Nap
## Room buttons. The card shows skills as segment bars (solid plus fresh), personality and
## quirk tags, a still-hidden trait, and which request they could help.

const Style := preload("res://scripts/ui/ui_style.gd")
const W := preload("res://scripts/ui/widgets.gd")
const Student := preload("res://scripts/student.gd")
const Readiness := preload("res://scripts/readiness.gd")
const CrayonNotes := preload("res://scripts/ui/crayon_notes.gd")

## The paper dragon's skill levels cap what students can learn (Systems doc, Teachers).
## Until teachers exist (M2) the starting teacher's caps are shown here.
const TEACHER_CAPS := {"bravery": 6, "listening": 4, "silliness": 2}
const TEACHER_NAME := "the paper dragon"

var hud: CanvasLayer
var student: Node3D
var _card: PanelContainer
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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.anchor_left = 1.0
	row.anchor_right = 1.0
	row.offset_right = -28
	row.offset_top = 52 + 18
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	# Beside the card: today's note and the actions.
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 14)
	side.custom_minimum_size.x = 250
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(side)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 14
	side.add_child(spacer)
	var note := W.Paper.new("lined", Vector4(22, 20, 14, 50), "b", -2.0)
	note.line_offset = 22.0
	side.add_child(note)
	_today = VBoxContainer.new()
	_today.add_theme_constant_override("separation", 0)
	note.add_child(_today)
	var follow := Style.button("Follow %s" % s.data.display_name, "md", true, "crosshair")
	follow.tooltip_text = "Glide the camera to %s." % s.data.display_name
	follow.pressed.connect(func():
		if hud.main.camera_rig != null:
			hud.main.camera_rig.focus_on(s.global_position))
	side.add_child(follow)
	var tt := Style.button("Edit Timetable", "md", true, "calendar")
	tt.disabled = true
	tt.tooltip_text = "The Timetable arrives with the day clock (M1 week 4)."
	side.add_child(tt)
	var nap := Style.button("Nap in Pillow Mountain", "md", true, "moon")
	nap.tooltip_text = "Pillow Mountain is the only room with beds. %s walks there for a rest." % s.data.display_name
	nap.pressed.connect(func():
		var dorm: Dictionary = hud.main.room_by_id("dorm")
		if not dorm.is_empty() and s.walk_to(hud.main.room_center(dorm) + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.0, 1.0))):
			s.activity = "Off to Pillow Mountain for a nap")
	side.add_child(nap)

	# The StudentCard: a cardboard frame (selected: ink rim, lifted, tilted -1°).
	_card = PanelContainer.new()
	var frame := Style.flat_box(Style.CARDBOARD, Style.INK, 3, 16, 8)
	frame.corner_radius_top_left = 18
	frame.corner_radius_top_right = 14
	frame.corner_radius_bottom_right = 20
	frame.corner_radius_bottom_left = 13
	frame.shadow_color = Style.WOOD
	frame.shadow_size = 1
	frame.shadow_offset = Vector2(0, 8)
	_card.add_theme_stylebox_override("panel", frame)
	_card.custom_minimum_size = Vector2(290, 0)
	_card.rotation_degrees = -1.0
	_card.resized.connect(func(): _card.pivot_offset = _card.size / 2.0)
	row.add_child(_card)
	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override("panel", Style.flat_box(Style.PAPER, Color(0, 0, 0, 0), 0, 12, 12))
	_card.add_child(inner)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	inner.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(Style.label(s.data.display_name, 24, 700))
	names.add_child(Style.hand_label(s.data.kind.capitalize(), 19, Style.INK_SOFT))
	var year := Style.chip("Year 1", Style.TAB_TAN, Color(0, 0, 0, 0), 12, 600)
	year.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(year)
	var close := Style.button("", "sm", false, "x")
	close.custom_minimum_size = Vector2(32, 30)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.tooltip_text = "Close the card  (Esc)"
	close.pressed.connect(UI.close_card)
	head.add_child(close)

	# Portrait slot: sky-light with paper stripes, the student in it, a mood sticker.
	var art := Control.new()
	art.custom_minimum_size = Vector2(0, 148)
	art.clip_contents = true
	col.add_child(art)
	var stripes := W.Stripes.new()
	stripes.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.add_child(stripes)
	var portrait := W.Portrait.new(s.data.gray_color, Vector2(110, 130), false, s.data.horns)
	portrait.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	portrait.offset_left = -55
	portrait.offset_right = 55
	portrait.offset_top = -130
	art.add_child(portrait)
	var mood := W.Icon.new(_mood_icon(s), 40, _mood_color(s), "fill", true)
	mood.anchor_left = 1.0
	mood.anchor_right = 1.0
	mood.offset_left = -50
	mood.offset_right = -10
	mood.offset_top = 8
	mood.offset_bottom = 48
	mood.name = "Mood"
	art.add_child(mood)

	# Skills (SkillBar size sm): label, segments, value, fresh chip.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 7)
	col.add_child(grid)
	for skill in Student.SKILLS:
		var l := Style.label(skill.capitalize(), 14, 600)
		l.custom_minimum_size.x = 70
		grid.add_child(l)
		var bar := W.DotBar.new(10, Vector2(120, 10))
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(bar)
		var v := Style.label("", 14, 700)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.custom_minimum_size.x = 26
		grid.add_child(v)
		var f := Style.chip("", Style.TAB_TAN, Color(0, 0, 0, 0), 12, 700)
		f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		f.tooltip_text = "Fresh points: they fade unless practiced, and count half in a Dream Test."
		f.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(f)
		_bars[skill] = bar
		_values[skill] = v
		_fresh[skill] = f

	var rule := W.Dashed.new(Style.PAPER_SHADOW, 2.0)
	rule.custom_minimum_size = Vector2(0, 2)
	col.add_child(rule)

	var traits := VBoxContainer.new()
	traits.add_theme_constant_override("separation", 6)
	col.add_child(traits)
	_trait(traits, "Personality", Style.chip(s.data.personality, Style.LAVENDER_LIGHT, Color(0, 0, 0, 0), 14, 600, Style.INK, 8))
	var q := Style.chip(s.data.quirk, Style.PEACH_LIGHT, Color(0, 0, 0, 0), 14, 600, Style.INK, 8)
	q.tooltip_text = s.data.quirk_text
	q.mouse_filter = Control.MOUSE_FILTER_PASS
	_trait(traits, "Quirk", q)
	_trait(traits, "Quirk", _undiscovered())

	_help_box = VBoxContainer.new()
	_help_box.add_theme_constant_override("separation", 6)
	col.add_child(_help_box)
	refresh()


func _trait(parent: Control, kind: String, value: Control) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	parent.add_child(r)
	var l := Style.caps(kind, 12)
	l.custom_minimum_size.x = 92
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(l)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(value)


## The hidden trait: a dashed lavender box with a "?" (found through play).
func _undiscovered() -> Control:
	var box := PanelContainer.new()
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	box.add_theme_stylebox_override("panel", sb)
	box.tooltip_text = "About 1 in 3 students has a hidden quirk you find through play. Loves and dislikes show up after 2 lessons each."
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(W.Dashed.new(Style.LAVENDER, 2.5))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var dot := PanelContainer.new()
	dot.add_theme_stylebox_override("panel", Style.flat_box(Style.LAVENDER, Color(0, 0, 0, 0), 0, 11, 0))
	dot.custom_minimum_size = Vector2(22, 22)
	var qm := Style.label("?", 15, 700, Style.PAPER)
	qm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dot.add_child(qm)
	row.add_child(dot)
	var t := Style.label("Not discovered yet", 14, 600, Style.INK_SOFT)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	return box


## The mood sticker (components/feedback/MoodIcon.jsx), from their lowest need.
func _mood_icon(s: Node3D) -> String:
	match s.lowest_need() if s.needs[s.lowest_need()] < Student.LOW_NEED else "":
		"calm":
			return "smiley-nervous"
		"rest":
			return "moon"
		"fun":
			return "cloud-rain"
	return "heart"


func _mood_color(s: Node3D) -> Color:
	match _mood_icon(s):
		"smiley-nervous":
			return Style.PEACH
		"moon":
			return Style.SKY
		"cloud-rain":
			return Style.LAVENDER
	return Style.HEART


func refresh() -> void:
	if student == null or not is_instance_valid(_today):
		return
	for skill in Student.SKILLS:
		var sol: float = student.solid(skill)
		var fr: float = student.fresh(skill)
		_bars[skill].set_values(sol, fr, TEACHER_CAPS.get(skill, -1))
		_values[skill].text = str(floori(sol + 0.0001))
		_fresh[skill].get_child(0).text = "+%s" % (str(snappedf(fr, 0.1)))
		_fresh[skill].modulate.a = 1.0 if fr > 0.05 else 0.0
		_bars[skill].tooltip_text = "%s: %.1f solid + %.1f fresh.\nFresh points fade 10%% a day and count half in a Dream Test.\nThe ink notch is %s's level: students can't learn past their teacher." % [
			skill.capitalize(), sol, fr, TEACHER_NAME]
	var mood: Control = _card.find_child("Mood", true, false)
	if mood != null:
		mood.set_icon(_mood_icon(student), _mood_color(student))
	# Today's note: what they're doing, their needs, and why those changed.
	for c in _today.get_children():
		c.queue_free()
	var head := Style.caps("Today", 13)
	head.custom_minimum_size.y = 20
	_today.add_child(head)
	_today.add_child(CrayonNotes.lined("now: " + String(student.activity).to_lower(), Style.INK, 180))
	var parts := []
	for need in Student.NEEDS:
		parts.append("%s %d%s" % [Student.NEED_NAMES[need].to_lower(), student.needs[need], "!" if student.needs[need] < Student.LOW_NEED else ""])
	_today.add_child(CrayonNotes.lined(" · ".join(parts), Style.INK, 180))
	var shown := 0
	for need in Student.NEEDS:
		for ch in student.last_changes.get(need, []):
			if int(ch[1]) != 0 and shown < 2:
				_today.add_child(CrayonNotes.lined("%s%d %s, %s" % ["+" if ch[1] > 0 else "", ch[1], Student.NEED_NAMES[need].to_lower(), ch[0]], Style.INK, 180))
				shown += 1
	if shown == 0:
		_today.add_child(CrayonNotes.lined("nothing much yet…", Style.INK_SOFT, 180))
	for c in _help_box.get_children():
		c.queue_free()
	for letter in GameState.accepted_letters:
		var r := Readiness.check(student, letter)
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", Style.flat_box(Style.BOARD, Style.PAPER_SHADOW, 2, 8, 8))
		_help_box.add_child(box)
		var hr := HBoxContainer.new()
		hr.add_theme_constant_override("separation", 8)
		box.add_child(hr)
		var mark := W.PlacementMark.new(r.steps_short == 0, 20)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hr.add_child(mark)
		var t := Style.label("Help %s? %s" % [letter.child, r.word], 14, 600)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.tooltip_text = "Needs %s %d and a %s friend." % [letter.skill_name(), letter.level, letter.best_trait]
		t.mouse_filter = Control.MOUSE_FILTER_PASS
		hr.add_child(t)


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.5
		refresh()
