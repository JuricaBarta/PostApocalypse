extends Node

signal level_complete

@export var spaceship_scene: PackedScene
@export var teleport_circle_scene: PackedScene

@onready var wave_manager: Node2D = $"../WaveManager"
@onready var player: Node2D = $"../Player"
@onready var camera: Camera2D = $"../Player/Camera2D"
@onready var pause_menu = $"../PauseMenu"
@onready var slot_machine = $"../UI/SlotMachine"
@onready var map = $"../Map"

const MAP_W_PX := 4480.0
const MAP_H_PX := 4480.0
const MAP_CENTER := Vector2(MAP_W_PX * 0.5, MAP_H_PX * 0.5)
const SHIP_LAND_OFFSET := Vector2(0, -120)
const CIRCLE_LAND_OFFSET := Vector2(0, 100)
const OUTRO_TIMEOUT := 30.0

var _spaceship: Node2D = null
var _teleport_circle: Node2D = null
var _arrow: Node2D = null
var _outro_timer := 0.0
var _outro_active := false
var _warning_label: Label = null
var _warning_tween: Tween = null

func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	
	var p = get_parent().get_node_or_null("Player")
	if p:
		GameManager.restore_player_state(p)
	
	wave_manager.wave_completed.connect(_on_wave_completed, CONNECT_ONE_SHOT)
	wave_manager.spaceship_warning.connect(_on_spaceship_warning)
	start_intro()
	
func _on_spaceship_warning() -> void:
	print("=== SPACESHIP WARNING - 30s LEFT ===")
	start_outro()

# ===================== WAVE DONE =====================

func _on_wave_completed() -> void:
	start_outro()

# ===================== INTRO =====================

func start_intro() -> void:
	player.visible = false
	player.set_physics_process(false)

	_spaceship = spaceship_scene.instantiate()
	get_parent().add_child(_spaceship)

	# Sigurna pozicija blizu centra mape
	var safe_pos = map.find_safe_position(MAP_CENTER, 0.0, 200.0)
	var land_pos = safe_pos + SHIP_LAND_OFFSET

	_follow_spaceship(true)
	_spaceship.landing_complete.connect(_on_intro_landed.bind(land_pos, safe_pos), CONNECT_ONE_SHOT)
	_spaceship.do_intro(land_pos)

func _on_intro_landed(land_pos: Vector2, safe_pos: Vector2) -> void:
	_teleport_circle = teleport_circle_scene.instantiate()
	_teleport_circle.global_position = safe_pos + CIRCLE_LAND_OFFSET
	_teleport_circle.wait_duration = 0.1
	get_parent().add_child(_teleport_circle)
	_teleport_circle.activate()

	player.global_position = _teleport_circle.global_position
	player.visible = true
	player.modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(player, "modulate:a", 1.0, 0.6)
	await tween.finished

	_finish_intro(land_pos)

func _finish_intro(_land_pos: Vector2) -> void:
	_follow_spaceship(false)

	if is_instance_valid(_teleport_circle):
		var tw = create_tween()
		tw.tween_property(_teleport_circle, "modulate:a", 0.0, 0.8)
		await tw.finished
		_teleport_circle.queue_free()
		_teleport_circle = null

	if is_instance_valid(_spaceship):
		_spaceship.departure_complete.connect(_on_intro_departure_done, CONNECT_ONE_SHOT)
		_spaceship.do_outro(_spaceship.global_position)

func _on_intro_departure_done() -> void:
	if is_instance_valid(_spaceship):
		_spaceship.queue_free()
	_spaceship = null

	_maybe_spawn_bonus_scrap()
	player.set_physics_process(true)
	wave_manager.wave_active = true

func _maybe_spawn_bonus_scrap() -> void:
	if randf() > 0.65:
		return
	# Odaberi tip scrapa po trenutnom levelu (bolji scrap na višim levelima)
	var lvl = GameManager.current_level
	var scrap_options := [
		[7, 8],   # circuit  (level 1-2)
		[7, 8],
		[9, 10],  # biogel   (level 3-4)
		[9, 10],
		[11, 12], # powercell (level 5)
		[11, 12], # powercell (level 6)
		[13, 14], # nanochip  (boss)
	]
	var type_pair = scrap_options[clampi(lvl, 0, scrap_options.size() - 1)]
	var scrap_id = type_pair[randi_range(0, 1)]
	# Nasumična pozicija daleko od centra (gdje je spawn)
	var clump_pos = map.find_safe_position(MAP_CENTER, 600.0, 1600.0)
	map.spawn_scrap_clump(clump_pos, scrap_id, 5)

# ===================== OUTRO =====================

