extends CharacterBody2D

@export var speed := 85
@export var type := "chaser"
@export var hp := 25
@export var xp_value := 8

# --- Dynamic speed ---
@export var comfort_radius := 160.0      # unutar ovog kruga = normalan speed
@export var max_chase_distance := 500.0  # na ovoj udaljenosti = max speed
@export var max_speed_multiplier := 1.6  # koliko puta brži kad je daleko

var player
var separation_strength := 160
var pushback_velocity := Vector2.ZERO
var roof_layer = null
var separation_timer := 0.0
var cached_separation := Vector2.ZERO
var nav_timer := 0.0
var cached_dir := Vector2.ZERO

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

	# Scale HP and XP with run depth so deeper levels feel tougher.
	var lvl = GameManager.current_level
	hp = int(round(hp * (1.0 + lvl * 0.12)))
	xp_value = int(round(xp_value * (1.0 + lvl * 0.10)))

	outline_sprite.visible = false
	outline_sprite.material = _get_outline_material()

func _process(_delta):
	outline_sprite.visible = false

func get_dynamic_speed() -> float:
	if player == null:
		return speed
	var dist = global_position.distance_to(player.global_position)
	if dist <= comfort_radius:
		return speed
	# linearni lerp od 1x do max_speed_multiplier
	var t = clampf((dist - comfort_radius) / (max_chase_distance - comfort_radius), 0.0, 1.0)
	# ease-in za prirodniji osjecaj (opcija: zamijeni s t za linearno)
	t = t * t
	return speed * lerpf(1.0, max_speed_multiplier, t)

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

	# Nav path samo svakih 0.3 sec
	nav_timer += delta
	if nav_timer >= 0.3:
		nav_timer = randf_range(0.0, 0.05)
		var spread = Vector2(randf_range(-24, 24), randf_range(-24, 24))
		nav_agent.target_position = player.global_position + spread
		var next_pos = nav_agent.get_next_path_position()
		cached_dir = (next_pos - global_position).normalized()

	# Separation samo svakih 0.2 sec
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
			if dist < 64:
				var push = (global_position - other.global_position).normalized()
				cached_separation += push * (1.0 - dist / 64.0)
				nearby_count += 1
		cached_separation *= separation_strength

	var current_speed = get_dynamic_speed()
	velocity = cached_dir * current_speed + cached_separation
	move_and_slide()

	if velocity.x > 0.1:
		$AnimatedSprite2D.frame = 1
	elif velocity.x < -0.1:
		$AnimatedSprite2D.frame = 0

func take_damage(amount: int):
	hp -= amount
	if hp <= 0:
		if player and player.stats.vampire:
			player.hp = min(player.hp + 5, player.stats.max_hp)
			print("  🧛 Vampire heal! hp = ", player.hp)
		drop_xp.call_deferred()
		queue_free.call_deferred()

func drop_xp():
	var orb = XP_ORB_SCENE.instantiate()
	orb.position = global_position
	orb.type = orb.PickupType.XP
	orb.value = xp_value
	get_tree().current_scene.add_child(orb)

	if randf() < 0.001:
		drop_heal()

	if randf() < 0.0001:
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
