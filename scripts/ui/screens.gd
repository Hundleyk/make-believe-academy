extends Control
## Full-screen screens over the game (design system: Game_Menus mockups 01-06 and 09): the
## main menu, pause, settings, Load/Save School, the quit note, loading, credits, and the
## arrival of a child's letter. While one is open the clock is paused and the world ignores
## clicks and keys. Sizes are the mockups' (1280x720 base).

const Style := preload("res://scripts/ui/ui_style.gd")
const W := preload("res://scripts/ui/widgets.gd")
const SaveGame := preload("res://scripts/save_game.gd")
const CrayonNotes := preload("res://scripts/ui/crayon_notes.gd")

const DIM := Color(0.165, 0.165, 0.267, 0.58)   # rgba(42,42,68,.58)
const SETTINGS_TABS := [["audio", "Audio", "speaker-high"], ["video", "Video", "monitor"], ["gameplay", "Gameplay", "puzzle-piece"], ["controls", "Controls", "keyboard"]]
const TIPS := [
	"sock serpents get grumpy if the laundry pile is too far away.",
	"fresh skill points fade. practice keeps them; a good night's rest makes them solid.",
	"two things that belong together glow when you hold one near the other. that's a combo!",
	"a student afraid of the dark stays calm in a nightlight's glow.",
	"hover a need in the Build panel to see what you can place to raise it.",
	"happy students giggle. giggles pay for everything.",
]
const BINDS := [
	["Pause", "Space"], ["Fast Forward", "]"], ["Build", "B"], ["Rotate Item", "R"],
	["Move Camera", "W A S D"], ["Students", "P"], ["Requests", "R"], ["Turn Camera", "Q  E"],
	["Sell Hovered Item", "X"], ["Back / Pause Menu", "Esc"],
]

## Kept across HUD rebuilds (the readable font rebuilds everything while Settings is open).
static var settings_back := "pause"
static var settings_tab := "audio"
static var slots_back := "pause"
static var slots_mode := "load"
static var quit_back := "title"

var hud: CanvasLayer
var _dim: ColorRect
var _holder: Control
var _letter: LetterData
var _pending := {}                 # Settings being edited, applied with Apply
var _selected_slot := 1
var _delete_armed := false


func setup(the_hud: CanvasLayer) -> void:
	hud = the_hud
	name = "Screens"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = DIM
	add_child(_dim)
	_holder = Control.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)


func show_screen(id: String) -> void:
	for c in _holder.get_children():
		c.queue_free()
	visible = id != ""
	match id:
		"title":
			_dim.color = Color(0, 0, 0, 0)
		"settings", "slots":
			_dim.color = Style.BOARD
		"loading":
			_dim.color = Style.INDIGO
		_:
			_dim.color = DIM
	match id:
		"title":
			_build_title()
		"pause":
			_build_pause()
		"settings":
			_build_settings()
		"slots":
			_build_slots()
		"letter":
			_build_letter()
		"loading":
			_build_loading()
		"quit":
			_build_quit()
		"credits":
			_build_credits()
	if visible and not Settings.reduce_motion:
		_holder.modulate.a = 0.0
		Style.ui_tween(_holder).tween_property(_holder, "modulate:a", 1.0, 0.18)
	else:
		_holder.modulate.a = 1.0


## Esc on a screen: one step back.
func escape() -> void:
	match UI.screen:
		"pause":
			UI.close_screen()
		"settings":
			UI.open_screen(settings_back)
		"slots":
			UI.open_screen(slots_back)
		"quit":
			if quit_back != "":
				UI.open_screen(quit_back)
			else:
				UI.close_screen()
		"credits":
			UI.open_screen("title")
		"letter":
			UI.close_screen()   # read later: it stays in Requests
		_:
			pass


func show_letter(letter: LetterData) -> void:
	_letter = letter
	UI.close_drawer()
	UI.open_screen("letter")


# --- Helpers ------------------------------------------------------------------------

