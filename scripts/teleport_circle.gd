extends Node2D

signal player_teleported

@export var wait_duration := 3.0        # kolko sekundi player mora stat
@export var pulse_speed := 2.0
@export var radius := 60.0

@onready var light: PointLight2D = $PointLight2D
@onready var detection: Area2D = $DetectionArea

var _player_inside := false
var _charge_timer := 0.0
var _active := false
var _pulse_t := 0.0
var _player_ref: Node2D = null

func _ready():
	visible = false
	_draw_circle()

func _draw_circle():
	# Crtamo krug kao Line2D
	var line = Line2D.new()
	line.width = 4.0
	line.default_color = Color(0.2, 0.6, 1.0, 1.0)  # jaki plavi obrub
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	var points: PackedVector2Array = []
	var segments := 64
	for i in range(segments + 1):
		var angle = (float(i) / segments) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	line.points = points
	add_child(line)

	# Unutarnji fill – Polygon2D
	var poly = Polygon2D.new()
	poly.color = Color(0.1, 0.4, 1.0, 0.15)  # transparentan plavi fill
	var verts: PackedVector2Array = []
	for i in range(segments):
		var angle = (float(i) / segments) * TAU
		verts.append(Vector2(cos(angle), sin(angle)) * radius)
	poly.polygon = verts
	add_child(poly)

func activate() -> void:
	visible = true
	_active = true
	detection.connect("body_entered", _on_body_entered)
	detection.connect("body_exited", _on_body_exited)

func deactivate() -> void:
	_active = false
	visible = false

func _process(delta):
	if not _active:
		return

	# Pulse glow
	_pulse_t += delta * pulse_speed
	var pulse = (sin(_pulse_t) * 0.5 + 0.5)
	light.energy = lerpf(0.6, 1.4, pulse)
	light.scale = Vector2.ONE * lerpf(0.9, 1.1, pulse)

	# Charge kad je player unutra
	if _player_inside and _player_ref != null:
		_charge_timer += delta
		if _charge_timer >= wait_duration:
			_active = false
			player_teleported.emit()
	else:
		_charge_timer = 0.0

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_player_ref = body
		if "portal_invincible" in body:
			body.portal_invincible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		if "portal_invincible" in body:
			body.portal_invincible = false
		_player_ref = null
