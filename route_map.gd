extends Node2D

const COLS := 3
const ROWS := 6   # start + 4 wava + boss
const NODE_RADIUS := 28.0
const H_SPACING := 180.0
const V_SPACING := 100.0

enum NodeType { COMBAT, BOSS }

const COLOR_COMBAT         = Color(0.8, 0.2, 0.2, 1.0)
const COLOR_BOSS           = Color(0.9, 0.1, 0.9, 1.0)
const COLOR_LOCKED         = Color(0.25, 0.25, 0.28, 1.0)
const COLOR_DONE           = Color(0.2, 0.5, 0.2, 1.0)
const COLOR_AVAILABLE      = Color(1.0, 0.85, 0.2, 1.0)
const COLOR_LINE           = Color(0.35, 0.35, 0.38, 0.8)
const COLOR_LINE_DONE      = Color(0.2, 0.5, 0.2, 0.9)
const COLOR_LINE_AVAILABLE = Color(1.0, 0.85, 0.2, 0.7)
const COLOR_BG             = Color(0.06, 0.06, 0.10, 1.0)

var nodes       := []
var connections := []
var rng         := RandomNumberGenerator.new()

var _zoom        := 1.0
var _zoom_min    := 0.4
var _zoom_max    := 2.5
var _pan_offset  := Vector2.ZERO
var _dragging    := false
var _drag_start  := Vector2.ZERO
var _pan_at_drag := Vector2.ZERO

var _canvas       : CanvasLayer = null
var _draw_node    : Control     = null
var _node_buttons := []

func _ready():
	rng.randomize()
	_build_background()

	if GameManager.route_generated:
		# Restore postojeći map
		nodes = GameManager.route_nodes.duplicate(true)
		connections = GameManager.route_connections.duplicate(true)
	else:
		# Generiraj novu mapu; ako nema prethodnih statova, inicijaliziraj run
		if GameManager.player_stats == null:
			GameManager.start_new_run()
		_generate_map()
		GameManager.route_generated = true
		GameManager.route_nodes = nodes.duplicate(true)
		GameManager.route_connections = connections.duplicate(true)

	_fit_map_to_screen()
	_build_ui()

func _build_background():
	var bg = ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var c = CanvasLayer.new()
	c.layer = -1
	add_child(c)
	c.add_child(bg)

func _fit_map_to_screen():
	var vp = get_viewport_rect().size
	var map_w = (COLS - 1) * H_SPACING
	var map_h = ROWS * V_SPACING  # +1 za start row
	var margin = 160.0
	var scale_x = (vp.x - margin) / map_w
	var scale_y = (vp.y - margin - 80) / map_h
	_zoom = clampf(min(scale_x, scale_y), _zoom_min, _zoom_max)
	_pan_offset = vp * 0.5 - Vector2(map_w, map_h) * 0.5 * _zoom
	_pan_offset.y += 40

