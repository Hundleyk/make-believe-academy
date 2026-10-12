extends CanvasLayer
## The HUD frame (design system mockups 07-10): the Giggles tag top left, the Term · Day
## banner with pause and speed tiles top center, Kids' Trust top right, Leo's pinned note
## bottom left, the navy tab bar bottom center, and the quick-build tiles bottom right.
## Drawers (Build, Students, Requests) and the trading card open over the world;
## full-screen screens (letters, pause, settings, title) sit on top of everything.

const Style := preload("res://scripts/ui/ui_style.gd")
const W := preload("res://scripts/ui/widgets.gd")
const BuildMenu := preload("res://scripts/build_menu.gd")
const StudentsPanel := preload("res://scripts/ui/students_panel.gd")
const TradingCard := preload("res://scripts/ui/trading_card.gd")
const RequestsPanel := preload("res://scripts/ui/requests_panel.gd")
const CrayonNotes := preload("res://scripts/ui/crayon_notes.gd")
const Screens := preload("res://scripts/ui/screens.gd")

## Bottom tabs: id, label, key, icon, what it says while it isn't built yet.
const TABS := [
	["build", "Build", KEY_B, "hammer", ""],
	["timetable", "Timetable", KEY_T, "calendar", "The Timetable arrives with the day clock (M1 week 4)."],
	["students", "Students", KEY_P, "students", ""],   # P for pupils (S pans the camera)
	["staff", "Staff", KEY_H, "staff", "Teachers and hiring arrive in M2."],
	["requests", "Requests", KEY_R, "requests", ""],
]
const QUICK_SLOTS := 6
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
var _trust_label: Label
var _trust_meter: Control
var _clock_title: Label
var _clock_sub: Label
var _clock_bar: Control
var _speed_chip: Label
var _pause_button: Button
var _pause_icon: Control
var _hint_label: Label
var _hint_panel: PanelContainer
var _toast: PanelContainer
var _toast_title: Label
var _toast_body: Label
var _toast_flavor: Label
var _toast_busy := false
var _tab_buttons := {}
var _requests_badge: Label
var _quick_grid: GridContainer
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

	_build_giggles()
	_build_clock()
	_build_trust()
	_build_tabs()
	_build_toast()

	screens = Screens.new()
	screens.setup(self)
	root.add_child(screens)


# --- Top bar ------------------------------------------------------------------------

func _build_giggles() -> void:
	var holder := Control.new()
	holder.position = Vector2(16, 14)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	var tag := Style.paper_panel(0)
	var sb := Style.paper_box(0, 4)
	sb.content_margin_left = 66
	sb.content_margin_right = 22
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	tag.add_theme_stylebox_override("panel", sb)
	tag.position = Vector2(30, 8)
	tag.rotation_degrees = -1.0
	tag.tooltip_text = "Giggles are the Academy's money.\nHappy students giggle (+2 a period at Fun 7+); finding a combo pays a 25-Giggle grant."
	holder.add_child(tag)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -6)
	tag.add_child(col)
	col.add_child(Style.label("Giggles", 17, 600))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	var small := W.Coin.new(22, false)
	small.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(small)
	_giggles_label = Style.label("500", 32, 700)
	row.add_child(_giggles_label)
	var coin := W.Coin.new(78)
	coin.position = Vector2(0, 0)
	holder.add_child(coin)


