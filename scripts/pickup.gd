extends Area2D

class_name Pickup

enum PickupType { XP, HEAL, MAGNET }

@export var type: PickupType = PickupType.XP
@export var value := 1

var move_speed := 0.0
var player: Node2D = null
var attracting := false
var collected := false
var lifetime := 30.0

func _ready():
	player = get_tree().get_root().get_node("Main/Player")
	add_to_group("pickup")

func _process(delta):
	if player == null or collected:
		return
	
	# Lifetime — nestani nakon 30 sec ako te nitko ne pokupi
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	
	var dist = global_position.distance_to(player.global_position)
	
	if dist < 30:
		collected = true
		apply_effect()
		queue_free()
		return
	
	var radius = player.get_pickup_radius()
	if dist < radius or attracting:
		attracting = true
		move_speed = lerp(move_speed, 400.0, delta * 5)
		var dir = (player.global_position - global_position).normalized()
		global_position += dir * move_speed * delta

func apply_effect():
	match type:
		PickupType.XP:
			if player.has_method("add_xp"):
				player.add_xp(value)
		PickupType.HEAL:
			player.hp = min(player.hp + value, player.stats.max_hp)
			print("❤️ Healed +", value, "! HP: ", player.hp)
		PickupType.MAGNET:
			var all_pickups = get_tree().get_nodes_in_group("pickup")
			var count = 0
			for p in all_pickups:
				if p == self or p.collected:
					continue
				if p.type == PickupType.XP:
					p.attracting = true
					count += 1
			print("🧲 Magnet! Privučeno ", count, " XP orbova!")
