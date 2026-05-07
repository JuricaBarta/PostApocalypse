extends Node2D

signal landing_complete
signal departure_complete

@export var fly_in_duration := 2.5
@export var hover_duration := 1.0
@export var fly_out_duration := 1.8

@onready var sprite: Sprite2D = $Sprite2D

var _tween: Tween

func _ready():
	sprite.texture = load("res://Images/Art/SpaceShipOne.png")
	z_index = 100
	visible = false

func do_intro(landing_pos: Vector2) -> void:
	visible = true
	modulate.a = 1.0
	var start_pos = landing_pos + Vector2(0, -800)
	global_position = start_pos

	_tween = create_tween()
	_tween.tween_property(self, "global_position", landing_pos, fly_in_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hover_duration)
	await _tween.finished
	landing_complete.emit()

func do_outro(from_pos: Vector2) -> void:
	visible = true
	modulate.a = 1.0
	global_position = from_pos

	var exit_pos = from_pos + Vector2(1200, -200)
	_tween = create_tween()
	_tween.tween_property(self, "global_position", exit_pos, fly_out_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await _tween.finished
	visible = false
	departure_complete.emit()
