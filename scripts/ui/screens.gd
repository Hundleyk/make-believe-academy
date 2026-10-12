extends Control
## Full-screen screens over the game (UI System doc, "Big moments"): the title screen,
## pause, settings, save/load slots, a loading card, and the arrival of a child's letter.
## While one is open the clock is paused and the world ignores clicks and keys.

const Style := preload("res://scripts/ui/ui_style.gd")
const W := preload("res://scripts/ui/widgets.gd")
const SaveGame := preload("res://scripts/save_game.gd")

var hud: CanvasLayer
var _dim: ColorRect
var _holder: Control
var _letter: LetterData
var _slots_mode := "load"          # save or load
var _settings_back := "pause"      # where Back goes from settings
var _slots_back := "pause"


func setup(the_hud: CanvasLayer) -> void:
	hud = the_hud
	name = "Screens"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(Style.NIGHT, 0.55)
	add_child(_dim)
	_holder = Control.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)


func show_screen(id: String) -> void:
	for c in _holder.get_children():
		c.queue_free()
	visible = id != ""
	_dim.color = Color(Style.NIGHT, 0.25 if id == "title" else 0.6)
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
			UI.open_screen(_settings_back)
		"slots":
			UI.open_screen(_slots_back)
		"letter":
			UI.close_screen()   # read later: it stays in Requests
		_:
			pass


func show_letter(letter: LetterData) -> void:
	_letter = letter
	UI.close_drawer()
	UI.open_screen("letter")


# --- Helpers ------------------------------------------------------------------------

func _card(width := 420.0) -> VBoxContainer:
	var p := Style.paper_panel(28)
	p.custom_minimum_size = Vector2(width, 0)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	_holder.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	p.add_child(col)
	p.add_child(Style.tape(width / 2.0 - 32.0, -2))
	return col


func _menu_button(col: Control, text: String, action: Callable, primary := false, enabled := true, tip := "") -> Button:
	var b := Style.button(text, 18, primary)
	b.custom_minimum_size = Vector2(0, 46)
	b.disabled = not enabled
	b.tooltip_text = tip
	b.pressed.connect(action)
	col.add_child(b)
	return b


func _center(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# --- Title --------------------------------------------------------------------------

func _build_title() -> void:
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 4)
	title_box.position = Vector2(90, 110)
	_holder.add_child(title_box)
	var t := Style.label("Make-Believe Academy", 76, 600, Style.PAPER)
	t.add_theme_color_override("font_outline_color", Style.INK)
	t.add_theme_constant_override("outline_size", 14)
	title_box.add_child(t)
	var tag := Style.hand_label("Every lonely kid deserves the perfect imaginary friend.", 30, Style.PAPER)
	tag.add_theme_color_override("font_outline_color", Style.NIGHT)
	tag.add_theme_constant_override("outline_size", 8)
	title_box.add_child(tag)

	var p := Style.paper_panel(26)
	p.custom_minimum_size = Vector2(340, 0)
	p.position = Vector2(96, 330)
	p.rotation_degrees = -1.0
	_holder.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	p.add_child(col)
	p.add_child(Style.tape(138, 2))
	_menu_button(col, "New Game", _new_game, true)
	var newest := SaveGame.newest_slot()
	_menu_button(col, "Continue", func(): _load_slot(newest), false, newest != -1,
		"No saves yet." if newest == -1 else "Load your newest save (slot %d)." % newest)
	_menu_button(col, "Load Game", func(): _open_slots("load", "title"))
	_menu_button(col, "Settings", func(): _open_settings("title"))
	_menu_button(col, "Quit", func(): get_tree().quit())

	var studio := Style.label("honeymilk labs · demo build", 14, 500, Style.PAPER)
	studio.add_theme_color_override("font_outline_color", Style.NIGHT)
	studio.add_theme_constant_override("outline_size", 6)
	studio.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 24)
	studio.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_holder.add_child(studio)


func _new_game() -> void:
	UI.close_screen()
	hud.main.start_new_game()


# --- Pause --------------------------------------------------------------------------

func _build_pause() -> void:
	var col := _card(380)
	col.add_child(_center(Style.label("Paused", 32, 600)))
	col.add_child(_center(Style.hand_label("The Academy holds its breath.", 20, Style.CRAYON_PURPLE)))
	_menu_button(col, "Resume", UI.close_screen, true)
	_menu_button(col, "Save Game", func(): _open_slots("save", "pause"))
	_menu_button(col, "Load Game", func(): _open_slots("load", "pause"))
	_menu_button(col, "Settings", func(): _open_settings("pause"))
	_menu_button(col, "Quit to Title", func(): hud.main.quit_to_title())
	col.add_child(_center(Style.label("Esc to resume", 13, 400, Style.INK_SOFT)))


# --- Settings -----------------------------------------------------------------------

func _open_settings(back_to: String) -> void:
	_settings_back = back_to
	UI.open_screen("settings")