func _build_clock() -> void:
	var holder := VBoxContainer.new()
	holder.name = "Clock"
	holder.add_theme_constant_override("separation", 6)
	holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 10)
	holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	var banner := W.Paper.new(Style.PAPER, 0, 2.0, 7)
	var bsb := StyleBoxEmpty.new()
	bsb.content_margin_left = 30
	bsb.content_margin_right = 30
	bsb.content_margin_top = 8
	bsb.content_margin_bottom = 10
	banner.add_theme_stylebox_override("panel", bsb)
	banner.custom_minimum_size = Vector2(400, 0)
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.add_child(banner)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	banner.add_child(col)
	_clock_title = Style.label("Term 1 · Day 1", 27, 700)
	_clock_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_clock_title)
	_clock_bar = W.Meter.new(Vector2(330, 18), false, true)
	_clock_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_clock_bar)
	_clock_sub = Style.hand_label("", 17, Style.INK_SOFT)
	_clock_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_clock_sub)
	banner.add_child(Style.tape(-18, -28, Style.WASHI_BLUE, 54))
	var right_tape := Style.tape(364, 28, Style.WASHI_BLUE, 54)
	banner.add_child(right_tape)

	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 10)
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tiles)
	_pause_button = _tile_button("pause", Style.HEART, "Pause or resume the students  (Space)")
	_pause_icon = _pause_button.get_child(0)
	_pause_button.pressed.connect(toggle_pause)
	tiles.add_child(_pause_button)
	var fast := _tile_button("fast", Style.OK_GREEN, "Faster: 1×, 2×, 3×  ( ] faster, [ slower )")
	fast.pressed.connect(func():
		GameState.set_speed(1 if GameState.speed >= 3 or GameState.speed == 0 else GameState.speed + 1))
	tiles.add_child(fast)
	var menu := _tile_button("gear", Style.WOOD, "Pause menu: save, load, settings  (Esc)")
	menu.pressed.connect(func(): UI.open_screen("pause"))
	tiles.add_child(menu)
	_speed_chip = Style.label("1×", 15, 700)
	var chip := PanelContainer.new()
	var csb := Style.flat_box(Style.PAPER, Style.INK, 2, 10, 0)
	csb.content_margin_left = 8
	csb.content_margin_right = 8
	chip.add_theme_stylebox_override("panel", csb)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(_speed_chip)
	tiles.add_child(chip)


## A square cardboard tile with a colored icon (pause, fast-forward, menu).
func _tile_button(icon: String, color: Color, tip: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(54, 50)
	b.tooltip_text = tip
	b.add_theme_stylebox_override("normal", Style.lip_box(Style.TAB_TAN, true, false, false, false, 10))
	b.add_theme_stylebox_override("hover", Style.lip_box(Style.TAB_TAN.lightened(0.12), true, false, false, false, 10))
	b.add_theme_stylebox_override("pressed", Style.lip_box(Style.PAPER, false, true, true, false, 10))
	b.add_theme_stylebox_override("hover_pressed", Style.lip_box(Style.PAPER, false, true, true, false, 10))
	var ic := W.Icon.new(icon, 26, color)
	ic.set_anchors_preset(Control.PRESET_CENTER)
	ic.offset_left = -13
	ic.offset_right = 13
	ic.offset_top = -15
	ic.offset_bottom = 11
	b.add_child(ic)
	return b


func _build_trust() -> void:
	var tag := W.Paper.new(Style.PAPER, 0, 2.0, 11)
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 18
	sb.content_margin_right = 20
	sb.content_margin_top = 10
	sb.content_margin_bottom = 14
	tag.add_theme_stylebox_override("panel", sb)
	tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
	tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tag.rotation_degrees = 0.8
	tag.tooltip_text = "Kids' Trust is the Academy's health.\nGreat postcards raise it; unanswered letters lower it. At 0 the Department gets worried."
	root.add_child(tag)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	tag.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var t := Style.label("Kids' Trust", 22, 700)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(t)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	col.add_child(row)
	var heart := W.Heart.new(true)
	heart.custom_minimum_size = Vector2(42, 38)
	row.add_child(heart)
	_trust_meter = W.Meter.new(Vector2(190, 22), true, false)
	_trust_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_trust_meter)
	_trust_label = Style.label("5 of 10", 13, 600, Style.INK_SOFT)
	_trust_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_trust_label)
	var clip := W.Paperclip.new(Vector2(18, 42))
	var o := Style.overlay()
	clip.position = Vector2(232, -20)
	o.add_child(clip)
	tag.add_child(o)


