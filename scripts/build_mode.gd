extends Node3D
## Build mode: pick an item, see a ghost preview, rotate it, place it with a wobble, or sell it.
##
## Controls
##   Left-click       place the held item / pick up a placed item to move it
##   Right-click, Esc stop holding (a moved item goes back where it was)
##   Right-click, X   sell the item under the mouse (when not holding anything)
##   R                rotate the held item
##   1-9              pick an item from the catalog

signal hint_changed(text: String)
signal toast_requested(title: String, body: String)
signal holding_changed(data: ItemData)
signal layout_changed   ## An item was placed, moved, or sold (students re-plan their paths)

const Visuals := preload("res://scripts/item_visuals.gd")
const ITEMS_DIR := "res://data/items"
const COMBOS_DIR := "res://data/combos"

# --- Feel knobs: tune these while playing ---------------------------------------
const SELL_REFUND := 0.5        ## Share of the price you get back when selling
const WOBBLE_DROP := 0.7        ## How high (m) a placed item drops from
const WOBBLE_SQUASH := Vector3(1.25, 0.7, 1.25)
const WOBBLE_TIME := 0.6        ## Seconds for the jelly settle
const WOBBLE_TILT := 0.18       ## Radians of side-to-side wobble
const HOVER_LIFT := 0.08        ## How far a hovered item lifts so you know it's selected


class Placed:
	extends RefCounted
	var data: ItemData
	var origin: Vector2i
	var rot := 0
	var node: Node3D
	var body: Node3D
	var ring: Node3D

	func footprint() -> Vector2i:
		return data.rotated_footprint(rot)

	func center() -> Vector2:
		var fp := footprint()
		return Vector2(origin.x + fp.x / 2.0, origin.y + fp.y / 2.0)

	func reach() -> float:
		return data.reach(rot)


var main: Node3D              # gives us room_at_tile()
var camera_rig: Node3D        # gives us screen_to_ground()
var students: Node3D          # hovering a student shows their needs instead of item hints
var catalog: Array[ItemData] = []
var combos: Array[ComboData] = []
var placed: Array[Placed] = []
var occupancy := {}           # Vector2i tile -> Placed

var holding: ItemData
var hold_rot := 0
var moving_from: Placed       # set while carrying an item picked up from the floor
var hover_tile: Variant = null
var debug_hover_tile: Variant = null   # tests set this instead of using the mouse

var _ghost: Node3D
var _ghost_body: Node3D
var _ghost_ring: Node3D
var _ghost_tiles: Array[MeshInstance3D] = []
var _ghost_badge: Sprite3D
var _ghost_ok := false
var _ghost_reason := ""
var _ghost_combos: Array = []
var _partner_lit: Array[Placed] = []
var _hovered: Placed
var _hint := ""


func _ready() -> void:
	for res in _load_dir(ITEMS_DIR):
		if res is ItemData:
			catalog.append(res)
	catalog.sort_custom(func(a: ItemData, b: ItemData): return a.cost < b.cost)
	for res in _load_dir(COMBOS_DIR):
		if res is ComboData:
			combos.append(res)
	_ghost = Node3D.new()
	_ghost.name = "Ghost"
	_ghost.visible = false
	add_child(_ghost)


func _load_dir(path: String) -> Array:
	var out := []
	for file in ResourceLoader.list_directory(path):
		file = file.trim_suffix(".remap")
		if file.ends_with(".tres") or file.ends_with(".res"):
			out.append(load(path.path_join(file)))
	return out


# --- Holding --------------------------------------------------------------------

func start_holding(data: ItemData, rot := 0) -> void:
	if data == null:
		stop_holding()
		return
	if moving_from != null and data != moving_from.data:
		stop_holding()   # put the carried item back before picking something new
	_clear_hover()
	holding = data
	hold_rot = rot
	_rebuild_ghost()
	holding_changed.emit(holding)


func stop_holding() -> void:
	if moving_from != null:
		# Put a carried item back exactly where it was.
		var back := moving_from
		moving_from = null
		place(back.data, back.origin, back.rot, false)
	holding = null
	_ghost.visible = false
	_light_partners([])
	holding_changed.emit(null)


func rotate_held() -> void:
	if holding == null:
		return
	hold_rot = (hold_rot + 1) % 4
	_rebuild_ghost()


