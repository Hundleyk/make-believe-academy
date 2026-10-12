extends PanelContainer
## The Build menu (mockup 07, "Building in the Cardboard Castle"): a paper sheet above the
## tab bar with one tab per room plus "Anywhere", like Two Point's room catalogs and
## Let's School's furniture tabs:
##   - A room tab lists the items made for that room, then classroom items (Fort and Castle),
##     with a "This room needs" checklist and the room's whimsy score on top.
##   - "Anywhere" lists items that go in any room, grouped by type.
## Big item cards show a thumbnail, price, size, and what it does. Picking a room tab glides
## the camera to that room. Keys 1-9 pick from the open tab.

const Style := preload("res://scripts/ui/ui_style.gd")
const W := preload("res://scripts/ui/widgets.gd")

const ANYWHERE := "any"
const START_TAB := "castle"
## Order of the type groups on the Anywhere tab.
const TYPE_ORDER := ["Structure", "Light", "Comfort", "Fun", "Decor", "Regulation"]
const CARD_SIZE := Vector2(176, 226)
const MENU_WIDTH := 1000.0
const NEED_LABELS := {"calm": "Calm", "fun": "Fun", "rest": "Rest"}

var hud: CanvasLayer
var build_mode: Node3D
var main: Node3D
var students: Node3D
var current_tab := ""
var sell_button: Button

var _tabs := {}          # tab id -> Button
var _cards := {}         # ItemData -> Button (only the open tab's)
var _body: VBoxContainer
var _room_title: Label
var _needs_box: HFlowContainer
var _info_label: Label
var _whimsy_label: Label
var _card_row: HBoxContainer
var _footer: Label


func setup(the_hud: CanvasLayer, mode: Node3D) -> void:
	hud = the_hud
	build_mode = mode
	main = mode.main
	students = mode.students
	var sb := Style.paper_box(0, 6)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 18
	sb.content_margin_bottom = 14
	add_theme_stylebox_override("panel", sb)
	visible = false
	custom_minimum_size.x = MENU_WIDTH
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 0)
	offset_bottom = -112
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	var title_col := VBoxContainer.new()
	title_col.add_theme_constant_override("separation", -4)
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_col)
	title_col.add_child(Style.caps("Building in", 13))
	_room_title = Style.label("", 30, 700)
	title_col.add_child(_room_title)
	for room in main.ROOMS:
		_add_tab(top, room.id, room.name)
	_add_tab(top, ANYWHERE, "Anywhere")
	var sep := VSeparator.new()
	sep.add_theme_constant_override("separation", 10)
	top.add_child(sep)
	sell_button = Style.button("Sell", 15, false, "sell")
	sell_button.toggle_mode = true
	sell_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sell_button.tooltip_text = "Click placed items to sell them for half price.\nRight-click or Esc to stop. (Hover an item and press X works too.)"
	sell_button.toggled.connect(func(on: bool): build_mode.set_sell_mode(on))
	build_mode.sell_mode_changed.connect(func(on: bool): sell_button.set_pressed_no_signal(on))
	top.add_child(sell_button)
	var close := Style.button("Close", 15, false, "close")
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.tooltip_text = "Close the Build menu  (B)"
	close.pressed.connect(UI.close_drawer)
	top.add_child(close)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	col.add_child(_body)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(MENU_WIDTH - 52, CARD_SIZE.y + 22)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_card_row = HBoxContainer.new()
	_card_row.add_theme_constant_override("separation", 14)
	scroll.add_child(_card_row)

	_footer = Style.label("", 15, 500, Style.INK_SOFT)
	col.add_child(_footer)
	add_child(Style.tape(MENU_WIDTH / 2.0 - 60, -2, Style.WASHI_BLUE, 120))

	build_mode.holding_changed.connect(func(_d): _refresh_cards())
	build_mode.layout_changed.connect(_refresh_room_info)
	GameState.giggles_changed.connect(func(_g): _refresh_cards())
	open_tab(START_TAB, false)
	set_hint(build_mode._hint)


func _add_tab(parent: Control, id: String, label: String) -> void:
	var b := Style.tab_button(label, 15)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(open_tab.bind(id))
	parent.add_child(b)
	_tabs[id] = b


## The footer line: build mode's hint, or the controls when nothing's going on.
func set_hint(t: String) -> void:
	if _footer == null:
		return
	if t == "" or t.begins_with("Pick an item"):
		_footer.text = "Click a card to pick it up   ·   Click to place   ·   R to rotate   ·   Right-click to cancel"
	else:
		_footer.text = t.replace("\n", "   ·   ")


