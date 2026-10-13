extends Node3D
## Pick up and drop off students and teachers anywhere (like Two Point and Let's School).
##   - Click a student or teacher to pick them up; click again to put them down.
##   - Or press, drag, and let go.
##   - Right-click or Esc puts them back where they were.
##   - Drop a student on an item and they go use it. Drop a teacher in a room and that
##     room becomes their home.
##   - Double-click a student to open their card instead.
## While carried they dangle above the cursor; a ring on the floor shows where they'll land
## (a coral X where they can't).

const LIFT := 0.9                 ## How high (m) a carried friend floats above the floor
const DRAG_START := 8.0           ## Pixels the mouse moves while pressed before it counts as a drag
const MAX_SNAP := 0.45            ## How far (m) a drop may snap to the nearest walkable spot

signal carried_changed(agent: Node3D)

var main: Node3D
var carried: Node3D = null
var drop_target = null            ## The item under the cursor (students go use it)

var _from := Vector3.ZERO
var _pending: Node3D = null       ## Pressed on, not yet lifted
var _press_pos := Vector2.ZERO
var _dragged := false
var _lift_time := 0.0
var _marker: Node3D
var _ring: MeshInstance3D
var _cross: Node3D
var _label: Label3D
var _drop_ok := false
var _drop_point := Vector3.ZERO
var debug_ground: Variant = null  ## Tests set this instead of using the mouse


func _ready() -> void:
	_build_marker()


func _build_marker() -> void:
	_marker = Node3D.new()
	_marker.name = "DropMarker"
	_marker.visible = false
	add_child(_marker)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.26
	torus.outer_radius = 0.36
	torus.rings = 24
	_ring.mesh = torus
	_ring.scale = Vector3(1, 0.15, 1)
	_ring.position.y = 0.03
	_marker.add_child(_ring)
	_cross = Node3D.new()
	_marker.add_child(_cross)
	for a in [45.0, -45.0]:
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.6, 0.04, 0.12)
		bar.mesh = box
		bar.rotation_degrees.y = a
		bar.position.y = 0.03
		bar.material_override = _flat(Color("E05A68"))
		_cross.add_child(bar)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 44
	_label.pixel_size = 0.007
	_label.outline_size = 12
	_label.outline_modulate = Color("3B2C24")
	_label.modulate = Color("FFF8E7")
	_label.position.y = 0.35
	_marker.add_child(_label)


static func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	m.render_priority = 4
	return m


# --- Picking up and putting down ----------------------------------------------------

func pick(agent: Node3D) -> void:
	if carried != null:
		cancel()
	carried = agent
	_from = agent.global_position
	_lift_time = 0.0
	agent.lift()
	if UI.card_student != null and UI.card_student != agent:
		UI.close_card()
	_marker.visible = true
	carried_changed.emit(agent)
	_follow()


## Put them back where they were picked up.
func cancel() -> void:
	if carried == null:
		return
	var a := carried
	carried = null
	_marker.visible = false
	a.land(_from)
	_after_drop(a, null)
	carried_changed.emit(null)


## Drop at a floor point. Returns false (and keeps carrying) if they can't go there.
func drop_at(ground: Vector3) -> bool:
	if carried == null:
		return false
	_evaluate(ground)
	if not _drop_ok:
		return false
	var a := carried
	var item = drop_target
	carried = null
	_marker.visible = false
	a.land(_drop_point)
	_after_drop(a, item)
	carried_changed.emit(null)
	return true


func _after_drop(a: Node3D, item) -> void:
	if a.is_teacher:
		main.staff.on_dropped(a)
		return
	if item != null and main.students.send_to(a, item):
		return
	main.students.choose_target(a)


