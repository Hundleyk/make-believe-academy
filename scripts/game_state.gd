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
signal letter_expired(letter: LetterData)
signal day_changed(day: int)
signal ideas_changed(amount: int)

var giggles := STARTING_GIGGLES
var discovered_combos: Dictionary = {}   # combo id -> true
var trust := STARTING_TRUST
var speed := 1                           ## 0 paused, 1 normal, 2 fast, 3 fastest
var accepted_letters: Array[LetterData] = []
var ideas := 0                          ## Spent on the research board (Systems doc, section 15)
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


## The school in play: its save slot (1-3, 0 = none yet), name, and the calendar day.
## Days advance with the day clock (M1 week 4); advance_day() is the hook.
var current_slot := 0
var school_name := ""
var day := 1
var expired_letters: Array[LetterData] = []   ## Requests that ran out of time
const SCHOOL_NAMES := ["Sunny Hollow Academy", "Pillow Peak School", "Maple Street Academy",
	"Blanket Bay School", "Moonbeam Meadow Academy", "Crayon Creek School"]


func advance_day() -> void:
	day += 1
	day_changed.emit(day)


## Days left before a request's deadline (Systems doc, Requests: time limits).
## Unanswered: answer within `answer_days` of arriving. Answered: be ready by Dream Night.
func days_left(letter: LetterData) -> int:
	if accepted_letters.has(letter):
		return letter.dream_day - day
	return letter.arrives_day + letter.answer_days - day


func expire_letter(letter: LetterData) -> void:
	if expired_letters.has(letter):
		return
	expired_letters.append(letter)
	trust = maxi(0, trust - (2 if letter.featured else 1))   # Systems doc: -1 routine, -2 featured
	trust_changed.emit(trust)
	letter_expired.emit(letter)


## Time played in this school (seconds, not counting menus), and when it was last saved.
var play_seconds := 0.0
var last_saved_at := 0                 ## Unix time; 0 = never saved


func _process(delta: float) -> void:
	if not moment_pause:
		play_seconds += delta


func reset() -> void:
	day = 1
	expired_letters.clear()
	school_name = ""
	play_seconds = 0.0
	last_saved_at = 0
	giggles = STARTING_GIGGLES
	ideas = 0
	ideas_changed.emit(ideas)
	discovered_combos.clear()
	researched.clear()
	accepted_letters.clear()
	trust = STARTING_TRUST
	speed = 1
	moment_pause = false
	giggles_changed.emit(giggles)