func _generate_map():
	nodes.clear()
	connections.clear()

	for row in range(ROWS):
		for col in range(COLS):
			var active = true
			var ntype  = NodeType.COMBAT
			var state  = "locked"

			if row == ROWS - 1:
				if col != 1:
					active = false
				else:
					ntype = NodeType.BOSS

			if row == 0:
				state = "available"

			nodes.append({
				"row": row, "col": col,
				"type": ntype, "state": state,
				"active": active, "connections": []
			})

	# START čvor – row -1, samo srednji, done od početka
	nodes.append({
		"row": -1, "col": 1,
		"type": NodeType.COMBAT, "state": "done",
		"active": true, "connections": []
	})
	# Spoji start na sve row 0 nodeove
	var start_idx = nodes.size() - 1
	for col in range(COLS):
		var r0_idx = _get_node_idx(0, col)
		if r0_idx != -1 and nodes[r0_idx]["active"]:
			_add_connection(start_idx, r0_idx)

	for row in range(ROWS - 1):
		for col in range(COLS):
			var from_idx = _get_node_idx(row, col)
			if from_idx == -1 or not nodes[from_idx]["active"]:
				continue

			if row == ROWS - 2:
				var to_idx = _get_node_idx(row + 1, 1)
				if to_idx != -1:
					_add_connection(from_idx, to_idx)
				continue

			var targets = [col]
			if col > 0 and rng.randf() > 0.4:
				targets.append(col - 1)
			if col < COLS - 1 and rng.randf() > 0.4:
				targets.append(col + 1)
			targets.shuffle()
			for i in range(min(2, targets.size())):
				var to_idx = _get_node_idx(row + 1, targets[i])
				if to_idx != -1 and nodes[to_idx]["active"]:
					_add_connection(from_idx, to_idx)

	for row in range(1, ROWS):
		for col in range(COLS):
			var idx = _get_node_idx(row, col)
			if idx == -1 or not nodes[idx]["active"]:
				continue
			var has_parent = false
			for conn in connections:
				if conn[1] == idx:
					has_parent = true
					break
			if not has_parent:
				var prev = []
				for c in range(COLS):
					var pidx = _get_node_idx(row - 1, c)
					if pidx != -1 and nodes[pidx]["active"]:
						prev.append(pidx)
				if prev.size() > 0:
					_add_connection(prev[rng.randi_range(0, prev.size()-1)], idx)

func _get_node_idx(row: int, col: int) -> int:
	for i in range(nodes.size()):
		if nodes[i]["row"] == row and nodes[i]["col"] == col:
			return i
	return -1

func _add_connection(from_idx: int, to_idx: int):
	for conn in connections:
		if conn[0] == from_idx and conn[1] == to_idx:
			return
	connections.append([from_idx, to_idx])
	if not nodes[from_idx]["connections"].has(to_idx):
		nodes[from_idx]["connections"].append(to_idx)

func _node_screen_pos(row: int, col: int) -> Vector2:
	var x = col * H_SPACING
	# row -1 je ispod row 0 za jedan V_SPACING
	var y = (ROWS - 1 - row) * V_SPACING
	return Vector2(x, y) * _zoom + _pan_offset

func _build_ui():
	_canvas = CanvasLayer.new()
	_canvas.layer = 10
	add_child(_canvas)

	_draw_node = _MapDrawer.new()
	_draw_node.map_ref = self
	_draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.add_child(_draw_node)

	var title = Label.new()
	title.text = "CHOOSE YOUR PATH"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_bottom = 48
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_canvas.add_child(title)

	var lvl_lbl = Label.new()
	lvl_lbl.text = "Level %d / %d" % [GameManager.current_level + 1, GameManager.total_levels]
	lvl_lbl.add_theme_font_size_override("font_size", 18)
	lvl_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 1))
	lvl_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	lvl_lbl.offset_top = 48
	lvl_lbl.offset_bottom = 74
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_canvas.add_child(lvl_lbl)

	_node_buttons.clear()
	for i in range(nodes.size()):
		if not nodes[i]["active"]:
			_node_buttons.append(null)
			continue
		var btn = _make_node_button(i)
		_canvas.add_child(btn)
		_node_buttons.append(btn)

func _make_node_button(i: int) -> Button:
	var nd = nodes[i]
	var pos = _node_screen_pos(nd["row"], nd["col"])
	var r = NODE_RADIUS * _zoom
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(r * 2, r * 2)
	btn.position = pos - Vector2(r, r)
	btn.text = "⚔" if nd["type"] == NodeType.COMBAT else "💀"
	btn.add_theme_font_size_override("font_size", int(18 * _zoom))
	_style_button(btn, nd["state"], nd["type"], r)
	btn.disabled = nd["state"] != "available"
	btn.pressed.connect(_on_node_selected.bind(i))
	return btn

func _style_button(btn: Button, state: String, ntype: NodeType, r: float):
	var color = _get_node_color(state, ntype)
	var s = StyleBoxFlat.new()
	s.bg_color = Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 0.9)
	s.set_corner_radius_all(int(r))
	s.border_color = color
	s.set_border_width_all(max(2, int(3 * _zoom)))
	btn.add_theme_stylebox_override("normal", s)
	var sh = StyleBoxFlat.new()
	sh.bg_color = color
	sh.set_corner_radius_all(int(r))
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", sh)