func _rebuild_ghost() -> void:
	for c in _ghost.get_children():
		c.queue_free()
	_ghost_tiles.clear()
	var fp := holding.rotated_footprint(hold_rot)
	_ghost_body = Visuals.make_body(holding, true)
	_ghost_body.rotation.y = hold_rot * PI / 2.0
	_ghost.add_child(_ghost_body)
	_ghost_ring = Visuals.make_ring(holding.reach(hold_rot))
	_ghost.add_child(_ghost_ring)
	for x in fp.x:
		for z in fp.y:
			var m := Visuals.make_tile_marker()
			m.position.x = x - fp.x / 2.0 + 0.5
			m.position.z = z - fp.y / 2.0 + 0.5
			_ghost.add_child(m)
			_ghost_tiles.append(m)
	_ghost_badge = Sprite3D.new()
	_ghost_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_ghost_badge.no_depth_test = true
	_ghost_badge.pixel_size = 0.005
	_ghost_badge.render_priority = 10
	var top := holding.gray_size.y if holding.gray_size != Vector3.ZERO else holding.gray_height
	_ghost_badge.position.y = top + 0.55
	_ghost.add_child(_ghost_badge)
	_ghost_ok = not _ghost_ok   # force a refresh of colors next update
	_update_ghost(true)


# --- Rules ----------------------------------------------------------------------

## The tile an item's corner sits on when the mouse points at `tile`.
## Items are centered on the mouse, so a 3x3 rug's middle follows the cursor.
func origin_for(data: ItemData, rot: int, tile: Vector2i) -> Vector2i:
	var fp := data.rotated_footprint(rot)
	return tile - Vector2i((fp.x - 1) / 2, (fp.y - 1) / 2)


## Empty string means it can go here; otherwise the reason it can't, in plain words.
func check_placement(data: ItemData, origin: Vector2i, rot: int) -> String:
	var fp := data.rotated_footprint(rot)
	var room_id := ""
	for x in fp.x:
		for z in fp.y:
			var t := origin + Vector2i(x, z)
			var room: Dictionary = main.room_at_tile(t)
			if room.is_empty():
				return "Items go inside a room."
			if room_id == "":
				room_id = room.id
			elif room_id != room.id:
				return "It has to fit inside one room."
			if occupancy.has(t):
				return "Something is already there."
	if not data.fits_room(room_id):
		return "%s goes in %s." % [data.display_name, data.room_rule_text()]
	if not GameState.can_afford(data.cost):
		return "Not enough Giggles (needs %d)." % data.cost
	return ""


func place(data: ItemData, origin: Vector2i, rot: int, celebrate := true) -> Placed:
	if check_placement(data, origin, rot) != "":
		return null
	GameState.spend(data.cost)
	var p := Placed.new()
	p.data = data
	p.origin = origin
	p.rot = rot
	p.node = Node3D.new()
	p.node.name = String(data.id)
	var c := p.center()
	p.node.position = Vector3(c.x, 0.0, c.y)
	add_child(p.node)
	p.body = Visuals.make_body(data)
	p.body.rotation.y = rot * PI / 2.0
	p.node.add_child(p.body)
	p.ring = Visuals.make_ring(p.reach())
	p.ring.visible = false
	p.node.add_child(p.ring)
	for x in p.footprint().x:
		for z in p.footprint().y:
			occupancy[origin + Vector2i(x, z)] = p
	placed.append(p)
	layout_changed.emit()
	if celebrate:
		_wobble(p.body)
		_check_new_combos(p)
	return p