## A centered PaperCard of a fixed width; returns the column to fill.
func _card(width: float, margin: Vector4, cut := "b", tilt := 0.0) -> VBoxContainer:
	var p := W.Paper.new("paper", margin, cut, tilt)
	p.custom_minimum_size = Vector2(width, 0)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	_holder.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	p.add_child(col)
	return col


## A wide, left-aligned PaperButton (size lg). `chosen` = the selected look.
func _menu_button(col: Control, text: String, icon: String, action: Callable, chosen := false, enabled := true, tip := "") -> Button:
	var b := Style.button(text, "lg", true, icon)
	if chosen:
		Style.select_button(b)
	b.disabled = not enabled
	b.tooltip_text = tip
	b.pressed.connect(action)
	col.add_child(b)
	return b


func _center(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _spacer(h := 8.0, expand := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## A form header: small caps form number over a 40px title.
func _form_head(parent: Control, form: String, title: String) -> VBoxContainer:
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(Style.caps(form, 13))
	head.add_child(Style.label(title, 40, 700))
	parent.add_child(head)
	return head


## The Letter component: lined paper, cut c, a paperclip, a crayon doodle, kid handwriting.
func _letter_card(greeting: String, body: String, signoff: String, width := 440.0, tilt := -2.0) -> Control:
	var p := W.Paper.new("lined", Vector4(26, 24, 64, 50), "c", tilt)
	p.custom_minimum_size = Vector2(width, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	p.add_child(col)
	for text in [greeting, body]:
		col.add_child(_hand_line(text, width - 90))
	col.add_child(_hand_line(" ", width - 90))
	var sign := _hand_line(signoff, width - 90 - 90)
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(sign)
	p.add_child(CrayonNotes._doodle())
	p.add_child(Style.clip(width))
	return p


## 25px handwriting on 33px rules (the Letter's line height).
func _hand_line(text: String, width: float) -> Label:
	var l := Style.hand_label(text, 25, Style.INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	l.add_theme_constant_override("line_spacing", int(33 - Style.hand().get_height(25)))
	return l


# --- 01 Main menu -------------------------------------------------------------------

func _build_title() -> void:
	var p := W.Paper.new("paper", Vector4(28, 32, 32, 32), "a", -1.0)
	p.custom_minimum_size = Vector2(420, 0)
	p.anchor_top = 0.0
	p.anchor_bottom = 1.0
	p.offset_left = 56
	p.offset_right = 56 + 420
	p.offset_top = 40
	p.offset_bottom = -40
	_holder.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	p.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)
	head.add_child(W.Seal.new(96))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 4)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(names)
	var title := Style.label("Make-Believe\nAcademy", 36, 700)
	title.add_theme_constant_override("line_spacing", -6)
	names.add_child(title)
	names.add_child(Style.hand_label("a school for imaginary friends", 20, Style.INK_SOFT))
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	buttons.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(buttons)
	var newest := SaveGame.newest_slot()
	var info := SaveGame.read_info(newest) if newest != -1 else {}
	var cont := _menu_button(buttons, "Continue", "play", func(): _load_slot(newest), newest != -1, newest != -1,
		"No saves yet." if newest == -1 else "Load your newest save (slot %d)." % newest)
	if newest != -1:
		var when := Style.hand_label("Term 1 · Day %d" % int(info.get("day", 1)), 20, Style.INK_SOFT)
		when.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
		when.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		when.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cont.add_child(when)
	_menu_button(buttons, "New School", "sparkle", func(): _open_slots("new", "title"), newest == -1)
	_menu_button(buttons, "Load School", "folder-open", func(): _open_slots("load", "title"))
	_menu_button(buttons, "Settings", "gear-six", func(): _open_settings("title"))
	_menu_button(buttons, "Credits", "star", func(): UI.open_screen("credits"))
	_menu_button(buttons, "Quit", "door-open", func(): _open_quit("title"))
	col.add_child(Style.caps("Dept. of Imaginary Affairs · demo", 13))
	p.add_child(Style.tape(40, -6, "sky"))


func _new_game(slot := 0, school := "") -> void:
	UI.close_screen()
	hud.main.start_new_game(slot, school)


func _build_credits() -> void:
	var col := _card(480, Vector4(36, 36, 32, 36), "b")
	col.add_theme_constant_override("separation", 10)
	col.add_child(_center(Style.caps("Form 0-C: Who made this", 13)))
	col.add_child(_center(Style.label("Credits", 44, 700)))
	for line in [["A game by", "Kyra Hundley · honeymilk labs"], ["Made with", "Godot 4"],
			["Fonts", "Fredoka, Patrick Hand, Atkinson Hyperlegible (SIL Open Font License)"],
			["Icons", "Phosphor Icons (MIT)"],
			["Thanks to", "every kid who ever had a friend nobody else could see"]]:
		col.add_child(_center(Style.caps(line[0], 12)))
		var v := _center(Style.hand_label(line[1], 22, Style.INK))
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.custom_minimum_size.x = 400
		col.add_child(v)
	col.add_child(_spacer(6))
	var back := Style.button("Back", "md", false, "arrow-left")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(escape)
	col.add_child(back)


# --- 02 Pause -----------------------------------------------------------------------

func _build_pause() -> void:
	var col := _card(400, Vector4(36, 36, 32, 36), "b")
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 6)
	col.add_child(titles)
	titles.add_child(_center(Style.label("Paused", 44, 700)))
	titles.add_child(_center(Style.hand_label("everyone freeze!", 20, Style.INK_SOFT)))
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)
	_menu_button(buttons, "Resume", "play", UI.close_screen, true)
	_menu_button(buttons, "Save School", "floppy-disk", func():
		if GameState.current_slot > 0:
			_save_to(GameState.current_slot)
		else:
			_open_slots("save", "pause"), false, true,
		"Save to slot %d" % GameState.current_slot if GameState.current_slot > 0 else "Pick a slot")
	_menu_button(buttons, "Load School", "folder-open", func(): _open_slots("load", "pause"))
	_menu_button(buttons, "Settings", "gear-six", func(): _open_settings("pause"))
	_menu_button(buttons, "Main Menu", "house", func(): hud.main.quit_to_title())
	var paper: Control = col.get_parent()
	paper.add_child(Style.tape_corners(400, "honey"))
	var o := Style.overlay()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	var stamp := W.Stamp.new("Recess", Style.HEART_DEEP, 22, 12, "Term 1 · Day 1")
	stamp.anchor_left = 1.0
	stamp.anchor_right = 1.0
	stamp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	stamp.offset_right = 60
	stamp.offset_top = -30
	o.add_child(stamp)
	paper.add_child(o)


