extends Area2D

@export var speed := 600.0
@export var size := 1.0
var pierce_count := 0
var direction := Vector2.ZERO
var damage := 1.0
var pierce_bonus := 0
var full_pierce := false
var wavy := false
var headshot_mult := 1.0  # >1.0 means first hit deals bonus damage
var explosive := false
var explosion_radius := 90.0
var lifetime := 3.0
var _wave_time := 0.0
var _life := 0.0

func _ready():
	body_entered.connect(_on_body_entered)
	if direction != Vector2.ZERO:
		rotation = direction.angle() + deg_to_rad(90)

func _physics_process(delta):
	_life += delta
	if _life >= lifetime:
		queue_free()
		return
	if wavy:
		_wave_time += delta
		var perp = direction.rotated(PI / 2.0)
		position += direction * speed * delta + perp * sin(_wave_time * 10.0) * 50.0 * delta
	else:
		position += direction * speed * delta

func _on_body_entered(body):
	if body.is_in_group("enemy"):
		var dmg_to_apply = damage
		if headshot_mult > 1.0:
			dmg_to_apply *= headshot_mult
			headshot_mult = 1.0  # only first hit

		if full_pierce:
			if body.has_method("take_damage"):
				body.take_damage(int(round(dmg_to_apply)))
			if explosive:
				_do_explosion(body.global_position)
				queue_free()
			return

		if pierce_count < pierce_bonus:
			# pass-through hit: 100% damage, projectile continues
			if body.has_method("take_damage"):
				body.take_damage(int(round(dmg_to_apply)))
			pierce_count += 1
		else:
			# final hit: 50% if piercing was active, 100% if no piercing
			var final_mult = 0.5 if pierce_bonus > 0 else 1.0
			if body.has_method("take_damage"):
				body.take_damage(int(round(dmg_to_apply * final_mult)))
			else:
				body.queue_free()
			if explosive:
				_do_explosion(body.global_position)
			queue_free()
	elif body is TileMapLayer:
		queue_free()

func _do_explosion(at: Vector2):
	var enemies = get_tree().get_nodes_in_group("enemy")
	var rad_sq = explosion_radius * explosion_radius
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_squared_to(at) <= rad_sq:
			if e.has_method("take_damage"):
				e.take_damage(int(round(damage * 0.6)))
