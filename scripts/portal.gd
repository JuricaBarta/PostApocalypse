extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_delay := 1.2

func _ready():

	# portal počinje mali
	scale = Vector2(0.08, 0.08)

	# random smjer rotacije
	var dir = 1
	if randi() % 2 == 0:
		dir = -1

	# tween animacija
	var tween = create_tween()
	tween.set_parallel(true)

	# rast portala
	tween.tween_property(self, "scale", Vector2(0.3,0.3), spawn_delay)

	# rotacija 360°
	tween.tween_property(self, "rotation", deg_to_rad(360 * dir), spawn_delay)

	# timer
	$Timer.wait_time = spawn_delay
	$Timer.start()


func _on_timer_timeout():

	if enemy_scene == null:
		queue_free()
		return

	var enemy = enemy_scene.instantiate()
	enemy.position = global_position

	get_tree().current_scene.add_child(enemy)

	queue_free()