# --- 03 Settings --------------------------------------------------------------------

func _open_settings(back_to: String) -> void:
	settings_back = back_to
	_pending = Settings.snapshot()
	UI.open_screen("settings")


func _build_settings() -> void:
	if _pending.is_empty():
		_pending = Settings.snapshot()
	var p := W.Paper.new("paper", Vector4(36, 44, 36, 44), "c")
	p.custom_minimum_size = Vector2(1040, 620)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	_holder.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	p.add_child(col)
	p.add_child(Style.clip(1040))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	col.add_child(top)
	_form_head(top, "Form 3-C: Comfort Preferences", "Settings")
	for t in SETTINGS_TABS:
		var b := Style.tab_button(t[1], "md", t[2])
		b.size_flags_vertical = Control.SIZE_SHRINK_END
		b.set_pressed_no_signal(settings_tab == t[0])
		b.pressed.connect(func():
			settings_tab = t[0]
			UI.open_screen("settings"))
		top.add_child(b)
	var rule := ColorRect.new()
	rule.color = Style.PAPER_SHADOW
	rule.custom_minimum_size.y = 3
	col.add_child(rule)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	match settings_tab:
		"audio":
			_slider(body, "Master Volume", "master_volume", 0, 100, 1, "%d")
			_slider(body, "Music", "music_volume", 0, 100, 1, "%d")
			_slider(body, "Sound Effects", "sfx_volume", 0, 100, 1, "%d")
			_slider(body, "Monster Babble", "babble_volume", 0, 100, 1, "%d")
			_toggle(body, "Subtitles", "Show what monsters say", "subtitles")
		"video":
			var wm := _row(body, "Window Mode")
			for m in [["windowed", "Windowed"], ["borderless", "Borderless"], ["fullscreen", "Fullscreen"]]:
				var b := Style.tab_button(m[1], "md")
				b.set_meta("tone", "paper")
				Style._style_button(b, "paper", Vector2(20, 10))
				b.set_pressed_no_signal(_pending.window_mode == m[0])
				b.pressed.connect(func():
					_pending.window_mode = m[0]
					UI.open_screen("settings"))
				wm.add_child(b)
			var us := _row(body, "UI Size")
			for v in Settings.UI_SCALES:
				var b := Style.tab_button("%d%%" % roundi(v * 100.0), "md")
				Style._style_button(b, "paper", Vector2(20, 10))
				b.set_pressed_no_signal(is_equal_approx(v, float(_pending.ui_scale)))
				b.pressed.connect(func():
					_pending.ui_scale = v
					UI.open_screen("settings"))
				us.add_child(b)
			_toggle(body, "V-Sync", "Smoother, a tiny bit slower", "vsync")
		"gameplay":
			_toggle(body, "Teacher Hints", "Little tips while you play", "teacher_hints")
			_toggle(body, "Gentle Motion", "Fewer bounces and wiggles", "reduce_motion")
			_toggle(body, "Readable Font", "Every font becomes Atkinson Hyperlegible, made for easy reading", "readable_font")
			_toggle(body, "Edge Scrolling", "Move the camera at screen edges", "edge_scroll")
			_slider(body, "Camera Speed", "camera_speed", 0.5, 2.0, 0.25, "%.2f×")
		"controls":
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 48)
			grid.add_theme_constant_override("v_separation", 16)
			body.add_child(grid)
			for bind in BINDS:
				var cell := VBoxContainer.new()
				cell.add_theme_constant_override("separation", 12)
				cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				grid.add_child(cell)
				var r := HBoxContainer.new()
				cell.add_child(r)
				var a := Style.label(bind[0], 19, 600)
				a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				r.add_child(a)
				var key := PanelContainer.new()
				var ksb := Style.button_box("tan", "normal", Vector2(14, 8))
				ksb.bg_color = Style.TAB_TAN_LIGHT
				ksb.shadow_offset = Vector2(0, 3)
				key.add_theme_stylebox_override("panel", ksb)
				var kl := Style.label(bind[1], 16, 700)
				kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				kl.custom_minimum_size.x = 28
				key.add_child(kl)
				r.add_child(key)
				var dash := W.Dashed.new(Style.PAPER_SHADOW, 2.0)
				dash.custom_minimum_size = Vector2(0, 2)
				cell.add_child(dash)
	var changed := _pending != Settings.snapshot()
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)
	var back := Style.button("Back", "md", false, "arrow-left")
	back.tooltip_text = "Leave without applying" if changed else ""
	back.pressed.connect(func():
		_pending = {}
		escape())
	buttons.add_child(back)
	var note := Style.hand_label("not applied yet…" if changed else "", 20, Style.INK_SOFT)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons.add_child(note)
	var reset := Style.button("Reset to Default", "md", false, "arrow-counter-clockwise")
	reset.pressed.connect(func():
		_pending = Settings.DEFAULTS.duplicate()
		UI.open_screen("settings"))
	buttons.add_child(reset)
	var apply := Style.button("Apply", "md", true, "check")
	apply.disabled = not changed
	apply.pressed.connect(func():
		var values := _pending.duplicate()
		Settings.set_values(values)
		_pending = Settings.snapshot()
		UI.open_screen("settings"))
	buttons.add_child(apply)


