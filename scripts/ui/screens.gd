extends Control
## Full-screen screens over the game (design system mockups 01-06 and 09): the main menu,
## pause, settings, Load/Save School, the quit note, a loading card, credits, and the
## arrival of a child's letter. While one is open the clock is paused and the world
## ignores clicks and keys.

const Style := preload("res://scripts/ui/ui_style.gd")
const W := preload("res://scripts/ui/widgets.gd")
const SaveGame := preload("res://scripts/save_game.gd")

const SETTINGS_TABS := [["audio", "Audio"], ["video", "Video"], ["gameplay", "Gameplay"], ["controls", "Controls"]]
const TIPS := [
	"Sock serpents get grumpy if the laundry pile is too far away.",
	"Fresh skill points fade. Practice keeps them; a good night's rest makes them solid.",
	"Two items that belong together glow when you hold one near the other. That's a combo!",
	"A student afraid of the dark stays calm in a nightlight's glow.",
	"Hover a need in the Build menu to see what you can place to raise it.",
	"Happy students giggle. Giggles pay for everything.",
]
const KEYS := [
	["W A S D / arrows", "Move the view"], ["Q / E", "Turn the view"], ["Mouse wheel", "Zoom"],
	["B", "Build menu"], ["P", "Students"], ["R", "Requests (rotates a held item)"],
	["1 - 9", "Pick an item from the open tab"], ["Right-click", "Cancel, stop selling, back"],
	["X", "Sell the hovered item"], ["Space", "Pause or resume"], ["[  ]", "Slower, faster"],
	["Esc", "Back, then the pause menu"],
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
	match id:
		"title":
			_dim.color = Color(Style.NIGHT, 0.12)
		"settings", "slots":
			_dim.color = Style.DESK
		"loading":
			_dim.color = Style.NAVY
		_:
			_dim.color = Color(Style.NIGHT, 0.45)
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

## A centered paper sheet; returns the column to fill.
func _card(width := 420.0, seed_value := 3) -> VBoxContainer:
	var p := W.Paper.new(Style.PAPER, 30, 3.0, seed_value)
	p.custom_minimum_size = Vector2(width, 0)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	_holder.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	p.add_child(col)
	return col


## A big menu button. `chosen` gives it the cream "selected" look (the first choice).
func _menu_button(col: Control, text: String, icon: String, action: Callable, chosen := false, enabled := true, tip := "") -> Button:
	var b := Style.button(text, 24, not chosen, icon)
	if chosen:
		for st in ["normal", "hover"]:
			var sb := Style.lip_box(Style.PAPER if st == "normal" else Color("FFFDF5"), false, false, true)
			sb.content_margin_left = 16 + 30 + 12
			b.add_theme_stylebox_override(st, sb)
	b.custom_minimum_size = Vector2(0, 64)
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
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## A form header: small caps form number over a big title.
func _form_head(col: Control, form: String, title: String) -> VBoxContainer:
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", -2)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(Style.caps(form, 15))
	head.add_child(Style.label(title, 46, 700))
	col.add_child(head)
	return head


# --- Main menu (01) -----------------------------------------------------------------

func _build_title() -> void:
	var p := W.Paper.new(Style.PAPER, 0, 3.5, 5)
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 34
	sb.content_margin_bottom = 26
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(540, 0)
	p.anchor_top = 0.0
	p.anchor_bottom = 1.0
	p.offset_left = 80
	p.offset_top = 70
	p.offset_bottom = -40
	p.rotation_degrees = 0.5
	_holder.add_child(p)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	p.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 22)
	col.add_child(head)
	head.add_child(W.Seal.new(132))
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -8)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(names)
	names.add_child(Style.label("Make-Believe\nAcademy", 46, 700))
	names.add_child(Style.hand_label("a school for imaginary friends", 26, Style.INK))
	col.add_child(_spacer(4))
	var newest := SaveGame.newest_slot()
	var info := SaveGame.read_info(newest) if newest != -1 else {}
	var cont := _menu_button(col, "Continue", "play", func(): _load_slot(newest), newest != -1, newest != -1,
		"No saves yet." if newest == -1 else "Load your newest save (slot %d)." % newest)
	if newest != -1:
		var when := Style.hand_label("Term 1 · Day %d" % int(info.get("day", 1)), 24, Style.INK)
		when.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 22)
		when.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		when.offset_top -= 4
		when.offset_bottom -= 4
		when.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cont.add_child(when)
	_menu_button(col, "New School", "plus", _new_game, newest == -1)
	_menu_button(col, "Load School", "folder", func(): _open_slots("load", "title"))
	_menu_button(col, "Settings", "gear", func(): _open_settings("title"))
	_menu_button(col, "Credits", "credits", func(): UI.open_screen("credits"))
	_menu_button(col, "Quit", "door", func(): _open_quit("title"))
	col.add_child(_spacer(0, true))
	col.add_child(Style.caps("Dept. of Imaginary Affairs · honeymilk labs · demo", 14))


