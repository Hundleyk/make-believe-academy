extends Control
## The objective tracker: a lined note pinned top right, in the child's crayon handwriting
## (Game Design Doc, Objectives). Done notes get a crayon strike; the next one is live;
## later ones stay hidden as "? ? ?". Checks run on the real game state.

const Style := preload("res://scripts/ui/ui_style.gd")
const W := preload("res://scripts/ui/widgets.gd")
const Readiness := preload("res://scripts/readiness.gd")

## What each of Leo's notes asks, in plain words (shown on hover).
const HOW := [
	"Build a Cardboard Castle. (Done: the Castle is already standing.)",
	"Place the Tamed Closet Monster in the Cardboard Castle (Build menu, Cardboard Castle tab).",
	"Put a Nightlight where Pip, the student afraid of the dark, stands in its glow.",
	"Schedule Monster Defense on the Timetable. (The Timetable arrives in M1 week 4.)",
	"Get any student to Bravery 3 in the dream (solid points plus half the fresh ones).",
]

var hud: CanvasLayer
var letter: LetterData
var done := []           # bool per note
var _paper: PanelContainer
var _lines: VBoxContainer
var _timer := 0.0


func setup(the_hud: CanvasLayer) -> void:
	hud = the_hud
	name = "CrayonNotes"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 0)
	_paper = W.Notebook.new(26, 40, 22)
	_paper.custom_minimum_size = Vector2(290, 0)
	_paper.position = Vector2(-318, 104)
	_paper.rotation_degrees = -1.2
	_paper.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_paper)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 0)
	_paper.add_child(_lines)
	_paper.add_child(Style.tape(110, 3))
	visible = false
	GameState.letter_accepted.connect(func(l):
		if letter == null:
			letter = l
			done = []
			for i in l.notes.size():
				done.append(false)
			_check(true))
	if not GameState.accepted_letters.is_empty():
		letter = GameState.accepted_letters[0]
		for i in letter.notes.size():
			done.append(false)
		_check(true)


func _process(delta: float) -> void:
	if letter == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		_check(false)


## Re-test every note; toast and redraw when one gets checked off.
func _check(force: bool) -> void:
	var changed := force
	for i in letter.notes.size():
		if not done[i] and is_done(i):
			done[i] = true
			changed = true
			if not force:
				UI.toast("%s's note checked off!" % letter.child, letter.notes[i])
	if changed:
		_draw_notes()


func is_done(i: int) -> bool:
	var main: Node3D = hud.main
	match i:
		0:
			return not main.room_by_id("castle").is_empty()
		1:
			for p in hud.build_mode.items_in_room("castle"):
				if p.data.id == &"tamed_closet_monster":
					return true
			return false
		2:
			for s in hud.students.students:
				if s.data.quirk == "Afraid of the dark":
					for p in hud.students.items_in_range(s):
						if p.data.tags.has("nightlight"):
							return true
			return false
		3:
			return false   # needs the Timetable (week 4)
		4:
			for s in hud.students.students:
				if s.effective(letter.skill) >= letter.level:
					return true
			return false
	return false


func current_index() -> int:
	for i in done.size():
		if not done[i]:
			return i
	return -1


func _draw_notes() -> void:
	visible = UI.drawer != "requests"
	for c in _lines.get_children():
		c.queue_free()
	_lines.add_child(Style.hand_label("%s's notes" % letter.child, 16, Style.CRAYON_PURPLE))
	var cur := current_index()
	for i in letter.notes.size():
		if i > cur and cur != -1:
			break
		var l := Style.hand_label(letter.notes[i], 19, Style.NIGHT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 240
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		l.tooltip_text = HOW[i] if i < HOW.size() else ""
		if done[i]:
			l.modulate.a = 0.6
			l.add_child(_strike())
		_lines.add_child(l)
	if cur != -1 and cur < letter.notes.size() - 1:
		_lines.add_child(Style.hand_label("? ? ?", 19, Color(Style.NIGHT, 0.4)))
	if cur == -1:
		_lines.add_child(Style.hand_label("All done! Now for the dream.", 19, Style.CRAYON_PURPLE))


## A wobbly coral crayon line across a finished note.
func _strike() -> Control:
	var s := Strike.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


class Strike extends Control:
	func _draw() -> void:
		var rows := maxi(1, roundi(size.y / 24.0))   # one strike per wrapped line
		for r in rows:
			var y := (r + 0.55) * size.y / rows
			var pts := PackedVector2Array()
			var x := 0.0
			var i := 0
			while x < size.x:
				pts.append(Vector2(x, y + (1.5 if i % 2 == 0 else -1.5)))
				x += 14.0
				i += 1
			pts.append(Vector2(size.x, y))
			draw_polyline(pts, Color("E05A68"), 3.0, true)
