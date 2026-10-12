extends Node3D
## The students: spawns them, ticks their needs once per period, sends each one to the
## item that best meets their lowest need, and keeps the navigation mesh in step with
## build mode (walls and items are obstacles; it's re-baked whenever an item moves).
##
## Until the day clock arrives (M1 week 4), a "period" is a simple timer and every period
## is free time. Week 4 replaces SCHOOL_DAY_DRIFT with the activity table in the Systems doc.

signal period_ticked(period: int)

const Student := preload("res://scripts/student.gd")
const STUDENTS_DIR := "res://data/students"

# --- Tuning knobs -----------------------------------------------------------------
const PERIOD_SECONDS := 20.0      ## Placeholder period length until the day clock
## How needs drift each period with no items around (placeholder for the activity table).
const SCHOOL_DAY_DRIFT := {"calm": -1, "fun": -1, "rest": -1}
## Happy students giggle, and giggles are money: each student with Fun at or above
## GIGGLE_FUN earns GIGGLES_PER_HAPPY each period, plus a bonus in a Just Right room.
const GIGGLE_FUN := 7
const GIGGLES_PER_HAPPY := 2
const JUST_RIGHT_BONUS := 1
const ITEM_CAPACITY := 2          ## An item serves up to 2 students at once (Systems doc)
const CONTENT_LEVEL := 8          ## Needs at or above this don't send a student anywhere
const CALM_NIGHTLIGHT_SPEEDUP := 0.5  ## Hiding near a nightlight ends in half the time
const IDLE_RETHINK := 4.0          ## Seconds an idle student stands before looking around again
const SPAWN_CENTER := Vector3(0, 0, 1.5)  ## Cardboard Castle

# --- Navigation mesh --------------------------------------------------------------

func _on_layout_changed() -> void:
	_nav_dirty = true
	# Anyone using an item that just left stops using it right away.
	for s in students:
		if s.target_item != null and not build_mode.placed.has(s.target_item) and not s.is_acting_out():
			s.target_item = null
			s.stop()
			s.state = Student.State.IDLE
			s.activity = "Looking around"
const NAV_CELL := 0.1
const AGENT_RADIUS := 0.3
const NAV_AREA := Rect2(-14.5, -4.25, 29.0, 11.0)  ## x, z, width, depth: the rooms and the yard
const FLAT_ITEM_HEIGHT := 0.1     ## Items this flat (rugs) can be walked over

var main: Node3D
var build_mode: Node3D
var camera_rig: Node3D

var students: Array = []          # student.gd nodes
var period := 1
var period_seconds := PERIOD_SECONDS
var period_left := PERIOD_SECONDS
var hovered: Node3D = null
var nav_ready := false            # true once the first navigation mesh is live

var _region: NavigationRegion3D
var _nav_dirty := true
var _waiting_for_iteration := -1


func _ready() -> void:
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, NAV_CELL)
	NavigationServer3D.map_set_cell_height(map, NAV_CELL)
	_region = NavigationRegion3D.new()
	_region.name = "NavRegion"
	add_child(_region)
	build_mode.layout_changed.connect(_on_layout_changed)

	var datas: Array[StudentData] = []
	for file in ResourceLoader.list_directory(STUDENTS_DIR):
		file = file.trim_suffix(".remap")
		if file.ends_with(".tres") or file.ends_with(".res"):
			var res = load(STUDENTS_DIR.path_join(file))
			if res is StudentData:
				datas.append(res)
	datas.sort_custom(func(a: StudentData, b: StudentData): return a.display_name < b.display_name)
	for i in datas.size():
		var s := Student.new()
		s.setup(datas[i])
		add_child(s)
		s.position = SPAWN_CENTER + Vector3((i - (datas.size() - 1) / 2.0) * 1.2, 0, 0)
		s.rotation.y = 0.0
		s.act_out_finished.connect(_on_act_out_finished)
		students.append(s)


# --- Periods ----------------------------------------------------------------------

func _process(delta: float) -> void:
	_update_hover()
	if not nav_ready:
		return
	# Idle students look for something new every few seconds.
	for s in students:
		if s.state == Student.State.IDLE and not s.is_moving():
			s.idle_time += delta
			if s.idle_time > IDLE_RETHINK:
				s.idle_time = 0.0
				choose_target(s)
	period_left -= delta
	if period_left <= 0.0:
		period_left += period_seconds
		tick_period()