func _new_game() -> void:
	UI.close_screen()
	hud.main.start_new_game()


func _build_credits() -> void:
	var col := _card(560, 9)
	col.add_child(_center(Style.caps("Form 0-C: Who made this", 14)))
	col.add_child(_center(Style.label("Credits", 44, 700)))
	for line in [["A game by", "Kyra Hundley · honeymilk labs"], ["Made with", "Godot 4"],
			["Fonts", "Fredoka, Patrick Hand, Atkinson Hyperlegible (SIL Open Font License)"],
			["Thanks to", "every kid who ever had a friend nobody else could see"]]:
		col.add_child(_center(Style.caps(line[0], 13)))
		var v := _center(Style.hand_label(line[1], 24, Style.INK))
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.custom_minimum_size.x = 480
		col.add_child(v)
	var back := Style.button("Back", 20, false, "back")
	back.custom_minimum_size.y = 54
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(escape)
	col.add_child(back)


# --- Pause (02) ---------------------------------------------------------------------

func _build_pause() -> void:
	var col := _card(440, 4)
	col.add_child(_center(Style.label("Paused", 46, 700)))
	var sub := _center(Style.hand_label("everyone freeze!", 24, Style.INK_SOFT))
	col.add_child(sub)
	_menu_button(col, "Resume", "play", UI.close_screen, true)
	_menu_button(col, "Save School", "save", func(): _open_slots("save", "pause"))
	_menu_button(col, "Load School", "folder", func(): _open_slots("load", "pause"))
	_menu_button(col, "Settings", "gear", func(): _open_settings("pause"))
	_menu_button(col, "Main Menu", "home", func(): hud.main.quit_to_title())
	col.add_child(_center(Style.label("Esc to resume", 14, 500, Style.INK_SOFT)))
	var paper: Control = col.get_parent()
	var o := Style.overlay()
	var stamp := W.Stamp.new("RECESS", Style.HEART, 26, 14)
	stamp.position = Vector2(300, 4)
	o.add_child(stamp)
	paper.add_child(o)
	paper.add_child(Style.tape(-26, -32, Style.HONEY, 90))


# --- Settings (03) ------------------------------------------------------------------

func _open_settings(back_to: String) -> void:
	settings_back = back_to
	_pending = Settings.snapshot()
	UI.open_screen("settings")


