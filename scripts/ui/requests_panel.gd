extends PanelContainer
## Requests drawer (right): the children's letters, and who could help each one.
## Letters waiting to be read show an "Open letter" button; accepted ones rank every
## student by readiness, with the reasons (Systems doc: readiness meter, matching).

const Style := preload("res://scripts/ui/ui_style.gd")
const W := preload("res://scripts/ui/widgets.gd")
const Readiness := preload("res://scripts/readiness.gd")

var hud: CanvasLayer
var current: LetterData
var _body: VBoxContainer
var _tabs: HBoxContainer
var _refresh := 0.0


func setup(the_hud: CanvasLayer) -> void:
	hud = the_hud
	name = "RequestsPanel"
	add_theme_stylebox_override("panel", Style.paper_box(16))
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = -580
	offset_right = -20
	offset_top = 18
	offset_bottom = -20
	visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Style.label("Requests", 22, 600)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Style.button("Close", 13)
	close.pressed.connect(UI.close_drawer)
	head.add_child(close)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	col.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)


func refresh() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	for c in _body.get_children():
		c.queue_free()
	var letters: Array = hud.main.letters
	if current == null and not letters.is_empty():
		current = letters[0]
	for l in letters:
		var b := Style.button("%s · %s %d" % [l.child, l.skill_name(), l.level], 14)
		b.toggle_mode = true
		b.set_pressed_no_signal(l == current)
		b.pressed.connect(func():
			current = l
			refresh())
		_tabs.add_child(b)
	var later := Style.button("Maya · arrives around day 3", 14)
	later.disabled = true
	later.tooltip_text = "More letters arrive with the day clock (week 4)."
	_tabs.add_child(later)
	if current == null:
		_body.add_child(Style.label("No letters yet.", 15))
		return
	_letter_summary(current)
	if not GameState.accepted_letters.has(current):
		var open := Style.button("Open %s's letter" % current.child, 16, true)
		open.pressed.connect(func(): hud.screens.show_letter(current))
		_body.add_child(open)
		return
	_body.add_child(Style.label("Who could help %s?" % current.child, 17, 600))
	var ranked: Array = []
	for s in hud.students.students:
		ranked.append([s, Readiness.check(s, current)])
	ranked.sort_custom(func(a, b):
		if a[1].chance != b[1].chance:
			return a[1].chance > b[1].chance
		return a[1].effective > b[1].effective)
	for i in ranked.size():
		_body.add_child(_student_row(ranked[i][0], ranked[i][1], i == 0))
	var key := Style.label("Readiness: Very likely at the level asked · Maybe one level short · Unlikely two or more short", 12, 400, Style.INK_SOFT)
	key.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	key.custom_minimum_size.x = 500
	_body.add_child(key)


func _letter_summary(l: LetterData) -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", Style.flat_box(Style.PAPER_DARK, Color(0, 0, 0, 0), 0, 12, 12))
	_body.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var paper := W.Notebook.new(16, 22, 10)
	paper.custom_minimum_size = Vector2(150, 110)
	paper.rotation_degrees = -3
	var snippet := Style.hand_label("Dear Academy, " + l.body.substr(0, 70) + "…", 13, Style.CRAYON_BLUE)
	snippet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	snippet.custom_minimum_size.x = 120
	paper.add_child(snippet)
	row.add_child(paper)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	col.add_child(Style.label("%s, %d · %s" % [l.child, l.age, l.neighborhood], 18, 600))
	col.add_child(Style.label("Needs %s %d and a %s friend" % [l.skill_name(), l.level, l.best_trait], 14))
	col.add_child(Style.label("Test: Dream Night, day %d · pays %d Giggles" % [l.dream_day, l.pays_great], 14))
	var ps := Style.hand_label(l.ps, 16, Style.CRAYON_PURPLE)
	ps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ps.custom_minimum_size.x = 320
	col.add_child(ps)


func _student_row(s: Node3D, r: Dictionary, expanded: bool) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", Style.flat_box(Style.PAPER, Style.INK if expanded else Style.PAPER_EDGE, 3 if expanded else 2, 12, 12))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	box.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	top.add_child(W.Portrait.new(s.data.gray_color, Vector2(34, 44), false, s.data.horns))
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(mid)
	var name_btn := LinkButton.new()
	name_btn.text = "%s  ·  %s" % [s.data.display_name, s.data.personality]
	name_btn.add_theme_font_override("font", Style.font(600))
	name_btn.add_theme_font_size_override("font_size", 16)
	name_btn.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	name_btn.tooltip_text = "Open %s's card" % s.data.display_name
	name_btn.pressed.connect(func(): UI.open_card(s))
	mid.add_child(name_btn)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 8)
	mid.add_child(bar_row)
	var bar := W.TwoShadeBar.new()
	bar.custom_minimum_size = Vector2(240, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.set_values(s.solid(current.skill), s.fresh(current.skill), -1.0, current.level)
	bar.tooltip_text = "Coral line: %s %d, what %s needs" % [current.skill_name(), current.level, current.child]
	bar_row.add_child(bar)
	bar_row.add_child(Style.label("%.1f / %d" % [s.total(current.skill), current.level], 13))
	top.add_child(Style.hand_label(r.word, 22, Style.INK))
	if expanded:
		for reason in r.reasons:
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 6)
			match reason[0]:
				"ok":
					line.add_child(W.Badge.new(true, 16))
				"bad":
					line.add_child(W.Badge.new(false, 16))
				_:
					line.add_child(W.Note.new(16))
			var t := Style.label(reason[1], 13)
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			t.custom_minimum_size.x = 380
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(t)
			col.add_child(line)
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 8)
		col.add_child(buttons)
		var plan := Style.button("Plan %s" % current.course, 14, true)
		plan.disabled = true
		plan.tooltip_text = "Teaching arrives with the day clock (M1 week 4)."
		buttons.add_child(plan)
		var mark := Style.button("Mark for Dream Night", 14)
		mark.disabled = true
		mark.tooltip_text = "Dream Night arrives in M1 week 5."
		buttons.add_child(mark)
	return box


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 2.0
		refresh()
