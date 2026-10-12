extends PanelContainer
## The Build menu (bottom right). One tab per room plus "Anywhere", like Two Point's room
## catalogs and Let's School's furniture tabs:
##   - A room tab lists the items made for that room, then classroom items (Fort and Castle),
##     with a "This room needs" checklist and the room's whimsy score on top.
##   - "Anywhere" lists items that go in any room, grouped by type.
## Picking a room tab glides the camera to that room. Keys 1-9 pick from the open tab.

const Style := preload("res://scripts/ui/ui_style.gd")
const W := preload("res://scripts/ui/widgets.gd")

const ANYWHERE := "any"
const START_TAB := "castle"
## Order of the type groups on the Anywhere tab.
const TYPE_ORDER := ["Structure", "Light", "Comfort", "Fun", "Decor", "Regulation"]
const CARD_SIZE := Vector2(184, 48)   ## Name and price; hover a card for its effect
const MENU_WIDTH := 600.0

var hud: CanvasLayer
var build_mode: Node3D
var main: Node3D
var students: Node3D
var current_tab := ""
var sell_button: Button

var _tabs := {}          # tab id -> Button
var _cards := {}         # ItemData -> Button (only the open tab's)
var _body: VBoxContainer
var _needs_box: VBoxContainer
var _info_label: Label
var _whimsy_label: Label


func setup(the_hud: CanvasLayer, mode: Node3D) -> void:
	hud = the_hud
	build_mode = mode
	main = mode.main
	students = mode.students
	add_theme_stylebox_override("panel", Style.paper_box(16))
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	col.add_child(top)
	var title := Style.label("Build  ", 21, 600)
	top.add_child(title)
	for room in main.ROOMS:
		_add_tab(top, room.id, room.name)
	_add_tab(top, ANYWHERE, "Anywhere")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	sell_button = Button.new()
	sell_button.text = "Sell items"
	sell_button.toggle_mode = true
	sell_button.focus_mode = Control.FOCUS_NONE
	sell_button.tooltip_text = "Click placed items to sell them for half price.\nRight-click or Esc to stop. (Hover an item and press X works too.)"
	sell_button.add_theme_font_size_override("font_size", 14)
	sell_button.toggled.connect(func(on: bool): build_mode.set_sell_mode(on))
	build_mode.sell_mode_changed.connect(func(on: bool): sell_button.set_pressed_no_signal(on))
	top.add_child(sell_button)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.custom_minimum_size.x = MENU_WIDTH
	col.add_child(_body)

	build_mode.holding_changed.connect(func(_d): _refresh_cards())
	build_mode.layout_changed.connect(_refresh_room_info)
	GameState.giggles_changed.connect(func(_g): _refresh_cards())
	open_tab(START_TAB, false)


func _add_tab(parent: Control, id: String, label: String) -> void:
	var b := Button.new()
	b.text = label
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(open_tab.bind(id))
	parent.add_child(b)
	_tabs[id] = b


## Switch tabs. Room tabs glide the camera to that room.
func open_tab(id: String, move_camera := true) -> void:
	current_tab = id
	for t in _tabs:
		_tabs[t].set_pressed_no_signal(t == id)
	for c in _body.get_children():
		c.queue_free()
	_cards.clear()
	_needs_box = null
	var order: Array[ItemData] = []

	if id == ANYWHERE:
		var groups := {}
		for d in build_mode.catalog:
			if _goes_anywhere(d):
				var t: String = d.type if TYPE_ORDER.has(d.type) else "Decor"
				if not groups.has(t):
					groups[t] = []
				groups[t].append(d)
		for t in TYPE_ORDER:
			if groups.has(t):
				_add_section(_plural(t), groups[t], order)
	else:
		var room: Dictionary = main.room_by_id(id)
		_add_room_info(room)
		var own: Array = []
		var classroom: Array = []
		for d in build_mode.catalog:
			if d.allowed_rooms.has(id):
				own.append(d)
			elif d.allowed_rooms.has("classroom") and id in ["fort", "castle"]:
				classroom.append(d)
		_add_section("Made for the " + room.name if id != "dorm" else "Made for Pillow Mountain", own, order)
		if not classroom.is_empty():
			_add_section("Classroom items (Blanket Fort or Cardboard Castle)", classroom, order)
		var tip := Style.label("Lights, comfort, toys, and partition walls are on the Anywhere tab.", 13, 400, Style.INK_SOFT)
		_body.add_child(tip)
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


func _add_section(title: String, items: Array, order: Array[ItemData]) -> void:
	if items.is_empty():
		return
	var head := Style.label(title, 13, 500, Style.INK_SOFT)
	_body.add_child(head)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	_body.add_child(flow)
	for d in items:
		order.append(d)
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = CARD_SIZE
		b.tooltip_text = _tooltip(d)
		b.pressed.connect(_on_card_pressed.bind(d))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		b.add_child(row)
		row.add_child(W.ItemIcon.new(d))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(col)
		var name_label := Style.label("", 13, 600)
		name_label.clip_text = true
		name_label.custom_minimum_size.x = 134
		col.add_child(name_label)
		var price_label := Style.label("", 12)
		col.add_child(price_label)
		b.set_meta("name_label", name_label)
		b.set_meta("price_label", price_label)
		flow.add_child(b)
		_cards[d] = b


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
		var key := "%d  " % (i + 1) if i < 9 else ""
		var locked := d.research_ideas > 0 and not GameState.researched.has(d.id)
		var name_label: Label = b.get_meta("name_label")
		var price_label: Label = b.get_meta("price_label")
		name_label.text = key + d.display_name
		if locked:
			price_label.text = "Research: %d Ideas" % d.research_ideas
			b.disabled = true
		else:
			price_label.text = "%d Giggles" % d.cost
			b.disabled = gig < d.cost
		b.modulate.a = 0.6 if b.disabled else 1.0
		b.set_pressed_no_signal(build_mode.holding == d)


# --- Room info: blurb, whimsy, and the "This room needs" checklist -----------------

func _add_room_info(room: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_body.add_child(row)
	_info_label = Style.label(room.blurb, 14)
	row.add_child(_info_label)
	_whimsy_label = Style.label("", 14, 500)
	_whimsy_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_whimsy_label.tooltip_text = "Whimsy adds up every item's whimsy in the room.\nBelow 4: bored.  4 to 9: Just Right.  Above 9: too wild to focus."
	row.add_child(_whimsy_label)

	var needs_head := Style.label("This room needs:", 14, 600)
	_body.add_child(needs_head)
	_needs_box = VBoxContainer.new()
	_needs_box.add_theme_constant_override("separation", 2)
	_body.add_child(_needs_box)


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
		row.add_theme_constant_override("separation", 6)
		_needs_box.add_child(row)
		# Check or cross drawn as a shape, so it never relies on color alone.
		row.add_child(W.Badge.new(got >= want, 18))
		var link := LinkButton.new()
		link.text = "%s  %d/%d  (%s)" % [data.display_name if data else String(need.item), mini(got, want), want, need.for]
		link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
		link.focus_mode = Control.FOCUS_NONE
		link.add_theme_color_override("font_color", Style.INK)
		link.add_theme_color_override("font_hover_color", Style.INK)
		link.add_theme_font_size_override("font_size", 14)
		link.tooltip_text = "Click to pick it up"
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
