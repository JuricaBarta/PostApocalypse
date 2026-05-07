extends Node

const SETTINGS_PATH = "user://display.sav"

const RESOLUTIONS := [
	Vector2i(1280,  720),
	Vector2i(1600,  900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3440, 1440),
	Vector2i(3840, 2160),
]

# stretch_mode: 0=keep (black bars), 1=expand (više mape vidljivo)
var pixel_perfect:     bool = false
var fullscreen:        bool = false
var stretch_mode:      int  = 1   # default: Expand
var resolution_index:  int  = 0

func _ready():
	_load_settings()
	_apply_all()

# ─────────────────────────────────────────────
#  PUBLIC API
# ─────────────────────────────────────────────
func set_pixel_perfect(enabled: bool):
	pixel_perfect = enabled
	_apply_scale_stretch()
	_save_settings()

func set_stretch_mode(mode: int):
	stretch_mode = clamp(mode, 0, 2)
	_apply_stretch_mode()
	_save_settings()

func set_resolution(index: int):
	resolution_index = clamp(index, 0, RESOLUTIONS.size() - 1)
	if not fullscreen:
		_apply_resolution()
	_save_settings()

func set_fullscreen(enabled: bool):
	fullscreen = enabled
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_apply_resolution()
	_save_settings()

# ─────────────────────────────────────────────
#  INTERNAL APPLY
# ─────────────────────────────────────────────
func _apply_all():
	_apply_scale_stretch()
	_apply_stretch_mode()
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		_apply_resolution()

func _apply_scale_stretch():
	get_tree().root.content_scale_stretch = (
		Window.CONTENT_SCALE_STRETCH_INTEGER if pixel_perfect
		else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	)

func _apply_stretch_mode():
	var root = get_tree().root
	match stretch_mode:
		0: root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		1: root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

func _apply_resolution():
	var res = RESOLUTIONS[resolution_index]
	DisplayServer.window_set_size(res)
	var screen := DisplayServer.screen_get_size()
	DisplayServer.window_set_position(Vector2i(
		(screen.x - res.x) / 2,
		(screen.y - res.y) / 2
	))

# ─────────────────────────────────────────────
#  SAVE / LOAD
# ─────────────────────────────────────────────
func _save_settings():
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_var({
			"pixel_perfect":    pixel_perfect,
			"fullscreen":       fullscreen,
			"stretch_mode":     stretch_mode,
			"resolution_index": resolution_index,
		})
		file.close()

func _load_settings():
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file:
		var data = file.get_var()
		file.close()
		if data is Dictionary:
			pixel_perfect    = data.get("pixel_perfect",    false)
			fullscreen       = data.get("fullscreen",       false)
			stretch_mode     = data.get("stretch_mode",     1)
			resolution_index = data.get("resolution_index", 0)