func _build_settings() -> void:
	if _pending.is_empty():
		_pending = Settings.snapshot()
	var col := _card(1100, 8)
	var paper: Control = col.get_parent()
	paper.add_child(Style.pin(Vector2(1040, -22)))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	_form_head(top, "Form 3-C: Comfort preferences", "Settings")
	for t in SETTINGS_TABS:
		var b := Style.tab_button(t[1], 20, _tab_icon(t[0]))
		b.custom_minimum_size.y = 56
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.set_pressed_no_signal(settings_tab == t[0])
		b.pressed.connect(func():
			settings_tab = t[0]
			UI.open_screen("settings"))
		top.add_child(b)
	var rule := ColorRect.new()
	rule.color = Style.PAPER_EDGE
	rule.custom_minimum_size.y = 3
	col.add_child(rule)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.custom_minimum_size.y = 330
	col.add_child(body)
	match settings_tab:
		"audio":
			_slider(body, "Master Volume", "master_volume", 0, 100, 5, "%d")
			_slider(body, "Music", "music_volume", 0, 100, 5, "%d")
			_slider(body, "Sound Effects", "sfx_volume", 0, 100, 5, "%d")
			body.add_child(Style.hand_label("Music and sound effects arrive with the audio pass (M4). The volumes are saved for then.", 20, Style.CRAYON_PURPLE))
		"video":
			_toggle(body, "Fullscreen", "", "fullscreen")
			var row := _row(body, "UI Size", "Make menus and text bigger.")
			for v in Settings.UI_SCALES:
				var b := Style.tab_button("%d%%" % roundi(v * 100.0), 17)
				b.set_pressed_no_signal(is_equal_approx(v, float(_pending.ui_scale)))
				b.pressed.connect(func():
					_pending.ui_scale = v
					UI.open_screen("settings"))
				row.add_child(b)
			_toggle(body, "Reduce Motion", "No wobbles, hops, bobbing, or fades.", "reduce_motion")
		"gameplay":
			_toggle(body, "Readable Font", "Switch every font to Atkinson Hyperlegible, made for easy reading.", "readable_font")
			_slider(body, "Camera Speed", "camera_speed", 0.5, 2.0, 0.25, "%.2f×")
		"controls":
			var grid := GridContainer.new()
			grid.columns = 4
			grid.add_theme_constant_override("h_separation", 26)
			grid.add_theme_constant_override("v_separation", 8)
			body.add_child(grid)
			for k in KEYS:
				var key := Style.chip(k[0], Style.TAB_TAN, Style.LIP, 15, 700)
				key.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				grid.add_child(key)
				grid.add_child(Style.label(k[1], 17, 500))
			body.add_child(Style.hand_label("Rebinding keys arrives with the final controls.", 20, Style.CRAYON_PURPLE))
	var changed := _pending != Settings.snapshot()
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	col.add_child(buttons)
	var back := Style.button("Back", 20, false, "back")
	back.custom_minimum_size = Vector2(0, 56)
	back.tooltip_text = "Leave without applying" if changed else ""
	back.pressed.connect(func():
		_pending = {}
		escape())
	buttons.add_child(back)
	var note := Style.hand_label("not applied yet..." if changed else "", 20, Style.CRAYON_PURPLE)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons.add_child(note)
	var reset := Style.button("Reset to Default", 20, false, "reset")
	reset.custom_minimum_size = Vector2(0, 56)
	reset.pressed.connect(func():
		_pending = Settings.DEFAULTS.duplicate()
		UI.open_screen("settings"))
	buttons.add_child(reset)
	var apply := Style.button("Apply", 20, true, "check")
	apply.custom_minimum_size = Vector2(0, 56)
	apply.disabled = not changed
	apply.pressed.connect(func():
		var values := _pending.duplicate()
		Settings.set_values(values)
		_pending = Settings.snapshot()
		UI.open_screen("settings"))
	buttons.add_child(apply)


func _tab_icon(id: String) -> String:
	match id:
		"audio":
			return "star"
		"video":
			return "eye"
		"gameplay":
			return "play"
		_:
			return "gear"


