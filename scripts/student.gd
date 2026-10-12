extends Node3D
## One student. Holds their needs, walks along the navigation mesh, uses items,
## and acts out when a need hits 0. The Students manager (students.gd) decides
## where each student goes; this script handles how they move and look.

signal act_out_finished(student: Node3D)

const StudentVisuals := preload("res://scripts/student_visuals.gd")

const NEEDS := ["calm", "fun", "rest"]
const NEED_NAMES := {"calm": "Calm", "fun": "Fun", "rest": "Rest"}
const SKILLS := ["bravery", "listening", "silliness"]
const MAX_NEED := 10
const LOW_NEED := 3               ## Below this a mood icon shows (Systems doc)

## What an empty need recovers to after its act-out (Systems doc, "Low and empty needs").
const RECOVER_TO := {"calm": 3, "fun": 4}
const REST_RECOVER_GAIN := 3

# --- Feel knobs -------------------------------------------------------------------
const WALK_SPEED := 1.7           ## Meters per second
const WANDER_SPEED := 2.3         ## Bored students zip about
const TURN_RATE := 10.0
const BOB_HEIGHT := 0.07          ## Hop height while walking
const BOB_RATE := 11.0
const ICON_HEIGHT := 0.55         ## Above the top of the head

enum State { IDLE, WALKING, USING, HIDING, WANDERING, NAPPING }

var data: StudentData
var needs := {}
var skills := {}                  ## skill -> [solid, fresh] (Systems doc, learning model)
var state := State.IDLE
var target_item = null            ## The Placed item they're heading to or using
var activity := "Looking around"  ## Shown in the HUD and hover hint
var last_changes := {}            ## need -> Array of [reason, amount] from the last period
var act_out_need := ""
var act_out_left := 0.0           ## Seconds until the act-out ends
var idle_time := 0.0              ## Seconds standing with nothing to do

var body: Node3D
var _icon: Sprite3D
var _icon_need := ""
var _prop: Node3D                 # blanket or zzz during act-outs
var _path := PackedVector3Array()
var _path_i := 0
var _goal := Vector3.ZERO
var _moving := false
var _anim_t := 0.0
var _hop_t := 0.0
var _hopping := false             # a hop or recovery tween owns the body's scale


func setup(student_data: StudentData) -> void:
	data = student_data
	name = String(data.display_name)
	for need in NEEDS:
		needs[need] = clampi(int(data.start_needs.get(need, 6)), 0, MAX_NEED)
	for skill in SKILLS:
		var pts: Array = data.start_skills.get(skill, [0.0, 0.0])
		skills[skill] = [float(pts[0]), float(pts[1])]
	body = StudentVisuals.make_body(data)
	add_child(body)
	_icon = Sprite3D.new()
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.no_depth_test = true
	_icon.render_priority = 5
	_icon.pixel_size = 0.0045
	_icon.position.y = data.gray_height + ICON_HEIGHT
	_icon.visible = false
	add_child(_icon)
	_anim_t = randf() * TAU


# --- Needs ------------------------------------------------------------------------

func lowest_need() -> String:
	var best := ""
	for need in NEEDS:
		if best == "" or needs[need] < needs[best]:
			best = need
	return best


func is_acting_out() -> bool:
	return state in [State.HIDING, State.WANDERING, State.NAPPING]


## Apply one period's changes: changes = {need: [[reason, amount], ...]}.
## Returns the need that just hit 0, or "".
func apply_period(changes: Dictionary) -> String:
	last_changes = changes
	var emptied := ""
	for need in NEEDS:
		var total := 0
		for c in changes.get(need, []):
			total += int(c[1])
		var before: int = needs[need]
		needs[need] = clampi(before + total, 0, MAX_NEED)
		if needs[need] == 0 and emptied == "":
			emptied = need
	_refresh_icon()
	return emptied


func set_need(need: String, value: int) -> void:
	needs[need] = clampi(value, 0, MAX_NEED)
	_refresh_icon()