## One period passes: every student's needs change, then they pick where to go.
func tick_period() -> void:
	period += 1
	var active: Array = build_mode.active_combos()
	for s in students:
		if s.is_acting_out():
			continue   # acting out skips the period (Systems doc)
		var emptied: String = s.apply_period(changes_for(s, active))
		if emptied != "":
			start_act_out(s, emptied)
	for s in students:
		if not s.is_acting_out():
			choose_target(s)
	pay_giggles()
	period_ticked.emit(period)


## Happy students laugh out Giggles at the end of each period.
func pay_giggles() -> int:
	var total := 0
	for s in students:
		var amount := giggles_from(s)
		if amount > 0:
			total += amount
			build_mode._float_text(s.global_position + Vector3.UP * (s.data.gray_height + 1.0), "+%d" % amount, Color("F6DA74"))
	if total > 0:
		GameState.earn(total)
	return total


func giggles_from(s: Node3D) -> int:
	if s.is_acting_out() or s.needs["fun"] < GIGGLE_FUN:
		return 0
	var amount := GIGGLES_PER_HAPPY
	var room: Dictionary = main.room_at_tile(Vector2i(floori(s.global_position.x), floori(s.global_position.z)))
	if not room.is_empty():
		var w: int = build_mode.room_whimsy(room.id)
		if w >= 4 and w <= 9:
			amount += JUST_RIGHT_BONUS
	return amount


## This period's changes for one student: {need: [[reason, amount], ...]}.
func changes_for(s: Node3D, active_combos: Array = []) -> Dictionary:
	var out := {}
	for need in Student.NEEDS:
		out[need] = []
		if SCHOOL_DAY_DRIFT.get(need, 0) != 0:
			out[need].append(["school day", SCHOOL_DAY_DRIFT[need]])
	for p in items_in_range(s):
		for need in p.data.need_mods:
			if out.has(need):
				out[need].append([p.data.display_name, int(p.data.need_mods[need])])
	for hit in active_combos:
		var near := false
		for p in hit.items:
			if in_range(s, p):
				near = true
				break
		if near:
			for need in hit.combo.need_mods:
				if out.has(need):
					out[need].append([hit.combo.display_name, int(hit.combo.need_mods[need])])
	return out


func in_range(s: Node3D, p) -> bool:
	var c: Vector2 = p.center()
	return Vector2(s.global_position.x, s.global_position.z).distance_to(c) <= p.reach() + 0.05


func items_in_range(s: Node3D) -> Array:
	var out := []
	for p in build_mode.placed:
		if in_range(s, p):
			out.append(p)
	return out


# --- Choosing where to go ---------------------------------------------------------

## Free-time rule from the Systems doc: walk to the item that best meets the lowest need.
## An item serves up to ITEM_CAPACITY students; when the best is full, try the next.
func choose_target(s: Node3D) -> void:
	if s.is_acting_out() or not nav_ready:
		return
	var order: Array = Student.NEEDS.duplicate()
	order.sort_custom(func(a, b): return s.needs[a] < s.needs[b])
	for need in order:
		if s.needs[need] >= CONTENT_LEVEL:
			break
		var best = null
		var best_score := -INF
		for p in build_mode.placed:
			var amount := int(p.data.need_mods.get(need, 0))
			if amount <= 0:
				continue
			if p != s.target_item and users_of(p, s) >= ITEM_CAPACITY:
				continue
			var c: Vector2 = p.center()
			var dist := Vector2(s.global_position.x, s.global_position.z).distance_to(c)
			var score := amount * 10.0 - dist
			if score > best_score:
				best_score = score
				best = p
		if best != null:
			if best == s.target_item and (s.state == Student.State.USING or s.is_moving()):
				return   # already on their way or there
			var spot = stand_spot(best, s)
			if spot != null:
				s.target_item = best
				s.activity = "Off to the %s (%s)" % [best.data.display_name, Student.NEED_NAMES[need]]
				if s.walk_to(spot):
					return
				s.target_item = null
	# Nothing helps (or they're content): mill about inside the room they're in.
	if s.state == Student.State.USING and s.target_item != null and build_mode.placed.has(s.target_item):
		return   # happy where they are
	s.target_item = null
	_mill_about(s)