func sell(p: Placed) -> int:
	if p == null or not placed.has(p):
		return 0
	_remove(p)
	var refund := roundi(p.data.cost * SELL_REFUND)
	GameState.earn(refund)
	_float_text(p.node.position + Vector3.UP * 1.2, "+%d Giggles" % refund, Color("F6DA74"))
	var tw := create_tween()
	tw.tween_property(p.body, "scale", Vector3(1.15, 1.15, 1.15), 0.08)
	tw.tween_property(p.body, "scale", Vector3(0.01, 0.01, 0.01), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(p.node.queue_free)
	return refund


## Lift a placed item to move it. Its price is refunded and re-spent when it's set down,
## so moving is always free.
func pick_up(p: Placed) -> void:
	if p == null or not placed.has(p):
		return
	_remove(p)
	GameState.earn(p.data.cost)
	p.node.queue_free()
	moving_from = p
	start_holding(p.data, p.rot)


func _remove(p: Placed) -> void:
	if _hovered == p:
		_hovered = null
	_partner_lit.erase(p)
	placed.erase(p)
	for x in p.footprint().x:
		for z in p.footprint().y:
			occupancy.erase(p.origin + Vector2i(x, z))
	layout_changed.emit()


# --- Combos ---------------------------------------------------------------------

## Two items are linked when they sit within either one's effect radius.
func _linked(a: Dictionary, b: Dictionary) -> bool:
	return a.center.distance_to(b.center) <= maxf(a.reach, b.reach)


func _entry(data: ItemData, center: Vector2, reach: float, p: Placed) -> Dictionary:
	return {"data": data, "center": center, "reach": reach, "placed": p}


func _entries_except(skip: Placed) -> Array:
	var out := []
	for p in placed:
		if p != skip:
			out.append(_entry(p.data, p.center(), p.reach(), p))
	return out


## Every combo that `entry` would complete with the other items.
## Returns [{combo, items}] where items are the matched entries (including `entry`).
func combos_including(entry: Dictionary, others: Array) -> Array:
	var found := []
	for combo in combos:
		var tags := Array(combo.required_tags)
		for i in tags.size():
			if not entry.data.tags.has(tags[i]):
				continue
			var rest := tags.duplicate()
			rest.remove_at(i)
			var picked := [entry]
			if _match(rest, others, picked):
				found.append({"combo": combo, "items": picked})
				break
	return found


func _match(tags: Array, pool: Array, picked: Array) -> bool:
	if tags.is_empty():
		return true
	var tag = tags[0]
	for e in pool:
		if picked.has(e) or not e.data.tags.has(tag):
			continue
		var fits := true
		for q in picked:
			if not _linked(e, q):
				fits = false
				break
		if fits:
			picked.append(e)
			if _match(tags.slice(1), pool, picked):
				return true
			picked.pop_back()
	return false


func _check_new_combos(p: Placed) -> void:
	var me := _entry(p.data, p.center(), p.reach(), p)
	for hit in combos_including(me, _entries_except(p)):
		var combo: ComboData = hit.combo
		var mid := Vector2.ZERO
		for e in hit.items:
			mid += e.center
		mid /= hit.items.size()
		_float_text(Vector3(mid.x, 1.6, mid.y), combo.display_name + "!", Color("FFF8E7"))
		if GameState.discover_combo(combo):
			toast_requested.emit("New combo: " + combo.display_name, combo.bonus_text + "\n" + combo.flavor_text)


## Every combo currently formed by placed items: [{combo, items: Array[Placed]}].
func active_combos() -> Array:
	var out := []
	var seen := {}
	for p in placed:
		for hit in combos_including(_entry(p.data, p.center(), p.reach(), p), _entries_except(p)):
			var ids := []
			var items: Array = []
			for e in hit.items:
				ids.append(e.placed.get_instance_id())
				items.append(e.placed)
			ids.sort()
			var key := "%s %s" % [hit.combo.id, ids]
			if not seen.has(key):
				seen[key] = true
				out.append({"combo": hit.combo, "items": items})
	return out


func _light_partners(list: Array[Placed]) -> void:
	for p in _partner_lit:
		if is_instance_valid(p.node) and p != _hovered:
			p.ring.visible = false
	_partner_lit = list
	for p in _partner_lit:
		p.ring.visible = true


# --- Per frame ------------------------------------------------------------------

func _process(_delta: float) -> void:
	hover_tile = _tile_under_mouse()
	if holding != null:
		_update_ghost()
	else:
		_update_hover()
	_set_hint(_compose_hint())


func _tile_under_mouse() -> Variant:
	if debug_hover_tile != null:
		return debug_hover_tile
	if get_viewport().gui_get_hovered_control() != null:
		return null   # the mouse is over the catalog or another panel
	var hit = camera_rig.screen_to_ground(get_viewport().get_mouse_position())
	if hit == null:
		return null
	return Vector2i(floori(hit.x), floori(hit.z))


func _update_ghost(force := false) -> void:
	if hover_tile == null:
		_ghost.visible = false
		_light_partners([])
		return
	_ghost.visible = true
	var origin := origin_for(holding, hold_rot, hover_tile)
	var fp := holding.rotated_footprint(hold_rot)
	_ghost.position = Vector3(origin.x + fp.x / 2.0, 0.0, origin.y + fp.y / 2.0)
	_ghost_reason = check_placement(holding, origin, hold_rot)
	var ok := _ghost_reason == ""
	if ok != _ghost_ok or force:
		_ghost_ok = ok
		var mat := Visuals.tile_material(ok)
		for t in _ghost_tiles:
			t.material_override = mat
		_ghost_badge.texture = Visuals.badge_texture(ok)
	# Preview combos this spot would make and light up the partner items' rings.
	var me := _entry(holding, Vector2(_ghost.position.x, _ghost.position.z), holding.reach(hold_rot), null)
	_ghost_combos = combos_including(me, _entries_except(null)) if ok else []
	var partners: Array[Placed] = []
	for hit in _ghost_combos:
		for e in hit.items:
			if e.placed != null and not partners.has(e.placed):
				partners.append(e.placed)
	_light_partners(partners)


func _update_hover() -> void:
	var p: Placed = occupancy.get(hover_tile) if hover_tile != null else null
	if students != null and students.hovered != null:
		p = null   # the student in front gets the hover, not the item behind them
	if p == _hovered:
		return
	_clear_hover()
	_hovered = p
	if p != null:
		p.body.position.y = HOVER_LIFT
		p.ring.visible = true


func _clear_hover() -> void:
	if _hovered != null and is_instance_valid(_hovered.node):
		_hovered.body.position.y = 0.0
		if not _partner_lit.has(_hovered):
			_hovered.ring.visible = false
	_hovered = null


func _compose_hint() -> String:
	if holding != null:
		var line := "%s  ·  %d Giggles  ·  %s" % [holding.display_name, holding.cost, holding.effect_text]
		if moving_from != null:
			line = "Moving: " + holding.display_name
		if hover_tile != null and _ghost_reason != "":
			line += "\n" + _ghost_reason
		elif not _ghost_combos.is_empty():
			var combo: ComboData = _ghost_combos[0].combo
			if GameState.discovered_combos.has(combo.id):
				line += "\nMakes a combo: %s (%s)" % [combo.display_name, combo.bonus_text]
			else:
				line += "\nOoh, these look like they belong together..."
		line += "\nClick to place  ·  R to rotate  ·  Right-click to stop"
		return line
	if students != null and students.hovered != null:
		return students.hovered.hint_text()
	if _hovered != null:
		return "%s  ·  %s\nClick to move  ·  Right-click or X to sell (+%d Giggles)" % [
			_hovered.data.display_name, _hovered.data.effect_text, roundi(_hovered.data.cost * SELL_REFUND)]
	return "Pick an item from the catalog (or press 1-%d)." % catalog.size()


func _set_hint(text: String) -> void:
	if text != _hint:
		_hint = text
		hint_changed.emit(text)


# --- Input ----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if holding != null:
				stop_holding()
			elif _hovered != null:
				sell(_hovered)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				rotate_held()
			KEY_ESCAPE:
				stop_holding()
			KEY_X, KEY_DELETE:
				if holding == null and _hovered != null:
					sell(_hovered)
			_:
				var n: int = event.physical_keycode - KEY_1
				if n >= 0 and n < mini(catalog.size(), 9):
					if moving_from == null:
						start_holding(null if holding == catalog[n] else catalog[n])


func _on_left_click() -> void:
	if hover_tile == null:
		return
	if holding == null:
		if _hovered != null:
			pick_up(_hovered)
		return
	var origin := origin_for(holding, hold_rot, hover_tile)
	if check_placement(holding, origin, hold_rot) != "":
		_shake_badge()
		return
	var was_moving := moving_from != null
	moving_from = null
	place(holding, origin, hold_rot)
	# Keep holding the same item so you can place several, unless it was a move
	# or you can't afford another.
	if was_moving or not GameState.can_afford(holding.cost):
		stop_holding()


# --- Juice ----------------------------------------------------------------------

func _wobble(body: Node3D) -> void:
	body.position.y = WOBBLE_DROP
	body.scale = Vector3.ONE
	var tw := create_tween()
	tw.tween_property(body, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(body, "scale", WOBBLE_SQUASH, 0.06)
	tw.tween_property(body, "scale", Vector3.ONE, WOBBLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(
		func(t: float): body.rotation.z = sin(t * TAU * 2.5) * WOBBLE_TILT * (1.0 - t),
		0.0, 1.0, WOBBLE_TIME)


func _shake_badge() -> void:
	if _ghost_badge == null:
		return
	var tw := create_tween()
	var base := _ghost_badge.position.x
	for i in 4:
		tw.tween_property(_ghost_badge, "position:x", base + (0.12 if i % 2 == 0 else -0.12), 0.04)
	tw.tween_property(_ghost_badge, "position:x", base, 0.04)


func _float_text(at: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 56
	label.pixel_size = 0.008
	label.outline_size = 14
	label.modulate = color
	label.outline_modulate = Color("3B2C24")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = at
	add_child(label)
	var tw := create_tween()
	tw.tween_property(label, "position:y", at.y + 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 1.4).set_delay(0.5)
	tw.parallel().tween_property(label, "outline_modulate:a", 0.0, 1.4).set_delay(0.5)
	tw.tween_callback(label.queue_free)
