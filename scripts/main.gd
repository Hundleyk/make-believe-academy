extends Node3D
## Graybox scene for Make-Believe Academy.
## Builds the light, a grid floor, three roofless gray rooms, the camera rig, and build mode in code,
## so the scene file stays tiny and every number lives here where it is easy to tune.

const CameraRig := preload("res://scripts/camera_rig.gd")
const BuildMode := preload("res://scripts/build_mode.gd")
const BuildHud := preload("res://scripts/build_hud.gd")

const WALL_HEIGHT := 1.2
const WALL_THICKNESS := 0.2
const DOOR_WIDTH := 2          ## Tiles; every room has a doorway in its front wall
const GROUND_SIZE := Vector2(44, 30)

## The three demo rooms. rect is in grid tiles: Rect2i(x, z, width, depth).
## One tile = one meter. A tile at (x, z) covers x..x+1 and z..z+1.
const ROOMS := [
	{"id": "fort", "name": "Blanket Fort", "rect": Rect2i(-13, -4, 8, 8), "tint": Color("7096BA")},
	{"id": "castle", "name": "Cardboard Castle", "rect": Rect2i(-4, -4, 8, 8), "tint": Color("C48F65")},
	{"id": "dorm", "name": "Pillow Mountain", "rect": Rect2i(5, -4, 8, 8), "tint": Color("7A789B")},
]

const GRID_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(0.46, 0.46, 0.48, 1.0);
uniform vec4 line_color : source_color = vec4(0.34, 0.34, 0.37, 1.0);
uniform float line_strength = 0.7;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 coord = world_pos.xz;
	vec2 grid = abs(fract(coord - 0.5) - 0.5) / fwidth(coord);
	float line = 1.0 - min(min(grid.x, grid.y), 1.0);
	ALBEDO = mix(base_color.rgb, line_color.rgb, line * line_strength);
	ROUGHNESS = 1.0;
}
"""

var camera_rig: Node3D
var build_mode: Node3D
var hud: CanvasLayer
var _grid_shader: Shader


func _ready() -> void:
	_grid_shader = Shader.new()
	_grid_shader.code = GRID_SHADER
	_build_environment()
	_build_ground()
	for room in ROOMS:
		_build_room(room)
	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)

	build_mode = BuildMode.new()
	build_mode.name = "BuildMode"
	build_mode.main = self
	build_mode.camera_rig = camera_rig
	add_child(build_mode)
	hud = BuildHud.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(build_mode)


# --- Rooms --------------------------------------------------------------------

## Returns the room whose floor contains this tile, or an empty Dictionary.
func room_at_tile(tile: Vector2i) -> Dictionary:
	for room in ROOMS:
		if (room.rect as Rect2i).has_point(tile):
			return room
	return {}


func _build_room(room: Dictionary) -> void:
	var rect: Rect2i = room.rect
	var holder := Node3D.new()
	holder.name = String(room.name).replace(" ", "")
	add_child(holder)

	# Floor: a slightly raised grid patch, gray with a faint hint of the room's color.
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(rect.size)
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = _grid_shader
	floor_mat.set_shader_parameter("base_color", Color(0.62, 0.62, 0.62).lerp(room.tint, 0.25))
	floor_mat.set_shader_parameter("line_color", Color(0.45, 0.45, 0.47))
	var floor_node := MeshInstance3D.new()
	floor_node.name = "Floor"
	floor_node.mesh = floor_mesh
	floor_node.material_override = floor_mat
	floor_node.position = Vector3(rect.position.x + rect.size.x / 2.0, 0.01, rect.position.y + rect.size.y / 2.0)
	holder.add_child(floor_node)

	# Walls sit just outside the floor so items can use every edge tile.
	var x0 := float(rect.position.x)
	var x1 := float(rect.end.x)
	var z0 := float(rect.position.y)
	var z1 := float(rect.end.y)
	var t := WALL_THICKNESS
	_add_wall(holder, Vector3(x0 - t, 0, z0 - t), Vector3(x1 + t, 0, z0))   # back
	_add_wall(holder, Vector3(x0 - t, 0, z0), Vector3(x0, 0, z1 + t))       # left
	_add_wall(holder, Vector3(x1, 0, z0), Vector3(x1 + t, 0, z1 + t))       # right
	# Front wall with a doorway in the middle.
	var door_start: float = x0 + floorf((rect.size.x - DOOR_WIDTH) / 2.0)
	var door_end: float = door_start + DOOR_WIDTH
	_add_wall(holder, Vector3(x0 - t, 0, z1), Vector3(door_start, 0, z1 + t))
	_add_wall(holder, Vector3(door_end, 0, z1), Vector3(x1 + t, 0, z1 + t))

	# Room name floating above the back wall.
	var label := Label3D.new()
	label.text = room.name
	label.font_size = 64
	label.pixel_size = 0.007
	label.outline_size = 12
	label.modulate = Color("FFF8E7")
	label.outline_modulate = Color("3B2C24")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3((x0 + x1) / 2.0, WALL_HEIGHT + 0.6, z0)
	holder.add_child(label)


func _add_wall(parent: Node3D, from: Vector3, to: Vector3) -> void:
	var size := Vector3(absf(to.x - from.x), WALL_HEIGHT, absf(to.z - from.z))
	if size.x <= 0.0 or size.z <= 0.0:
		return
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.72, 0.72)
	mat.roughness = 1.0
	var wall := MeshInstance3D.new()
	wall.mesh = box
	wall.material_override = mat
	wall.position = Vector3((from.x + to.x) / 2.0, WALL_HEIGHT / 2.0, (from.z + to.z) / 2.0)
	parent.add_child(wall)


# --- World --------------------------------------------------------------------

func _build_ground() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = GROUND_SIZE
	var mat := ShaderMaterial.new()
	mat.shader = _grid_shader
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = mesh
	ground.material_override = mat
	add_child(ground)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2A2A44")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("FFF1DC")
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("FFE2B8")   # warm evening light
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55, -35, 0)
	add_child(sun)
