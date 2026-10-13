extends CanvasLayer
## The HUD, laid out like Two Point and Let's School in the design system's paper style:
##   - A thin top bar: the school and the day, Giggles, Ideas, students, Kids' Trust, the
##     Dream Night countdown, and the menu.
##   - Bottom left: the day clock with speed controls, then the category tiles (Build,
##     Timetable, Students, Staff, Requests, Research).
##   - Bottom right: quick build. Top left, under the bar: the child's crayon notes.
## Panels (Build, Students, Requests) and the student card open over the world, below the
## top bar and clear of the bottom-left bar; full-screen screens sit on top of everything.
## The UI's base size is 1280x720 (the mockups'); Godot scales it to the window.

const Style := preload("res://scripts/ui/ui_style.gd")
const W := preload("res://scripts/ui/widgets.gd")
const BuildMenu := preload("res://scripts/build_menu.gd")
const StudentsPanel := preload("res://scripts/ui/students_panel.gd")
const TradingCard := preload("res://scripts/ui/trading_card.gd")
const RequestsPanel := preload("res://scripts/ui/requests_panel.gd")
const CrayonNotes := preload("res://scripts/ui/crayon_notes.gd")
const Screens := preload("res://scripts/ui/screens.gd")

## Bottom menu tabs: id, label, key, what it says while it isn't built yet.
const TABS := [
	["build", "Build", KEY_B, ""],
	["timetable", "Timetable", KEY_T, "The Timetable arrives with the day clock (M1 week 4)."],
	["students", "Students", KEY_P, ""],   # P for pupils (S pans the camera)
	["staff", "Staff", KEY_H, "Teachers and hiring arrive in M2."],
	["requests", "Requests", KEY_R, ""],
	["research", "Research", KEY_I, "The Daydream Room and the research board arrive in M3."],
]
const DREAM_NIGHTS := [7, 14]   ## Systems doc, The Dream Test
const QUICK_SLOTS := 6
const INSET := Style.HUD_INSET
## The Academy's calendar. Days arrive with the day clock (M1 week 4); until then it's day 1.
const TERM := 1

var main: Node3D
var build_mode: Node3D
var students: Node3D

var root: Control
var build_menu: PanelContainer
var students_panel: PanelContainer
var trading_card: Control
var requests_panel: Control
var crayon_notes: Control
var screens: Control

var quick_items: Array[ItemData] = []   ## Recently picked items, newest first

var _giggles_label: Label
var _trust_bar: Control
var _trust_tag: Control
var _clock: Control
var _clock_title: Label
var _clock_bar: Control
var _pause_button: Button
var _fast_button: Button
var _speed_buttons: Array = []
var _school_label: Label
var _ideas_label: Label
var _students_label: Label
var _dream_chip: PanelContainer
var _dream_label: Label
var _phase_label: Label
var _phase_icon: Control
var _time_bar: Control
var _hint_label: Label
var _hint_panel: Control
var _toast: Control
var _toast_title: Label
var _toast_body: Label
var _toast_flavor: Label
var _toast_busy := false
var _tab_buttons := {}
var _requests_badge: Label
var _quick_grid: GridContainer
var _quick_panel: Control
var _refresh := 0.0


func setup(the_main: Node3D) -> void:
	main = the_main
	build_mode = main.build_mode
	students = main.students
	_seed_quick()
	_build()
	UI.drawer_changed.connect(_on_drawer_changed)
	UI.card_changed.connect(_on_card_changed)
	UI.toast_queued.connect(_next_toast)
	UI.screen_changed.connect(_on_screen_changed)
	build_mode.hint_changed.connect(_on_hint)
	build_mode.toast_requested.connect(func(title: String, body: String): UI.toast(title, body))
	build_mode.holding_changed.connect(_on_holding)
	GameState.giggles_changed.connect(func(_g): _update_top())
	GameState.trust_changed.connect(func(_t): _update_top())
	GameState.speed_changed.connect(func(_s): _update_top())
	GameState.letter_accepted.connect(func(_l): _update_top())
	GameState.letter_expired.connect(func(_l): _update_top())
	GameState.day_changed.connect(func(_d): _update_top())
	GameState.ideas_changed.connect(func(_i): _update_top())
	Settings.changed.connect(_on_settings_changed)
	_update_top()
	_on_drawer_changed(UI.drawer)