func start_outro() -> void:
	_outro_active = true

	# Sigurna random pozicija na mapi – ne blizu centra
	var safe_pos = map.find_safe_position(MAP_CENTER, 800.0, 1800.0)
	var land_pos = safe_pos + SHIP_LAND_OFFSET

	_spaceship = spaceship_scene.instantiate()
	get_parent().add_child(_spaceship)
	_spaceship.landing_complete.connect(_on_outro_landed.bind(land_pos, safe_pos), CONNECT_ONE_SHOT)
	_spaceship.do_intro(land_pos)

	_show_warning("⚠  SPACESHIP INCOMING — GET TO THE EXTRACTION ZONE")

func _on_outro_landed(land_pos: Vector2, safe_pos: Vector2) -> void:
	_teleport_circle = teleport_circle_scene.instantiate()
	_teleport_circle.global_position = safe_pos + CIRCLE_LAND_OFFSET
	_teleport_circle.wait_duration = 2.0
	get_parent().add_child(_teleport_circle)
	_teleport_circle.activate()
	_teleport_circle.player_teleported.connect(_on_outro_teleport_done, CONNECT_ONE_SHOT)

	_arrow = load("res://scenes/arrow_indicator.tscn").instantiate()
	camera.add_child(_arrow)
	_arrow.activate(_teleport_circle)

	_outro_timer = 0.0
	set_process(true)

func _do_game_over() -> void:
	_cleanup_outro()
	player.set_physics_process(false)
	wave_manager.wave_active = false
	
	if is_instance_valid(_spaceship):
		_spaceship.do_outro(_spaceship.global_position)
		await _spaceship.departure_complete
	
	print("=== GAME OVER - TIME OUT ===")
	get_tree().quit()

func _process(delta):
	if not _outro_active:
		return
	_outro_timer += delta
	if _outro_timer >= OUTRO_TIMEOUT:
		_outro_active = false
		set_process(false)
		_do_game_over()

func _on_outro_teleport_done() -> void:
	_outro_active = false
	set_process(false)
	_hide_warning()

	if is_instance_valid(_arrow):
		_arrow.queue_free()
		_arrow = null

	var tween = create_tween()
	tween.tween_property(player, "modulate:a", 0.0, 1.2)
	await tween.finished

	if is_instance_valid(_spaceship):
		_spaceship.departure_complete.connect(_on_outro_departure_done, CONNECT_ONE_SHOT)
		_spaceship.do_outro(_spaceship.global_position)

func _on_outro_departure_done() -> void:
	_cleanup_outro()
	print("=== LEVEL COMPLETE ===")
	level_complete.emit()

	slot_machine.show_wave_reward(player)

func _cleanup_outro() -> void:
	if is_instance_valid(_spaceship):
		_spaceship.queue_free()
	_spaceship = null
	if is_instance_valid(_teleport_circle):
		_teleport_circle.queue_free()
	_teleport_circle = null
	if is_instance_valid(_arrow):
		_arrow.queue_free()
	_arrow = null
	_hide_warning()

# ===================== WARNING LABEL =====================

func _show_warning(text: String) -> void:
	if is_instance_valid(_warning_label):
		_warning_label.queue_free()

	var canvas = CanvasLayer.new()
	canvas.layer = 50
	get_parent().add_child(canvas)

	_warning_label = Label.new()
	_warning_label.text = text
	_warning_label.add_theme_font_size_override("font_size", 22)
	_warning_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1.0))
	_warning_label.anchor_left = 0.0
	_warning_label.anchor_right = 1.0
	_warning_label.anchor_top = 0.0
	_warning_label.anchor_bottom = 0.0
	_warning_label.offset_top = 100
	_warning_label.offset_bottom = 140
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	canvas.add_child(_warning_label)

	if _warning_tween:
		_warning_tween.kill()
	_warning_tween = create_tween().set_loops()
	_warning_tween.tween_property(_warning_label, "modulate:a", 0.3, 0.7)
	_warning_tween.tween_property(_warning_label, "modulate:a", 1.0, 0.7)

func _hide_warning() -> void:
	if _warning_tween:
		_warning_tween.kill()
		_warning_tween = null
	if is_instance_valid(_warning_label):
		var parent = _warning_label.get_parent()
		if is_instance_valid(parent):
			parent.queue_free()
		else:
			_warning_label.queue_free()
	_warning_label = null

# ===================== CAMERA =====================

func _follow_spaceship(enable: bool) -> void:
	if enable and is_instance_valid(_spaceship):
		camera.reparent(_spaceship, true)
		camera.position = Vector2.ZERO
	else:
		if is_instance_valid(camera) and is_instance_valid(player):
			camera.reparent(player, true)
			camera.position = Vector2.ZERO
