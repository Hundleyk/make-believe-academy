extends PanelContainer
## Requests (mockup 10, "Who can help Leo?"): the Department form on the left, and every
## student ranked by readiness on the right (Systems doc: readiness meter, matching).
## Pick a friend to see why they would or wouldn't do; sending them waits for Dream Night.
## A letter not yet read shows an "Open the letter" button on its form.

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
	var sb := Style.paper_box(0, 6)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 26
	sb.content_margin_bottom = 22
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(1180, 0)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	offset_top += 16
	offset_bottom += 16
	visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 34)
	add_child(row)
	_form_holder = MarginContainer.new()
	_form_holder.custom_minimum_size.x = 400
	row.add_child(_form_holder)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var head := HBoxContainer.new()
	right.add_child(head)
	_title = Style.label("Who can help?", 32, 700)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close := Style.button("Close", 16, false, "close")
	close.tooltip_text = "Close Requests  (R or Esc)"
	close.pressed.connect(UI.close_drawer)
	head.add_child(close)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	right.add_child(_tabs)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	right.add_child(_body)
	_why = VBoxContainer.new()
	_why.add_theme_constant_override("separation", 2)
	right.add_child(_why)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	right.add_child(foot)
	_needs_line = Style.label("", 17, 500, Style.INK_SOFT)
	_needs_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_needs_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_needs_line)
	_send = Style.button("Send a friend", 22, true, "letter")
	_send.custom_minimum_size = Vector2(0, 62)
	_send.disabled = true
	_send.tooltip_text = "Friends are sent on Dream Night (M1 week 5).\nFor now: get them ready."
	foot.add_child(_send)
	add_child(Style.tape(560, -2, Style.WASHI_PINK, 140))


func refresh() -> void:
	var letters: Array = hud.main.letters
	if current == null and not letters.is_empty():
		current = letters[0]
	for c in _tabs.get_children():
		c.queue_free()
	if letters.size() > 1:
		for l in letters:
			var b := Style.tab_button("%s · %s %d" % [l.child, l.skill_name(), l.level], 14)
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
		_body.add_child(_friend_row(r[0], r[1]))
	_needs_line.text = "Needs %s %d or more · pairs best with a %s friend" % [current.skill_name(), current.level, current.best_trait]
	if picked != null:
		_send.text = "Send %s" % picked.data.display_name
		var pr := Readiness.check(picked, current)
		for reason in pr.reasons:
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 8)
			match reason[0]:
				"ok":
					line.add_child(W.Badge.new(true, 18))
				"bad":
					line.add_child(W.Badge.new(false, 18))
				_:
					line.add_child(W.Note.new(18))
			line.add_child(Style.label(reason[1], 15))
			_why.add_child(line)