## Throw the whole HUD away and build it again (the readable-font setting needs this).
func rebuild() -> void:
	if root != null:
		root.queue_free()
	_tab_buttons.clear()
	_build()
	_update_top()
	_on_drawer_changed(UI.drawer)
	_on_card_changed(UI.card_student)
	_on_screen_changed(UI.screen)


func _on_settings_changed() -> void:
	if root != null and root.get_meta("readable", false) != Settings.readable_font:
		rebuild.call_deferred()
	if _hint_panel != null and is_instance_valid(_hint_panel):
		_on_hint(build_mode._hint)


func _build() -> void:
	root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Style.make_theme()
	root.set_meta("readable", Settings.readable_font)
	add_child(root)

	crayon_notes = CrayonNotes.new()
	crayon_notes.setup(self)
	root.add_child(crayon_notes)

	_build_quick()
	_build_hint()

	students_panel = StudentsPanel.new()
	students_panel.setup(self)
	root.add_child(students_panel)

	requests_panel = RequestsPanel.new()
	requests_panel.setup(self)
	root.add_child(requests_panel)

	build_menu = BuildMenu.new()
	build_menu.name = "BuildMenu"
	root.add_child(build_menu)
	build_menu.setup(self, build_mode)

	trading_card = TradingCard.new()
	trading_card.setup(self)
	root.add_child(trading_card)

	_build_top_bar()
	_build_time_bar()
	_build_toast()

	screens = Screens.new()
	screens.setup(self)
	root.add_child(screens)


# --- Top bar (Two Point, Let's School): school, money, Ideas, students, Trust, Dream Night -

const TOP_H := 52.0

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "TopBar"
	var sb := Style.flat_box(Style.PAPER, Style.CARDBOARD, 0, 0, 0)
	sb.border_width_bottom = 3
	sb.shadow_color = Color(Style.WOOD, 0.35)
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = INSET
	sb.content_margin_right = INSET - 6
	bar.add_theme_stylebox_override("panel", sb)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = TOP_H
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)

	# The school: crest, name, and the day.
	var crest := W.Seal.new(40)
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(crest)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -4)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.custom_minimum_size.x = 210
	row.add_child(names)
	_school_label = Style.label("Make-Believe Academy", 17, 600)
	_school_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(_school_label)
	_clock_title = Style.label(day_text(), 13, 500, Style.INK_SOFT)
	names.add_child(_clock_title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	# The stats, each a little tag with a tooltip.
	var coin := W.Coin.new(22)
	_giggles_label = _stat(row, coin, "500", "Giggles: the Academy's money.\nHappy students giggle (+2 a period at Fun 7+); finding a combo pays a 25-Giggle grant.")
	_ideas_label = _stat(row, W.Icon.new("sparkle", 22, Style.HONEY_DEEP, "fill", true), "0", "Ideas: spent on the research board in the Daydream Room.\nThey come from daydreaming staff, tamed Worries, and new combos.")
	_students_label = _stat(row, W.Icon.new("ghost", 22, Style.LAVENDER, "fill", true), "0", "Students enrolled")
	var heart := W.Icon.new("heart", 24, Style.HEART, "fill", true)
	_trust_bar = W.TrustBar.new(Vector2(110, 18))
	_trust_tag = _stat(row, heart, "", "", _trust_bar).get_parent().get_parent()

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer2)

	# Dream Night countdown, then the menu.
	_dream_chip = PanelContainer.new()
	var dsb := Style.flat_box(Style.INDIGO, Style.LAVENDER, 2, 999, 0)
	dsb.content_margin_left = 10
	dsb.content_margin_right = 12
	dsb.content_margin_top = 4
	dsb.content_margin_bottom = 4
	_dream_chip.add_theme_stylebox_override("panel", dsb)
	_dream_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dream_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(_dream_chip)
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 6)
	_dream_chip.add_child(drow)
	drow.add_child(W.Icon.new("moon-stars", 18, Style.HONEY, "fill"))
	_dream_label = Style.label("", 14, 600, Style.PAPER)
	drow.add_child(_dream_label)

	var menu := _toy_button("gear-six", Style.TAB_TAN, "Pause menu: save, load, settings  (Esc)", 38)
	menu.toggle_mode = false
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu.pressed.connect(func(): UI.open_screen("pause"))
	row.add_child(menu)


