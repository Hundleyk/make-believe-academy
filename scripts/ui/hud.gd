extends CanvasLayer
## The HUD (design system: ui_kits/game and mockups 07-10), pinned to the corners with an
## 18px inset: Giggles (CoinCounter) top left, the Term clock with toy buttons top center,
## Kids' Trust (TrustMeter) top right, Leo's letter bottom left, the bottom menu bar bottom
## center, and the quick-build catalog bottom right. Panels (Build, Students, Requests) and
## the student card open over the world; full-screen screens sit on top of everything.
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
]
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
var _speed_chip: PanelContainer
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

	_build_giggles()
	_build_clock()
	_build_trust()
	_build_tabs()
	_build_toast()

	screens = Screens.new()
	screens.setup(self)
	root.add_child(screens)


# --- CoinCounter (top left) ---------------------------------------------------------

func _build_giggles() -> void:
	var holder := Control.new()
	holder.name = "Giggles"
	holder.position = Vector2(INSET, INSET)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	var tag := W.Paper.new("paper", Vector4(8, 26, 10, 44), "b")
	tag.position = Vector2(46, 4)
	tag.mouse_filter = Control.MOUSE_FILTER_PASS
	tag.tooltip_text = "Giggles are the Academy's money.\nHappy students giggle (+2 a period at Fun 7+); finding a combo pays a 25-Giggle grant."
	holder.add_child(tag)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	tag.add_child(col)
	col.add_child(Style.label("Giggles", 18, 600))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	var small := W.Coin.new(22)
	small.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(small)
	_giggles_label = Style.label("500", 28, 700)
	row.add_child(_giggles_label)
	var coin := W.Coin.new(78, true, -8)
	coin.big_shadow = true
	holder.add_child(coin)


# --- TermClock and toy buttons (top center) -----------------------------------------

func _build_clock() -> void:
	_clock = VBoxContainer.new()
	_clock.name = "Clock"
	_clock.add_theme_constant_override("separation", 14)
	_clock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 14)
	_clock.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_clock)
	var card := W.Paper.new("paper", Vector4(12, 30, 18, 30), "a")
	card.custom_minimum_size = Vector2(340, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	_clock.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	_clock_title = Style.label("Term 1 · Day 1", 26, 600)
	_clock_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_clock_title)
	_clock_bar = W.ClockBar.new(Vector2(280, 16))
	col.add_child(_clock_bar)
	card.add_child(Style.tape_corners(340, "sky"))

	var toys := HBoxContainer.new()
	toys.add_theme_constant_override("separation", 10)
	toys.alignment = BoxContainer.ALIGNMENT_CENTER
	toys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock.add_child(toys)
	_pause_button = _toy_button("pause", Style.HEART, "Pause  (Space)")
	_pause_button.pressed.connect(toggle_pause)
	toys.add_child(_pause_button)
	_fast_button = _toy_button("fast-forward", Style.GREEN, "Fast forward: 1×, 2×, 3×  ( ] faster, [ slower )")
	_fast_button.pressed.connect(func():
		GameState.set_speed(1 if GameState.speed >= 3 or GameState.speed == 0 else GameState.speed + 1))
	toys.add_child(_fast_button)
	_speed_chip = Style.chip("2×", Style.LIME, Style.INK, 13, 700)
	_speed_chip.position = Vector2(34, -8)
	_speed_chip.rotation_degrees = 8
	_fast_button.add_child(_speed_chip)
	var menu := _toy_button("gear-six", Style.TAB_TAN, "Pause menu: save, load, settings  (Esc)")
	menu.toggle_mode = false
	menu.pressed.connect(func(): UI.open_screen("pause"))
	toys.add_child(menu)