## The Department of Imaginary Affairs form for a letter (left side).
func _form(l: LetterData) -> Control:
	var accepted := GameState.accepted_letters.has(l)
	var paper := W.Paper.new(Style.FORM, 26, 2.5, 21)
	paper.rotation_degrees = -0.6
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	paper.add_child(col)
	var dept := Style.caps("Department of Imaginary Affairs", 14, Style.WOOD)
	dept.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(dept)
	var rule := W.Dashed.new(Style.WOOD)
	rule.custom_minimum_size = Vector2(0, 2)
	col.add_child(rule)
	var head := HBoxContainer.new()
	col.add_child(head)
	var t := Style.label("Request for\n%s" % l.skill_name(), 26, 700)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var no := Style.label("Form 7-%s" % l.skill_name().left(1), 15, 600, Style.INK_SOFT)
	no.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(no)
	_field(col, "From", "%s, age %d" % [l.child, l.age])
	_field(col, "Problem", l.problem if l.problem != "" else l.body.left(40))
	_field(col, "Needs", l.wants if l.wants != "" else "%s %d" % [l.skill_name(), l.level])
	_field(col, "Dream test", "Dream Night, day %d · pays %d" % [l.dream_day, l.pays_great])
	var boxes := HBoxContainer.new()
	boxes.add_theme_constant_override("separation", 10)
	col.add_child(boxes)
	boxes.add_child(W.CheckSquare.new(accepted, 26))
	boxes.add_child(Style.label("Approved", 17, 600))
	var gap := Control.new()
	gap.custom_minimum_size.x = 18
	boxes.add_child(gap)
	boxes.add_child(W.CheckSquare.new(false, 26))
	boxes.add_child(Style.label("Denied", 17, 600))
	var ps := Style.hand_label(l.ps, 18, Style.CRAYON_PURPLE)
	ps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ps.custom_minimum_size.x = 330
	col.add_child(ps)
	if accepted:
		var o := Style.overlay()
		var stamp := W.Stamp.new("RECEIVED", Style.HEART, 34, -14)
		stamp.position = Vector2(150, 390)
		o.add_child(stamp)
		var sub := Style.label("TERM 1 · DAY %d" % l.arrives_day, 13, 700, Style.HEART)
		sub.rotation_degrees = -14
		sub.position = Vector2(196, 442)
		sub.modulate.a = 0.85
		o.add_child(sub)
		paper.add_child(o)
	else:
		var open := Style.button("Open %s's letter" % l.child, 18, true, "letter")
		open.custom_minimum_size.y = 52
		open.pressed.connect(func(): hud.screens.show_letter(l))
		col.add_child(open)
	return paper


func _field(col: Control, key: String, value: String) -> void:
	col.add_child(Style.caps(key, 13, Style.INK_SOFT))
	var v := Style.hand_label(value, 24, Style.INK)
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.custom_minimum_size.x = 330
	col.add_child(v)
	var line := ColorRect.new()
	line.color = Style.NOTEBOOK_LINE
	line.custom_minimum_size = Vector2(0, 2)
	col.add_child(line)


## One friend in the list: portrait, name, species, readiness, the skill as dots, a tick box.
func _friend_row(s: Node3D, r: Dictionary) -> Control:
	var chosen := s == picked
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 104)
	b.add_theme_stylebox_override("normal", Style.card_box(chosen, not chosen, 0))
	var hover := Style.card_box(chosen, not chosen, 0)
	hover.bg_color = hover.bg_color.lightened(0.1)
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
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	row.offset_left = 20
	row.offset_right = -20
	row.offset_bottom = -16
	b.add_child(row)
	var face := PanelContainer.new()
	face.add_theme_stylebox_override("panel", Style.flat_box(Style.SKY, Color("E8D3B5"), 3, 40, 4))
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face.clip_contents = true
	face.add_child(W.Portrait.new(s.data.gray_color, Vector2(62, 62), false, s.data.horns))
	row.add_child(face)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", -4)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mid)
	mid.add_child(Style.label(s.data.display_name, 21, 700))
	mid.add_child(Style.hand_label("%s · %s" % [s.data.kind.capitalize(), s.data.personality], 21, Style.INK_SOFT))
	var status := Style.label("%s · %s" % [r.word, _status(s)], 15, 500)
	status.clip_text = true
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.custom_minimum_size.x = 250
	mid.add_child(status)
	var skill := Style.label(current.skill_name(), 17, 600)
	skill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(skill)
	var bar := W.DotBar.new(10, Vector2(130, 16))
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.set_values(s.solid(current.skill), s.fresh(current.skill), -1.0, current.level)
	bar.tooltip_text = "Coral line: %s %d, what %s needs" % [current.skill_name(), current.level, current.child]
	row.add_child(bar)
	var n := Style.label("%.1f" % r.effective, 17, 700)
	n.custom_minimum_size.x = 34
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	n.tooltip_text = "Counts as %.1f in the dream (fresh points count half)" % r.effective
	n.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(n)
	var tick := W.CheckSquare.new(chosen, 30)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tick)
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
