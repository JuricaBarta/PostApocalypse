extends CharacterBody2D

signal hit
signal game_over

@export var projectile_scene: PackedScene
@export var pushback_force := 800.0
@export var pushback_radius := 250.0
@export var starting_weapon_scene: PackedScene

var stats := PlayerStats.new()

var pushback_timer := 0.0
var pushback_cooldown := 0.5
var screen_size
var radius
var xp := 0
var level := 1
var pending_levelups := 0
var multiplayer_mode := false
var last_direction := "right"
var invincible := false
var flash_timer := 0.0
var flash_duration := 2.0
var portal_invincible := false

# ✅ SCALE FIX (GLOBALNO)
var run_scale = Vector2(0.25, 0.25)
var idle_scale = Vector2(0.07, 0.07)

# === MINING ===
var mine_timer := 0.0
var mine_interval := 0.2
var mine_damage := 1
var mine_range := 16.0
var is_mining := false
var _map_ref: Node = null
var _scrap_layer_ref: Node = null

# === SCRAP INVENTORY ===
var scrap_inventory := {
	"generic": 0,
	"metal": 0,
	"copper": 0,
	"circuit": 0,
	"biogel": 0,
	"powercell": 0,
	"nanochip": 0,
}

var hp := 10

var max_hp: int:
	get: return stats.max_hp

var pickup_radius: float:
	get: return stats.pickup_radius * 100.0

var speed: float:
	get: return 200.0 * stats.move_speed


# === WEAPONS ===
var weapon_slots: Array[Node2D] = []

func _ready():
	screen_size = get_viewport_rect().size
	position = Vector2(2240, 2240)
	radius = $CollisionShape2D.shape.radius
	add_to_group("player")

	$Camera2D.position_smoothing_enabled = true
	$Camera2D.position_smoothing_speed = 4.0
	$Camera2D.zoom = Vector2(1.00, 1.00)

	$AnimatedSprite2D.offset = Vector2(0, 0)

	hp = stats.max_hp
	_init_weapon_slots()
	_equip_starting_weapon()
	
func _equip_starting_weapon():
	if starting_weapon_scene == null:
		return
	var weapon = starting_weapon_scene.instantiate()
	$WeaponSlot1.add_child(weapon)


func _process(delta):
	auto_shoot(delta)

func _physics_process(delta):
	move_player(delta)
	auto_mine(delta)

	if pushback_timer > 0:
		pushback_timer -= delta
	
	if invincible:
		flash_timer -= delta
		if fmod(flash_timer, 0.2) < 0.1:
			$AnimatedSprite2D.modulate = Color(3, 3, 3, 1)
		else:
			$AnimatedSprite2D.modulate = Color(1, 1, 1, 1)
		if flash_timer <= 0:
			invincible = false
			$AnimatedSprite2D.modulate = Color(1, 1, 1, 1)

func move_player(_delta):
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	var current_speed = speed
	if is_mining:
		current_speed = speed * 0.35
	
	velocity = input_vector * current_speed
	move_and_slide()

	var anim = $AnimatedSprite2D

# SPREMI SMJER (samo kad se miče lijevo/desno)
	if input_vector.x > 0:
		last_direction = "right"
	elif input_vector.x < 0:
		last_direction = "left"

	# IDLE
	if input_vector == Vector2.ZERO:
		anim.animation = "StandStill"
		anim.scale = idle_scale
		if last_direction == "left":
			anim.frame = 0
		else:
			anim.frame = 1
		anim.flip_h = false
		anim.stop()
		return

	# RUN
	if anim.animation != "RunRight":
		anim.play("RunRight")
	anim.scale = run_scale
	anim.flip_h = (last_direction == "left")

const WEAPON_SLOT_OFFSETS := [
	Vector2(-40, -40),  # Slot1: gore lijevo
	Vector2(40, -40),   # Slot2: gore desno
	Vector2(-40, 40),   # Slot3: dolje lijevo
	Vector2(40, 40),    # Slot4: dolje desno
	Vector2(0, 0),      # Slot5: centar
]

func _init_weapon_slots():
	weapon_slots.clear()
	for i in range(5):
		var slot_name = "WeaponSlot%d" % (i + 1)
		var slot = get_node_or_null(slot_name)
		if slot:
			slot.position = WEAPON_SLOT_OFFSETS[i]
			weapon_slots.append(slot)
		
func get_next_free_slot() -> Node2D:
	for slot in weapon_slots:
		if slot.get_child_count() == 0:
			return slot
	return null

func auto_shoot(_delta):
	for slot in weapon_slots:
		if slot.get_child_count() == 0:
			continue
		var weapon = slot.get_child(0)
		if not weapon.has_method("shoot"):
			continue
		if weapon.is_reloading:
			continue
		if weapon.current_ammo <= 0:
			weapon.is_reloading = true
			weapon.reload_timer = weapon.reload_time * weapon.reload_multiplier
			continue
		if weapon.fire_timer > 0:
			continue
		# Skip the fire-rate cooldown when there is nothing to shoot at — otherwise
		# weapons "waste" a cycle on no target and feel sluggish to engage.
		if weapon.current_target == null or not is_instance_valid(weapon.current_target):
			continue
		var rate_mod = weapon.fire_rate_multiplier * stats.fire_rate * weapon.fire_rate_bonus
		if rate_mod < 0.1:
			rate_mod = 0.1
		weapon.fire_timer = weapon.fire_rate / rate_mod
		weapon.shoot(projectile_scene, position)