func _build_settings() -> void:
	var col := _card(520)
	col.add_child(Style.label("Settings", 30, 600))
	col.add_child(Style.label("Saved automatically.", 13, 400, Style.INK_SOFT))

	_section(col, "Reading and comfort")
	_toggle(col, "Readable font", "Switch every font to Atkinson Hyperlegible, made for easy reading.", "readable_font")
	var scale_row := _row(col, "UI size", "Make menus and text bigger.")
	var scales := OptionButton.new()
	scales.focus_mode = Control.FOCUS_NONE
	for i in Settings.UI_SCALES.size():
		scales.add_item("%d%%" % roundi(Settings.UI_SCALES[i] * 100.0), i)
		if is_equal_approx(Settings.UI_SCALES[i], Settings.ui_scale):
			scales.select(i)
	scales.item_selected.connect(func(i: int): Settings.set_value("ui_scale", Settings.UI_SCALES[i]))
	scale_row.add_child(scales)
	_toggle(col, "Reduce motion", "No wobbles, hops, bobbing, or fades.", "reduce_motion")

	_section(col, "Screen and controls")
	_toggle(col, "Fullscreen", "", "fullscreen")
	var cam_row := _row(col, "Camera speed", "How fast WASD moves the view.")
	var slider := HSlider.new()
	slider.min_value = 0.5
	slider.max_value = 2.0
	slider.step = 0.25
	slider.value = Settings.camera_speed
	slider.custom_minimum_size = Vector2(160, 24)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(v: float): Settings.set_value("camera_speed", v))
	cam_row.add_child(slider)

	col.add_child(Style.label("Volume and key remapping arrive with sound and final controls.", 13, 400, Style.INK_SOFT))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	col.add_child(buttons)
	var back := Style.button("Back", 16, true)
	back.custom_minimum_size = Vector2(120, 42)
	back.pressed.connect(escape)
	buttons.add_child(back)
	var reset := Style.button("Reset to defaults", 15)
	reset.pressed.connect(func():
		Settings.reset()
		UI.open_screen("settings"))
	buttons.add_child(reset)


func _section(col: Control, text: String) -> void:
	col.add_child(Style.label(text, 15, 600, Style.CRAYON_PURPLE))


func _row(col: Control, title: String, help: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	text.add_child(Style.label(title, 16, 500))
	if help != "":
		var h := Style.label(help, 13, 400, Style.INK_SOFT)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.custom_minimum_size.x = 300
		text.add_child(h)
	return row


func _toggle(col: Control, title: String, help: String, key: String) -> void:
	var row := _row(col, title, help)
	var c := CheckButton.new()
	c.focus_mode = Control.FOCUS_NONE
	c.button_pressed = Settings.get(key)
	c.tooltip_text = title
	c.toggled.connect(func(on: bool): Settings.set_value(key, on))
	row.add_child(c)


# --- Save and load slots ------------------------------------------------------------

func _open_slots(mode: String, back_to: String) -> void:
	_slots_mode = mode
	_slots_back = back_to
	UI.open_screen("slots")


func _build_slots() -> void:
	var col := _card(480)
	col.add_child(Style.label("Save Game" if _slots_mode == "save" else "Load Game", 30, 600))
	for slot in range(1, SaveGame.SLOTS + 1):
		var info := SaveGame.read_info(slot)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 64)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", Style.font(500))
		b.add_theme_font_size_override("font_size", 16)
		if info.is_empty():
			b.text = "Slot %d  ·  empty" % slot
			b.disabled = _slots_mode == "load"
		else:
			b.text = "Slot %d  ·  Period %d  ·  %s Giggles\n%s" % [slot, int(info.get("period", 1)),
				hud._comma(int(info.get("giggles", 0))), SaveGame.when(int(info.get("saved_at", 0)))]
		if _slots_mode == "save":
			b.tooltip_text = "Save here" + ("" if info.is_empty() else " (replaces this save)")
			b.pressed.connect(func():
				if SaveGame.save(hud.main, slot):
					UI.close_screen()
					UI.toast("Saved to slot %d" % slot, "", "Tucked in safe and sound.")
				else:
					UI.toast("Couldn't save", "Something went wrong writing slot %d." % slot))
		else:
			b.pressed.connect(func(): _load_slot(slot))
		col.add_child(b)
	var back := Style.button("Back", 16)
	back.pressed.connect(escape)
	col.add_child(back)


func _load_slot(slot: int) -> void:
	if slot < 1:
		return
	UI.open_screen("loading")
	# Let the loading card draw first, then load and close it.
	await get_tree().create_timer(0.35, true, false, true).timeout
	var ok := SaveGame.load_into(hud.main, slot)
	await get_tree().create_timer(0.35, true, false, true).timeout
	UI.close_screen()
	if ok:
		UI.toast("Welcome back!", "Loaded slot %d." % slot)
	else:
		UI.toast("Couldn't load", "Slot %d couldn't be read." % slot)


func _build_loading() -> void:
	var col := _card(360)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var coin := W.Coin.new(40)
	coin.pivot_offset = Vector2(20, 20)
	row.add_child(coin)
	if not Settings.reduce_motion:
		var tw := Style.ui_tween(coin).set_loops()
		tw.tween_property(coin, "rotation", TAU, 1.0).from(0.0)
	row.add_child(Style.label("Loading the Academy…", 22, 600))
	col.add_child(_center(Style.hand_label("Fluffing the pillows. Waking the nightlights.", 19, Style.CRAYON_PURPLE)))


