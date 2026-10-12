class_name ItemData
extends Resource
## One buildable item. Each item is a .tres file in res://data/items/.
## Fields follow the "Into Godot" section of the Item List doc.
## Every number is a first-pass placeholder to tune after playtesting.

@export var id: StringName
@export var display_name := ""
@export var type := ""                       ## Course item, Light, Comfort, Fun, Decor, ...
## Where it can go: "any", "classroom" (Blanket Fort or Cardboard Castle), or room ids
## ("fort", "castle", "dorm"). Empty means any room.
@export var allowed_rooms := PackedStringArray(["any"])
@export var footprint := Vector2i(1, 1)      ## Tiles (width, depth) before rotating
@export var cost := 0                        ## Giggles
@export var radius := 0                      ## Effect radius in tiles, measured from the item's edge
@export var need_mods := {}                  ## e.g. {"calm": 2, "fun": 1}
@export var focus_mods := {}                 ## e.g. {"listening": 0.15, "lecture": 0.10}
@export var whimsy := 0
@export var unlocks_course := ""
@export var enables_method := ""
## Tags let combos and clashes find items without naming them,
## so new items join existing combos with no code changes.
@export var tags := PackedStringArray()
@export_multiline var effect_text := ""      ## Short line shown in the catalog and hints
@export var buyable := true                  ## False for things you earn (keepsakes); hidden from the Build menu
@export var research_ideas := 0              ## Above 0: locked until researched for this many Ideas
@export var wall_item := false               ## Has to sit on a tile touching a wall (glow stars)
@export var drag_place := false              ## Click and drag places a line of them (partition walls)

@export_group("Graybox look")
@export var gray_color := Color(0.7, 0.7, 0.7)
@export_enum("box", "cylinder", "sphere") var gray_shape := "box"
## Size of the gray shape in meters. Leave at zero to fill the footprint.
@export var gray_size := Vector3.ZERO
@export var gray_height := 0.5
@export var gray_glow := false               ## Adds a small warm light (nightlights)


func fits_room(room_id: String) -> bool:
	if allowed_rooms.is_empty() or allowed_rooms.has("any"):
		return true
	if allowed_rooms.has(room_id):
		return true
	return allowed_rooms.has("classroom") and room_id in ["fort", "castle"]


func room_rule_text() -> String:
	if allowed_rooms.is_empty() or allowed_rooms.has("any"):
		return "any room"
	if allowed_rooms.has("classroom"):
		return "a classroom (Blanket Fort or Cardboard Castle)"
	var names := {"fort": "the Blanket Fort", "castle": "the Cardboard Castle", "dorm": "Pillow Mountain"}
	var parts: Array[String] = []
	for r in allowed_rooms:
		parts.append(names.get(r, r))
	return " or ".join(parts)


## Footprint after turning the item `rot` quarter-turns.
func rotated_footprint(rot: int) -> Vector2i:
	return Vector2i(footprint.y, footprint.x) if rot % 2 == 1 else footprint


## How far the effect reaches from the item's center, in tiles.
func reach(rot: int = 0) -> float:
	if radius <= 0:
		return 0.0
	var fp := rotated_footprint(rot)
	return radius + maxf(fp.x, fp.y) / 2.0
