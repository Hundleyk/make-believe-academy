extends Node
## Player settings (autoloaded as Settings), saved to user://settings.cfg between sessions.
## Laid out like the Settings mockup (03): Audio, Video, Gameplay, Controls. Accessibility
## settings from the Game Design Doc: readable font, UI size, gentle motion.

signal changed

const PATH := "user://settings.cfg"
const UI_SCALES := [1.0, 1.15, 1.3]
const WINDOW_MODES := ["windowed", "borderless", "fullscreen"]

# Audio
var master_volume := 80          ## 0-100, the Master bus
var music_volume := 60           ## 0-100, the Music bus (audio pass, M4)
var sfx_volume := 70             ## 0-100, the SFX bus (audio pass, M4)
var babble_volume := 45          ## 0-100, monster voices (audio pass, M4)
var subtitles := true            ## Show what monsters say
# Video
var window_mode := "windowed"    ## windowed, borderless, fullscreen
var vsync := true
var ui_scale := 1.0              ## Makes all UI bigger
# Gameplay
var teacher_hints := true        ## The hint slip above the bottom menu
var reduce_motion := false       ## "Gentle Motion": fewer bounces and wiggles
var readable_font := false       ## Swap every font for Atkinson Hyperlegible
var edge_scroll := false         ## Move the camera at the screen edges
var camera_speed := 1.0          ## Multiplies camera pan speed (0.5 to 2)

## Every setting with its default and its section in the file.
const DEFAULTS := {
	"master_volume": 80, "music_volume": 60, "sfx_volume": 70, "babble_volume": 45, "subtitles": true,
	"window_mode": "windowed", "vsync": true, "ui_scale": 1.0,
	"teacher_hints": true, "reduce_motion": false, "readable_font": false, "edge_scroll": false, "camera_speed": 1.0,
}
const SECTIONS := {
	"master_volume": "audio", "music_volume": "audio", "sfx_volume": "audio", "babble_volume": "audio", "subtitles": "audio",
	"window_mode": "video", "vsync": "video", "ui_scale": "video",
	"teacher_hints": "gameplay", "reduce_motion": "gameplay", "readable_font": "gameplay", "edge_scroll": "gameplay", "camera_speed": "gameplay",
}


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in DEFAULTS:
			set(k, cf.get_value(SECTIONS[k], k, DEFAULTS[k]))
		# Older files kept fullscreen as a switch.
		if cf.get_value("display", "fullscreen", false):
			window_mode = "fullscreen"
	apply()


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in DEFAULTS:
		cf.set_value(SECTIONS[k], k, get(k))
	cf.save(PATH)


## Change several settings at once (the Settings screen's Apply), then apply and save.
func set_values(values: Dictionary) -> void:
	for k in values:
		set(k, values[k])
	apply()
	save_settings()


## The current value of every setting, by name.
func snapshot() -> Dictionary:
	var out := {}
	for k in DEFAULTS:
		out[k] = get(k)
	return out


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
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.001) / 100.0))
	AudioServer.set_bus_mute(0, master_volume <= 0)
	for bus in [["Music", music_volume], ["SFX", sfx_volume], ["Babble", babble_volume]]:
		var i := AudioServer.get_bus_index(bus[0])
		if i != -1:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(bus[1], 0.001) / 100.0))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		var mode := DisplayServer.WINDOW_MODE_WINDOWED
		var borderless := false
		match window_mode:
			"fullscreen":
				mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			"borderless":
				mode = DisplayServer.WINDOW_MODE_FULLSCREEN
				borderless = true
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, borderless)
	changed.emit()


func reset() -> void:
	for k in DEFAULTS:
		set(k, DEFAULTS[k])
	apply()
	save_settings()
