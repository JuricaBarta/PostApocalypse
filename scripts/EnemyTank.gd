extends CharacterBody2D

@export var speed := 75                   # Brži! (bio 50)
@export var type := "ranged"
@export var hp := 60
@export var xp_value := 25
@export var projectile_scene: PackedScene

# --- Distanca ---
@export var preferred_distance := 80.0    # koliko blizu želi biti od playera (AGRESIVNO)
@export var distance_tolerance := 30.0    # +/- zona

# --- Pucanje ---
@export var fire_rate := 1.5              # Brže puca! (bilo 2.5)
@export var projectile_speed := 200.0
@export var projectile_damage := 12

var player: Node2D
var separation_strength := 200
var pushback_velocity := Vector2.ZERO
var fire_timer := 0.0
var separation_timer := 0.0
var cached_separation := Vector2.ZERO
var nav_timer := 0.0
var cached_move_dir := Vector2.ZERO
var mining_speed_multiplier := 0.2  # koliko usporite ide kroz scrap
var stuck_timer := 0.0
var last_pos := Vector2.ZERO

@onready var nav_agent = $NavigationAgent2D
@onready var outline_sprite = $OutlineSprite

const OUTLINE_SHADER := preload("res://shaders/enemy_outline.gdshader")
const XP_ORB_SCENE := preload("res://scenes/xp_orb.tscn")
const HEAL_ORB_SCENE := preload("res://scenes/heal_orb.tscn")
const MAGNET_ORB_SCENE := preload("res://scenes/magnet_orb.tscn")
static var _shared_outline_mat: ShaderMaterial = null

static func _get_outline_material() -> ShaderMaterial:
	if _shared_outline_mat == null:
		_shared_outline_mat = ShaderMaterial.new()
		_shared_outline_mat.shader = OUTLINE_SHADER
	return _shared_outline_mat

func _ready():
	add_to_group("enemy")
	player = get_tree().get_root().get_node("Main/Player")
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0

	var lvl = GameManager.current_level
	hp = int(round(hp * (1.0 + lvl * 0.12)))
	xp_value = int(round(xp_value * (1.0 + lvl * 0.10)))
	projectile_damage = int(round(projectile_damage * (1.0 + lvl * 0.08)))

	outline_sprite.visible = false
	outline_sprite.material = _get_outline_material()

func _process(_delta):
	outline_sprite.visible = false
	
func has_line_of_sight() -> bool:
	if player == null:
		return false
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, player.global_position)
	query.collision_mask = 0b1100
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result = space.intersect_ray(query)
	return result.is_empty()

