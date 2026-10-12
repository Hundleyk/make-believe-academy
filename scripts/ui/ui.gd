extends Node
## The UI manager (autoloaded as UI). It owns which drawer and card are open, the toast
## queue, and what Esc does, so panels never fight (UI System doc, "In Godot").
##
## Esc and right-click back out one step at a time: stop holding an item (build mode
## handles that), then close the card, then close the drawer, then open the pause screen.

signal drawer_changed(id: String)        ## "" when none is open
signal card_changed(student: Node3D)     ## null when closed
signal toast_queued
signal screen_changed(id: String)        ## "pause", "settings", "letter", or ""

var drawer := ""                         ## build, students, requests, or ""
var card_student: Node3D = null
var screen := ""                         ## a full-screen moment or menu is open
var skip_intro := false                  ## tests set this so Leo's letter doesn't pop up
var toasts: Array = []                   ## [title, body, flavor]


## True while a full-screen moment or menu is open: the world ignores clicks and keys.
func blocking() -> bool:
	return screen != ""


func open_drawer(id: String) -> void:
	if drawer == id:
		return
	drawer = id
	if id != "students" and id != "requests":
		close_card()
	drawer_changed.emit(id)


func toggle_drawer(id: String) -> void:
	if drawer == id:
		close_drawer()
	else:
		open_drawer(id)


func close_drawer() -> void:
	if drawer == "":
		return
	drawer = ""
	close_card()
	drawer_changed.emit("")


func open_card(student: Node3D) -> void:
	card_student = student
	card_changed.emit(student)


func close_card() -> void:
	if card_student == null:
		return
	card_student = null
	card_changed.emit(null)


## Open a full-screen moment or menu. Moments pause the simulation.
func open_screen(id: String) -> void:
	screen = id
	GameState.moment_pause = id != ""
	screen_changed.emit(id)


func close_screen() -> void:
	open_screen("")
	_release_toasts()


## One step back. Returns true if something closed.
func back() -> bool:
	if screen == "settings":
		open_screen("pause")
		return true
	if screen != "":
		close_screen()
		return true
	if card_student != null:
		close_card()
		return true
	if drawer != "":
		close_drawer()
		return true
	open_screen("pause")
	return true


func toast(title: String, body := "", flavor := "") -> void:
	toasts.append([title, body, flavor])
	if not blocking():
		toast_queued.emit()


func _release_toasts() -> void:
	if not toasts.is_empty():
		toast_queued.emit()


func reset() -> void:
	drawer = ""
	card_student = null
	screen = ""
	toasts.clear()
	GameState.moment_pause = false
