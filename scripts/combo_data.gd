class_name ComboData
extends Resource
## A combo: a set of items that give a bonus when they sit within each other's radius.
## Each combo is a .tres file in res://data/combos/.

@export var id: StringName
@export var display_name := ""
## One placed item is needed per entry. Repeat a tag to need several
## (Tea for Two would be ["tea_set", "cushion", "cushion"]).
@export var required_tags := PackedStringArray()
@export var need_mods := {}
@export var focus_mods := {}
@export var bonus_text := ""                 ## Shown in the discovery popup
@export_multiline var flavor_text := ""
