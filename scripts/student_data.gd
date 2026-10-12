class_name StudentData
extends Resource
## One student (an imaginary friend). Each student is a .tres file in res://data/students/.
## Needs use the 0-10 scale from the Systems doc. Quirks, skills, and personality come later.

@export var id: StringName
@export var display_name := ""
@export var kind := ""                        ## What they are, e.g. "small dragon"
## Needs at the start of the game (0-10). Belonging arrives with buddies in M2.
@export var start_needs := {"calm": 6, "fun": 6, "rest": 6}

@export_group("Graybox look")
@export var gray_color := Color(0.7, 0.7, 0.7)
@export var gray_height := 1.0                ## Capsule height in meters