## One stat tag in the top bar: an icon and a number (or a widget). Returns the label.
func _stat(row: HBoxContainer, icon: Control, text: String, tip: String, extra: Control = null) -> Label:
	var tag := PanelContainer.new()
	var sb := Style.flat_box(Style.BOARD, Style.PAPER_SHADOW, 2, 10, 0)
	sb.content_margin_left = 8
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	tag.add_theme_stylebox_override("panel", sb)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_PASS
	tag.tooltip_text = tip
	row.add_child(tag)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	tag.add_child(r)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(icon)
	var l := Style.label(text, 18, 700)
	l.visible = text != ""
	r.add_child(l)
	if extra != null:
		extra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(extra)
	return l


# --- Time and category bar (bottom left) ----------------------------------------------

const BAR_H := 92.0
const TILE := Vector2(70, 64)

func _build_time_bar() -> void:
	var holder := PanelContainer.new()
	holder.name = "Tabs"
	var sb := Style.flat_box(Style.INDIGO, Style.LAVENDER, 4, 18, 0)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	holder.add_theme_stylebox_override("panel", sb)
	holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, INSET)
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(holder)
	_time_bar = holder
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	holder.add_child(row)

	# The day clock: phase, progress, and speed.
	_clock = PanelContainer.new()
	_clock.name = "Clock"
	var csb := Style.flat_box(Style.PAPER, Style.CARDBOARD, 3, 12, 0)
	csb.content_margin_left = 12
	csb.content_margin_right = 12
	csb.content_margin_top = 6
	csb.content_margin_bottom = 8
	_clock.add_theme_stylebox_override("panel", csb)
	_clock.custom_minimum_size.x = 232
	row.add_child(_clock)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	_clock.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	col.add_child(top)
	_phase_icon = W.Icon.new("sun", 20, Style.HONEY_DEEP, "fill", true)
	_phase_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_phase_icon)
	_phase_label = Style.label("Free Play", 17, 600)
	_phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_phase_label)
	_clock_bar = W.ClockBar.new(Vector2(206, 12))
	col.add_child(_clock_bar)
	var speeds := HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 6)
	col.add_child(speeds)
	_pause_button = _speed_button("pause", "", "Pause  (Space)")
	_pause_button.pressed.connect(toggle_pause)
	speeds.add_child(_pause_button)
	_speed_buttons.clear()
	for s in [1, 2, 3]:
		var b := _speed_button("play" if s == 1 else "fast-forward", "" if s == 1 else "%d×" % s,
			"Speed %d×  ( ] faster, [ slower )" % s)
		b.pressed.connect(GameState.set_speed.bind(s))
		speeds.add_child(b)
		_speed_buttons.append(b)
	_fast_button = _speed_buttons[1]

	# The categories (the old bottom menu), as tiles.
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 8)
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(tiles)
	for t in TABS:
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = TILE
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pivot_offset = TILE / 2.0
		var face := Style.button_box("tan", "normal", Vector2.ZERO)
		face.bg_color = Style.TAB_TAN_LIGHT
		var hover := Style.button_box("paper", "normal", Vector2.ZERO)
		var sel := Style.button_box("paper", "selected", Vector2.ZERO)
		sel.expand_margin_top = 0
		sel.expand_margin_bottom = 0
		b.add_theme_stylebox_override("normal", face)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", sel)
		b.add_theme_stylebox_override("hover_pressed", sel)
		b.add_theme_stylebox_override("disabled", face)
		var spec: Array = Style.TAB_ICONS[t[0]]
		var ic := W.Icon.new(spec[0], 30, spec[1], "fill", true)
		ic.position = Vector2((TILE.x - 30) / 2.0, 7)
		b.add_child(ic)
		var l := Style.label(t[1], 12, 600)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(-6, 40)
		l.size = Vector2(TILE.x + 12, 16)
		b.add_child(l)
		var key := OS.get_keycode_string(t[2])
		if t[3] != "":
			b.disabled = true
			b.tooltip_text = "%s\n%s" % [t[1], t[3]]
			b.modulate = Color(1, 1, 1, 0.55)
		else:
			b.tooltip_text = "%s  (%s)" % [t[1], key]
			b.pressed.connect(UI.toggle_drawer.bind(t[0]))
		tiles.add_child(b)
		_tab_buttons[t[0]] = b
		if t[0] == "requests":
			var badge := PanelContainer.new()
			badge.add_theme_stylebox_override("panel", Style.flat_box(Style.HEART, Style.INK, 3, 12, 0))
			badge.custom_minimum_size = Vector2(24, 24)
			badge.position = Vector2(TILE.x - 16, -8)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_requests_badge = Style.label("1", 13, 700, Style.PAPER)
			_requests_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_requests_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge.add_child(_requests_badge)
			b.add_child(badge)


