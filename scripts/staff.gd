extends Node3D
## Teachers (Systems doc, Teachers). For now one: the paper dragon, the Academy's first
## teacher. They use the student body and walking (student.gd with is_teacher on) and
## wander inside their home room: the room the player last dropped them in. Teaching,
## hiring, and Energy arrive in M2.

const Student := preload("res://scripts/student.gd")
const TEACHERS_DIR := "res://data/teachers"
const START_ROOM := "castle"
const WANDER_EVERY := Vector2(4.0, 8.0)   ## Seconds between strolls

var main: Node3D
var teachers: Array = []
var _timers := {}


func _ready() -> void:
	for file in ResourceLoader.list_directory(TEACHERS_DIR):
		file = file.trim_suffix(".remap")
		if not (file.ends_with(".tres") or file.ends_with(".res")):
			continue
		var res = load(TEACHERS_DIR.path_join(file))
		if not (res is StudentData):
			continue
		var t := Student.new()
		t.is_teacher = true
		t.setup(res)
		t.home_room = START_ROOM
		t.activity = "Waiting to teach (classes start with the Timetable)"
		add_child(t)
		var room: Dictionary = main.room_by_id(START_ROOM)
		var c: Vector3 = main.room_center(room)
		t.position = c + Vector3(1.5, 0, -1.5)
		teachers.append(t)
		_timers[t] = randf_range(WANDER_EVERY.x, WANDER_EVERY.y)


func _process(real_delta: float) -> void:
	var delta := real_delta * GameState.sim_scale()
	if delta <= 0.0 or not main.students.nav_ready:
		return
	for t in teachers:
		if t.carried or t.is_moving():
			continue
		_timers[t] -= delta
		if _timers[t] <= 0.0:
			_timers[t] = randf_range(WANDER_EVERY.x, WANDER_EVERY.y)
			_stroll(t)


## A few steps somewhere inside their home room (or near where they stand, outdoors).
func _stroll(t: Node3D) -> void:
	var room: Dictionary = main.room_by_id(t.home_room)
	var area := Rect2(t.global_position.x - 2.0, t.global_position.z - 2.0, 4.0, 4.0)
	if not room.is_empty():
		var r: Rect2i = room.rect
		area = Rect2(r.position.x + 1.0, r.position.y + 1.0, r.size.x - 2.0, r.size.y - 2.0)
	for i in 5:
		var p := Vector3(randf_range(area.position.x, area.end.x), 0, randf_range(area.position.y, area.end.y))
		if t.walk_to(p):
			t.activity = "Waiting to teach (classes start with the Timetable)"
			return


## Called after a teacher is dropped: whichever room they land in becomes home.
func on_dropped(t: Node3D) -> void:
	var here := Vector2i(floori(t.global_position.x), floori(t.global_position.z))
	var room: Dictionary = main.room_at_tile(here)
	t.home_room = room.id if not room.is_empty() else ""
	_timers[t] = randf_range(WANDER_EVERY.x, WANDER_EVERY.y)