## A settings row: a 240px label column, then the control.
func _row(col: Control, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var l := Style.label(title, 19, 600)
	l.custom_minimum_size.x = 264
	row.add_child(l)
	return row


func _slider(col: Control, title: String, key: String, lo: float, hi: float, step: float, fmt: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	var l := Style.label(title, 19, 600)
	l.custom_minimum_size.x = 240
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = float(_pending[key])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.y = 34
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)
	var v := Style.label(fmt % slider.value, 19, 700)
	v.custom_minimum_size.x = 56
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	slider.value_changed.connect(func(x: float):
		_pending[key] = int(x) if typeof(Settings.DEFAULTS[key]) == TYPE_INT else x
		v.text = fmt % x)
	slider.drag_ended.connect(func(_c: bool): UI.open_screen("settings"))


func _toggle(col: Control, title: String, help: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(Style.label(title, 19, 600))
	if help != "":
		text.add_child(Style.label(help, 15, 500, Style.INK_SOFT))
	var on: bool = _pending[key]
	var state := Style.label("On" if on else "Off", 16, 700)
	state.custom_minimum_size.x = 30
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(state)
	var t := W.Toggle.new(on)
	t.tooltip_text = title
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.toggled.connect(func(x: bool):
		_pending[key] = x
		UI.open_screen("settings"))
	row.add_child(t)


# --- 04 Load and Save School --------------------------------------------------------

func _open_slots(mode: String, back_to: String) -> void:
	slots_mode = mode
	slots_back = back_to
	_selected_slot = maxi(1, SaveGame.newest_slot()) if mode == "load" else maxi(1, GameState.current_slot)
	if mode == "new" or (mode == "save" and GameState.current_slot == 0):
		_selected_slot = 1
		for slot in range(1, SaveGame.SLOTS + 1):
			if not SaveGame.exists(slot):
				_selected_slot = slot
				break
	_delete_armed = false
	_new_name = GameState.SCHOOL_NAMES[randi() % GameState.SCHOOL_NAMES.size()]
	UI.open_screen("slots")


var _new_name := ""


## Load School, Save School, and New School (mockup 04): three cubbies, filled or empty.
func _build_slots() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 28)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 72
	col.offset_right = -72
	col.offset_top = 56
	col.offset_bottom = -56
	_holder.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	var saving := slots_mode == "save"
	var starting := slots_mode == "new"
	var head := _form_head(top, "Form 12-S: Saved Schools", "New School" if starting else ("Save School" if saving else "Load School"))
	if starting:
		head.add_child(Style.hand_label("pick a cubby for your new school (three to choose from)", 22, Style.INK_SOFT))
	var back := Style.button("Back", "md", false, "arrow-left")
	back.size_flags_vertical = Control.SIZE_SHRINK_END
	back.pressed.connect(escape)
	top.add_child(back)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 40)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(grid)
	for slot in range(1, SaveGame.SLOTS + 1):
		grid.add_child(_slot_card(slot))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	col.add_child(foot)
	var info := SaveGame.read_info(_selected_slot)
	if starting:
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 12)
		name_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(name_row)
		var nl := Style.caps("School name", 13)
		nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_row.add_child(nl)
		var field := LineEdit.new()
		field.text = _new_name
		field.max_length = 32
		field.custom_minimum_size = Vector2(320, 48)
		field.add_theme_font_override("font", Style.hand())
		field.add_theme_font_size_override("font_size", 24)
		field.add_theme_color_override("font_color", Style.INK)
		field.add_theme_color_override("caret_color", Style.INK)
		var fsb := Style.flat_box(Style.PAPER, Style.CARDBOARD, 3, 10, 0)
		fsb.content_margin_left = 14
		fsb.content_margin_right = 14
		field.add_theme_stylebox_override("normal", fsb)
		var ffocus := fsb.duplicate()
		ffocus.border_color = Style.INK
		field.add_theme_stylebox_override("focus", ffocus)
		field.text_changed.connect(func(t: String): _new_name = t)
		name_row.add_child(field)
		var dice := Style.button("", "md", false, "sparkle")
		dice.tooltip_text = "Another name"
		dice.pressed.connect(func():
			_new_name = GameState.SCHOOL_NAMES[randi() % GameState.SCHOOL_NAMES.size()]
			UI.open_screen("slots"))
		name_row.add_child(dice)
	else:
		var desc := Style.hand_label("", 22, Style.INK)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if info.is_empty():
			desc.text = "Slot %d — an empty cubby" % _selected_slot
		else:
			desc.text = "%s — Term 1 · Day %d" % [info.get("school", "Make-Believe Academy"), int(info.get("day", 1))]
			desc.tooltip_text = "Saved %s" % SaveGame.when(int(info.get("saved_at", 0)))
			desc.mouse_filter = Control.MOUSE_FILTER_PASS
		foot.add_child(desc)
		var del := Style.button("Really delete?" if _delete_armed else "Delete", "md", false, "trash")
		del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		del.disabled = info.is_empty() or _selected_slot == GameState.current_slot
		if _selected_slot == GameState.current_slot and not info.is_empty():
			del.tooltip_text = "That's the school you're playing."
		del.pressed.connect(func():
			if _delete_armed:
				SaveGame.delete(_selected_slot)
				_delete_armed = false
				UI.toast("Slot %d emptied" % _selected_slot)
			else:
				_delete_armed = true
			UI.open_screen("slots"))
		foot.add_child(del)
	var go_text := "Load School"
	var go_icon := "play"
	if saving:
		go_text = "Save Here"
		go_icon = "floppy-disk"
	elif starting:
		go_text = ("Really start over?" if _delete_armed else "Start Over Here") if not info.is_empty() else "Start Here"
		go_icon = "sparkle"
	var go := Style.button(go_text, "lg", true, go_icon)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.disabled = slots_mode == "load" and info.is_empty()
	if (saving or starting) and not info.is_empty():
		go.tooltip_text = "Replaces %s in slot %d." % [info.get("school", "the school"), _selected_slot]
	go.pressed.connect(func():
		if saving:
			_save_to(_selected_slot)
		elif starting:
			if not info.is_empty() and not _delete_armed:
				_delete_armed = true
				UI.open_screen("slots")
				return
			SaveGame.delete(_selected_slot)
			var nm := _new_name.strip_edges()
			_new_game(_selected_slot, nm)
		else:
			_load_slot(_selected_slot))
	foot.add_child(go)


