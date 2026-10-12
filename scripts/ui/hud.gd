extends CanvasLayer
## The HUD frame (UI System doc, "HUD layout"): Giggles top left, the clock top center,
## Kids' Trust and Leo's crayon notes top right, the hint strip bottom left, paper tabs
## along the bottom, and the drawers (Build, Students, Requests) on the sides.
## Full-screen screens (letters, pause, settings, title) sit on top of everything.

const Style := preload("res://scripts/ui/ui_style.gd")
const W := preload("res://scripts/ui/widgets.gd")
const BuildMenu := preload("res://scripts/build_menu.gd")
const StudentsPanel := preload("res://scripts/ui/students_panel.gd")
const TradingCard := preload("res://scripts/ui/trading_card.gd")
const RequestsPanel := preload("res://scripts/ui/requests_panel.gd")
const CrayonNotes := preload("res://scripts/ui/crayon_notes.gd")
const Screens := preload("res://scripts/ui/screens.gd")

## Bottom tabs: id, label, key, what it says while it isn't built yet.
const TABS := [
	["build", "Build", KEY_B, ""],
	["timetable", "Timetable", KEY_T, "The Timetable arrives with the day clock (M1 week 4)."],
	["students", "Students", KEY_P, ""],   # P for pupils (S pans the camera)
	["staff", "Staff", KEY_H, "Teachers and hiring arrive in M2."],
	["requests", "Requests", KEY_R, ""],
]

var main: Node3D
var build_mode: Node3D
var students: Node3D

var root: Control
var build_menu: PanelContainer
var students_panel: PanelContainer
var trading_card: PanelContainer
var requests_panel: PanelContainer
var crayon_notes: Control
var screens: Control

var _giggles_label: Label
var _trust_label: Label
var _hearts: HBoxContainer
var _clock_title: Label
var _clock_sub: Label
var _speed_label: Label
var _pause_button: Button
var _period_bar: ProgressBar
var _hint_label: Label
var _hint_panel: PanelContainer
var _toast: PanelContainer
var _toast_title: Label
var _toast_body: Label
var _toast_flavor: Label
var _toast_busy := false
var _tab_buttons := {}
var _requests_badge: Label
var _refresh := 0.0


func setup(the_main: Node3D) -> void:
	main = the_main
	build_mode = main.build_mode
	students = main.students
	_build()
	UI.drawer_changed.connect(_on_drawer_changed)
	UI.card_changed.connect(_on_card_changed)
	UI.toast_queued.connect(_next_toast)
	UI.screen_changed.connect(_on_screen_changed)
	build_mode.hint_changed.connect(func(t: String): _hint_label.text = t)
	build_mode.toast_requested.connect(func(title: String, body: String): UI.toast(title, body))
	GameState.giggles_changed.connect(func(_g): _update_top())
	GameState.trust_changed.connect(func(_t): _update_top())
	GameState.speed_changed.connect(func(_s): _update_top())
	GameState.letter_accepted.connect(func(_l): _update_top())
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


func _build() -> void:
	root = Control.new()
	root.name = "HUDRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Style.make_theme()
	root.set_meta("readable", Settings.readable_font)
	add_child(root)

	_build_giggles()
	_build_clock()
	_build_trust()

	crayon_notes = CrayonNotes.new()
	crayon_notes.setup(self)
	root.add_child(crayon_notes)

	_build_toast()
	_build_hint()

	students_panel = StudentsPanel.new()
	students_panel.setup(self)
	root.add_child(students_panel)

	trading_card = TradingCard.new()
	trading_card.setup(self)
	root.add_child(trading_card)

	requests_panel = RequestsPanel.new()
	requests_panel.setup(self)
	root.add_child(requests_panel)

	build_menu = BuildMenu.new()
	build_menu.name = "BuildMenu"
	root.add_child(build_menu)
	build_menu.setup(self, build_mode)

	_build_tabs()

	screens = Screens.new()
	screens.setup(self)
	root.add_child(screens)


# --- Top bar ------------------------------------------------------------------------

func _build_giggles() -> void:
	var tag := Style.paper_panel(10)
	tag.position = Vector2(20, 18)
	tag.rotation_degrees = -1.5
	tag.tooltip_text = "Giggles are the Academy's money.\nHappy students giggle (+2 a period at Fun 7+); finding a combo pays a 25-Giggle grant."
	root.add_child(tag)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	tag.add_child(row)
	row.add_child(W.Coin.new(34))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	row.add_child(col)
	col.add_child(Style.label("Giggles", 13, 500, Style.INK_SOFT))
	_giggles_label = Style.label("500", 28, 600)
	col.add_child(_giggles_label)
	tag.add_child(Style.tape(40, -4))   # after the content, so it's on top


