extends PanelContainer
## The Build panel (mockup 07's pieces, docked on the left like Two Point's and Let's
## School's build catalogs): cut paper with lavender tape, one tab per room plus "Anywhere":
##   - A room tab lists the items made for that room, then classroom items (Fort and Castle),
##     with a "This room needs" checklist and the room's whimsy score on top.
##   - "Anywhere" lists items that go in any room, grouped by type.
## ItemCards show a picture, price, footprint and effect. Picking a room tab glides the camera
## to that room. Keys 1-9 pick from the open tab.

const Style := preload("res://scripts/ui/ui_style.gd")
const W := preload("res://scripts/ui/widgets.gd")

const ANYWHERE := "any"
const START_TAB := "castle"
## Order of the type groups on the Anywhere tab.
const TYPE_ORDER := ["Structure", "Light", "Comfort", "Fun", "Decor", "Regulation"]
const CARD_W := 180.0
const MENU_WIDTH := 432.0
const NEED_LABELS := {"calm": "Calm", "fun": "Fun", "rest": "Rest"}
const TAB_ICONS := {"fort": "tent", "castle": "castle-turret", "dorm": "moon-stars", "any": "sparkle"}

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
var _card_row: VBoxContainer
var _footer: Label


func setup(the_hud: CanvasLayer, mode: Node3D) -> void:
	hud = the_hud
	build_mode = mode
	main = mode.main
	students = mode.students
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	visible = false
	# Docked left, from under the Giggles counter down to the bottom edge.
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = Style.HUD_INSET
	offset_right = Style.HUD_INSET + MENU_WIDTH
	offset_top = 52 + 14                # under the top bar
	offset_bottom = -Style.HUD_INSET - 92 - 12   # above the bottom-left time bar
	custom_minimum_size.x = MENU_WIDTH

	var paper := W.Paper.new("paper", Vector4(18, 20, 16, 20), "a")
	add_child(paper)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	paper.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	var title_col := VBoxContainer.new()
	title_col.add_theme_constant_override("separation", 4)
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_col)
	title_col.add_child(Style.caps("Building in", 13))
	_room_title = Style.label("", 24, 600)
	title_col.add_child(_room_title)
	var close := Style.button("Close", "sm", false, "x")
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.tooltip_text = "Close the Build panel  (B)"
	close.pressed.connect(UI.close_drawer)
	top.add_child(close)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	col.add_child(tabs)
	for room in main.ROOMS:
		_add_tab(tabs, room.id, room.name)
	_add_tab(tabs, ANYWHERE, "Anywhere")

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	col.add_child(_body)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	pad.add_theme_constant_override("margin_left", 2)
	pad.add_theme_constant_override("margin_right", 6)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	_card_row = VBoxContainer.new()
	_card_row.add_theme_constant_override("separation", 12)
	pad.add_child(_card_row)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	col.add_child(bottom)
	_footer = Style.label("", 14, 500, Style.INK_SOFT)
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(_footer)
	sell_button = Style.button("Sell", "sm", false, "tag")
	sell_button.toggle_mode = true
	sell_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sell_button.tooltip_text = "Click placed items to sell them for half price.\nRight-click or Esc to stop. (Hover an item and press X works too.)"
	sell_button.toggled.connect(func(on: bool): build_mode.set_sell_mode(on))
	build_mode.sell_mode_changed.connect(func(on: bool): sell_button.set_pressed_no_signal(on))
	bottom.add_child(sell_button)
	paper.add_child(Style.tape(MENU_WIDTH / 2.0 - 48, -4, "lavender"))

	build_mode.holding_changed.connect(func(_d): _refresh_cards())
	build_mode.layout_changed.connect(_refresh_room_info)
	GameState.giggles_changed.connect(func(_g): _refresh_cards())
	open_tab(START_TAB, false)
	set_hint(build_mode._hint)


func _add_tab(parent: Control, id: String, label: String) -> void:
	# Icon tabs, one per room, named on hover and in the title above.
	var b := Style.tab_button("", "md", TAB_ICONS.get(id, ""))
	b.custom_minimum_size = Vector2(84, 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = label
	b.pressed.connect(open_tab.bind(id))
	parent.add_child(b)
	_tabs[id] = b


## The footer line: build mode's hint, or the controls when nothing's going on.
func set_hint(t: String) -> void:
	if _footer == null or not is_instance_valid(_footer):
		return
	if t == "" or t.begins_with("Pick an item"):
		_footer.text = "Click to place · R to rotate · Right-click to cancel"
	else:
		_footer.text = t.replace("\n", "  ·  ")


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


## A group of cards: a small caps heading, then the cards two to a row.
func _add_cards(title: String, items: Array, order: Array[ItemData]) -> void:
	if items.is_empty():
		return
	_card_row.add_child(Style.caps(title, 12))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 16)
	_card_row.add_child(grid)
	for d in items:
		order.append(d)
		grid.add_child(_card(d))


