extends Node3D
## Angled management-sim camera.
## WASD or arrow keys pan, mouse wheel zooms, Q and E rotate.
## The rig sits on the ground; the camera hangs above and behind it, looking down.

@export var pan_speed := 12.0          ## Tiles per second at the default zoom
@export var rotate_speed := 90.0       ## Degrees per second while Q or E is held
@export var zoom_min := 6.0
@export var zoom_max := 36.0
@export var zoom_step := 1.5
@export var start_zoom := 26.0
@export var pitch_degrees := -50.0     ## How steeply the camera looks down
@export var bounds := Rect2(-18, -12, 36, 24)  ## How far the view can pan (x, z)

var camera: Camera3D
var _zoom := 26.0
var _target_zoom := 26.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 40.0
	add_child(camera)
	_zoom = start_zoom
	_target_zoom = start_zoom
	_apply_zoom()


func _process(delta: float) -> void:
	# Pan relative to the way the camera is facing.
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input.x += 1.0
	if input != Vector2.ZERO:
		input = input.normalized()
		var right := global_transform.basis.x
		var back := global_transform.basis.z
		right.y = 0.0
		back.y = 0.0
		var move := right.normalized() * input.x + back.normalized() * input.y
		position += move * pan_speed * (_zoom / start_zoom) * delta
		position.x = clampf(position.x, bounds.position.x, bounds.end.x)
		position.z = clampf(position.z, bounds.position.y, bounds.end.y)

	# Rotate around the point the camera looks at.
	var turn := 0.0
	if Input.is_physical_key_pressed(KEY_Q):
		turn -= 1.0
	if Input.is_physical_key_pressed(KEY_E):
		turn += 1.0
	rotation.y += deg_to_rad(rotate_speed) * turn * delta

	# Ease toward the target zoom so the wheel feels smooth.
	if not is_equal_approx(_zoom, _target_zoom):
		_zoom = lerpf(_zoom, _target_zoom, 1.0 - exp(-12.0 * delta))
		_apply_zoom()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clampf(_target_zoom - zoom_step, zoom_min, zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clampf(_target_zoom + zoom_step, zoom_min, zoom_max)


func _apply_zoom() -> void:
	var tilt := deg_to_rad(-pitch_degrees)
	camera.position = Vector3(0.0, sin(tilt) * _zoom, cos(tilt) * _zoom)
	camera.rotation = Vector3(deg_to_rad(pitch_degrees), 0.0, 0.0)


## Glide the view over to a point (the Build menu does this when you pick a room tab).
func focus_on(point: Vector3) -> void:
	var to := Vector3(clampf(point.x, bounds.position.x, bounds.end.x), 0.0, clampf(point.z, bounds.position.y, bounds.end.y))
	var tw := create_tween()
	tw.tween_property(self, "position", to, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Where a point on the screen hits the floor (y = 0). Returns null if it misses.
func screen_to_ground(screen_pos: Vector2) -> Variant:
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	return Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
