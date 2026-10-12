extends Node
## Global game state (autoloaded as GameState). Holds money and discoveries
## so any scene can read them. Grows as more systems arrive.

signal giggles_changed(amount: int)
signal combo_discovered(combo: ComboData)

const STARTING_GIGGLES := 500

var giggles := STARTING_GIGGLES
var discovered_combos: Dictionary = {}   # combo id -> true
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
	giggles_changed.emit(giggles)