## An ItemCard (components/cards/ItemCard.jsx).
func _card(d: ItemData) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(CARD_W, 190)
	b.clip_contents = true   # long names and chips never stretch a card
	b.tooltip_text = _tooltip(d)
	var normal := Style.card_box(false, false, 10)
	var hover := Style.button_box("paper", "hover", Vector2(10, 10))
	hover.bg_color = Style.PAPER
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", Style.card_box(true, false, 10))
	b.add_theme_stylebox_override("hover_pressed", Style.card_box(true, false, 10))
	b.add_theme_stylebox_override("disabled", normal)
	b.pressed.connect(_on_card_pressed.bind(d))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	b.add_child(col)
	var thumb := PanelContainer.new()
	thumb.add_theme_stylebox_override("panel", Style.flat_box(W.ItemIcon.item_tint(d), Color(Style.WOOD, 0.18), 3, 10, 0))
	thumb.custom_minimum_size = Vector2(0, 84)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(thumb)
	var icon := W.ItemIcon.new(d, 56)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	thumb.add_child(icon)
	var lock := PanelContainer.new()
	lock.add_theme_stylebox_override("panel", Style.flat_box(Color(Style.PAPER_SHADOW, 0.82), Color(0, 0, 0, 0), 0, 10, 0))
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var li := W.Icon.new("lock-simple", 40, Style.INK, "fill")
	li.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	li.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lock.add_child(li)
	lock.visible = false
	thumb.add_child(lock)
	var key := Style.label("", 13, 700, Style.INK_SOFT)
	key.position = Vector2(8, 4)
	var ko := Style.overlay()
	ko.add_child(key)
	thumb.add_child(ko)
	var name_label := Style.label(d.display_name, 17, 600)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	var coin := W.Coin.new(18)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	var price_label := Style.label("", 16, 700)
	price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(price_label)
	var fp := PanelContainer.new()
	var fsb := Style.flat_box(Style.BOARD, Style.PAPER_SHADOW, 2, 6, 0)
	fsb.content_margin_left = 7
	fsb.content_margin_right = 7
	fsb.content_margin_top = 3
	fsb.content_margin_bottom = 3
	fp.add_theme_stylebox_override("panel", fsb)
	fp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fprow := HBoxContainer.new()
	fprow.add_theme_constant_override("separation", 4)
	fp.add_child(fprow)
	var grid_icon := W.Icon.new("grid-four", 13, Style.INK, "bold")
	grid_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fprow.add_child(grid_icon)
	fprow.add_child(Style.label("%d×%d" % [d.footprint.x, d.footprint.y], 13, 600))
	row.add_child(fp)
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 4)
	chip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(chip_row)
	var effect: String = effect_chips(d)[0]
	if effect.length() > 22:
		effect = effect.left(21) + "…"
	var chip := Style.effect_chip(effect)
	chip.tooltip_text = effect_chips(d)[0]
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip_row.clip_contents = true
	chip_row.add_child(chip)
	b.set_meta("price_label", price_label)
	b.set_meta("key_label", key)
	b.set_meta("lock", lock)
	_cards[d] = b
	return b


## A card's effect chip: "+2 Calm", "Teaches Monster Defense", or what kind of thing it is.
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
	lines.append("Size %d × %d  ·  goes in %s" % [d.footprint.x, d.footprint.y, d.room_rule_text()])
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
		(b.get_meta("lock") as Control).visible = locked
		if locked:
			price_label.text = "%d Ideas" % d.research_ideas
			b.tooltip_text = "Locked: research it for %d Ideas (the research board arrives in M3).\n\n%s" % [d.research_ideas, _tooltip(d)]
			b.disabled = true
			b.modulate.a = 1.0
		else:
			price_label.text = str(d.cost)
			b.disabled = gig < d.cost
			b.modulate.a = 0.6 if b.disabled else 1.0
		var held: bool = build_mode.holding == d
		b.set_pressed_no_signal(held)
		b.pivot_offset = b.custom_minimum_size / 2.0
		b.rotation_degrees = -1.5 if held else 0.0


# --- Room info: whimsy and the "This room needs" checklist --------------------------

func _add_room_info(room: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_body.add_child(row)
	var lead := Style.caps("This room needs", 12)
	lead.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lead)
	_needs_box = HFlowContainer.new()
	_needs_box.add_theme_constant_override("h_separation", 16)
	_needs_box.add_theme_constant_override("v_separation", 4)
	_needs_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_needs_box)
	var whimsy := PanelContainer.new()
	var wsb := Style.flat_box(Style.LAVENDER_LIGHT, Color(0, 0, 0, 0), 0, 8, 0)
	wsb.content_margin_left = 9
	wsb.content_margin_right = 9
	wsb.content_margin_top = 4
	wsb.content_margin_bottom = 4
	whimsy.add_theme_stylebox_override("panel", wsb)
	whimsy.tooltip_text = "%s\n\nWhimsy adds up every item's whimsy in the room.\nBelow 4: bored.  4 to 9: Just Right.  Above 9: too wild to focus." % room.blurb
	whimsy.mouse_filter = Control.MOUSE_FILTER_PASS
	whimsy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_whimsy_label = Style.label("", 14, 600)
	whimsy.add_child(_whimsy_label)
	row.add_child(whimsy)
	_info_label = _whimsy_label


func _refresh_room_info() -> void:
	if current_tab == ANYWHERE or _needs_box == null or not is_instance_valid(_needs_box):
		return
	var room: Dictionary = main.room_by_id(current_tab)
	var w: int = build_mode.room_whimsy(current_tab)
	_whimsy_label.text = "Whimsy %d · %s" % [w, whimsy_word(w)]
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
		# A round check or a tilted square X: shape, never color alone.
		var mark := W.PlacementMark.new(got >= want, 18)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mark)
		var link := LinkButton.new()
		link.text = "%s  %d/%d" % [data.display_name if data else String(need.item), mini(got, want), want]
		link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
		link.focus_mode = Control.FOCUS_NONE
		link.add_theme_color_override("font_color", Style.INK)
		link.add_theme_color_override("font_hover_color", Style.INK)
		link.add_theme_font_override("font", Style.font(600))
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