func _row(col: Control, title: String, help: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var text := VBoxContainer.new()
	text.custom_minimum_size.x = 380
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	text.add_child(Style.label(title, 21, 600))
	if help != "":
		text.add_child(Style.label(help, 16, 400, Style.INK_SOFT))
	return row


func _slider(col: Control, title: String, key: String, lo: float, hi: float, step: float, fmt: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	col.add_child(row)
	var l := Style.label(title, 21, 600)
	l.custom_minimum_size.x = 260
	row.add_child(l)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = float(_pending[key])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.y = 32
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)
	var v := Style.label(fmt % slider.value, 21, 700)
	v.custom_minimum_size.x = 70
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	slider.value_changed.connect(func(x: float):
		_pending[key] = int(x) if typeof(Settings.DEFAULTS[key]) == TYPE_INT else x
		v.text = fmt % x)
	slider.drag_ended.connect(func(_c: bool): UI.open_screen("settings"))


func _toggle(col: Control, title: String, help: String, key: String) -> void:
	var row := _row(col, title, help)
	var on: bool = _pending[key]
	var state := Style.label("On" if on else "Off", 18, 700)
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(state)
	var c := CheckButton.new()
	c.focus_mode = Control.FOCUS_NONE
	c.button_pressed = on
	c.tooltip_text = title
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.toggled.connect(func(x: bool):
		_pending[key] = x
		UI.open_screen("settings"))
	row.add_child(c)


# --- Load and Save School (04) ------------------------------------------------------

func _open_slots(mode: String, back_to: String) -> void:
	slots_mode = mode
	slots_back = back_to
	_selected_slot = maxi(1, SaveGame.newest_slot()) if mode == "load" else 1
	if mode == "save":
		for slot in range(1, SaveGame.SLOTS + 1):
			if not SaveGame.exists(slot):
				_selected_slot = slot
				break
	_delete_armed = false
	UI.open_screen("slots")


func _build_slots() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 110
	col.offset_right = -110
	col.offset_top = 80
	col.offset_bottom = -70
	_holder.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	var saving := slots_mode == "save"
	_form_head(top, "Form 12-S: Saved schools", "Save School" if saving else "Load School")
	var back := Style.button("Back", 20, false, "back")
	back.custom_minimum_size.y = 56
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(escape)
	top.add_child(back)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	col.add_child(row)
	var newest := SaveGame.newest_slot()
	for slot in range(1, SaveGame.SLOTS + 1):
		row.add_child(_slot_card(slot, slot == newest))
	col.add_child(_spacer(0, true))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	col.add_child(foot)
	var info := SaveGame.read_info(_selected_slot)
	var desc := Style.hand_label("", 26, Style.INK)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if info.is_empty():
		desc.text = "Slot %d — an empty cubby" % _selected_slot
	else:
		desc.text = "%s — Term 1 · Day %d · saved %s" % [info.get("school", "Make-Believe Academy"), int(info.get("day", 1)), SaveGame.when(int(info.get("saved_at", 0)))]
	foot.add_child(desc)
	var del := Style.button("Really delete?" if _delete_armed else "Delete", 20, false, "trash")
	del.custom_minimum_size.y = 58
	del.disabled = info.is_empty()
	if _delete_armed:
		del.add_theme_color_override("font_color", Style.HEART.darkened(0.2))
	del.pressed.connect(func():
		if _delete_armed:
			SaveGame.delete(_selected_slot)
			_delete_armed = false
			UI.toast("Slot %d emptied" % _selected_slot)
		else:
			_delete_armed = true
		UI.open_screen("slots"))
	foot.add_child(del)
	var go := Style.button("Save Here" if saving else "Load School", 24, true, "save" if saving else "folder")
	go.custom_minimum_size = Vector2(260, 62)
	go.disabled = not saving and info.is_empty()
	if saving and not info.is_empty():
		go.tooltip_text = "Replaces the save in slot %d." % _selected_slot
	go.pressed.connect(func():
		if saving:
			_save_to(_selected_slot)
		else:
			_load_slot(_selected_slot))
	foot.add_child(go)


func _slot_card(slot: int, newest: bool) -> Control:
	var info := SaveGame.read_info(slot)
	var chosen := slot == _selected_slot
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(330, 340)
	b.pressed.connect(func():
		_selected_slot = slot
		_delete_armed = false
		UI.open_screen("slots"))
	b.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.double_click and not info.is_empty() and slots_mode == "load":
			_load_slot(slot))
	if info.is_empty():
		var empty := Style.empty_box()
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st, empty)
		var d := W.Dashed.new(Style.INK if chosen else Style.CARDBOARD)
		d.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_child(d)
		var l := Style.label("Empty Cubby", 20, 600, Style.INK_SOFT)
		l.set_anchors_preset(Control.PRESET_CENTER)
		l.grow_horizontal = Control.GROW_DIRECTION_BOTH
		l.grow_vertical = Control.GROW_DIRECTION_BOTH
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(l)
		return b
	b.add_theme_stylebox_override("normal", Style.card_box(chosen, false, 0))
	b.add_theme_stylebox_override("hover", Style.card_box(chosen, false, 0))
	b.add_theme_stylebox_override("pressed", Style.card_box(true, false, 0))
	b.add_theme_stylebox_override("hover_pressed", Style.card_box(true, false, 0))
	if chosen:
		b.rotation_degrees = -1.5
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	col.offset_bottom = -20
	b.add_child(col)
	var pic := Control.new()
	pic.custom_minimum_size = Vector2(0, 170)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.clip_contents = true
	col.add_child(pic)
	var tex := SaveGame.thumbnail(slot)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.add_child(tr)
	else:
		var st := W.Stripes.new(Style.SKY)
		st.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.add_child(st)
		var seal := W.Seal.new(90)
		seal.set_anchors_preset(Control.PRESET_CENTER)
		seal.offset_left = -45
		seal.offset_top = -45
		seal.offset_right = 45
		seal.offset_bottom = 45
		pic.add_child(seal)
	col.add_child(_spacer(6))
	col.add_child(Style.hand_label(info.get("school", "Make-Believe Academy"), 28, Style.INK))
	col.add_child(Style.label("Term 1 · Day %d · Period %d" % [int(info.get("day", 1)), int(info.get("period", 1))], 17, 700))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	var coin := W.Coin.new(20, false)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	var g := Style.label(hud._comma(int(info.get("giggles", 0))), 18, 700)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(g)
	row.add_child(Style.label(SaveGame.playtime(float(info.get("play_seconds", 0.0))), 17, 500, Style.INK_SOFT))
	var tag := Style.caps("Slot %d" % slot, 12)
	tag.position = Vector2(20, -22)
	var o := Style.overlay()
	o.add_child(tag)
	if newest:
		var stamp := W.Stamp.new("NEWEST", Style.HEART, 18, 8)
		stamp.position = Vector2(200, -16)
		o.add_child(stamp)
	b.add_child(o)
	return b


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
		UI.toast("Saved to slot %d" % slot, "", "Tucked in safe and sound.")
	else:
		UI.toast("Couldn't save", "Something went wrong writing slot %d." % slot)


