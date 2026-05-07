extends Node2D

# Edge-of-screen strelica prema cilju
# Dodaj kao child od Player/Camera2D ili CanvasLayer

@export var target: Node2D = null
@export var margin := 60.0
@export var arrow_size := 24.0
@export var arrow_color := Color(0.2, 0.8, 1.0, 0.9)

var _visible_arrow := false

func _ready():
	z_index = 100
	set_process(false)
	hide()

func activate(t: Node2D) -> void:
	target = t
	show()
	set_process(true)

func deactivate() -> void:
	target = null
	hide()
	set_process(false)

func _process(_delta):
	if target == null or not is_instance_valid(target):
		return
	queue_redraw()

func _draw():
	if target == null or not is_instance_valid(target):
		return

	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return

	var screen_size = get_viewport_rect().size
	var half = screen_size * 0.5

	# Target pozicija relativno na centar ekrana
	var target_screen = cam.get_screen_center_position()
	var to_target = target.global_position - target_screen

	# Provjeri je li target na ekranu
	var local_target = to_target
	if abs(local_target.x) < half.x - margin and abs(local_target.y) < half.y - margin:
		return  # na ekranu, ne treba strelica

	# Klampaj na rub ekrana
	var dir = to_target.normalized()
	var t_x = (half.x - margin) / abs(dir.x) if abs(dir.x) > 0.001 else INF
	var t_y = (half.y - margin) / abs(dir.y) if abs(dir.y) > 0.001 else INF
	var t_min = min(t_x, t_y)
	var edge_pos = half + dir * t_min  # u screen koordinatama

	# Crtaj strelicu na edge_pos (u local coords ovog Node2D koji je child Camerae)
	var draw_pos = edge_pos - half  # centar = 0,0
	var angle = dir.angle()

	var tip = draw_pos + dir * arrow_size
	var left = draw_pos + Vector2(cos(angle + PI * 0.75), sin(angle + PI * 0.75)) * arrow_size
	var right = draw_pos + Vector2(cos(angle - PI * 0.75), sin(angle - PI * 0.75)) * arrow_size

	draw_colored_polygon(PackedVector2Array([tip, left, right]), arrow_color)
	draw_polyline(PackedVector2Array([tip, left, right, tip]), Color(1,1,1,0.6), 2.0)
