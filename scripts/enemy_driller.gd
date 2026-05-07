extends CharacterBody2D

@export var speed := 60
@export var type := "driller"
@export var hp := 35
@export var xp_value := 20

# --- Rush ---
@export var rush_speed := 500.0
@export var rush_distance := 450.0
@export var warn_duration := 1.0
@export var cooldown_after_rush := 1.5

enum State { WALKING, WARNING, RUSHING, COOLDOWN }
var state := State.WALKING
var rush_direction := Vector2.ZERO
var rush_traveled := 0.0
var warn_timer := 0.0
var cooldown_timer := 0.0
var flash_timer := 0.0

var player: Node2D
var separation_strength := 200
var pushback_velocity := Vector2.ZERO

var nav_timer := 0.0
var cached_dir := Vector2.ZERO
var separation_timer := 0.0
var cached_separation := Vector2.ZERO

@onready var nav_agent = $NavigationAgent2D
@onready var outline_sprite = $OutlineSprite
@onready var sprite = $AnimatedSprite2D

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

	outline_sprite.visible = false
	outline_sprite.material = _get_outline_material()

func _process(_delta):
	outline_sprite.visible = false

func _physics_process(delta):
	if player == null:
		return

	# Pushback
	if pushback_velocity.length() > 10:
		velocity = pushback_velocity
		pushback_velocity = pushback_velocity.lerp(Vector2.ZERO, delta * 8)
		move_and_slide()
		return

	match state:
		State.WALKING:
			do_walking(delta)
		State.WARNING:
			do_warning(delta)
		State.RUSHING:
			do_rushing(delta)
		State.COOLDOWN:
			do_cooldown(delta)

	# Sprite flip
	if velocity.length() > 5:
		if velocity.x > 0.1:
			sprite.frame = 1
		elif velocity.x < -0.1:
			sprite.frame = 0

func do_walking(delta):
	# Kolizija s playerom
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider() == player:
			player.take_damage(10)

	# Nav path cached
	nav_timer += delta
	if nav_timer >= 0.3:
		nav_timer = randf_range(0.0, 0.05)
		nav_agent.target_position = player.global_position
		var next_pos = nav_agent.get_next_path_position()
		cached_dir = (next_pos - global_position).normalized()

	# Separation cached
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

	velocity = cached_dir * speed + cached_separation
	move_and_slide()

	# Ako je blizu playera — počni warning
	var dist_to_player = global_position.distance_to(player.global_position)
	if dist_to_player < 350.0:
		state = State.WARNING
		warn_timer = 0.0
		flash_timer = 0.0
		velocity = Vector2.ZERO

func do_warning(delta):
	# Stoji na mjestu, treperi crveno
	velocity = Vector2.ZERO
	warn_timer += delta
	flash_timer += delta

	# Flash crveno 2x u sekundi
	if fmod(flash_timer, 0.5) < 0.25:
		sprite.modulate = Color(2.0, 0.3, 0.3, 1.0)
	else:
		sprite.modulate = Color(1, 1, 1, 1)

	# Lockaj smjer prema playeru dok warninguje
	rush_direction = (player.global_position - global_position).normalized()

	if warn_timer >= warn_duration:
		# Kreni rush!
		state = State.RUSHING
		rush_traveled = 0.0
		sprite.modulate = Color(2.0, 0.2, 0.2, 1.0)
		# Tijekom rusha ignoriraj scrap collision — privremeno makni layer 4 iz maske
		collision_mask = collision_mask & ~(1 << 3)  # makni bit 4 (layer 4 = scrap)

func do_rushing(delta):
	var move_amount = rush_speed * delta
	rush_traveled += move_amount

	velocity = rush_direction * rush_speed
	move_and_slide()

	# Provjeri koliziju s playerom
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider == player:
			player.take_damage(20)
			end_rush()
			return
		# Ako udari u wall (layer 3) — zaustavi se
		if collider is TileMapLayer:
			# Provjeri jel wall ili scrap
			if is_wall_collision(collider, collision):
				end_rush()
				return

	# Uništavaj generic scrap usput
	destroy_scrap_at_position()

	# Kraj rusha po distanci
	if rush_traveled >= rush_distance:
		end_rush()

func is_wall_collision(collider: TileMapLayer, collision: KinematicCollision2D) -> bool:
	# Provjeri ime layera
	if collider.name == "WallLayer":
		return true
	# Provjeri jel scrap koji NIJE generic (metal, copper, itd)
	if collider.name == "ScrapLayer":
		var map_node = get_tree().get_root().get_node_or_null("Main/Map")
		if map_node:
			var tile_pos = Vector2i(int(global_position.x / 16), int(global_position.y / 16))
			var scrap_type = map_node.scrap_type_map[tile_pos.x][tile_pos.y] if tile_pos.x >= 0 and tile_pos.x < map_node.map_w and tile_pos.y >= 0 and tile_pos.y < map_node.map_h else -1
			# Generic scrap = prolazi, ostalo = stop
			if scrap_type in [map_node.SCRAP_GENERIC_1, map_node.SCRAP_GENERIC_2, map_node.SCRAP_GENERIC_3]:
				return false  # prolazi kroz generic
			elif scrap_type >= 0:
				return true  # zabije se u metal/copper/itd
	return false

func destroy_scrap_at_position():
	var map_node = get_tree().get_root().get_node_or_null("Main/Map")
	if map_node == null:
		return
	# Provjeri 3x3 tile area oko drillera
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
			# Samo generic scrap uništava
			if scrap_type in [map_node.SCRAP_GENERIC_1, map_node.SCRAP_GENERIC_2, map_node.SCRAP_GENERIC_3]:
				map_node.mine_scrap_no_outline(tile_pos, 999)
				destroyed_tiles.append(tile_pos)
	if destroyed_tiles.size() > 0:
		map_node.batch_refresh_outlines(destroyed_tiles)

func end_rush():
	state = State.COOLDOWN
	cooldown_timer = 0.0
	sprite.modulate = Color(1, 1, 1, 1)
	velocity = Vector2.ZERO
	# Vrati scrap collision mask
	collision_mask = collision_mask | (1 << 3)  # vrati bit 4 (layer 4 = scrap)

func do_cooldown(delta):
	cooldown_timer += delta
	velocity = Vector2.ZERO
	if cooldown_timer >= cooldown_after_rush:
		state = State.WALKING

func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		if player and player.stats.vampire:
			player.hp = min(player.hp + 5, player.stats.max_hp)
		drop_xp.call_deferred()
		queue_free.call_deferred()

func drop_xp():
	for i in range(3):
		var orb = XP_ORB_SCENE.instantiate()
		orb.position = global_position + Vector2(randf_range(-12, 12), randf_range(-12, 12))
		orb.type = orb.PickupType.XP
		orb.value = xp_value
		get_tree().current_scene.add_child(orb)
	if randf() < 0.002:
		drop_heal()
	if randf() < 0.0002:
		drop_magnet()

func drop_heal():
	var heal = HEAL_ORB_SCENE.instantiate()
	heal.position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
	get_tree().current_scene.add_child(heal)

func drop_magnet():
	var magnet = MAGNET_ORB_SCENE.instantiate()
	magnet.position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
	get_tree().current_scene.add_child(magnet)

func apply_pushback(force: Vector2):
	pushback_velocity = force