func _get_node_color(state: String, ntype: NodeType) -> Color:
	match state:
		"available": return COLOR_BOSS if ntype == NodeType.BOSS else COLOR_AVAILABLE
		"done":      return COLOR_DONE
		_:           return COLOR_LOCKED

func _on_node_selected(idx: int):
	var nd = nodes[idx]
	if nd["state"] != "available":
		return

	var selected_row = nd["row"]

	# Zaključaj sve ostale available nodeove u istom rowu
	for i in range(nodes.size()):
		if nodes[i]["row"] == selected_row and i != idx:
			if nodes[i]["state"] == "available":
				nodes[i]["state"] = "locked"

	# Odabrani postaje done
	nodes[idx]["state"] = "done"

	# Unlock children
	for child_idx in nd["connections"]:
		if nodes[child_idx]["state"] == "locked":
			nodes[child_idx]["state"] = "available"

	# Spremi updated state u GameManager
	GameManager.route_nodes = nodes.duplicate(true)
	GameManager.route_connections = connections.duplicate(true)

	GameManager.advance_level()
	await get_tree().create_timer(0.25).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.12)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 1.0 / 1.12)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			if _dragging:
				_drag_start  = event.position
				_pan_at_drag = _pan_offset
	if event is InputEventMouseMotion and _dragging:
		_pan_offset = _pan_at_drag + (event.position - _drag_start)
		_rebuild_buttons()
		_draw_node.queue_redraw()

func _zoom_at(mouse_pos: Vector2, factor: float):
	var new_zoom = clampf(_zoom * factor, _zoom_min, _zoom_max)
	_pan_offset = mouse_pos + (_pan_offset - mouse_pos) * (new_zoom / _zoom)
	_zoom = new_zoom
	_rebuild_buttons()
	_draw_node.queue_redraw()

func _rebuild_buttons():
	for i in range(_node_buttons.size()):
		var btn = _node_buttons[i]
		if btn == null:
			continue
		var nd = nodes[i]
		var pos = _node_screen_pos(nd["row"], nd["col"])
		var r = NODE_RADIUS * _zoom
		btn.custom_minimum_size = Vector2(r * 2, r * 2)
		btn.size = Vector2(r * 2, r * 2)
		btn.position = pos - Vector2(r, r)
		btn.add_theme_font_size_override("font_size", int(18 * _zoom))
		_style_button(btn, nd["state"], nd["type"], r)

class _MapDrawer extends Control:
	var map_ref: Node2D = null

	func _draw():
		if map_ref == null:
			return
		var r = map_ref.NODE_RADIUS * map_ref._zoom

		for conn in map_ref.connections:
			var fn = map_ref.nodes[conn[0]]
			var tn = map_ref.nodes[conn[1]]
			var fp = map_ref._node_screen_pos(fn["row"], fn["col"])
			var tp = map_ref._node_screen_pos(tn["row"], tn["col"])
			var col: Color
			var w: float
			if fn["state"] == "done" and tn["state"] == "done":
				col = map_ref.COLOR_LINE_DONE
				w   = 3.5
			elif fn["state"] == "done" and tn["state"] == "available":
				col = map_ref.COLOR_LINE_AVAILABLE
				w   = 3.0
			else:
				col = map_ref.COLOR_LINE
				w   = 1.5
			draw_line(fp, tp, col, w * map_ref._zoom, true)

		for i in range(map_ref.nodes.size()):
			var nd = map_ref.nodes[i]
			if not nd["active"]:
				continue
			var pos   = map_ref._node_screen_pos(nd["row"], nd["col"])
			var color = map_ref._get_node_color(nd["state"], nd["type"])
			if nd["state"] == "available":
				draw_circle(pos, r + 6 * map_ref._zoom, Color(color.r, color.g, color.b, 0.18))
			draw_circle(pos, r, Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.85))
			draw_arc(pos, r, 0, TAU, 48, color, 2.5 * map_ref._zoom, true)