func _physics_process(delta):
	if player == null:
		return

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider() == player:
			player.take_damage(10)

	if pushback_velocity.length() > 10:
		velocity = pushback_velocity
		pushback_velocity = pushback_velocity.lerp(Vector2.ZERO, delta * 8)
		move_and_slide()
		return

	var dist_to_player = global_position.distance_to(player.global_position)

	# Detektiraj ako je zapnut (nije se mikao 0.5s)
	stuck_timer += delta
	if global_position.distance_to(last_pos) > 5:
		stuck_timer = 0.0
	if stuck_timer > 0.5:
		mining_speed_multiplier = 0.15  # kopaj sporo kroz scrap
	else:
		mining_speed_multiplier = 0.2

	last_pos = global_position

	nav_timer += delta
	if nav_timer >= 0.3:
		nav_timer = randf_range(0.0, 0.05)
		cached_move_dir = Vector2.ZERO
		var has_los = has_line_of_sight()

		# AGRESIVNA LOGIKA: Broj 1 cilj je doći do playera i pucati
		if has_los:
			# AKO IMA LoS -> idi DIREKTNO na playera (agresivno!)
			cached_move_dir = (player.global_position - global_position).normalized()
		else:
			# Nema LoS -> koristi navAgent
			nav_agent.target_position = player.global_position
			var next_pos = nav_agent.get_next_path_position()
			cached_move_dir = (next_pos - global_position).normalized()

		# Fallback: ako je zapnut, forsira direktnu kretnju kroz scrap
		if stuck_timer > 0.3:
			cached_move_dir = (player.global_position - global_position).normalized()

	separation_timer += delta
	if separation_timer >= 0.2:
		separation_timer = randf_range(0.0, 0.05)
		cached_separation = Vector2.ZERO
		var nearby_count = 0
		for other in get_tree().get_nodes_in_group("enemy"):
			if other == self:
				continue
			if nearby_count > 5:
				break
			var dist = global_position.distance_to(other.global_position)
			if dist < 32:
				var push = (global_position - other.global_position).normalized()
				cached_separation += push * (1.0 - dist / 32.0)
				nearby_count += 1
		cached_separation *= separation_strength

	# Ako je zapnut kroz scrap, ide normalnom brzinom (forsira kroz)
	var current_speed = speed
	if stuck_timer > 0.5:
		current_speed = speed * 0.7  # Malo sporije kroz scrap, ali ipak agresivno

	velocity = cached_move_dir * current_speed + cached_separation
	move_and_slide()

	# Kontinuirano ruši generic scrap dok se kreće (sporo trganja)
	destroy_scrap_at_position()

	if player.global_position.x > global_position.x:
		$AnimatedSprite2D.frame = 1
	else:
		$AnimatedSprite2D.frame = 0

	fire_timer += delta
	if fire_timer >= fire_rate and dist_to_player < 500.0:
		if has_line_of_sight():
			fire_timer = 0.0
			shoot()

func shoot():
	if projectile_scene == null:
		return
	var bullet = projectile_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = (player.global_position - global_position).normalized()
	bullet.speed = projectile_speed
	bullet.damage = projectile_damage
	bullet.rotation = bullet.direction.angle() + deg_to_rad(90)
	get_tree().current_scene.add_child(bullet)

func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		if player and player.stats.vampire:
			player.hp = min(player.hp + 5, player.stats.max_hp)
		drop_xp.call_deferred()
		queue_free.call_deferred()

func drop_xp():
	for i in range(2):
		var orb = XP_ORB_SCENE.instantiate()
		orb.position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		orb.type = orb.PickupType.XP
		orb.value = xp_value
		get_tree().current_scene.add_child(orb)
	if randf() < 0.003:
		drop_heal()
	if randf() < 0.0003:
		drop_magnet()

func drop_heal():
	var heal = HEAL_ORB_SCENE.instantiate()
	heal.position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
	get_tree().current_scene.add_child(heal)

func drop_magnet():
	var magnet = MAGNET_ORB_SCENE.instantiate()
	magnet.position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
	get_tree().current_scene.add_child(magnet)

func destroy_scrap_at_position():
	var map_node = get_tree().get_root().get_node_or_null("Main/Map")
	if map_node == null:
		return
	# Provjeri 3x3 tile area oko tanka
	var center_tile = Vector2i(int(global_position.x / 16), int(global_position.y / 16))
	var destroyed_tiles = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var tile_pos = Vector2i(center_tile.x + dx, center_tile.y + dy)
			if tile_pos.x < 0 or tile_pos.x >= map_node.map_w or tile_pos.y < 0 or tile_pos.y >= map_node.map_h:
				continue
			if not map_node.scrap_hp.has(tile_pos):
				continue
			var scrap_type = map_node.scrap_type_map[tile_pos.x][tile_pos.y]
			# Samo generic scrap uništava (lagano, sporija damage)
			if scrap_type in [map_node.SCRAP_GENERIC_1, map_node.SCRAP_GENERIC_2, map_node.SCRAP_GENERIC_3]:
				map_node.mine_scrap_no_outline(tile_pos, 3)  # Mali damage (3) = spora trganja
				destroyed_tiles.append(tile_pos)
	if destroyed_tiles.size() > 0:
		map_node.batch_refresh_outlines(destroyed_tiles)

func apply_pushback(force: Vector2):
	pushback_velocity = force