# --- A letter arrives ---------------------------------------------------------------

func _build_letter() -> void:
	if _letter == null:
		_letter = hud.main.letters[0]
	var l := _letter
	var head := VBoxContainer.new()
	head.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 30)
	head.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_holder.add_child(head)
	head.add_child(_center(Style.label("DAY %d · A LETTER FOR THE ACADEMY" % l.arrives_day, 15, 500, Color(Style.PAPER, 0.85))))
	head.add_child(_center(Style.label("Someone needs a friend", 32, 600, Style.PAPER)))

	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	stage.custom_minimum_size = Vector2(1080, 640)
	stage.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stage.grow_vertical = Control.GROW_DIRECTION_BOTH
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(stage)

	# The Department form (behind).
	var form := PanelContainer.new()
	var fsb := Style.flat_box(Style.FORM, Style.FORM_LINE, 2, 6, 28)
	fsb.shadow_color = Color(0, 0, 0, 0.4)
	fsb.shadow_size = 12
	form.add_theme_stylebox_override("panel", fsb)
	form.position = Vector2(540, 20)
	form.custom_minimum_size = Vector2(540, 560)
	form.rotation_degrees = 2.0
	stage.add_child(form)
	var fcol := VBoxContainer.new()
	fcol.add_theme_constant_override("separation", 6)
	form.add_child(fcol)
	fcol.add_child(Style.label("DEPARTMENT OF IMAGINARY AFFAIRS", 12, 600, Style.INK_SOFT))
	fcol.add_child(Style.label("Request for a Friend", 24, 600))
	fcol.add_child(Style.label("Form 7-W · Request no. 001", 13, 400, Style.INK_SOFT))
	for f in [["Child", "%s, age %d" % [l.child, l.age]], ["Neighborhood", l.neighborhood],
			["Skill requested", "%s %d" % [l.skill_name(), l.level]], ["Child seems", l.seems],
			["Best friend would be", l.best_trait], ["Dream Test", "Dream Night, day %d" % l.dream_day],
			["Payment on success", "%d Giggles (great) · %d (okay)" % [l.pays_great, l.pays_okay]]]:
		var row := HBoxContainer.new()
		var k := Style.label(String(f[0]).to_upper(), 12, 500, Style.INK_SOFT)
		k.custom_minimum_size.x = 180
		row.add_child(k)
		row.add_child(Style.label(f[1], 15, 600 if f[0] in ["Skill requested", "Best friend would be"] else 400))
		fcol.add_child(row)
		var rule := ColorRect.new()
		rule.color = Style.FORM_LINE
		rule.custom_minimum_size = Vector2(0, 1.5)
		fcol.add_child(rule)
	var fine := Style.label("All requests must be stamped twice. Requests stamped once will be stamped again.", 12, 400, Style.INK_SOFT)
	fine.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fcol.add_child(fine)
	var stamps := Style.overlay()
	form.add_child(stamps)
	var s1 := W.Stamp.new("RECEIVED", Style.HEART, 32, -12)
	s1.position = Vector2(250, 430)
	stamps.add_child(s1)
	var s2 := W.Stamp.new("RECEIVED", Style.HEART, 20, -5)
	s2.position = Vector2(290, 490)
	s2.modulate.a = 0.55
	stamps.add_child(s2)

	# The child's letter (front).
	var paper := W.Notebook.new(35, 76, 46)
	paper.position = Vector2(0, 30)
	paper.custom_minimum_size = Vector2(500, 540)
	paper.rotation_degrees = -2.5
	stage.add_child(paper)
	var pcol := VBoxContainer.new()
	pcol.add_theme_constant_override("separation", 0)
	paper.add_child(pcol)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 30
	pcol.add_child(spacer)
	for text in ["Dear Academy,", "", l.body, "", l.ps]:
		var line := Style.hand_label(text if text != "" else " ", 27, Style.CRAYON_BLUE)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = 400
		line.add_theme_constant_override("line_spacing", 0)
		pcol.add_child(line)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 40)
	buttons.grow_horizontal = Control.GROW_DIRECTION_BOTH
	buttons.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_holder.add_child(buttons)
	var accept := Style.button("Accept %s's request" % l.child, 20, true)
	accept.custom_minimum_size = Vector2(0, 52)
	accept.pressed.connect(func():
		GameState.accept_letter(l)
		UI.close_screen()
		UI.toast("%s's request is pinned" % l.child, "Open Requests (R) to see who could help.", "His notes are on the right. Let's start with the castle.")
		UI.open_drawer("build"))
	buttons.add_child(accept)
	var later := Style.button("Read later", 17)
	later.custom_minimum_size = Vector2(0, 52)
	later.pressed.connect(UI.close_screen)
	buttons.add_child(later)
	var note := Style.label("The clock is paused · Esc to read later", 13, 400, Color(Style.PAPER, 0.8))
	note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	note.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	note.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_holder.add_child(note)