## A small speed toy: 44x30, an icon and maybe "2×"; pressed in lime when it's the speed.
func _speed_button(icon: String, text: String, tip: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(46, 28)
	b.tooltip_text = tip
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		var on: bool = st.contains("pressed")
		var s := Style.toy_box(on, st == "hover")
		s.shadow_offset = Vector2(0, 1 if on else 3)
		s.expand_margin_top = -2 if on else 0
		s.expand_margin_bottom = 2 if on else 0
		b.add_theme_stylebox_override(st, s)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 1)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(r)
	var ic := W.Icon.new(icon, 16, Style.INK, "fill")
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(ic)
	if text != "":
		r.add_child(Style.label(text, 12, 700))
	return b


## A ToyButton: a tan-light tile with a filled sticker icon; active presses down lime.
func _toy_button(icon: String, color: Color, tip: String, px := 52) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(px, px)
	b.tooltip_text = tip
	b.toggle_mode = true
	b.add_theme_stylebox_override("normal", Style.toy_box(false, false))
	b.add_theme_stylebox_override("hover", Style.toy_box(false, true))
	b.add_theme_stylebox_override("pressed", Style.toy_box(true))
	b.add_theme_stylebox_override("hover_pressed", Style.toy_box(true))
	var ip := px * 0.56
	var ic := W.Icon.new(icon, ip, color, "fill", true)
	ic.set_anchors_preset(Control.PRESET_CENTER)
	ic.offset_left = -ip / 2.0
	ic.offset_right = ip / 2.0
	ic.offset_top = -ip / 2.0
	ic.offset_bottom = ip / 2.0
	b.add_child(ic)
	return b


