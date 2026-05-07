extends Area2D

var direction := Vector2.ZERO
var speed := 200.0
var damage := 1
var max_distance := 600.0
var start_position := Vector2.ZERO

func _ready():
	start_position = global_position
	# Rotiraj sprite u smjeru leta
	rotation = direction.angle() + deg_to_rad(90)
	get_tree().create_timer(4.0).timeout.connect(queue_free)

func _physics_process(delta):
	position += direction * speed * delta
	if global_position.distance_to(start_position) > max_distance:
		queue_free()

func _on_body_entered(body):
	if body.name == "Player" or body.is_in_group("player"):
		body.take_damage(damage)
		queue_free()
	elif body is TileMapLayer:
		queue_free()
	elif not body.is_in_group("enemy"):
		queue_free()
