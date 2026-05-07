class_name WeaponBase
extends Node2D

var damage := 1.0
var current_target: Node2D = null
var fire_rate_multiplier := 1.0
var reload_multiplier := 1.0
var range_multiplier := 1.0
var spread_multiplier := 1.0
var pierce_bonus := 0
var proj_count := 1
var max_ammo := 6
var current_ammo := 6
var reload_time := 2.0
var is_reloading := false
var reload_timer := 0.0
var fire_rate := 0.0
var fire_timer := 0.0
var stats_restored := false
var weapon_level := 0
var fire_rate_bonus := 1.0  # extra fire rate (e.g. minigun heat)

var _player_ref: Node = null

func _process(delta):
	update_target()
	rotate_to_target()
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0:
			is_reloading = false
			current_ammo = max_ammo
	if fire_timer > 0:
		fire_timer -= delta

func can_shoot() -> bool:
	return fire_timer <= 0 and not is_reloading and current_ammo > 0

func has_line_of_sight(target: Node2D) -> bool:
	var space = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	query.collision_mask = 0b1100
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result = space.intersect_ray(query)
	return result.is_empty()

func _get_player() -> Node:
	if _player_ref and is_instance_valid(_player_ref):
		return _player_ref
	_player_ref = get_tree().get_root().get_node_or_null("Main/Player")
	return _player_ref

func get_shoot_range() -> float:
	var p = _get_player()
	if p and p.stats:
		return p.stats.shoot_range * range_multiplier
	return 300.0 * range_multiplier

func update_target():
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.size() == 0:
		current_target = null
		return
	var shoot_range = get_shoot_range()
	var range_sq = shoot_range * shoot_range
	var closest = null
	var min_dist_sq = INF
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var d_sq = global_position.distance_squared_to(e.global_position)
		if d_sq > range_sq:
			continue
		if d_sq >= min_dist_sq:
			continue
		if not has_line_of_sight(e):
			continue
		min_dist_sq = d_sq
		closest = e
	current_target = closest

func rotate_to_target():
	if current_target == null:
		return
	look_at(current_target.global_position)
	var spr := get_node_or_null("WeaponSprite") as Sprite2D
	if spr:
		# Use world-space direction to target — avoids local-rotation confusion
		# when parent node has non-unit scale (WeaponSlot1 has scale 0.5).
		var facing_left := (current_target.global_position.x - global_position.x) < 0.0
		spr.flip_h = true          # barrel (left of texture) → local +X → toward target
		spr.flip_v = facing_left   # correct upside-down only when truly facing left

func shoot(_projectile_scene: PackedScene, _player_pos: Vector2):
	pass

func _setup_sprite(tex_path: String, spr_scale: Vector2) -> void:
	for child in get_children():
		if child is Polygon2D:
			child.visible = false
	var spr: Sprite2D = null
	for child in get_children():
		if child is Sprite2D:
			spr = child
			break
	if spr == null:
		spr = Sprite2D.new()
		add_child(spr)
	spr.name = "WeaponSprite"
	var tex = load(tex_path)
	if tex:
		spr.texture = tex
	spr.scale = spr_scale
	spr.flip_h = true
	spr.visible = true