func _update_top() -> void:
	if root == null:
		return
	_giggles_label.text = _comma(GameState.giggles)
	_ideas_label.text = str(GameState.ideas)
	_students_label.text = str(students.students.size())
	_school_label.text = GameState.school_name if GameState.school_name != "" else "Make-Believe Academy"
	_clock_title.text = day_text()
	_trust_bar.set_values(GameState.trust / 10.0)
	_trust_tag.tooltip_text = "Kids' Trust: %d of 10. The Academy's health.\nGreat postcards raise it; unanswered letters lower it. At 0 the Department gets worried." % GameState.trust
	var paused := GameState.speed == 0
	_pause_button.set_pressed_no_signal(paused)
	for i in _speed_buttons.size():
		_speed_buttons[i].set_pressed_no_signal(GameState.speed == i + 1)
	var dn := next_dream_night()
	_dream_label.text = "Dream Night tonight!" if dn == GameState.day else "Dream Night in %d days" % (dn - GameState.day) if dn - GameState.day != 1 else "Dream Night tomorrow"
	_dream_chip.tooltip_text = "Dream Night (day %d): students you've marked ready are tested in a child's dream at Bedtime." % dn
	var waiting := 0
	for l in main.open_letters():
		if not GameState.accepted_letters.has(l):
			waiting += 1
	if _requests_badge != null:
		_requests_badge.text = str(waiting)
		_requests_badge.get_parent().visible = waiting > 0


## The next Dream Night: day 7 and day 14 of the term (Systems doc, The Dream Test).
static func next_dream_night() -> int:
	for d in DREAM_NIGHTS:
		if d >= GameState.day:
			return d
	return DREAM_NIGHTS[-1]


func toggle_pause() -> void:
	if GameState.speed == 0:
		GameState.set_speed(GameState.get_meta("last_speed", 1))
	else:
		GameState.set_meta("last_speed", GameState.speed)
		GameState.set_speed(0)


## "Term 1 · Day 1" (shared with the title screen and save slots).
static func day_text() -> String:
	return "Term %d · Day %d" % [TERM, GameState.day]


func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0 or root == null:
		return
	_refresh = 0.2
	_clock_title.text = day_text()
	_students_label.text = str(students.students.size())
	_clock_bar.set_value(1.0 - students.period_left / students.period_seconds)
	_phase_label.text = "Free Play · %d" % students.period
	_clock.tooltip_text = "Free Play, period %d. Needs change in %ds.\n(Morning and Afternoon classes arrive with the day clock.)" % [students.period, ceili(maxf(students.period_left, 0.0))]


static func _comma(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# --- Toasts and the hint slip -------------------------------------------------------

func _build_toast() -> void:
	var card := W.Paper.new("paper", Vector4(18, 24, 18, 24), "a", 1.0)
	card.custom_minimum_size = Vector2(380, 0)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, TOP_H + 18)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.visible = false
	root.add_child(card)
	_toast = card
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	_toast_title = Style.label("", 22, 600)
	_toast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_toast_title)
	_toast_body = Style.label("", 15, 500, Style.INK_SOFT)
	_toast_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_body.custom_minimum_size.x = 330
	col.add_child(_toast_body)
	_toast_flavor = Style.hand_label("", 20, Style.INK)
	_toast_flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_flavor.custom_minimum_size.x = 330
	col.add_child(_toast_flavor)
	card.add_child(Style.tape(142, -4, "honey"))


## Show the next queued toast: one at a time, four seconds each, never during a moment.
func _next_toast() -> void:
	if _toast_busy or UI.toasts.is_empty() or UI.blocking() or root == null:
		return
	_toast_busy = true
	var t: Array = UI.toasts.pop_front()
	_toast_title.text = t[0]
	var lines: PackedStringArray = String(t[1]).split("\n")
	_toast_body.text = lines[0] if lines.size() > 0 else ""
	_toast_body.visible = _toast_body.text != ""
	var flavor: String = t[2] if t[2] != "" else ("\n".join(lines.slice(1)) if lines.size() > 1 else "")
	_toast_flavor.text = flavor
	_toast_flavor.visible = flavor != ""
	_toast.visible = true
	_toast.modulate.a = 0.0
	_toast.scale = Vector2(0.9, 0.9) if not Settings.reduce_motion else Vector2.ONE
	var tw := Style.ui_tween(_toast)
	tw.tween_property(_toast, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(_toast, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(4.0)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.42)
	tw.tween_callback(func():
		_toast.visible = false
		_toast_busy = false
		_next_toast())


## Hover hints and building help, above the bottom menu. The Build panel shows them in its
## footer instead. Teacher Hints off hides it.
func _build_hint() -> void:
	_hint_panel = W.Paper.new("paper", Vector4(8, 18, 10, 18), "b")
	_hint_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, INSET + BAR_H + 34)
	_hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint_panel)
	_hint_label = Style.label(build_mode._hint, 15, 500)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_panel.add_child(_hint_label)
	_on_hint(build_mode._hint)