func add_xp(amount: int):
	xp += amount
	while xp >= xp_per_level:
		xp -= xp_per_level
		level_up()

var xp_per_level: int:
	get: return stats.xp_per_level

func level_up():
	level += 1
	# Smoother XP curve: small early growth, ramps faster at higher levels
	# +18% per level up to level 10, +14% after that (avoids huge late-game wall)
	var growth = 1.18 if level <= 10 else 1.14
	stats.xp_per_level = int(round(stats.xp_per_level * growth))
	pending_levelups += 1

	var slot_machine = get_tree().get_root().get_node_or_null("Main/UI/SlotMachine")
	if slot_machine:
		slot_machine.show_for_player(self)
	else:
		push_warning("SlotMachine nije pronađen! Provjeri path Main/UI/SlotMachine")

func get_pickup_radius() -> float:
	return pickup_radius

func take_damage(amount: int):
	if invincible or portal_invincible:
		return
	hp -= amount
	invincible = true
	flash_timer = flash_duration
	if hp <= 0:
		hp = 0
		emit_signal("game_over")
		print("GAME OVER!")
	pushback_enemies()

func pushback_enemies():
	if pushback_timer > 0:
		return
	pushback_timer = pushback_cooldown
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var dist = global_position.distance_to(enemy.global_position)
		if dist < pushback_radius:
			var dir = (enemy.global_position - global_position).normalized()
			var strength = pushback_force * (1.0 - dist / pushback_radius)
			enemy.apply_pushback(dir * strength)

const SCRAP_XP := {
	"generic": 1, "metal": 2, "copper": 4,
	"circuit": 7, "biogel": 10, "powercell": 14, "nanochip": 20,
}

# =============================================
#  AUTO MINING — kopa scrap kad je blizu
# =============================================
func auto_mine(delta):
	mine_timer += delta
	var effective_interval = mine_interval / stats.mining_speed
	if mine_timer < effective_interval:
		return
	mine_timer = 0.0

	if _map_ref == null:
		_map_ref = get_tree().get_root().get_node_or_null("Main/Map")
	if _map_ref == null:
		is_mining = false
		return

	if _scrap_layer_ref == null:
		_scrap_layer_ref = _map_ref.get_node_or_null("ScrapLayer")
	if _scrap_layer_ref == null:
		is_mining = false
		return

	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector == Vector2.ZERO:
		is_mining = false
		return

	var mined_any = false
	var tile_dir_x = 0
	var tile_dir_y = 0
	if input_vector.x > 0.3:
		tile_dir_x = 1
	elif input_vector.x < -0.3:
		tile_dir_x = -1
	if input_vector.y > 0.3:
		tile_dir_y = 1
	elif input_vector.y < -0.3:
		tile_dir_y = -1

	var player_tile = _scrap_layer_ref.local_to_map(_scrap_layer_ref.to_local(global_position))
	var destroyed_tiles = []

	for depth in range(1, 3):
		for width in range(-1, 2):
			var target = player_tile
			if tile_dir_x != 0 and tile_dir_y != 0:
				target.x += tile_dir_x * depth + (-tile_dir_y) * width
				target.y += tile_dir_y * depth + tile_dir_x * width
				for extra in [Vector2i(player_tile.x + tile_dir_x * depth, player_tile.y + width),
							  Vector2i(player_tile.x + width, player_tile.y + tile_dir_y * depth)]:
					var ecell = _scrap_layer_ref.get_cell_source_id(extra)
					if ecell != -1:
						mined_any = true
						var eres = _map_ref.mine_scrap_no_outline(extra, mine_damage)
						if eres["destroyed"]:
							scrap_inventory[eres["scrap_type"]] += eres["amount"]
							add_xp(SCRAP_XP.get(eres["scrap_type"], 1))
							destroyed_tiles.append(extra)
			else:
				target.x += tile_dir_x * depth + (-tile_dir_y) * width
				target.y += tile_dir_y * depth + tile_dir_x * width

			var cell = _scrap_layer_ref.get_cell_source_id(target)
			if cell == -1:
				continue

			mined_any = true
			var result = _map_ref.mine_scrap_no_outline(target, mine_damage)
			if result["destroyed"]:
				scrap_inventory[result["scrap_type"]] += result["amount"]
				add_xp(SCRAP_XP.get(result["scrap_type"], 1))
				destroyed_tiles.append(target)

	if destroyed_tiles.size() > 0:
		_map_ref.batch_refresh_outlines(destroyed_tiles)

	is_mining = mined_any
