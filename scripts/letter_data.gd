class_name LetterData
extends Resource
## One child's request: the letter (the heart) and the Department form under it (the data).
## Each is a .tres file in res://data/letters/. Text comes from the Child Letters doc.

@export var id: StringName
@export var child := ""
@export var age := 0
@export var neighborhood := ""
@export var featured := true                 ## Featured letters have a dream and a hidden need
@export var arrives_day := 1
@export_multiline var body := ""             ## The letter, in the child's words
@export_multiline var ps := ""               ## The P.S. that hints at the hidden need
@export var skill := "bravery"               ## bravery, listening, silliness
@export var level := 3
@export var problem := ""                   ## The form's PROBLEM line, short ("room too dark")
@export var wants := ""                     ## The form's NEEDS line, in the child's words ("someone brave")
@export var seems := ""                      ## Personality hint on the form (Worried, Shy, Bouncy)
@export var best_trait := ""                 ## The friend personality that pairs well
@export var pays_great := 150
@export var pays_okay := 80
@export var dream_day := 7                   ## Dream Night: the friend must be ready by then
@export var answer_days := 3                 ## Days to answer the letter before it's gone (Trust -1)
@export var course := ""                     ## The course that teaches the skill
## Leo's crayon notes: the chapter objectives, in his voice (Game Design Doc, Objectives).
@export var notes: Array[String] = []


func skill_name() -> String:
	return skill.capitalize()