func _build_clock() -> void:
	var clock := Style.paper_panel(10)
	clock.custom_minimum_size = Vector2(420, 0)
	clock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 16)
	clock.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(clock)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	clock.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	col.add_child(top)
	_clock_title = Style.label("Free time · Period 1", 20, 600)
	_clock_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_clock_title)
	var slower := Style.button("«", 14)
	slower.tooltip_text = "Slower  ( [ )"
	slower.custom_minimum_size = Vector2(36, 30)
	slower.pressed.connect(func(): GameState.set_speed(maxi(1, GameState.speed - 1)) if GameState.speed > 0 else null)
	top.add_child(slower)
	_pause_button = Style.button("Pause", 14)
	_pause_button.tooltip_text = "Pause or resume the students  (Space)"
	_pause_button.custom_minimum_size = Vector2(70, 30)
	_pause_button.pressed.connect(toggle_pause)
	top.add_child(_pause_button)
	var faster := Style.button("»", 14)
	faster.tooltip_text = "Faster  ( ] )"
	faster.custom_minimum_size = Vector2(36, 30)
	faster.pressed.connect(func(): GameState.set_speed(mini(3, maxi(1, GameState.speed + 1))))
	top.add_child(faster)
	var menu := Style.button("Menu", 14)
	menu.tooltip_text = "Pause screen: save, load, settings  (Esc)"
	menu.custom_minimum_size = Vector2(64, 30)
	menu.pressed.connect(func(): UI.open_screen("pause"))
	top.add_child(menu)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	col.add_child(bottom)
	_period_bar = ProgressBar.new()
	_period_bar.show_percentage = false
	_period_bar.custom_minimum_size = Vector2(150, 10)
	_period_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_period_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_period_bar)
	_clock_sub = Style.label("", 13, 400, Style.INK_SOFT)
	_clock_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_clock_sub)
	_speed_label = Style.hand_label("1×", 18, Style.CRAYON_PURPLE)
	bottom.add_child(_speed_label)


func _build_trust() -> void:
	var tag := Style.paper_panel(10)
	tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tag.rotation_degrees = 1.0
	tag.tooltip_text = "Kids' Trust is the Academy's health.\nGreat postcards raise it; unanswered letters lower it. At 0 the Department gets worried."
	root.add_child(tag)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	tag.add_child(col)
	_trust_label = Style.label("Kids' Trust · 5 of 10", 13, 500, Style.INK_SOFT)
	col.add_child(_trust_label)
	_hearts = HBoxContainer.new()
	_hearts.add_theme_constant_override("separation", 3)
	col.add_child(_hearts)


func _update_top() -> void:
	if root == null:
		return
	_giggles_label.text = _comma(GameState.giggles)
	_trust_label.text = "Kids' Trust · %d of 10" % GameState.trust
	for c in _hearts.get_children():
		c.queue_free()
	for i in 10:
		_hearts.add_child(W.Heart.new(i < GameState.trust))
	var paused := GameState.speed == 0
	_pause_button.text = "Play" if paused else "Pause"
	_pause_button.set_pressed_no_signal(paused)
	_speed_label.text = "paused" if paused else "%d×" % GameState.speed
	var waiting := 0
	for l in main.letters:
		if not GameState.accepted_letters.has(l):
			waiting += 1
	if _requests_badge != null:
		_requests_badge.text = str(waiting)
		_requests_badge.get_parent().visible = waiting > 0


func toggle_pause() -> void:
	if GameState.speed == 0:
		GameState.set_speed(GameState.get_meta("last_speed", 1))
	else:
		GameState.set_meta("last_speed", GameState.speed)
		GameState.set_speed(0)


func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0 or root == null:
		return
	_refresh = 0.2
	_clock_title.text = "Free time · Period %d" % students.period
	_period_bar.max_value = students.period_seconds
	_period_bar.value = students.period_seconds - students.period_left
	_clock_sub.text = "needs change in %ds" % ceili(maxf(students.period_left, 0.0))


