extends Node
## Player settings (autoloaded as Settings), saved to user://settings.cfg between sessions.
## Accessibility settings from the Game Design Doc: readable font, UI scale, reduce motion.

signal changed

const PATH := "user://settings.cfg"
const UI_SCALES := [1.0, 1.15, 1.3]

var readable_font := false       ## Swap every font for Atkinson Hyperlegible
var ui_scale := 1.0              ## Makes all UI bigger
var reduce_motion := false       ## No wobbles, hops, or bobbing
var fullscreen := false
var camera_speed := 1.0          ## Multiplies camera pan speed (0.5 to 2)

var _loading := false


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		readable_font = cf.get_value("access", "readable_font", false)
		ui_scale = cf.get_value("access", "ui_scale", 1.0)
		reduce_motion = cf.get_value("access", "reduce_motion", false)
		fullscreen = cf.get_value("display", "fullscreen", false)
		camera_speed = cf.get_value("controls", "camera_speed", 1.0)
	apply()


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("access", "readable_font", readable_font)
	cf.set_value("access", "ui_scale", ui_scale)
	cf.set_value("access", "reduce_motion", reduce_motion)
	cf.set_value("display", "fullscreen", fullscreen)
	cf.set_value("controls", "camera_speed", camera_speed)
	cf.save(PATH)


## Change one setting by name, apply it, and save.
func set_value(key: String, value: Variant) -> void:
	set(key, value)
	apply()
	save_settings()


func apply() -> void:
	var Style = load("res://scripts/ui/ui_style.gd")
	Style.readable_font = readable_font
	Style._fonts.clear()
	var root := get_tree().root
	root.content_scale_factor = ui_scale
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	changed.emit()


func reset() -> void:
	readable_font = false
	ui_scale = 1.0
	reduce_motion = false
	fullscreen = false
	camera_speed = 1.0
	apply()
	save_settings()