func _mill_about(s: Node3D) -> void:
	var here := Vector2i(floori(s.global_position.x), floori(s.global_position.z))
	var room: Dictionary = main.room_at_tile(here)
	var area := Rect2(NAV_AREA)
	if not room.is_empty():
		var r: Rect2i = room.rect
		area = Rect2(r.position.x + 0.8, r.position.y + 0.8, r.size.x - 1.6, r.size.y - 1.6)
	for i in 6:
		var p := Vector3(randf_range(area.position.x, area.end.x), 0, randf_range(area.position.y, area.end.y))
		if s.walk_to(p):
			s.activity = "Looking around" if s.needs[s.lowest_need()] >= CONTENT_LEVEL else "Looking for something to do"
			return
	s.state = Student.State.IDLE


func users_of(p, except: Node3D = null) -> int:
	var n := 0
	for s in students:
		if s != except and s.target_item == p and not s.is_acting_out():
			n += 1
	return n


## A free spot on the floor, within the item's effect radius, where a student can stand.
func stand_spot(p, s: Node3D) -> Variant:
	var map := get_world_3d().navigation_map
	var c: Vector2 = p.center()
	var fp: Vector2i = p.footprint()
	var flat := _item_height(p.data) <= FLAT_ITEM_HEIGHT
	var candidates: Array[Vector3] = []
	if flat:
		candidates.append(Vector3(c.x, 0, c.y))
	var d := maxf(fp.x, fp.y) / 2.0 + AGENT_RADIUS + 0.2
	for i in 12:
		var a := TAU * i / 12.0
		candidates.append(Vector3(c.x + cos(a) * d, 0, c.y + sin(a) * d))
	var best = null
	var best_dist := INF
	for cand in candidates:
		var spot := NavigationServer3D.map_get_closest_point(map, cand)
		spot.y = 0.0
		if Vector2(spot.x, spot.z).distance_to(c) > p.reach() - 0.1:
			continue
		if _spot_taken(spot, s):
			continue
		var dist := spot.distance_to(s.global_position)
		if dist < best_dist:
			best_dist = dist
			best = spot
	return best


func _spot_taken(spot: Vector3, me: Node3D) -> bool:
	for o in students:
		if o == me:
			continue
		var theirs: Vector3 = o.goal() if o.is_moving() else o.global_position
		if theirs.distance_to(spot) < 0.7:
			return true
	return false


# --- Act-outs ---------------------------------------------------------------------

func start_act_out(s: Node3D, need: String) -> void:
	var seconds := period_seconds
	if need == "calm":
		for p in items_in_range(s):
			if p.data.tags.has("nightlight"):
				seconds *= CALM_NIGHTLIGHT_SPEEDUP
				break
	s.start_act_out(need, seconds)
	if need == "fun":
		_wander_to_toy(s)


## "Wanders off to the nearest toy" (Systems doc). With no toy, they just roam.
func _wander_to_toy(s: Node3D) -> void:
	var best = null
	var best_dist := INF
	for p in build_mode.placed:
		if p.data.tags.has("toy"):
			var c: Vector2 = p.center()
			var dist := Vector2(s.global_position.x, s.global_position.z).distance_to(c)
			if dist < best_dist:
				best_dist = dist
				best = p
	if best != null:
		var spot = stand_spot(best, s)
		if spot != null and s.walk_to(spot, Student.State.WANDERING):
			s.target_item = best
			return
	_roam(s)


func _roam(s: Node3D) -> void:
	for i in 8:
		var p := Vector3(randf_range(NAV_AREA.position.x, NAV_AREA.end.x), 0, randf_range(NAV_AREA.position.y, NAV_AREA.end.y))
		if s.walk_to(p, Student.State.WANDERING):
			s.activity = "Wandering off, bored"
			return


func _on_act_out_finished(s: Node3D) -> void:
	choose_target(s)


## Test helper: empty one need right now and act it out (C, F, Z while hovering).
func empty_need(s: Node3D, need: String) -> void:
	if s.is_acting_out():
		s.end_act_out()
	s.set_need(need, 0)
	s.last_changes = {need: [["test key", -10]]}
	start_act_out(s, need)


# --- Navigation mesh --------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	var map := get_world_3d().navigation_map
	if _nav_dirty:
		_nav_dirty = false
		_bake()
		_waiting_for_iteration = NavigationServer3D.map_get_iteration_id(map)
	elif _waiting_for_iteration >= 0 and NavigationServer3D.map_get_iteration_id(map) > _waiting_for_iteration \
			and _map_has_mesh(map):
		_waiting_for_iteration = -1
		_on_nav_updated()
	# Wandering students without a toy keep roaming until they feel better.
	for s in students:
		if s.state == Student.State.WANDERING and not s.is_moving() and s.target_item == null:
			_roam(s)