func _on_hint(t: String) -> void:
	if _hint_label == null or not is_instance_valid(_hint_label):
		return
	_hint_label.text = t
	var idle := t.begins_with("Pick an item")
	_hint_panel.visible = Settings.teacher_hints and t != "" and not idle and UI.drawer != "build" and UI.drawer != "requests"
	if build_menu != null and is_instance_valid(build_menu):
		build_menu.set_hint(t)


# --- Quick-build catalog (bottom right) ---------------------------------------------

func _seed_quick() -> void:
	quick_items.clear()
	for id in [&"toy_chest", &"nightlight", &"pillow_bed", &"floor_cushion", &"cardboard_boxes", &"tamed_closet_monster"]:
		for d in build_mode.catalog:
			if d.id == id:
				quick_items.append(d)
	for d in build_mode.catalog:
		if quick_items.size() >= QUICK_SLOTS:
			break
		if not quick_items.has(d) and d.research_ideas == 0:
			quick_items.append(d)


func _on_holding(d: ItemData) -> void:
	if d == null:
		return
	quick_items.erase(d)
	quick_items.push_front(d)
	if quick_items.size() > QUICK_SLOTS:
		quick_items.resize(QUICK_SLOTS)
	_refresh_quick()


func _build_quick() -> void:
	var panel := PanelContainer.new()
	panel.name = "QuickBuild"
	var sb := Style.button_box("tan", "normal", Vector2(10, 10))
	sb.bg_color = Style.TAB_TAN_LIGHT
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, INSET)
	panel.offset_bottom = -INSET - 4
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.tooltip_text = "Quick build: your recent items"
	root.add_child(panel)
	_quick_panel = panel
	_quick_grid = GridContainer.new()
	_quick_grid.columns = 3
	_quick_grid.add_theme_constant_override("h_separation", 8)
	_quick_grid.add_theme_constant_override("v_separation", 10)
	panel.add_child(_quick_grid)
	_refresh_quick()


func _refresh_quick() -> void:
	if _quick_grid == null or not is_instance_valid(_quick_grid):
		return
	for c in _quick_grid.get_children():
		c.queue_free()
	for i in QUICK_SLOTS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(52, 52)
		if i < quick_items.size():
			var d: ItemData = quick_items[i]
			var tint := W.ItemIcon.item_tint(d)
			for st in ["normal", "hover", "pressed", "disabled"]:
				var state: String = "selected" if st == "pressed" else st
				var s := Style.button_box("tan", state, Vector2(4, 4))
				if st == "normal":
					s.bg_color = tint
				elif st == "hover":
					s.bg_color = tint.lightened(0.25)
				if st != "pressed":
					s.shadow_offset = Vector2(0, 3)
				b.add_theme_stylebox_override(st, s)
			b.tooltip_text = "%s · %d Giggles\n%s" % [d.display_name, d.cost, d.effect_text]
			var icon := W.ItemIcon.new(d, 32)
			icon.set_anchors_preset(Control.PRESET_CENTER)
			icon.offset_left = -16
			icon.offset_right = 16
			icon.offset_top = -16
			icon.offset_bottom = 16
			b.add_child(icon)
			b.pressed.connect(func():
				if build_mode.holding == d:
					build_mode.stop_holding()
				else:
					if UI.drawer != "build":
						UI.open_drawer("build")
					build_mode.start_holding(d))
		else:
			b.disabled = true
			b.add_theme_stylebox_override("disabled", Style.flat_box(Color(Style.PAPER_SHADOW, 0.6), Color(0, 0, 0, 0), 0, 10, 0))
		_quick_grid.add_child(b)