static func _comma(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# --- Toasts and hint ----------------------------------------------------------------

func _build_toast() -> void:
	_toast = Style.paper_panel(12)
	_toast.custom_minimum_size = Vector2(380, 0)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 124)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.rotation_degrees = 0.8
	_toast.visible = false
	root.add_child(_toast)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	_toast.add_child(col)
	_toast_title = Style.label("", 19, 600)
	_toast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_toast_title)
	_toast_body = Style.label("", 14)
	_toast_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_toast_body)
	_toast_flavor = Style.hand_label("", 17, Style.INK_SOFT)
	_toast_flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_toast_flavor)
	_toast.add_child(Style.tape(158, 2))


## Show the next queued toast: one at a time, four seconds each, never during a moment.
func _next_toast() -> void:
	if _toast_busy or UI.toasts.is_empty() or UI.blocking() or root == null:
		return
	_toast_busy = true
	var t: Array = UI.toasts.pop_front()
	_toast_title.text = t[0]
	var lines: PackedStringArray = String(t[1]).split("\n")
	_toast_body.text = lines[0] if lines.size() > 0 else ""
	var flavor: String = t[2] if t[2] != "" else ("\n".join(lines.slice(1)) if lines.size() > 1 else "")
	_toast_flavor.text = flavor
	_toast_flavor.visible = flavor != ""
	_toast.visible = true
	_toast.modulate.a = 0.0
	var tw := Style.ui_tween(_toast)
	tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(4.0)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		_toast.visible = false
		_toast_busy = false
		_next_toast())


func _build_hint() -> void:
	_hint_panel = Style.paper_panel(12)
	_hint_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	_hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint_panel)
	_hint_label = Style.label(build_mode._hint, 14)
	_hint_label.custom_minimum_size.x = 400
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_panel.add_child(_hint_label)


# --- Bottom tabs and drawers --------------------------------------------------------

func _build_tabs() -> void:
	var row := HBoxContainer.new()
	row.name = "Tabs"
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.anchor_left = 0.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = 460
	row.offset_top = -64
	row.offset_bottom = 0
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	for t in TABS:
		var b := Button.new()
		b.text = "%s  %s" % [t[1], OS.get_keycode_string(t[2])]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_vertical = Control.SIZE_SHRINK_END
		b.add_theme_font_override("font", Style.font(500))
		b.add_theme_font_size_override("font_size", 15)
		for st in ["normal", "hover", "disabled"]:
			b.add_theme_stylebox_override(st, Style.tab_box(false))
		for st in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st, Style.tab_box(true))
		b.custom_minimum_size = Vector2(0, 46)
		if t[3] != "":
			b.disabled = true
			b.tooltip_text = t[3]
		else:
			b.tooltip_text = "Open %s  (%s)" % [t[1], OS.get_keycode_string(t[2])]
			b.pressed.connect(UI.toggle_drawer.bind(t[0]))
		row.add_child(b)
		_tab_buttons[t[0]] = b
		if t[0] == "requests":
			var badge := PanelContainer.new()
			badge.add_theme_stylebox_override("panel", Style.flat_box(Style.HEART, Style.INK, 2, 10, 2))
			badge.position = Vector2(86, -8)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_requests_badge = Style.label("1", 12, 600, Style.PAPER)
			_requests_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_requests_badge.custom_minimum_size.x = 14
			badge.add_child(_requests_badge)
			b.add_child(badge)


func _on_drawer_changed(id: String) -> void:
	if root == null:
		return
	for t in _tab_buttons:
		_tab_buttons[t].set_pressed_no_signal(t == id)
		_tab_buttons[t].custom_minimum_size.y = 56 if t == id else 46
	_show(build_menu, id == "build")
	_show(students_panel, id == "students")
	_show(requests_panel, id == "requests")
	crayon_notes.visible = id != "requests" and crayon_notes.letter != null
	if id == "students":
		students_panel.refresh()
	elif id == "requests":
		requests_panel.refresh()
	if id != "build" and build_mode.holding != null:
		build_mode.stop_holding()
	if id != "build":
		build_mode.set_sell_mode(false)


func _on_card_changed(student: Node3D) -> void:
	if root == null:
		return
	if student == null:
		_show(trading_card, false)
	else:
		trading_card.show_student(student)
		_show(trading_card, true)


## Fade a drawer in or out (the tween runs even while the game is paused).
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
	# Big moments and menus take the whole screen: the HUD steps aside (UI System doc).
	for c in root.get_children():
		if c != screens and c != _toast:
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
			if build_mode.holding != null or build_mode.sell_mode:
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
