extends Control

@onready var xp_bar        = $ProgressBar
@onready var pending_label = $PendingLabel
@onready var minimap_display = $MinimapPanel/MinimapDisplay
@onready var hp_label      = $HPLabel
@onready var level_label   = $LevelLabel
@onready var hp_bar        = $HPBar

var wave_timer_label:       Label = null
var spaceship_warning_label: Label = null

var player:      Node2D        = null
var wall_layer:  TileMapLayer  = null
var wave_manager: Node2D       = null

var debug_timer  := 0.0
var frame_times  := []
var minimap_size := Vector2(150, 150)

# ─────────────────────────────────────────────
#  INIT
# ─────────────────────────────────────────────
func _ready():
	# HUD pokriva cijeli viewport — proceduralni layout radi sam
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_build_dynamic_nodes()
	_apply_styles()

	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

	await get_tree().process_frame
	player       = get_tree().get_root().get_node_or_null("Main/Player")
	wall_layer   = get_tree().get_root().get_node_or_null("Main/Map/WallLayer")
	wave_manager = get_tree().get_root().get_node_or_null("Main/WaveManager")

func _build_dynamic_nodes():
	# Timer (vrh, centar)
	var t        = Label.new()
	t.name       = "WaveTimerLabel"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	add_child(t)
	wave_timer_label = t

	# Warning / LEVEL UP poruka (sredina ekrana)
	var w        = Label.new()
	w.name       = "SpaceshipWarningLabel"
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	w.add_theme_font_size_override("font_size", 24)
	w.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
	w.hide()
	add_child(w)
	spaceship_warning_label = w

func _apply_styles():
	# XP bar
	var xp_bg   = _make_bar_bg()
	var xp_fill = StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.3, 0.8, 0.43, 0.85)
	xp_fill.set_corner_radius_all(4)
	xp_bar.add_theme_stylebox_override("background", xp_bg)
	xp_bar.add_theme_stylebox_override("fill", xp_fill)
	xp_bar.show_percentage = false

	# HP bar
	var hp_bg   = _make_bar_bg()
	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.85, 0.2, 0.2, 0.9)
	hp_fill.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override("background", hp_bg)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	hp_bar.min_value    = 0
	hp_bar.max_value    = 10
	hp_bar.value        = 10
	hp_bar.show_percentage = false
	hp_bar.fill_mode    = 0

	# HP label
	hp_label.add_theme_font_size_override("font_size", 16)
	hp_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))

	# Level label
	level_label.add_theme_font_size_override("font_size", 16)
	level_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))

	# Pending label
	pending_label.add_theme_font_size_override("font_size", 18)
	pending_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
	pending_label.hide()

	# Minimap
	var mm_style = StyleBoxFlat.new()
	mm_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	mm_style.set_border_width_all(2)
	mm_style.border_color = Color(0.6, 0.6, 0.6, 0.8)
	mm_style.set_corner_radius_all(4)
	$MinimapPanel.add_theme_stylebox_override("panel", mm_style)
	minimap_display.custom_minimum_size = minimap_size

func _make_bar_bg() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.5)
	s.set_border_width_all(2)
	s.border_color = Color(0.6, 0.6, 0.6, 0.8)
	s.set_corner_radius_all(4)
	return s

# ─────────────────────────────────────────────
#  LAYOUT PROCEDURAL
#  Svaki element pozicioniran relativno na vp
# ─────────────────────────────────────────────
func _update_layout():
	var vp := get_viewport_rect().size

	# ── Gornji lijevi kut ──────────────────
	hp_bar.position    = Vector2(10, 10)
	hp_bar.size        = Vector2(200, 18)
	hp_label.position  = Vector2(10, 36)
	level_label.position = Vector2(10, 57)

	# ── Gornji centar — timer ──────────────
	if wave_timer_label:
		wave_timer_label.position = Vector2(vp.x * 0.5 - 150, 8)
		wave_timer_label.size     = Vector2(300, 44)

	# ── Centar ekrana — warning poruka ─────
	if spaceship_warning_label:
		spaceship_warning_label.position = Vector2(vp.x * 0.5 - 150, vp.y * 0.38)
		spaceship_warning_label.size     = Vector2(300, 40)

	# ── Gornji desni kut — minimap ─────────
	$MinimapPanel.position = Vector2(vp.x - 210, 10)
	$MinimapPanel.size     = Vector2(200, 200)

	# ── Dno ekrana — XP bar ────────────────
	var xp_x = 200.0
	var xp_w = vp.x - 400.0  # margine lijevo/desno
	xp_bar.position = Vector2(xp_x, vp.y - 18)
	xp_bar.size     = Vector2(xp_w, 14)

	# Pending label desno od XP bara
	pending_label.position = Vector2(xp_x + xp_w + 8, vp.y - 18)
	pending_label.size     = Vector2(60, 14)

# ─────────────────────────────────────────────
#  UPDATE
# ─────────────────────────────────────────────
func _process(delta):
	if player == null:
		return

	xp_bar.value    = float(player.xp) / float(player.xp_per_level) * 100.0
	hp_bar.value    = player.hp
	hp_bar.max_value = player.max_hp
	hp_label.text   = "HP: %d / %d" % [player.hp, player.max_hp]
	level_label.text = "Level: %d" % player.level

	if player.get("multiplayer_mode") and player.pending_levelups > 0:
		pending_label.text = "x" + str(player.pending_levelups)
		pending_label.show()
	else:
		pending_label.hide()

	if wave_manager != null and wave_timer_label != null:
		var remaining = max(0.0, wave_manager.wave_duration - wave_manager.wave_timer)
		var minutes   = int(remaining) / 60
		var seconds   = int(remaining) % 60
		wave_timer_label.text = "%d:%02d" % [minutes, seconds]

		if wave_manager.get("spaceship_warning_active"):
			var blink = int(Time.get_ticks_msec() / 333) % 2
			wave_timer_label.visible = (blink == 0)
		else:
			wave_timer_label.visible = true

		var slot_machine = get_tree().get_root().get_node_or_null("Main/UI/SlotMachine")
		var show_warning = slot_machine != null and slot_machine.visible

		if show_warning:
			if remaining <= 30.0:
				wave_timer_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
				spaceship_warning_label.text = "SPACESHIP INCOMING"
				spaceship_warning_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
			else:
				wave_timer_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
				spaceship_warning_label.text = "LEVEL UP"
				spaceship_warning_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
			spaceship_warning_label.show()
		else:
			spaceship_warning_label.hide()
			wave_timer_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))

	minimap_display.queue_redraw()

	# Debug
	debug_timer += delta
	frame_times.append(delta)
	if frame_times.size() > 60:
		frame_times.pop_front()
	if debug_timer >= 3.0:
		debug_timer = 0.0
		var enemy_count  = get_tree().get_nodes_in_group("enemy").size()
		var object_count = Performance.get_monitor(Performance.OBJECT_COUNT)
		var proj = 0; var orbs = 0; var pbul = 0; var other = 0
		for node in get_tree().current_scene.get_children():
			if node is Area2D:
				if node.name.begins_with("TankProjectile"): proj += 1
				elif node.name.begins_with("Projectile") or node.name.begins_with("projectile"): pbul += 1
				elif node.name.begins_with("XP") or node.name.begins_with("Heal") or node.name.begins_with("Magnet"): orbs += 1
				else: other += 1
		print("📊 FPS:%d | Enemies:%d | TProj:%d | PBul:%d | Orbs:%d | Other:%d | Obj:%d" % [
			Engine.get_frames_per_second(), enemy_count, proj, pbul, orbs, other, object_count])
