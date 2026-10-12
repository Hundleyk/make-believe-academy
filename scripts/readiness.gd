extends RefCounted
## How ready a student is for a child's request, in words (Systems doc: the Dream Test's
## readiness meter, and Matching). Shown on trading cards and in the Requests panel.

## Chance to pass by how far the student's effective level is below the request.
const CHANCE := {0: 0.9, 1: 0.5, 2: 0.15}
const WORDS := {0: "Very likely", 1: "Maybe", 2: "Unlikely"}
## Personality pairs (Systems doc, Matching): child's hint -> best friend trait, clash.
const CLASH := {"Worried": "Thoughtful", "Shy": "Goofy", "Bouncy": "Gentle", "Curious": "Bold"}


## {word, chance, steps_short, effective, reasons: [[kind, text]]}; kind = ok, bad, warn.
static func check(s: Node3D, letter: LetterData) -> Dictionary:
	var eff: float = s.effective(letter.skill)
	var level := floori(eff + 0.0001)
	var short := maxi(0, letter.level - level)
	var steps := mini(short, 2)
	var reasons := []
	var skill_name := letter.skill_name()
	if short == 0:
		reasons.append(["ok", "%s %.1f in the dream: meets %s %d" % [skill_name, eff, skill_name, letter.level]])
	else:
		var fresh_note := " (fresh points count half)" if s.fresh(letter.skill) > 0.0 else ""
		reasons.append(["bad", "%s counts as %.1f in the dream%s: %s short" % [
			skill_name, eff, fresh_note, "one level" if short == 1 else "%d levels" % short]])
	if s.data.personality == letter.best_trait:
		reasons.append(["ok", "%s: a good pair for a %s child" % [s.data.personality, letter.seems.to_lower()]])
	elif CLASH.get(letter.seems, "") == s.data.personality:
		reasons.append(["bad", "%s clashes with a %s child" % [s.data.personality, letter.seems.to_lower()]])
	else:
		reasons.append(["warn", "%s: not the best pair (%s is)" % [s.data.personality, letter.best_trait]])
	if s.needs["calm"] < 3:
		steps = mini(steps + 1, 2)
		reasons.append(["warn", "Calm %d: low Calm lowers the chance one step" % s.needs["calm"]])
	return {"word": WORDS[steps], "chance": CHANCE[steps], "steps_short": short, "effective": eff, "reasons": reasons}