func _on_drawer_changed(id: String) -> void:
	if root == null:
		return
	for t in _tab_buttons:
		var b: Button = _tab_buttons[t]
		var on: bool = t == id
		b.set_pressed_no_signal(on)
		# The open category lifts a little (the tiles sit in a row, so it scales and tilts).
		var sc := Vector2(1.08, 1.08) if on else Vector2.ONE
		var rot := -3.0 if on else 0.0
		if Settings.reduce_motion or not b.is_inside_tree():
			b.scale = sc
			b.rotation_degrees = rot
		else:
			var tw := Style.ui_tween(b).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_parallel()
			tw.tween_property(b, "scale", sc, 0.22)
			tw.tween_property(b, "rotation_degrees", rot, 0.22)
	_show(build_menu, id == "build")
	_show(students_panel, id == "students")
	_show(requests_panel, id == "requests")
	crayon_notes.visible = id == "" and crayon_notes.letter != null
	_quick_panel.visible = id != "requests" and UI.card_student == null   # the request form is wide
	if id == "students":
		students_panel.refresh()
	elif id == "requests":
		requests_panel.refresh()
	if id != "build" and build_mode.holding != null:
		build_mode.stop_holding()
	if id != "build":
		build_mode.set_sell_mode(false)
	_on_hint(build_mode._hint)


func _on_card_changed(student: Node3D) -> void:
	if root == null:
		return
	if student == null:
		_show(trading_card, false)
		_quick_panel.visible = UI.drawer != "requests"
	else:
		trading_card.show_student(student)
		_show(trading_card, true)
		_quick_panel.visible = false


## Fade a panel in or out (the tween runs even while the game is paused).
func _show(c: Control, on: bool) -> void:
	if c.visible == on:
		return
	if on:
		c.visible = true
		c.modulate.a = 0.0
		var tw := Style.ui_tween(c)
		tw.tween_property(c, "modulate:a", 1.0, 0.0 if Settings.reduce_motion else 0.15)
	else:
		c.visible = false


func _on_screen_changed(id: String) -> void:
	if root == null:
		return
	# Menus and moments sit over a dimmed HUD (mockups 01, 02, 05, 09); open panels and
	# toasts step aside so the screen reads cleanly.
	for c in [build_menu, students_panel, requests_panel, trading_card, _hint_panel, _toast]:
		c.modulate.a = 0.0 if id != "" else 1.0
	screens.show_screen(id)
	if id == "":
		_next_toast()


# --- Keys ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if UI.blocking():
		if event.physical_keycode == KEY_ESCAPE:
			screens.escape()
		get_viewport().set_input_as_handled()   # the world ignores keys during moments and menus
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			if build_mode.holding != null or build_mode.sell_mode or main.carry.carried != null:
				return   # build mode backs out of holding or selling first
			UI.back()
		KEY_SPACE:
			toggle_pause()
		KEY_BRACKETLEFT:
			if GameState.speed > 1:
				GameState.set_speed(GameState.speed - 1)
		KEY_BRACKETRIGHT:
			GameState.set_speed(mini(3, maxi(1, GameState.speed + 1)))
		KEY_R:
			if build_mode.holding != null:
				return   # R rotates the held item; otherwise it opens Requests
			UI.toggle_drawer("requests")
		_:
			var hit := false
			for t in TABS:
				if t[2] == event.physical_keycode and t[3] == "" and t[0] != "requests":
					UI.toggle_drawer(t[0])
					hit = true
			if not hit:
				return
	get_viewport().set_input_as_handled()
