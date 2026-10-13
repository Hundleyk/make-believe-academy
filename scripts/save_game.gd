extends RefCounted
## Save and load (three slots, JSON in user://saves/). A save keeps the placed items,
## the students' needs, skills and spots, Giggles, Kids' Trust, combos found, research,
## accepted letters, the period, and the camera.

const DIR := "user://saves"
const SLOTS := 3
const VERSION := 1


static func path(slot: int) -> String:
	return "%s/slot_%d.json" % [DIR, slot]


static func thumb_path(slot: int) -> String:
	return "%s/slot_%d.png" % [DIR, slot]


## The slot's picture of the school, or null.
static func thumbnail(slot: int) -> Texture2D:
	if not FileAccess.file_exists(thumb_path(slot)):
		return null
	var img := Image.load_from_file(thumb_path(slot))
	return ImageTexture.create_from_image(img) if img != null else null


static func delete(slot: int) -> void:
	for p in [path(slot), thumb_path(slot)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## "3h 12m" or "14m".
static func playtime(seconds: float) -> String:
	var m := int(seconds / 60.0)
	return "%dh %02dm" % [m / 60, m % 60] if m >= 60 else "%dm" % m


static func exists(slot: int) -> bool:
	return FileAccess.file_exists(path(slot))


## The newest save, or -1 when there are none (the title screen's Continue button).
static func newest_slot() -> int:
	var best := -1
	var best_t := -1
	for slot in range(1, SLOTS + 1):
		var info := read_info(slot)
		if not info.is_empty() and int(info.get("saved_at", 0)) > best_t:
			best_t = int(info.saved_at)
			best = slot
	return best


static func read_info(slot: int) -> Dictionary:
	if not exists(slot):
		return {}
	var f := FileAccess.open(path(slot), FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


## `picture` (optional) is a screenshot of the school for the Load School card.
static func save(main: Node3D, slot: int, picture: Image = null) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var bm: Node3D = main.build_mode
	var st: Node3D = main.students
	var items := []
	for p in bm.placed:
		items.append({"id": String(p.data.id), "x": p.origin.x, "z": p.origin.y, "rot": p.rot})
	var studs := []
	for s in st.students:
		studs.append({"id": String(s.data.id), "x": s.global_position.x, "z": s.global_position.z,
			"needs": s.needs, "skills": s.skills})
	var letters := []
	for l in GameState.accepted_letters:
		letters.append(String(l.id))
	var data := {
		"version": VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"school": GameState.school_name if GameState.school_name != "" else "Make-Believe Academy",
		"day": GameState.day,
		"expired": GameState.expired_letters.map(func(l): return String(l.id)),
		"play_seconds": GameState.play_seconds,
		"period": st.period,
		"period_left": st.period_left,
		"giggles": GameState.giggles,
		"trust": GameState.trust,
		"speed": GameState.speed,
		"combos": GameState.discovered_combos.keys().map(func(k): return String(k)),
		"researched": GameState.researched.keys().map(func(k): return String(k)),
		"letters": letters,
		"items": items,
		"students": studs,
		"camera": {"x": main.camera_rig.position.x, "z": main.camera_rig.position.z, "turn": main.camera_rig.rotation.y},
	}
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	GameState.last_saved_at = int(data.saved_at)
	GameState.current_slot = slot
	if picture != null:
		var img := picture.duplicate() as Image
		img.resize(384, int(384.0 * img.get_height() / maxf(img.get_width(), 1.0)), Image.INTERPOLATE_BILINEAR)
		img.save_png(thumb_path(slot))
	return true


static func load_into(main: Node3D, slot: int) -> bool:
	var data := read_info(slot)
	if data.is_empty():
		return false
	var bm: Node3D = main.build_mode
	var st: Node3D = main.students
	bm.stop_holding()
	bm.set_sell_mode(false)
	bm.clear_all()
	var by_id := {}
	for d in bm.catalog:
		by_id[String(d.id)] = d
	GameState.giggles = 1000000   # placing re-spends prices; the saved total is set after
	for it in data.get("items", []):
		var d: ItemData = by_id.get(it.id)
		if d != null:
			bm.place(d, Vector2i(int(it.x), int(it.z)), int(it.rot), false)
	GameState.giggles = int(data.get("giggles", GameState.STARTING_GIGGLES))
	GameState.trust = int(data.get("trust", GameState.STARTING_TRUST))
	GameState.play_seconds = float(data.get("play_seconds", 0.0))
	GameState.last_saved_at = int(data.get("saved_at", 0))
	GameState.current_slot = slot
	GameState.school_name = String(data.get("school", "Make-Believe Academy"))
	GameState.day = int(data.get("day", 1))
	GameState.expired_letters.clear()
	for lid in data.get("expired", []):
		for l in main.letters:
			if String(l.id) == lid:
				GameState.expired_letters.append(l)
	GameState.discovered_combos.clear()
	for c in data.get("combos", []):
		GameState.discovered_combos[StringName(c)] = true
	GameState.researched.clear()
	for r in data.get("researched", []):
		GameState.researched[StringName(r)] = true
	GameState.accepted_letters.clear()
	for lid in data.get("letters", []):
		for l in main.letters:
			if String(l.id) == lid:
				GameState.accepted_letters.append(l)
	st.period = int(data.get("period", 1))
	st.period_left = float(data.get("period_left", st.period_seconds))
	for sd in data.get("students", []):
		for s in st.students:
			if String(s.data.id) == sd.id:
				if s.is_acting_out():
					s.end_act_out()
				s.stop()
				s.target_item = null
				s.global_position = Vector3(float(sd.x), 0.0, float(sd.z))
				for need in sd.needs:
					s.set_need(need, int(sd.needs[need]))
				for skill in sd.skills:
					var pts: Array = sd.skills[skill]
					s.skills[skill] = [float(pts[0]), float(pts[1])]
				s.state = s.State.IDLE
				s.activity = "Looking around"
	var cam: Dictionary = data.get("camera", {})
	if not cam.is_empty():
		main.camera_rig.position = Vector3(float(cam.x), 0.0, float(cam.z))
		main.camera_rig.rotation.y = float(cam.get("turn", 0.0))
	GameState.set_speed(int(data.get("speed", 1)))
	GameState.giggles_changed.emit(GameState.giggles)
	GameState.trust_changed.emit(GameState.trust)
	for l in GameState.accepted_letters:
		GameState.letter_accepted.emit(l)
	return true


## "Oct 12, 6:45 PM" in the player's own time zone.
static func when(unix: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(unix + bias)
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var h: int = d.hour % 12
	return "%s %d, %d:%02d %s" % [months[d.month - 1], d.day, 12 if h == 0 else h, d.minute, "PM" if d.hour >= 12 else "AM"]
