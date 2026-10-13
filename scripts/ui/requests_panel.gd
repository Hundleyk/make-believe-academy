extends PanelContainer
## Requests (mockup 10, "Who can help Leo?"): cut paper with peach tape. The Department's
## RequestForm on the left; on the right every student ranked by readiness (Systems doc:
## readiness meter, matching), as helper rows with a skill bar and a placement mark. Pick a
## friend to see why they would or wouldn't do; sending them waits for Dream Night.

const Style := preload("res://scripts/ui/ui_style.gd")
const W := preload("res://scripts/ui/widgets.gd")
const Readiness := preload("res://scripts/readiness.gd")

var hud: CanvasLayer
var current: LetterData
var picked: Node3D                 ## The friend ticked in the list
var _form_holder: Control
var _title: Label
var _tabs: HBoxContainer
var _body: VBoxContainer          ## One row per student
var _why: VBoxContainer
var _needs_line: Label
var _send: Button
var _refresh := 0.0


func setup(the_hud: CanvasLayer) -> void:
	hud = the_hud
	name = "RequestsPanel"
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 52 + 18)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	visible = false
	var paper := W.Paper.new("paper", Vector4(22, 26, 24, 26), "a")
	add_child(paper)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	paper.add_child(row)
	_form_holder = MarginContainer.new()
	_form_holder.custom_minimum_size.x = 340
	_form_holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_form_holder)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.custom_minimum_size.x = 540
	row.add_child(right)
	var head := HBoxContainer.new()
	right.add_child(head)
	_title = Style.label("Who can help?", 26, 600)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := Style.button("Close", "sm", false, "x")
	close.tooltip_text = "Close Requests  (R or Esc)"
	close.pressed.connect(UI.close_drawer)
	head.add_child(close)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	right.add_child(_tabs)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	right.add_child(_body)
	_why = VBoxContainer.new()
	_why.add_theme_constant_override("separation", 2)
	right.add_child(_why)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	right.add_child(foot)
	_needs_line = Style.label("", 15, 500, Style.INK_SOFT)
	_needs_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_needs_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_needs_line)
	_send = Style.button("Send a friend", "lg", true, "paper-plane-tilt")
	_send.disabled = true
	_send.tooltip_text = "Friends are sent on Dream Night (M1 week 5).\nFor now: get them ready."
	foot.add_child(_send)
	paper.add_child(Style.tape(130, -4, "peach"))


func refresh() -> void:
	var letters: Array = hud.main.open_letters()
	if current != null and not letters.has(current):
		current = null
	if current == null and not letters.is_empty():
		current = letters[0]
	for c in _tabs.get_children():
		c.queue_free()
	_tabs.visible = letters.size() > 1
	if letters.size() > 1:
		for l in letters:
			var b := Style.tab_button("%s · %s %d" % [l.child, l.skill_name(), l.level], "sm")
			b.set_pressed_no_signal(l == current)
			b.pressed.connect(func():
				current = l
				picked = null
				refresh())
			_tabs.add_child(b)
	for c in _form_holder.get_children():
		c.queue_free()
	for c in _body.get_children():
		c.queue_free()
	for c in _why.get_children():
		c.queue_free()
	if current == null:
		_title.text = "No letters yet"
		return
	_form_holder.add_child(_form(current))
	_title.text = "Who can help %s?" % current.child
	var left := GameState.days_left(current)
	_title.tooltip_text = "%d day%s left: %s" % [left, "" if left == 1 else "s", "be ready by Dream Night, day %d." % current.dream_day if GameState.accepted_letters.has(current) else "answer within %d days or the letter is gone (Kids' Trust -1)." % current.answer_days]
	_title.mouse_filter = Control.MOUSE_FILTER_PASS
	var ranked: Array = []
	for s in hud.students.students:
		ranked.append([s, Readiness.check(s, current)])
	ranked.sort_custom(func(a, b):
		if a[1].chance != b[1].chance:
			return a[1].chance > b[1].chance
		return a[1].effective > b[1].effective)
	if picked == null or not is_instance_valid(picked):
		picked = ranked[0][0] if not ranked.is_empty() else null
	for r in ranked:
		_body.add_child(_helper_row(r[0], r[1]))
	_needs_line.text = "Needs %s %d or more" % [current.skill_name(), current.level]
	_needs_line.tooltip_text = "Pairs best with a %s friend." % current.best_trait
	if picked != null:
		_send.text = "Send %s" % picked.data.display_name
		var pr := Readiness.check(picked, current)
		for reason in pr.reasons:
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 8)
			match reason[0]:
				"ok":
					line.add_child(W.PlacementMark.new(true, 16))
				"bad":
					line.add_child(W.PlacementMark.new(false, 16))
				_:
					line.add_child(W.Note.new(16))
			line.add_child(Style.label(reason[1], 14, 500, Style.INK_SOFT))
			_why.add_child(line)