func _update_top() -> void:
	if root == null:
		return
	_giggles_label.text = _comma(GameState.giggles)
	_trust_label.text = "%d of 10" % GameState.trust
	_trust_meter.set_value(GameState.trust / 10.0)
	var paused := GameState.speed == 0
	_pause_button.toggle_mode = true
	_pause_button.set_pressed_no_signal(paused)
	_pause_icon.shape = "play" if paused else "pause"
	_pause_icon.queue_redraw()
	_speed_chip.text = "paused" if paused else "%d×" % GameState.speed
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


## "Term 1 · Day 1" (shared with the title screen and save slots).
static func day_text() -> String:
	return "Term %d · Day %d" % [TERM, 1]


func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0 or root == null:
		return
	_refresh = 0.2
	_clock_title.text = day_text()
	_clock_bar.set_value(1.0 - students.period_left / students.period_seconds)
	_clock_sub.text = "free time · period %d" % students.period
	_clock_bar.tooltip_text = "Period %d: needs change in %ds" % [students.period, ceili(maxf(students.period_left, 0.0))]


static func _comma(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# --- Toasts and hint ----------------------------------------------------------------

func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", Style.paper_box(14, 6))
	_toast.custom_minimum_size = Vector2(400, 0)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 172)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.rotation_degrees = 0.8
	_toast.visible = false
	root.add_child(_toast)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	_toast.add_child(col)
	_toast_title = Style.label("", 20, 700)
	_toast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_toast_title)
	_toast_body = Style.label("", 15)
	_toast_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_body.custom_minimum_size.x = 370
	col.add_child(_toast_body)
	_toast_flavor = Style.hand_label("", 19, Style.CRAYON_PURPLE)
	_toast_flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_flavor.custom_minimum_size.x = 370
	col.add_child(_toast_flavor)
	_toast.add_child(Style.tape(164, 2, Style.WASHI_PINK))


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
	var tw := Style.ui_tween(_toast)
	tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(4.0)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		_toast.visible = false
		_toast_busy = false
		_next_toast())


## The hint slip above the tab bar (hover hints, holding an item, selling).
## While the Build menu is open its footer shows the hint instead.
func _build_hint() -> void:
	_hint_panel = PanelContainer.new()
	var sb := Style.paper_box(0, 10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	_hint_panel.add_theme_stylebox_override("panel", sb)
	_hint_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 136)
	_hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hint_panel)
	_hint_label = Style.label(build_mode._hint, 15, 500)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_panel.add_child(_hint_label)
	_on_hint(build_mode._hint)


func _on_hint(t: String) -> void:
	if _hint_label == null:
		return
	_hint_label.text = t
	var idle := t.begins_with("Pick an item")
	_hint_panel.visible = t != "" and not idle and UI.drawer != "build" and UI.drawer != "requests"
	if build_menu != null:
		build_menu.set_hint(t)


# --- Quick build tiles (bottom right) -----------------------------------------------

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
	var sb := Style.lip_box(Color("F6E6CC"), true, false, false, false, 14)
	sb.set_content_margin_all(10)
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.tooltip_text = "Quick build: your recent items"
	root.add_child(panel)
	_quick_grid = GridContainer.new()
	_quick_grid.columns = 3
	_quick_grid.add_theme_constant_override("h_separation", 8)
	_quick_grid.add_theme_constant_override("v_separation", 8)
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
		b.custom_minimum_size = Vector2(56, 56)
		if i < quick_items.size():
			var d: ItemData = quick_items[i]
			var bg := d.gray_color.lightened(0.45)
			b.add_theme_stylebox_override("normal", Style.lip_box(bg, true, false, false, false, 10))
			b.add_theme_stylebox_override("hover", Style.lip_box(bg.lightened(0.2), true, false, false, false, 10))
			b.add_theme_stylebox_override("pressed", Style.lip_box(Style.PAPER, false, true, true, false, 10))
			b.add_theme_stylebox_override("disabled", Style.lip_box(bg.lerp(Style.DESK, 0.6), true, false, false, true, 10))
			b.tooltip_text = "%s · %d Giggles\n%s" % [d.display_name, d.cost, d.effect_text]
			var icon := W.ItemIcon.new(d)
			icon.set_anchors_preset(Control.PRESET_CENTER)
			icon.offset_left = -15
			icon.offset_right = 15
			icon.offset_top = -17
			icon.offset_bottom = 13
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
			b.add_theme_stylebox_override("disabled", Style.flat_box(Color(Style.TRACK, 0.5), Style.PAPER_EDGE, 2, 10, 0))
		_quick_grid.add_child(b)