## Where would they land if dropped at `ground`? Sets _drop_ok, _drop_point, drop_target.
func _evaluate(ground: Vector3) -> void:
	drop_target = null
	var tile := Vector2i(floori(ground.x), floori(ground.z))
	var item = main.build_mode.occupancy.get(tile)
	var map := get_world_3d().navigation_map
	var snapped := NavigationServer3D.map_get_closest_point(map, ground)
	snapped.y = 0.0
	var area: Rect2 = main.students.NAV_AREA
	var inside := area.has_point(Vector2(ground.x, ground.z))
	if item != null and not carried.is_teacher:
		# On an item: the student will walk over and use it, if it does something for them.
		drop_target = item
		_drop_ok = inside and main.students.users_of(item, carried) < main.students.ITEM_CAPACITY
		_drop_point = snapped
		return
	_drop_point = snapped
	_drop_ok = inside and snapped.distance_to(Vector3(ground.x, 0, ground.z)) <= MAX_SNAP


func _ground_under_mouse() -> Variant:
	if debug_ground != null:
		return debug_ground
	var cam_rig: Node3D = main.camera_rig
	if cam_rig == null:
		return null
	return cam_rig.screen_to_ground(get_viewport().get_mouse_position())


func _process(delta: float) -> void:
	if carried == null:
		return
	_lift_time += delta
	_follow()


func _follow() -> void:
	var g = _ground_under_mouse()
	if g == null or carried == null:
		return
	var ground: Vector3 = g
	carried.global_position = ground + Vector3.UP * LIFT
	_evaluate(ground)
	_marker.global_position = _drop_point if _drop_ok else Vector3(ground.x, 0, ground.z)
	_ring.visible = _drop_ok
	_cross.visible = not _drop_ok
	_ring.material_override = _flat(Color("42C872") if _drop_ok else Color("E05A68"))
	if drop_target != null and _drop_ok:
		_label.text = "Use the %s" % drop_target.data.display_name
	elif drop_target != null:
		_label.text = "Full!"
	elif not _drop_ok:
		_label.text = "Can't go there"
	else:
		var room: Dictionary = main.room_at_tile(Vector2i(floori(ground.x), floori(ground.z)))
		_label.text = room.name if not room.is_empty() else ""


## The hint line while carrying (shown in the HUD).
func hint() -> String:
	if carried == null:
		return ""
	var who: String = carried.data.display_name
	if carried.is_teacher:
		return "Carrying %s  ·  drop in a room to make it their classroom\nClick to put down  ·  Right-click or Esc to put back" % who
	return "Carrying %s  ·  drop on an item to send them to it\nClick to put down  ·  Right-click or Esc to put back" % who


# --- Input --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if UI.blocking():
		return
	var bm: Node3D = main.build_mode
	if carried == null and (bm.holding != null or bm.sell_mode):
		return   # building comes first
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if carried != null:
				if event.double_click and _lift_time < 0.5 and not _dragged and not carried.is_teacher:
					var a := carried
					cancel()
					UI.open_drawer("students")
					UI.open_card(a)
				else:
					_try_drop()
				get_viewport().set_input_as_handled()
				return
			var h: Node3D = main.students.hovered
			if h != null:
				_pending = h
				_press_pos = event.position
				_dragged = false
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _pending != null:
				# A click without dragging: pick up and keep carrying until the next click.
				var p := _pending
				_pending = null
				pick(p)
				_dragged = false
				get_viewport().set_input_as_handled()
			elif carried != null and _dragged:
				_try_drop()
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and carried != null:
			cancel()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _pending != null and event.position.distance_to(_press_pos) > DRAG_START:
			var p := _pending
			_pending = null
			pick(p)
			_dragged = true
	elif event is InputEventKey and event.pressed and not event.echo and carried != null:
		if event.physical_keycode == KEY_ESCAPE:
			cancel()
			get_viewport().set_input_as_handled()


func _try_drop() -> void:
	var g = _ground_under_mouse()
	if g == null or not drop_at(g):
		# Can't land there: a little shake of the marker, and they stay in hand.
		if not Settings.reduce_motion:
			var tw := create_tween()
			var base := _marker.position.x
			for i in 4:
				tw.tween_property(_marker, "position:x", base + (0.08 if i % 2 == 0 else -0.08), 0.04)
	_dragged = false
