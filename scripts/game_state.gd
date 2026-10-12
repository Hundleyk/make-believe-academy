extends Node
## Global game state (autoloaded as GameState). Holds money and discoveries
## so any scene can read them. Grows as more systems arrive.

signal giggles_changed(amount: int)
signal combo_discovered(combo: ComboData)

const STARTING_GIGGLES := 500
const STARTING_TRUST := 5                ## Kids' Trust, 0-10 (Systems doc, Losing)

signal trust_changed(amount: int)
signal speed_changed(speed: int)
signal letter_accepted(letter: LetterData)

var giggles := STARTING_GIGGLES
var discovered_combos: Dictionary = {}   # combo id -> true
var trust := STARTING_TRUST
var speed := 1                           ## 0 paused, 1 normal, 2 fast, 3 fastest
var accepted_letters: Array[LetterData] = []
var researched: Dictionary = {}          # item id -> true once researched (research board comes in M3)


func can_afford(cost: int) -> bool:
	return giggles >= cost


func spend(cost: int) -> bool:
	if cost > giggles:
		return false
	giggles -= cost
	giggles_changed.emit(giggles)
	return true


func earn(amount: int) -> void:
	giggles += amount
	giggles_changed.emit(giggles)


## Game speed for the simulation (students, periods). A big moment pauses it without
## changing the player's chosen speed.
var moment_pause := false

func sim_scale() -> float:
	return 0.0 if moment_pause else float(speed)


func set_speed(s: int) -> void:
	speed = clampi(s, 0, 3)
	speed_changed.emit(speed)


func accept_letter(letter: LetterData) -> void:
	if not accepted_letters.has(letter):
		accepted_letters.append(letter)
		letter_accepted.emit(letter)


## Returns true the first time this combo is found.
func discover_combo(combo: ComboData) -> bool:
	if discovered_combos.has(combo.id):
		return false
	discovered_combos[combo.id] = true
	combo_discovered.emit(combo)
	return true


func reset() -> void:
	giggles = STARTING_GIGGLES
	discovered_combos.clear()
	researched.clear()
	accepted_letters.clear()
	trust = STARTING_TRUST
	speed = 1
	moment_pause = false
	giggles_changed.emit(giggles)