## Switch tabs. Room tabs glide the camera to that room.
func open_tab(id: String, move_camera := true) -> void:
	current_tab = id
	for t in _tabs:
		_tabs[t].set_pressed_no_signal(t == id)
	for c in _body.get_children():
		c.queue_free()
	for c in _card_row.get_children():
		c.queue_free()
	_cards.clear()
	_needs_box = null
	var order: Array[ItemData] = []

	if id == ANYWHERE:
		_room_title.text = "Anywhere in the Academy"
		var groups := {}
		for d in build_mode.catalog:
			if _goes_anywhere(d):
				var t: String = d.type if TYPE_ORDER.has(d.type) else "Decor"
				if not groups.has(t):
					groups[t] = []
				groups[t].append(d)
		var line := Style.hand_label("Walls, lights, comfort, and toys go in any room.", 20, Style.CRAYON_PURPLE)
		_body.add_child(line)
		for t in TYPE_ORDER:
			if groups.has(t):
				_add_cards(_plural(t), groups[t], order)
	else:
		var room: Dictionary = main.room_by_id(id)
		_room_title.text = room.name if room.id == "dorm" else "The " + room.name
		_add_room_info(room)
		var own: Array = []
		var classroom: Array = []
		for d in build_mode.catalog:
			if d.allowed_rooms.has(id):
				own.append(d)
			elif d.allowed_rooms.has("classroom") and id in ["fort", "castle"]:
				classroom.append(d)
		_add_cards("Made for this room", own, order)
		_add_cards("Classroom items", classroom, order)
		if move_camera and main.camera_rig != null:
			main.camera_rig.focus_on(main.room_center(room))

	build_mode.hotbar = order
	_refresh_cards()
	_refresh_room_info()


func _goes_anywhere(d: ItemData) -> bool:
	return d.allowed_rooms.is_empty() or d.allowed_rooms.has("any")


func _plural(t: String) -> String:
	match t:
		"Light":
			return "Lights"
		"Structure":
			return "Walls"
		_:
			return t


## A group of cards in the scrolling row, with a small caps label on a divider card.
func _add_cards(title: String, items: Array, order: Array[ItemData]) -> void:
	if items.is_empty():
		return
	var divider := VBoxContainer.new()
	divider.alignment = BoxContainer.ALIGNMENT_CENTER
	divider.custom_minimum_size = Vector2(28, CARD_SIZE.y)
	var l := Style.caps(title, 12)
	l.rotation_degrees = -90
	l.position = Vector2(4, CARD_SIZE.y - 10)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(24, CARD_SIZE.y)
	holder.add_child(l)
	_card_row.add_child(holder)
	for d in items:
		order.append(d)
		_card_row.add_child(_card(d))


func _card(d: ItemData) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = CARD_SIZE
	b.tooltip_text = _tooltip(d)
	b.add_theme_stylebox_override("normal", Style.card_box(false, false, 10))
	b.add_theme_stylebox_override("hover", Style.card_box(false, false, 10))
	b.get_theme_stylebox("hover").bg_color = Color("FFFDF5")
	b.add_theme_stylebox_override("pressed", Style.card_box(true, false, 10))
	b.add_theme_stylebox_override("hover_pressed", Style.card_box(true, false, 10))
	b.add_theme_stylebox_override("disabled", Style.card_box(false, false, 10))
	b.pressed.connect(_on_card_pressed.bind(d))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	col.offset_bottom = -16
	b.add_child(col)
	var thumb := PanelContainer.new()
	thumb.add_theme_stylebox_override("panel", Style.flat_box(d.gray_color.lightened(0.55), d.gray_color.lightened(0.2), 3, 10, 6))
	thumb.custom_minimum_size = Vector2(0, 92)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(thumb)
	var icon := W.ItemIcon.new(d)
	icon.custom_minimum_size = Vector2(76, 76)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	thumb.add_child(icon)
	var key := Style.label("", 13, 700, Style.INK_SOFT)
	key.position = Vector2(8, 4)
	var ko := Style.overlay()
	ko.add_child(key)
	thumb.add_child(ko)
	var name_label := Style.label(d.display_name, 16, 600)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	var coin := W.Coin.new(18, false)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	var price_label := Style.label("", 16, 700)
	price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(price_label)
	row.add_child(Style.chip("%dx%d" % [d.footprint.x, d.footprint.y], Style.PAPER_DARK, Style.PAPER_EDGE, 12))
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 4)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(chips)
	for e in effect_chips(d).slice(0, 2):
		chips.add_child(Style.chip(e, Style.MINT, Style.OK_DEEP, 12, 600, Style.OK_DEEP.darkened(0.3)))
	b.set_meta("name_label", name_label)
	b.set_meta("price_label", price_label)
	b.set_meta("key_label", key)
	_cards[d] = b
	return b


## Short effect chips for a card: "+2 Calm", "+1 Fun", or what kind of thing it is.
static func effect_chips(d: ItemData) -> Array:
	var out := []
	for need in d.need_mods:
		var v: int = int(d.need_mods[need])
		if v != 0:
			out.append("%s%d %s" % ["+" if v > 0 else "", v, NEED_LABELS.get(need, String(need).capitalize())])
	if d.unlocks_course != "":
		out.append("Teaches " + d.unlocks_course.replace("_", " ").capitalize())
	if out.is_empty() and not d.focus_mods.is_empty():
		out.append("Helps focus")
	if out.is_empty() and d.whimsy != 0:
		out.append("%s%d Whimsy" % ["+" if d.whimsy > 0 else "", d.whimsy])
	if out.is_empty():
		out.append(d.type if d.type != "" else "Decor")
	return out