func _refresh_icon() -> void:
	var need := act_out_need if is_acting_out() else lowest_need()
	var show: bool = is_acting_out() or needs[need] < LOW_NEED
	if not show:
		_icon.visible = false
		_icon_need = ""
		return
	if need != _icon_need:
		_icon_need = need
		_icon.texture = StudentVisuals.mood_icon(need)
		# Pop in so a new icon catches the eye.
		_icon.scale = Vector3.ONE * 0.3
		var tw := create_tween()
		tw.tween_property(_icon, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_icon.visible = true


# --- Moving -----------------------------------------------------------------------

## Walk to a point on the navigation mesh. Returns false if there's no way there.
func walk_to(point: Vector3, new_state := State.WALKING) -> bool:
	var map := get_world_3d().navigation_map
	var goal := NavigationServer3D.map_get_closest_point(map, point)
	goal.y = 0.0
	var path := NavigationServer3D.map_get_path(map, global_position, goal, true)
	if path.is_empty():
		return false
	_path = path
	_path_i = 0
	_goal = goal
	_moving = true
	state = new_state
	return true


## Find the path again (the manager calls this after the navigation mesh changes).
func repath() -> void:
	if _moving:
		walk_to(_goal, state)


func stop() -> void:
	_moving = false
	_path = PackedVector3Array()


func is_moving() -> bool:
	return _moving


func goal() -> Vector3:
	return _goal


func _physics_process(real_delta: float) -> void:
	var delta := real_delta * GameState.sim_scale()   # game speed; 0 when paused
	if not _moving or delta <= 0.0:
		return
	var speed := WANDER_SPEED if state == State.WANDERING else WALK_SPEED
	var step := speed * delta
	while step > 0.0 and _path_i < _path.size():
		var to := _path[_path_i] - global_position
		to.y = 0.0
		var dist := to.length()
		if dist <= step:
			global_position.x = _path[_path_i].x
			global_position.z = _path[_path_i].z
			step -= dist
			_path_i += 1
		else:
			global_position += to / dist * step
			_face(to, delta)
			step = 0.0
	if _path_i >= _path.size():
		_moving = false
		_on_arrived()


func _face(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	var want := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, want, 1.0 - exp(-TURN_RATE * delta))


func face_point(p: Vector3) -> void:
	var d := p - global_position
	if d.length_squared() > 0.0001:
		rotation.y = atan2(d.x, d.z)


func _on_arrived() -> void:
	match state:
		State.WALKING:
			if target_item != null:
				state = State.USING
				activity = "Using the " + target_item.data.display_name
				var c: Vector2 = target_item.center()
				face_point(Vector3(c.x, 0, c.y))
				_hop()
			else:
				state = State.IDLE
				activity = "Looking around"
		State.WANDERING:
			if target_item != null:
				activity = "Playing with the " + target_item.data.display_name + " (bored!)"
				var c: Vector2 = target_item.center()
				face_point(Vector3(c.x, 0, c.y))


# --- Act-outs ---------------------------------------------------------------------

## Start acting out an empty need for `seconds`.
func start_act_out(need: String, seconds: float) -> void:
	stop()
	_clear_prop()
	act_out_need = need
	act_out_left = seconds
	target_item = null
	body.rotation = Vector3.ZERO
	body.position = Vector3.ZERO
	body.scale = Vector3.ONE
	match need:
		"calm":
			state = State.HIDING
			activity = "Hiding under a blanket"
			body.scale = Vector3(0.8, 0.55, 0.8)
			_prop = StudentVisuals.make_blanket()
			add_child(_prop)
			_prop.scale = Vector3.ONE * 0.2
			create_tween().tween_property(_prop, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"fun":
			state = State.WANDERING
			activity = "Wandering off, bored"
		"rest":
			state = State.NAPPING
			activity = "Napping right here"
			var tw := create_tween()
			# Tip over onto one side, keeping the capsule centered where they stood.
			tw.tween_property(body, "rotation:z", PI / 2.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(body, "position", Vector3(data.gray_height / 2.0, 0.27, 0.0), 0.5)
			_prop = StudentVisuals.make_zzz()
			_prop.position.y = 1.0
			add_child(_prop)
	_refresh_icon()


## End the act-out early or on time and recover the need.
func end_act_out() -> void:
	if not is_acting_out():
		return
	var need := act_out_need
	if need == "rest":
		needs["rest"] = clampi(needs["rest"] + REST_RECOVER_GAIN, 0, MAX_NEED)
	else:
		needs[need] = maxi(needs[need], RECOVER_TO[need])
	stop()
	_clear_prop()
	act_out_need = ""
	target_item = null
	state = State.IDLE
	activity = "Feeling better"
	_hopping = true
	var tw := create_tween()
	tw.tween_property(body, "rotation:z", 0.0, 0.25)
	tw.parallel().tween_property(body, "position", Vector3.ZERO, 0.25)
	tw.parallel().tween_property(body, "scale", Vector3.ONE, 0.25)
	tw.tween_callback(_hop)
	_refresh_icon()
	act_out_finished.emit(self)


func _clear_prop() -> void:
	if _prop != null:
		_prop.queue_free()
		_prop = null


# --- Animation --------------------------------------------------------------------

func _process(real_delta: float) -> void:
	var delta := real_delta * GameState.sim_scale()
	_anim_t += delta
	if is_acting_out():
		act_out_left -= delta
		if act_out_left <= 0.0:
			end_act_out()
			return
	match state:
		State.WALKING, State.WANDERING:
			if _moving and not Settings.reduce_motion:
				# Squash-and-stretch hop while walking.
				var s := absf(sin(_anim_t * BOB_RATE))
				body.position.y = s * BOB_HEIGHT
				body.scale = Vector3(1.0 - s * 0.04, 0.96 + s * 0.08, 1.0 - s * 0.04)
			else:
				_breathe()
		State.HIDING:
			if _prop != null:
				_prop.rotation.z = sin(_anim_t * 40.0) * 0.04   # shivering blanket
		State.NAPPING:
			if _prop != null:
				_prop.position.y = 1.0 + fmod(_anim_t * 0.4, 0.5)
				_prop.modulate.a = 1.0 - fmod(_anim_t * 0.4, 0.5) * 1.6
		_:
			_breathe()
			_hop_t -= delta
			if state == State.USING and _hop_t <= 0.0:
				_hop()
	if _icon.visible:
		_icon.position.y = data.gray_height + ICON_HEIGHT + sin(_anim_t * 3.0) * 0.05
		if _icon_need == "calm":
			_icon.position.x = sin(_anim_t * 35.0) * 0.02   # the shaky face shakes


func _breathe() -> void:
	if _hopping:
		return
	var b := sin(_anim_t * 2.2) * 0.025
	body.scale = Vector3(1.0 - b * 0.5, 1.0 + b, 1.0 - b * 0.5)


## A happy little hop (arriving at an item, feeling better).
func _hop() -> void:
	_hop_t = randf_range(2.5, 4.5)
	if Settings.reduce_motion:
		return
	_hopping = true
	var tw := create_tween()
	tw.tween_property(body, "position:y", 0.25, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(body, "position:y", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(body, "scale", Vector3(1.15, 0.85, 1.15), 0.06)
	tw.tween_property(body, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _hopping = false)


# --- Skills -----------------------------------------------------------------------

func solid(skill: String) -> float:
	return skills.get(skill, [0.0, 0.0])[0]


func fresh(skill: String) -> float:
	return skills.get(skill, [0.0, 0.0])[1]


func total(skill: String) -> float:
	return solid(skill) + fresh(skill)


## What the skill counts as in a Dream Test: fresh points count half (Systems doc).
func effective(skill: String) -> float:
	return solid(skill) + fresh(skill) * 0.5


## The student's strongest skill (for the Students list).
func best_skill() -> String:
	var best := SKILLS[0]
	for s in SKILLS:
		if total(s) > total(best):
			best = s
	return best


# --- Words ------------------------------------------------------------------------

## Hover text: name, needs, and why they changed last period.
func hint_text() -> String:
	var parts: Array[String] = []
	for need in NEEDS:
		var low := "  (low)" if needs[need] < LOW_NEED else ""
		parts.append("%s %d%s" % [NEED_NAMES[need], needs[need], low])
	var lines := ["%s  ·  %s  ·  %s" % [data.display_name, data.kind, activity], "  ·  ".join(parts)]
	var why: Array[String] = []
	for need in NEEDS:
		for c in last_changes.get(need, []):
			if int(c[1]) != 0:
				why.append("%s %s%d (%s)" % [NEED_NAMES[need], "+" if c[1] > 0 else "", c[1], c[0]])
	if not why.is_empty():
		lines.append("Last period: " + ", ".join(why))
	lines.append("Test keys while hovering: C, F, Z empty Calm, Fun, Rest")
	return "\n".join(lines)
