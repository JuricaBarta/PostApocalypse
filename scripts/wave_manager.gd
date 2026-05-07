extends Node2D

signal wave_completed
signal spaceship_warning

@export var enemy_scene: PackedScene
@export var tank_scene: PackedScene
@export var portal_scene: PackedScene

# --- Wave timing ---
@export var wave_duration := 120.0
@export var spawn_interval := 0.5
@export var min_spawn_distance := 300.0
@export var max_spawn_distance := 600.0
@export var max_alive_enemies := 80

# --- Tank spawning ---
@export var tank_start_time := 5.0
@export var tank_ratio_start := 0.05
@export var tank_ratio_end := 0.3

# --- Driller spawning ---
@export var driller_scene: PackedScene
@export var driller_start_time := 45.0
@export var driller_ratio_start := 0.03
@export var driller_ratio_end := 0.15

var spawn_timer := 0.0
var wave_timer := 0.0
var player: Node2D
var wave_active := false   # PROMJENA: false dok LevelSequence ne pokrene
var spaceship_warning_active := false

func _ready():
	if enemy_scene == null:
		push_error("WaveManager: enemy_scene nije postavljen!")
	if portal_scene == null:
		push_error("WaveManager: portal_scene nije postavljen!")
	if tank_scene == null:
		push_warning("WaveManager: tank_scene nije postavljen — neće biti tankova!")
	player = get_tree().get_root().get_node("Main/Player")
	if player == null:
		push_error("WaveManager: Player nije pronađen!")

	# Skaliraj težinu po trenutnom levelu (level 1 = baza, +15% neprijatelja i +10% spawn speed per level)
	var lvl = max(1, GameManager.current_level)
	max_alive_enemies = int(max_alive_enemies * (1.0 + (lvl - 1) * 0.15))
	spawn_interval = max(0.18, spawn_interval / (1.0 + (lvl - 1) * 0.10))

	# Ne čekamo 2s ovdje – LevelSequence kontrolira start
	set_physics_process(true)

func _physics_process(delta):
	if not wave_active or player == null:
		return

	wave_timer += delta

	# Spaceship dolazi na 30s
	if wave_timer >= wave_duration - 30.0 and not spaceship_warning_active:
		spaceship_warning_active = true
		spaceship_warning.emit()
	
	# Timer istekao = game over
	if wave_timer >= wave_duration:
		wave_active = false
		spaceship_warning_active = false
		print("=== TIME OUT - GAME OVER ===")
		wave_completed.emit()
		return

	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0

		var alive = get_tree().get_nodes_in_group("enemy").size()
		if alive >= max_alive_enemies:
			return

		var ratio = get_tank_ratio()
		if fmod(wave_timer, 10.0) < spawn_interval:
			print("⏱ Wave: %.1f/%.1f | Enemies: %d/%d | Tank%%: %.0f%%" % [wave_timer, wave_duration, alive, max_alive_enemies, ratio * 100])
		spawn_portal()

func get_tank_ratio() -> float:
	if tank_scene == null:
		return 0.0
	if wave_timer < tank_start_time:
		return 0.0
	var t = clampf((wave_timer - tank_start_time) / (wave_duration - tank_start_time), 0.0, 1.0)
	return lerpf(tank_ratio_start, tank_ratio_end, t)

func get_driller_ratio() -> float:
	if driller_scene == null:
		return 0.0
	if wave_timer < driller_start_time:
		return 0.0
	var t = clampf((wave_timer - driller_start_time) / (wave_duration - driller_start_time), 0.0, 1.0)
	return lerpf(driller_ratio_start, driller_ratio_end, t)

func spawn_portal():
	if portal_scene == null:
		return
	var spawn_pos = find_valid_spawn()
	if spawn_pos == Vector2.ZERO:
		return
	var portal = portal_scene.instantiate()
	portal.position = spawn_pos

	var roll = randf()
	var tank_r = get_tank_ratio()
	var drill_r = get_driller_ratio()

	if roll < drill_r:
		if driller_scene:
			portal.enemy_scene = driller_scene
		else:
			portal.enemy_scene = enemy_scene
	elif roll < drill_r + tank_r:
		if tank_scene:
			portal.enemy_scene = tank_scene
		else:
			portal.enemy_scene = enemy_scene
	else:
		portal.enemy_scene = enemy_scene

	add_child(portal)

func find_valid_spawn() -> Vector2:
	var space = get_world_2d().direct_space_state
	var shape = CircleShape2D.new()
	shape.radius = 16
	var map_node = get_tree().get_root().get_node("Main/Map")

	for _i in range(40):
		var angle = randf_range(0, TAU)
		var distance = randf_range(min_spawn_distance, max_spawn_distance)
		var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * distance

		if spawn_pos.distance_to(player.global_position) < min_spawn_distance:
			continue

		var tile_pos = Vector2i(int(spawn_pos.x / 16), int(spawn_pos.y / 16))
		if map_node and map_node.has_method("is_in_map"):
			if not map_node.is_in_map(tile_pos.x, tile_pos.y):
				continue

		var params = PhysicsShapeQueryParameters2D.new()
		params.shape = shape
		params.transform = Transform2D(0, spawn_pos)
		params.collision_mask = 0b1100
		params.collide_with_areas = true
		params.collide_with_bodies = true

		var result = space.intersect_shape(params, 1)

		if result.is_empty():
			return spawn_pos

	return Vector2.ZERO