## The map can sync before the new mesh is in it; probe a spot that is always walkable.
func _map_has_mesh(map: RID) -> bool:
	var probe := NavigationServer3D.map_get_closest_point(map, SPAWN_CENTER)
	return Vector2(probe.x, probe.z).distance_to(Vector2(SPAWN_CENTER.x, SPAWN_CENTER.z)) < 0.5


func _bake() -> void:
	var nm := NavigationMesh.new()
	nm.cell_size = NAV_CELL
	nm.cell_height = NAV_CELL
	nm.agent_radius = AGENT_RADIUS
	nm.agent_height = 1.0
	nm.agent_max_climb = 0.2
	nm.region_min_size = 1.0
	var src := NavigationMeshSourceGeometryData3D.new()
	var a := NAV_AREA
	var y := 0.0
	src.add_faces(PackedVector3Array([
		Vector3(a.position.x, y, a.position.y), Vector3(a.end.x, y, a.position.y), Vector3(a.end.x, y, a.end.y),
		Vector3(a.position.x, y, a.position.y), Vector3(a.end.x, y, a.end.y), Vector3(a.position.x, y, a.end.y),
	]), Transform3D.IDENTITY)
	for w in main.wall_rects:
		_add_block(src, w, main.WALL_HEIGHT)
	for p in build_mode.placed:
		var h := _item_height(p.data)
		if h <= FLAT_ITEM_HEIGHT:
			continue
		var fp: Vector2i = p.footprint()
		var c: Vector2 = p.center()
		# Use the gray shape's real size so small items (a duck) don't block a whole tile.
		var size := Vector2(fp.x, fp.y) - Vector2(0.2, 0.2)
		if p.data.gray_size != Vector3.ZERO:
			size = Vector2(p.data.gray_size.x, p.data.gray_size.z)
			if p.rot % 2 == 1:
				size = Vector2(size.y, size.x)
		_add_block(src, Rect2(c - size / 2.0, size), h)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	_region.navigation_mesh = nm


func _add_block(src: NavigationMeshSourceGeometryData3D, r: Rect2, height: float) -> void:
	src.add_projected_obstruction(PackedVector3Array([
		Vector3(r.position.x, 0, r.position.y), Vector3(r.end.x, 0, r.position.y),
		Vector3(r.end.x, 0, r.end.y), Vector3(r.position.x, 0, r.end.y),
	]), 0.0, height, false)


func _item_height(data: ItemData) -> float:
	return data.gray_size.y if data.gray_size != Vector3.ZERO else data.gray_height


func _on_nav_updated() -> void:
	var first := not nav_ready
	nav_ready = true
	var map := get_world_3d().navigation_map
	for s in students:
		# An item dropped on top of a student nudges them to the nearest free floor.
		var on_mesh := NavigationServer3D.map_get_closest_point(map, s.global_position)
		if Vector2(on_mesh.x, on_mesh.z).distance_to(Vector2(s.global_position.x, s.global_position.z)) > 0.05:
			s.global_position = Vector3(on_mesh.x, 0, on_mesh.z)
		if s.target_item != null and not build_mode.placed.has(s.target_item):
			s.target_item = null
			if s.state == Student.State.USING:
				s.state = Student.State.IDLE
		if s.is_moving():
			s.repath()
		# A new item may suit them better; choose_target keeps them put if not.
		if not s.is_acting_out() and (first or s.target_item == null or s.state == Student.State.USING):
			choose_target(s)


# --- Hover and test keys ----------------------------------------------------------

func _update_hover() -> void:
	var found: Node3D = null
	if build_mode.holding == null and build_mode.debug_hover_tile == null and camera_rig != null:
		var vp := get_viewport()
		if vp.gui_get_hovered_control() == null:
			var mouse := vp.get_mouse_position()
			var cam: Camera3D = camera_rig.camera
			var best := 34.0   # pixels
			for s in students:
				var head: Vector3 = s.global_position + Vector3.UP * s.data.gray_height * 0.6
				if cam.is_position_behind(head):
					continue
				var d := cam.unproject_position(head).distance_to(mouse)
				if d < best:
					best = d
					found = s
	if debug_hovered != null:
		found = debug_hovered
	hovered = found


var debug_hovered: Node3D = null   # tests set this instead of using the mouse


func _unhandled_input(event: InputEvent) -> void:
	if hovered == null or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_C:
			empty_need(hovered, "calm")
		KEY_F:
			empty_need(hovered, "fun")
		KEY_Z:
			empty_need(hovered, "rest")
		_:
			return
	get_viewport().set_input_as_handled()