func _slot_card(slot: int) -> Control:
	var info := SaveGame.read_info(slot)
	var chosen := slot == _selected_slot
	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.custom_minimum_size = Vector2(0, 280)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.set_anchors_preset(Control.PRESET_TOP_WIDE)
	b.offset_bottom = 268
	b.pressed.connect(func():
		_selected_slot = slot
		_delete_armed = false
		UI.open_screen("slots"))
	b.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.double_click and not info.is_empty() and slots_mode == "load":
			_load_slot(slot))
	holder.add_child(b)
	if info.is_empty():
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st, Style.empty_box())
		var d := W.Dashed.new(Style.INK if chosen else Style.CARDBOARD, 3.0)
		d.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_child(d)
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 10)
		c.alignment = BoxContainer.ALIGNMENT_CENTER
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(c)
		var plus := W.Icon.new("plus-circle", 36, Style.INK_SOFT, "bold")
		plus.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		c.add_child(plus)
		c.add_child(_center(Style.label("Empty Cubby", 17, 600, Style.INK_SOFT)))
		c.add_child(_center(Style.caps("Slot %d" % slot, 12)))
		return holder
	b.add_theme_stylebox_override("normal", Style.card_box(chosen, false, 12))
	b.add_theme_stylebox_override("hover", Style.card_box(chosen, false, 12))
	b.add_theme_stylebox_override("pressed", Style.card_box(true, false, 12))
	b.add_theme_stylebox_override("hover_pressed", Style.card_box(true, false, 12))
	if chosen:
		b.offset_top = -6
		b.offset_bottom = 262
		b.rotation_degrees = -1.5
		b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	b.add_child(col)
	var pic := PanelContainer.new()
	pic.add_theme_stylebox_override("panel", Style.flat_box(Style.SKY_LIGHT, Style.PAPER_SHADOW, 2, 8, 0))
	pic.custom_minimum_size = Vector2(0, 150)
	pic.clip_contents = true
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(pic)
	var tex := SaveGame.thumbnail(slot)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(tr)
	else:
		pic.add_child(W.Stripes.new())
		var seal := W.Seal.new(84)
		seal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pic.add_child(seal)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 6)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(text)
	text.add_child(Style.hand_label(info.get("school", "Make-Believe Academy"), 24, Style.INK))
	text.add_child(Style.label("Term 1 · Day %d  ·  Slot %d" % [int(info.get("day", 1)), slot], 16, 600))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(row)
	var coin := W.Coin.new(20)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	var g := Style.label(hud._comma(int(info.get("giggles", 0))), 16, 700)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(g)
	row.add_child(Style.label(SaveGame.playtime(float(info.get("play_seconds", 0.0))), 15, 500, Style.INK_SOFT))
	if slot == GameState.current_slot and UI.screen == "slots" and slots_mode != "new":
		var o2 := Style.overlay()
		o2.set_anchors_preset(Control.PRESET_FULL_RECT)
		var st2 := W.Stamp.new("Playing", Style.HEART_DEEP, 14, 8)
		st2.anchor_left = 1.0
		st2.anchor_right = 1.0
		st2.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		st2.offset_right = 10
		st2.offset_top = -14
		o2.add_child(st2)
		b.add_child(o2)
	if bool(info.get("autosave", false)):
		var o := Style.overlay()
		o.set_anchors_preset(Control.PRESET_FULL_RECT)
		var stamp := W.Stamp.new("Autosave", Style.HEART_DEEP, 14, 8)
		stamp.anchor_left = 1.0
		stamp.anchor_right = 1.0
		stamp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		stamp.offset_right = 10
		stamp.offset_top = -14
		o.add_child(stamp)
		b.add_child(o)
	return holder


