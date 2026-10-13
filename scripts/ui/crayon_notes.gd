extends Control
## The objective tracker: the child's note clipped bottom left (mockups 07-10), in crayon handwriting
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
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# The Letter component (components/paper/Letter.jsx): lined paper, cut c, a blue
	# paperclip, a crayon doodle in the corner.
	_paper = W.Notebook.new()
	_paper.custom_minimum_size = Vector2(286, 0)
	# Top left, under the top bar (Two Point keeps objectives there).
	_paper.offset_left = Style.HUD_INSET + 4
	_paper.offset_top = 52 + 22
	_paper.rotation_degrees = -1.5
	_paper.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_paper)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 0)
	_paper.add_child(_lines)
	_paper.add_child(_doodle())
	_paper.add_child(Style.clip(286))
	visible = false
	GameState.day_changed.connect(func(_d):
		if letter != null:
			_draw_notes())
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
	visible = UI.drawer == ""
	for c in _lines.get_children():
		c.queue_free()
	var head := HBoxContainer.new()
	_lines.add_child(head)
	var dear := lined("Dear Academy,", Style.INK, 120)
	dear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(dear)
	var left := GameState.days_left(letter)
	var due := Style.chip("today!" if left <= 0 else "%d day%s left" % [left, "" if left == 1 else "s"], Style.HONEY if left > 2 else Style.PEACH_LIGHT, Style.HONEY_DEEP if left > 2 else Style.HEART, 12, 700)
	due.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	due.rotation_degrees = 3
	due.tooltip_text = "%s's friend has to be ready by Dream Night, day %d." % [letter.child, letter.dream_day]
	due.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_child(due)
	var clip_room := Control.new()   # keep the chip clear of the paperclip
	clip_room.custom_minimum_size.x = 30
	head.add_child(clip_room)
	var cur := current_index()
	for i in letter.notes.size():
		if i > cur and cur != -1:
			break
		var l := lined(letter.notes[i])
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		l.tooltip_text = HOW[i] if i < HOW.size() else ""
		if done[i]:
			l.modulate.a = 0.6
			l.add_child(_strike())
		_lines.add_child(l)
	if cur != -1 and cur < letter.notes.size() - 1:
		_lines.add_child(lined("? ? ?", Style.INK_SOFT))
	if cur == -1:
		_lines.add_child(lined("All done! Now for the dream."))
	var sign := lined("— %s" % letter.child)
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sign.custom_minimum_size.x = 150
	_lines.add_child(sign)


## Handwriting that sits on the paper's rules: 22px Patrick Hand on 33px lines.
static func lined(text: String, color := Style.INK, width := 212.0) -> Label:
	var l := Style.hand_label(text, 22, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	var f := Style.hand()
	l.add_theme_constant_override("line_spacing", int(33 - f.get_height(22)))
	l.custom_minimum_size.y = 33
	return l


## The crayon doodle in a letter's corner: a lavender scribble, a honey star, a coral heart.
static func _doodle() -> Control:
	var o := Style.overlay()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	var holder := Control.new()
	holder.anchor_left = 1.0
	holder.anchor_right = 1.0
	holder.anchor_top = 1.0
	holder.anchor_bottom = 1.0
	holder.offset_left = -18 - 96
	holder.offset_top = -16 - 80
	holder.offset_right = -18
	holder.offset_bottom = -16
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(holder)
	var scribble := W.Icon.new("scribble-loop", 70, Style.LAVENDER, "bold")
	scribble.position = Vector2(0, 10)
	scribble.rotation_degrees = -10
	scribble.modulate.a = 0.9
	holder.add_child(scribble)
	var star := W.Icon.new("star", 34, Style.HONEY, "fill", true)
	star.position = Vector2(62, 0)
	star.rotation_degrees = 12
	holder.add_child(star)
	var heart := W.Icon.new("heart", 22, Style.HEART, "fill")
	heart.position = Vector2(58, 54)
	heart.rotation_degrees = -14
	holder.add_child(heart)
	return o


## A wobbly coral crayon line across a finished note.
func _strike() -> Control:
	var s := Strike.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


class Strike extends Control:
	func _draw() -> void:
		var rows := maxi(1, roundi(size.y / 33.0))   # one strike per wrapped line
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
			draw_polyline(pts, Color("E05A68"), 3.5, true)