## The Department form (components/paper/RequestForm.jsx).
func _form(l: LetterData) -> Control:
	var accepted := GameState.accepted_letters.has(l)
	var paper := W.Paper.new("paper", Vector4(22, 26, 26, 26), "a", 0.0, true)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	paper.add_child(col)
	var dept := Label.new()
	dept.text = "DEPARTMENT OF IMAGINARY AFFAIRS"
	dept.add_theme_font_override("font", Style.font(700, 1))
	dept.add_theme_font_size_override("font_size", 13)
	dept.add_theme_color_override("font_color", Style.WOOD)
	dept.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dept.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dept.custom_minimum_size.x = 280
	col.add_child(dept)
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	col.add_child(gap)
	var rule := W.Dashed.new(Style.CARDBOARD, 2.0)
	rule.custom_minimum_size = Vector2(0, 2)
	col.add_child(rule)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	var t := Style.label("Request for\n%s" % l.skill_name(), 22, 600)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var no := Style.label("Form 7-%s" % l.skill_name().left(1), 13, 600, Style.INK_SOFT)
	no.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(no)
	var fields := VBoxContainer.new()
	fields.add_theme_constant_override("separation", 12)
	col.add_child(fields)
	_field(fields, "From", "%s, age %d" % [l.child, l.age])
	_field(fields, "Problem", l.problem if l.problem != "" else l.body.left(40))
	_field(fields, "Needs", l.wants if l.wants != "" else "%s %d" % [l.skill_name(), l.level])
	var left := GameState.days_left(l)
	var due := "Dream Night, day %d" % l.dream_day if accepted else "answer by day %d" % (l.arrives_day + l.answer_days)
	_field(fields, "Due", "%s (%s)" % [due, "today!" if left <= 0 else "%d day%s left" % [left, "" if left == 1 else "s"]])
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	col.add_child(spacer)
	var boxes := HBoxContainer.new()
	boxes.add_theme_constant_override("separation", 6)
	col.add_child(boxes)
	boxes.add_child(W.CheckSquare.new(accepted, 18))
	boxes.add_child(Style.label("Approved", 15, 600))
	var g2 := Control.new()
	g2.custom_minimum_size.x = 12
	boxes.add_child(g2)
	boxes.add_child(W.CheckSquare.new(false, 18))
	boxes.add_child(Style.label("Denied", 15, 600))
	if accepted:
		var o := Style.overlay()
		o.set_anchors_preset(Control.PRESET_FULL_RECT)
		var stamp := W.Stamp.new("Received", Style.HEART_DEEP, 28, -12, "Term 1 · Day %d" % l.arrives_day)
		stamp.anchor_left = 1.0
		stamp.anchor_right = 1.0
		stamp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		stamp.offset_right = -10
		stamp.offset_top = 128
		o.add_child(stamp)
		paper.add_child(o)
	else:
		var gap3 := Control.new()
		gap3.custom_minimum_size.y = 14
		col.add_child(gap3)
		var open := Style.button("Open %s's letter" % l.child, "md", true, "paper-plane-tilt")
		open.pressed.connect(func(): hud.screens.show_letter(l))
		col.add_child(open)
	return paper


func _field(col: Control, key: String, value: String) -> void:
	var f := VBoxContainer.new()
	f.add_theme_constant_override("separation", 2)
	col.add_child(f)
	f.add_child(Style.caps(key, 12))
	var v := Style.hand_label(value, 22, Style.INK)
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.custom_minimum_size.x = 280
	f.add_child(v)
	var line := ColorRect.new()
	line.color = Style.PAPER_LINE
	line.custom_minimum_size = Vector2(0, 2)
	f.add_child(line)


## One friend: portrait, name, species, a note, the skill as a bar, valid or not.
func _helper_row(s: Node3D, r: Dictionary) -> Control:
	var chosen := s == picked
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 90)
	var face_box := Style.card_box(chosen, not chosen, 0)
	face_box.shadow_offset = Vector2(0, 3)
	b.add_theme_stylebox_override("normal", face_box)
	var hover := Style.card_box(chosen, false, 0)
	hover.shadow_offset = Vector2(0, 3)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", Style.card_box(true, false, 0))
	b.tooltip_text = "Pick %s to see why. Right-click to open their card." % s.data.display_name
	b.pressed.connect(func():
		picked = s
		refresh())
	b.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
			UI.open_card(s))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	row.offset_left = 14
	row.offset_right = -14
	row.offset_top = 10
	row.offset_bottom = -10
	b.add_child(row)
	var face := PanelContainer.new()
	face.add_theme_stylebox_override("panel", Style.flat_box(Style.SKY_LIGHT, Style.PAPER_SHADOW, 2, 28, 2))
	face.custom_minimum_size = Vector2(56, 56)
	face.clip_contents = true
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face.add_child(W.Portrait.new(s.data.gray_color, Vector2(52, 52), false, s.data.horns))
	row.add_child(face)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", -2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mid)
	mid.add_child(Style.label(s.data.display_name, 18, 600))
	mid.add_child(Style.hand_label("%s · %s" % [s.data.kind.capitalize(), s.data.personality], 18, Style.INK_SOFT))
	var note := Style.label("%s · %s" % [r.word, _status(s)], 14, 500, Style.INK_SOFT)
	note.clip_text = true
	note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	note.custom_minimum_size.x = 200
	mid.add_child(note)
	var skill := HBoxContainer.new()
	skill.add_theme_constant_override("separation", 10)
	skill.custom_minimum_size.x = 196
	skill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(skill)
	skill.add_child(Style.label(current.skill_name(), 14, 600))
	var bar := W.DotBar.new(10, Vector2(90, 10))
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.set_values(s.solid(current.skill), s.fresh(current.skill), -1.0, current.level)
	bar.tooltip_text = "Coral line: %s %d, what %s needs" % [current.skill_name(), current.level, current.child]
	skill.add_child(bar)
	var n := Style.label("%.1f" % r.effective, 14, 700)
	n.tooltip_text = "Counts as %.1f in the dream (fresh points count half)" % r.effective
	n.mouse_filter = Control.MOUSE_FILTER_PASS
	skill.add_child(n)
	var mark := W.PlacementMark.new(r.steps_short == 0, 32)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	return b


## What a student is up to, in a few words ("Free after Naptime" in the mockup).
func _status(s: Node3D) -> String:
	for need in ["calm", "fun", "rest"]:
		if s.needs[need] < 3:
			return "%s is low" % need.capitalize()
	return String(s.activity)


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 2.0
		refresh()