## Save with a picture of the school: hide the menus for one frame and take a screenshot.
func _save_to(slot: int) -> void:
	var picture: Image = null
	if DisplayServer.get_name() != "headless":
		hud.root.visible = false
		await RenderingServer.frame_post_draw
		picture = get_viewport().get_texture().get_image()
		hud.root.visible = true
	if SaveGame.save(hud.main, slot, picture):
		UI.close_screen()
		UI.toast("Saved to slot %d" % slot, "", "tucked in safe and sound.")
	else:
		UI.toast("Couldn't save", "Something went wrong writing slot %d." % slot)


func _load_slot(slot: int) -> void:
	if slot < 1:
		return
	UI.open_screen("loading")
	# Let the loading screen draw first, then load and close it.
	await get_tree().create_timer(0.5, true, false, true).timeout
	var ok := SaveGame.load_into(hud.main, slot)
	await get_tree().create_timer(0.45, true, false, true).timeout
	UI.close_screen()
	if ok:
		UI.toast("Welcome back!", "Loaded slot %d." % slot)
	else:
		UI.toast("Couldn't load", "Slot %d couldn't be read." % slot)


# --- 05 Quit ------------------------------------------------------------------------

func _open_quit(back_to: String) -> void:
	quit_back = back_to
	UI.open_screen("quit")