func _load_slot(slot: int) -> void:
	if slot < 1:
		return
	UI.open_screen("loading")
	# Let the loading card draw first, then load and close it.
	await get_tree().create_timer(0.5, true, false, true).timeout
	var ok := SaveGame.load_into(hud.main, slot)
	await get_tree().create_timer(0.45, true, false, true).timeout
	UI.close_screen()
	if ok:
		UI.toast("Welcome back!", "Loaded slot %d." % slot)
	else:
		UI.toast("Couldn't load", "Slot %d couldn't be read." % slot)


# --- Quit (05) ----------------------------------------------------------------------

func _open_quit(back_to: String) -> void:
	quit_back = back_to
	UI.open_screen("quit")


func _build_quit() -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 26)
	stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stack.grow_vertical = Control.GROW_DIRECTION_BOTH
	_holder.add_child(stack)
	var note := W.Notebook.new(38, 58, 30)
	note.custom_minimum_size = Vector2(640, 0)
	note.rotation_degrees = -1.2
	stack.add_child(note)
	var ncol := VBoxContainer.new()
	ncol.add_theme_constant_override("separation", 0)
	note.add_child(ncol)
	ncol.add_child(_spacer(14))
	for line in ["Dear Headteacher,", "are you leaving already? we will save you a cookie. come back tomorrow!"]:
		var l := Style.hand_label(line, 28, Style.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 560
		ncol.add_child(l)
	var sign := Style.hand_label("— Pip, Drizzle & Bo", 28, Style.INK)
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ncol.add_child(sign)
	note.add_child(Style.pin(Vector2(600, -14), Style.PIN_BLUE, 34))
	var o := Style.overlay()
	var sticky := ColorRect.new()
	sticky.color = Style.HONEY
	sticky.size = Vector2(34, 34)
	sticky.position = Vector2(586, 120)
	sticky.rotation_degrees = 10
	o.add_child(sticky)
	note.add_child(o)

	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", Style.paper_box(22, 6))
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.rotation_degrees = 0.6
	stack.add_child(box)
	var bcol := VBoxContainer.new()
	bcol.add_theme_constant_override("separation", 12)
	box.add_child(bcol)
	bcol.add_child(Style.label(_last_saved_text(), 17, 600))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bcol.add_child(row)
	var stay := Style.button("Stay a Bit", 20, false, "back")
	stay.custom_minimum_size = Vector2(190, 60)
	stay.pressed.connect(escape)
	row.add_child(stay)
	var quit := Style.button("Quit to Desktop", 20, true, "door")
	quit.custom_minimum_size = Vector2(220, 60)
	quit.pressed.connect(func(): get_tree().quit())
	row.add_child(quit)


func _last_saved_text() -> String:
	if quit_back == "title":
		return "See you soon!"
	if GameState.last_saved_at <= 0:
		return "Not saved yet: this school hasn't been saved."
	var mins := int((Time.get_unix_time_from_system() - GameState.last_saved_at) / 60.0)
	if mins < 1:
		return "Last saved just now"
	return "Last saved %d minute%s ago" % [mins, "" if mins == 1 else "s"]


# --- Loading (06) -------------------------------------------------------------------

func _build_loading() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	_holder.add_child(col)
	var seal := W.Seal.new(180)
	seal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(seal)
	col.add_child(_center(Style.label("Fluffing the pillows...", 24, 600, Style.PAPER)))
	var bar := W.LoadBar.new(Vector2(460, 24))
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(bar)
	Style.ui_tween(bar).tween_property(bar, "value", 1.0, 0.9).from(0.1)

	var tip := W.Notebook.new(30, 52, 24)
	tip.custom_minimum_size = Vector2(380, 0)
	tip.rotation_degrees = 1.5
	tip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 70)
	tip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_holder.add_child(tip)
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", 0)
	tip.add_child(tcol)
	tcol.add_child(Style.caps("Teacher's tip", 13))
	var t := Style.hand_label(TIPS[randi() % TIPS.size()], 22, Style.INK)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 320
	tcol.add_child(t)
	tip.add_child(Style.tape(150, -3, Color("BFE3A8"), 64))