## A ToyButton: a 52px tan-light tile with a filled sticker icon; active presses down lime.
func _toy_button(icon: String, color: Color, tip: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(52, 52)
	b.tooltip_text = tip
	b.toggle_mode = true
	b.add_theme_stylebox_override("normal", Style.toy_box(false, false))
	b.add_theme_stylebox_override("hover", Style.toy_box(false, true))
	b.add_theme_stylebox_override("pressed", Style.toy_box(true))
	b.add_theme_stylebox_override("hover_pressed", Style.toy_box(true))
	var ic := W.Icon.new(icon, 29, color, "fill", true)
	ic.set_anchors_preset(Control.PRESET_CENTER)
	ic.offset_left = -14.5
	ic.offset_right = 14.5
	ic.offset_top = -14.5
	ic.offset_bottom = 14.5
	b.add_child(ic)
	b.toggled.connect(func(on: bool):
		ic.offset_top = -14.5 + (4 if on else 0)
		ic.offset_bottom = 14.5 + (4 if on else 0))
	return b


# --- TrustMeter (top right) ---------------------------------------------------------

func _build_trust() -> void:
	var card := W.Paper.new("paper", Vector4(14, 22, 20, 22), "b", -1.0)
	card.name = "Trust"
	card.custom_minimum_size = Vector2(280, 0)
	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, INSET)
	card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(card)
	_trust_tag = card
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	var t := Style.label("Kids' Trust", 24, 600)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var row := Control.new()
	row.custom_minimum_size = Vector2(236, 54)
	col.add_child(row)
	_trust_bar = W.TrustBar.new(Vector2(236 - 36, 24))
	_trust_bar.position = Vector2(36, 15)
	row.add_child(_trust_bar)
	var heart := W.Icon.new("heart", 54, Style.HEART, "fill", true)
	row.add_child(heart)
	if not Settings.reduce_motion:
		var tw := Style.ui_tween(heart).set_loops()
		tw.tween_property(heart, "scale", Vector2(1.12, 1.12), 0.24).set_trans(Tween.TRANS_SINE)
		tw.tween_property(heart, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(1.1)
	card.add_child(Style.clip(280))


func _update_top() -> void:
	if root == null:
		return
	_giggles_label.text = _comma(GameState.giggles)
	_trust_bar.set_values(GameState.trust / 10.0)
	_trust_tag.tooltip_text = "Kids' Trust: %d of 10. The Academy's health.\nGreat postcards raise it; unanswered letters lower it. At 0 the Department gets worried." % GameState.trust
	var paused := GameState.speed == 0
	_pause_button.set_pressed_no_signal(paused)
	_pause_button.toggled.emit(paused)
	_fast_button.set_pressed_no_signal(GameState.speed > 1)
	_fast_button.toggled.emit(GameState.speed > 1)
	_speed_chip.visible = GameState.speed > 1
	(_speed_chip.get_child(0) as Label).text = "%d×" % GameState.speed
	var waiting := 0
	for l in main.open_letters():
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
	return "Term %d · Day %d" % [TERM, GameState.day]


func _process(delta: float) -> void:
	_refresh -= delta
	if _refresh > 0.0 or root == null:
		return
	_refresh = 0.2
	_clock_title.text = day_text()
	_clock_bar.set_value(1.0 - students.period_left / students.period_seconds)
	_clock_bar.tooltip_text = "Free time · period %d. Needs change in %ds." % [students.period, ceili(maxf(students.period_left, 0.0))]


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
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 160)
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
	_hint_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 132)
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


# --- BottomMenu (bottom center) -----------------------------------------------------

func _build_tabs() -> void:
	var tile := Vector2(96, 76)
	var gap := 18.0
	var width := TABS.size() * tile.x + (TABS.size() - 1) * gap + 52.0
	var bar := Control.new()
	bar.name = "Tabs"
	bar.custom_minimum_size = Vector2(width, 112)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 0)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	var dock := Panel.new()
	var sb := Style.flat_box(Style.INDIGO, Style.LAVENDER, 0, 24, 0)
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.border_width_top = 4
	dock.add_theme_stylebox_override("panel", sb)
	dock.position = Vector2(0, 34)
	dock.size = Vector2(width, 112 - 34)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(dock)
	for i in TABS.size():
		var t: Array = TABS[i]
		var slot := Control.new()
		slot.position = Vector2(26 + i * (tile.x + gap), 4)
		slot.size = Vector2(tile.x, 104)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(slot)
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size = tile
		b.pivot_offset = tile / 2.0
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
		var ic := W.Icon.new(spec[0], 44, spec[1], "fill", true)
		ic.position = (tile - Vector2(44, 44)) / 2.0
		b.add_child(ic)
		var key := OS.get_keycode_string(t[2])
		if t[3] != "":
			b.disabled = true
			b.tooltip_text = t[3]
			slot.modulate = Color(1, 1, 1, 0.62)
		else:
			b.tooltip_text = "%s  (%s)" % [t[1], key]
			b.pressed.connect(UI.toggle_drawer.bind(t[0]))
		slot.add_child(b)
		var l := Style.label(t[1], 18, 600, Style.PAPER)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(-10, tile.y + 6)
		l.size = Vector2(tile.x + 20, 22)
		slot.add_child(l)
		_tab_buttons[t[0]] = b
		if t[0] == "requests":
			var badge := PanelContainer.new()
			badge.add_theme_stylebox_override("panel", Style.flat_box(Style.HEART, Style.INK, 3, 13, 0))
			badge.custom_minimum_size = Vector2(26, 26)
			badge.position = Vector2(tile.x - 16, -10)
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
		var b: Button = _tab_buttons[t]
		var on: bool = t == id
		b.set_pressed_no_signal(on)
		var y := -10.0 if on else 0.0
		var rot := -2.0 if on else 0.0
		if Settings.reduce_motion or not b.is_inside_tree():
			b.position.y = y
			b.rotation_degrees = rot
		else:
			var tw := Style.ui_tween(b).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_parallel()
			tw.tween_property(b, "position:y", y, 0.22)
			tw.tween_property(b, "rotation_degrees", rot, 0.22)
	_show(build_menu, id == "build")
	_show(students_panel, id == "students")
	_show(requests_panel, id == "requests")
	crayon_notes.visible = id == "" and crayon_notes.letter != null
	_clock.visible = id != "requests"   # mockup 10: the request form takes the top
	# The Build panel docks left (Two Point, Let's School); the bottom menu makes room.
	var dock: Control = root.get_node_or_null("Tabs")
	if dock != null:
		var shift := 124.0 if id == "build" else 0.0
		var w: float = dock.custom_minimum_size.x
		if Settings.reduce_motion:
			dock.offset_left = -w / 2.0 + shift
			dock.offset_right = w / 2.0 + shift
		else:
			var tw := Style.ui_tween(dock).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_parallel()
			tw.tween_property(dock, "offset_left", -w / 2.0 + shift, 0.22)
			tw.tween_property(dock, "offset_right", w / 2.0 + shift, 0.22)
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
		_quick_panel.visible = true
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