func _build_quit() -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 30)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stack.grow_vertical = Control.GROW_DIRECTION_BOTH
	_holder.add_child(stack)
	var letter := _letter_card("Dear Headteacher,", "are you leaving already? we will save you a cookie. come back tomorrow!", "— Pip, Drizzle & Bo", 440, -2.0)
	letter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(letter)
	var box := W.Paper.new("paper", Vector4(22, 26, 22, 26), "b")
	box.custom_minimum_size = Vector2(440, 0)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(box)
	var bcol := VBoxContainer.new()
	bcol.add_theme_constant_override("separation", 16)
	box.add_child(bcol)
	var saved := HBoxContainer.new()
	saved.add_theme_constant_override("separation", 10)
	bcol.add_child(saved)
	saved.add_child(W.Icon.new("floppy-disk", 20, Style.INK, "bold"))
	saved.add_child(Style.label(_last_saved_text(), 17, 600))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bcol.add_child(row)
	var stay := Style.button("Stay a Bit", "md", true, "heart")
	Style.select_button(stay)
	stay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stay.pressed.connect(escape)
	row.add_child(stay)
	var quit := Style.button("Quit to Desktop", "md", false, "door-open")
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit.pressed.connect(func(): get_tree().quit())
	row.add_child(quit)


func _last_saved_text() -> String:
	if quit_back == "title":
		return "See you soon!"
	if GameState.last_saved_at <= 0:
		return "This school hasn't been saved yet"
	var mins := int((Time.get_unix_time_from_system() - GameState.last_saved_at) / 60.0)
	if mins < 1:
		return "Last saved just now"
	return "Last saved %d minute%s ago" % [mins, "" if mins == 1 else "s"]