# --- A letter arrives (09) ----------------------------------------------------------

func _build_letter() -> void:
	if _letter == null:
		_letter = hud.main.letters[0]
	var l := _letter
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stack.grow_vertical = Control.GROW_DIRECTION_BOTH
	_holder.add_child(stack)
	var banner := PanelContainer.new()
	var bsb := Style.flat_box(Style.NAVY, Color(0, 0, 0, 0), 0, 10, 0)
	bsb.content_margin_left = 18
	bsb.content_margin_right = 18
	bsb.content_margin_top = 6
	bsb.content_margin_bottom = 8
	banner.add_theme_stylebox_override("panel", bsb)
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	banner.rotation_degrees = -1.0
	stack.add_child(banner)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 10)
	banner.add_child(brow)
	brow.add_child(W.Icon.new("letter", 22, Style.HONEY))
	brow.add_child(Style.label("New letter from %s, age %d" % [l.child, l.age], 19, 600, Style.PAPER))

	var paper := W.Notebook.new(40, 64, 36)
	paper.custom_minimum_size = Vector2(700, 0)
	paper.rotation_degrees = -1.5
	stack.add_child(paper)
	var pcol := VBoxContainer.new()
	pcol.add_theme_constant_override("separation", 0)
	paper.add_child(pcol)
	pcol.add_child(_spacer(20))
	for text in ["Dear Academy,", l.body, l.ps]:
		var line := Style.hand_label(text, 30, Style.CRAYON_BLUE)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = 600
		line.add_theme_constant_override("line_spacing", 0)
		pcol.add_child(line)
	var sign := Style.hand_label("— %s" % l.child, 30, Style.CRAYON_BLUE)
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pcol.add_child(sign)
	paper.add_child(Style.pin(Vector2(664, -12)))
	var o := Style.overlay()
	var sticky := ColorRect.new()
	sticky.color = Style.HONEY
	sticky.size = Vector2(38, 38)
	sticky.position = Vector2(640, 150)
	sticky.rotation_degrees = 12
	o.add_child(sticky)
	paper.add_child(o)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(buttons)
	var later := Style.button("Read Later", 20, false, "clock")
	later.custom_minimum_size = Vector2(200, 60)
	later.tooltip_text = "It waits in Requests (R)."
	later.pressed.connect(UI.close_screen)
	buttons.add_child(later)
	var help := Style.button("Find a Helper", 20, true, "students")
	help.custom_minimum_size = Vector2(230, 60)
	help.tooltip_text = "Approve %s's request and see who could help." % l.child
	help.pressed.connect(func():
		GameState.accept_letter(l)
		UI.close_screen()
		UI.open_drawer("requests")
		UI.toast("%s's request is approved" % l.child, "His notes are clipped bottom left.", "Let's start with the castle."))
	buttons.add_child(help)
	var note := Style.label("The clock is paused · Esc to read later", 14, 500, Color(Style.PAPER, 0.85))
	note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	note.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	note.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_holder.add_child(note)