func _tooltip(d: ItemData) -> String:
	var lines := [d.display_name, d.effect_text]
	lines.append("Size %d x %d  ·  goes in %s" % [d.footprint.x, d.footprint.y, d.room_rule_text()])
	if d.radius > 0:
		lines.append("Reaches %d tiles" % d.radius)
	if d.whimsy != 0:
		lines.append("Whimsy %s%d" % ["+" if d.whimsy > 0 else "", d.whimsy])
	return "\n".join(lines)


func _on_card_pressed(d: ItemData) -> void:
	if build_mode.holding == d:
		build_mode.stop_holding()
	else:
		build_mode.start_holding(d)


func _refresh_cards() -> void:
	var gig: int = GameState.giggles
	for i in build_mode.hotbar.size():
		var d: ItemData = build_mode.hotbar[i]
		var b: Button = _cards.get(d)
		if b == null or not is_instance_valid(b):
			continue
		var locked := d.research_ideas > 0 and not GameState.researched.has(d.id)
		var price_label: Label = b.get_meta("price_label")
		var key_label: Label = b.get_meta("key_label")
		key_label.text = str(i + 1) if i < 9 else ""
		if locked:
			price_label.text = "%d Ideas" % d.research_ideas
			b.tooltip_text = "Locked: research it for %d Ideas (the research board arrives in M3).\n\n%s" % [d.research_ideas, _tooltip(d)]
			b.disabled = true
		else:
			price_label.text = str(d.cost)
			b.disabled = gig < d.cost
		b.modulate.a = 0.55 if b.disabled else 1.0
		b.set_pressed_no_signal(build_mode.holding == d)


# --- Room info: blurb, whimsy, and the "This room needs" checklist -----------------

func _add_room_info(room: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_body.add_child(row)
	_info_label = Style.hand_label(room.blurb, 20, Style.CRAYON_PURPLE)
	_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_info_label)
	var whimsy := PanelContainer.new()
	var wsb := Style.flat_box(Style.LAVENDER, Color(0, 0, 0, 0), 0, 10, 0)
	wsb.content_margin_left = 10
	wsb.content_margin_right = 10
	wsb.content_margin_top = 3
	wsb.content_margin_bottom = 3
	whimsy.add_theme_stylebox_override("panel", wsb)
	whimsy.tooltip_text = "Whimsy adds up every item's whimsy in the room.\nBelow 4: bored.  4 to 9: Just Right.  Above 9: too wild to focus."
	whimsy.mouse_filter = Control.MOUSE_FILTER_PASS
	_whimsy_label = Style.label("", 14, 600)
	whimsy.add_child(_whimsy_label)
	row.add_child(whimsy)

	var needs_row := HBoxContainer.new()
	needs_row.add_theme_constant_override("separation", 10)
	_body.add_child(needs_row)
	needs_row.add_child(Style.caps("This room needs", 12))
	_needs_box = HFlowContainer.new()
	_needs_box.add_theme_constant_override("h_separation", 16)
	_needs_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	needs_row.add_child(_needs_box)


func _refresh_room_info() -> void:
	if current_tab == ANYWHERE or _needs_box == null or not is_instance_valid(_needs_box):
		return
	var room: Dictionary = main.room_by_id(current_tab)
	var w: int = build_mode.room_whimsy(current_tab)
	_whimsy_label.text = "Whimsy %d  ·  %s" % [w, whimsy_word(w)]
	for c in _needs_box.get_children():
		c.queue_free()
	var have := {}
	for p in build_mode.items_in_room(current_tab):
		have[p.data.id] = have.get(p.data.id, 0) + 1
	for need in room.needs:
		var want: int = need.count if need.count > 0 else students.students.size()
		var got: int = have.get(need.item, 0)
		var data := _item(need.item)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		_needs_box.add_child(row)
		# Check or cross drawn as a shape, so it never relies on color alone.
		row.add_child(W.Badge.new(got >= want, 18))
		var link := LinkButton.new()
		link.text = "%s  %d/%d" % [data.display_name if data else String(need.item), mini(got, want), want]
		link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
		link.focus_mode = Control.FOCUS_NONE
		link.add_theme_color_override("font_color", Style.INK)
		link.add_theme_color_override("font_hover_color", Style.INK)
		link.add_theme_font_override("font", Style.font(500))
		link.add_theme_font_size_override("font_size", 15)
		link.tooltip_text = "For %s. Click to pick one up." % need.for
		if data != null:
			link.pressed.connect(func(): build_mode.start_holding(data))
		row.add_child(link)


static func whimsy_word(w: int) -> String:
	if w < 4:
		return "a bit bored"
	if w > 9:
		return "too wild to focus"
	return "Just Right"


func _item(id: StringName) -> ItemData:
	for d in build_mode.catalog:
		if d.id == id:
			return d
	return null