# --- 06 Loading ---------------------------------------------------------------------

func _build_loading() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 40)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	_holder.add_child(col)
	var seal := W.Seal.new(180)
	seal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(seal)
	var lower := VBoxContainer.new()
	lower.add_theme_constant_override("separation", 14)
	col.add_child(lower)
	lower.add_child(_center(Style.label("Fluffing the pillows…", 22, 600, Style.PAPER)))
	var bar := W.LoadBar.new(Vector2(520, 22))
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lower.add_child(bar)
	Style.ui_tween(bar).tween_property(bar, "value", 1.0, 0.9).from(0.12)

	var tip := W.Paper.new("lined", Vector4(26, 24, 18, 52), "a", 2.0)
	tip.line_offset = 26.0
	tip.custom_minimum_size = Vector2(380, 0)
	tip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 0)
	tip.offset_right = -56
	tip.offset_bottom = -48
	tip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_holder.add_child(tip)
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", 8)
	tip.add_child(tcol)
	tcol.add_child(Style.caps("Teacher's Tip", 13))
	var t := Style.hand_label(TIPS[randi() % TIPS.size()], 22, Style.INK)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 300
	t.add_theme_constant_override("line_spacing", int(33 - Style.hand().get_height(22)))
	tcol.add_child(t)
	tip.add_child(Style.tape(380 / 2.0 - 48, -4, "lime"))


# --- 09 A letter arrives ------------------------------------------------------------

func _build_letter() -> void:
	if _letter == null:
		_letter = hud.main.letters[0]
	var l := _letter
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 22)
	stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 140)
	stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_holder.add_child(stack)
	var pill := PanelContainer.new()
	var psb := Style.flat_box(Style.INDIGO, Color(0, 0, 0, 0), 0, 999, 0)
	psb.content_margin_left = 18
	psb.content_margin_right = 18
	psb.content_margin_top = 10
	psb.content_margin_bottom = 10
	pill.add_theme_stylebox_override("panel", psb)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(pill)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 10)
	pill.add_child(prow)
	prow.add_child(W.Icon.new("paper-plane-tilt", 22, Style.HONEY, "fill"))
	prow.add_child(Style.label("New letter from %s, age %d" % [l.child, l.age], 17, 600, Style.PAPER))
	var letter := _letter_card("Dear Academy,", l.body + " " + l.ps, "— %s" % l.child, 480, -3.0)
	var due := Style.chip("Answer within %d days" % l.answer_days, Style.HONEY, Style.HONEY_DEEP, 13, 700)
	due.rotation_degrees = 4
	due.tooltip_text = "Unanswered letters run out of time, and the child's trust drops."
	due.mouse_filter = Control.MOUSE_FILTER_PASS
	var duo := Style.overlay()
	duo.set_anchors_preset(Control.PRESET_FULL_RECT)
	due.position = Vector2(220, -16)
	duo.add_child(due)
	letter.add_child(duo)
	letter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(letter)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(buttons)
	var later := Style.button("Read Later", "md", false, "tray")
	later.tooltip_text = "It waits in Requests (R)."
	later.pressed.connect(UI.close_screen)
	buttons.add_child(later)
	var help := Style.button("Find a Helper", "md", true, "magnifying-glass")
	Style.select_button(help)
	help.tooltip_text = "Approve %s's request and see who could help." % l.child
	help.pressed.connect(func():
		GameState.accept_letter(l)
		UI.close_screen()
		UI.open_drawer("requests")
		UI.toast("%s's request is approved" % l.child, "His notes are clipped bottom left.", "let's start with the castle."))
	buttons.add_child(help)
	var note := Style.label("The clock is paused · Esc to read later", 14, 500, Style.PAPER)
	note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
	note.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	note.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_holder.add_child(note)
