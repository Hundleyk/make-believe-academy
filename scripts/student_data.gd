class_name StudentData
extends Resource
## One student (an imaginary friend). Each student is a .tres file in res://data/students/.
## Needs use the 0-10 scale from the Systems doc. Quirks, skills, and personality come later.

@export var id: StringName
@export var display_name := ""
@export var kind := ""                        ## What they are, e.g. "small dragon"
## Needs at the start of the game (0-10). Belonging arrives with buddies in M2.
@export var start_needs := {"calm": 6, "fun": 6, "rest": 6}

@export_group("Skills and personality")
## Starting skill points per skill: [solid, fresh]. Solid points stay; fresh ones fade
## (Systems doc, learning model). Teaching in week 4 adds to these.
@export var start_skills := {"bravery": [0.0, 0.0], "listening": [0.0, 0.0], "silliness": [0.0, 0.0]}
@export var personality := ""                ## Bold, Gentle, Goofy, Thoughtful
@export var quirk := ""                      ## Shown on the trading card
@export_multiline var quirk_text := ""
@export var learning_pace := "Steady"        ## Steady, Quick but leaky, Slow and sure
@export var horns := false                   ## Graybox portrait detail (dragon)

@export_group("Graybox look")
@export var gray_color := Color(0.7, 0.7, 0.7)
@export var gray_height := 1.0                ## Capsule height in meters