# --- Bottom tab bar and drawers -----------------------------------------------------

func _build_tabs() -> void:
	var bar := PanelContainer.new()
	bar.name = "Tabs"
	var sb := Style.flat_box(Style.NAVY, Color(0, 0, 0, 0), 0, 22, 0)
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(Style.NIGHT, 0.3)
	sb.shadow_size = 8
	bar.add_theme_stylebox_override("panel", sb)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 0)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)
	for t in TABS:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		row.add_child(col)
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(80, 70)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var tile := Color("F4D9B6")
		b.add_theme_stylebox_override("normal", Style.lip_box(tile, true, false, false, false, 12))
		b.add_theme_stylebox_override("hover", Style.lip_box(tile.lightened(0.15), true, false, false, false, 12))
		b.add_theme_stylebox_override("pressed", Style.lip_box(Style.PAPER, false, false, true, false, 12))
		b.add_theme_stylebox_override("hover_pressed", Style.lip_box(Style.PAPER, false, false, true, false, 12))
		b.add_theme_stylebox_override("disabled", Style.lip_box(tile.lerp(Style.NAVY, 0.35), true, false, false, true, 12))
		var inner := PanelContainer.new()
		inner.add_theme_stylebox_override("panel", Style.flat_box(Style.TAB_COLORS[t[0]], Style.INK, 2, 6, 0))
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.set_anchors_preset(Control.PRESET_CENTER)
		inner.offset_left = -21
		inner.offset_right = 21
		inner.offset_top = -24
		inner.offset_bottom = 18
		b.add_child(inner)
		var ic := W.Icon.new(t[3], 26, Style.PAPER)
		ic.set_anchors_preset(Control.PRESET_CENTER)
		ic.offset_left = -13
		ic.offset_right = 13
		ic.offset_top = -16
		ic.offset_bottom = 10
		b.add_child(ic)
		var key := OS.get_keycode_string(t[2])
		if t[4] != "":
			b.disabled = true
			b.tooltip_text = t[4]
			col.modulate.a = 0.6
		else:
			b.tooltip_text = "%s  (%s)" % [t[1], key]
			b.pressed.connect(UI.toggle_drawer.bind(t[0]))
		col.add_child(b)
		var l := Style.label(t[1], 17, 600, Style.PAPER)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		_tab_buttons[t[0]] = b
		if t[0] == "requests":
			var badge := PanelContainer.new()
			badge.add_theme_stylebox_override("panel", Style.flat_box(Style.HEART, Style.PAPER, 2, 12, 0))
			badge.custom_minimum_size = Vector2(26, 26)
			badge.position = Vector2(64, -12)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_requests_badge = Style.label("1", 14, 700, Style.PAPER)
			_requests_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_requests_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge.add_child(_requests_badge)
			b.add_child(badge)


func _on_drawer_changed(id: String) -> void:
	if root == null:
		return
	for t in _tab_buttons:
		_tab_buttons[t].set_pressed_no_signal(t == id)
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
	_on_hint(build_mode._hint)


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
	# Menus and moments sit over a dimmed HUD (mockups 01, 02, 05, 09); the Build menu,
	# cards, and toasts step aside so the screen reads cleanly.
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
				if t[2] == event.physical_keycode and t[4] == "" and t[0] != "requests":
					UI.toggle_drawer(t[0])
					hit = true
			if not hit:
				return
	get_viewport().set_input_as_handled()
