extends Control

var player: Node2D = null
var wall_layer: TileMapLayer = null
var scrap_layer: TileMapLayer = null
var map_node: Node2D = null

# Map config
var map_w := 280
var map_h := 280
var tile_size := 16  # pixels per tile

# Minimap config
var minimap_zoom := 0.2  # 10% of actual size
var minimap_offset := Vector2.ZERO

# Scrap type colors
var scrap_colors := {
	0: Color(0.6, 0.6, 0.6, 1),    # GENERIC - siva
	1: Color(0.6, 0.6, 0.6, 1),    # GENERIC - siva
	2: Color(0.6, 0.6, 0.6, 1),    # GENERIC - siva
	3: Color(0.55, 0.55, 0.55, 1), # METAL - tamnija siva
	4: Color(0.55, 0.55, 0.55, 1), # METAL - tamnija siva
	5: Color(0.7, 0.5, 0.3, 1),    # COPPER - smeđa
	6: Color(0.7, 0.5, 0.3, 1),    # COPPER - smeđa
	7: Color(0.2, 0.8, 0.3, 1),    # CIRCUIT - zelena
	8: Color(0.2, 0.8, 0.3, 1),    # CIRCUIT - zelena
	9: Color(0.2, 0.8, 0.8, 1),    # BIOGEL - tirkizna
	10: Color(0.2, 0.8, 0.8, 1),   # BIOGEL - tirkizna
	11: Color(0.3, 0.6, 1.0, 1),   # POWERCELL - plava
	12: Color(0.3, 0.6, 1.0, 1),   # POWERCELL - plava
	13: Color(0.7, 0.3, 1.0, 1),   # NANOCHIP - ljubicasta
	14: Color(0.7, 0.3, 1.0, 1),   # NANOCHIP - ljubicasta
}

func _ready():
	await get_tree().process_frame
	player = get_tree().get_root().get_node_or_null("Main/Player")
	wall_layer = get_tree().get_root().get_node_or_null("Main/Map/WallLayer")
	scrap_layer = get_tree().get_root().get_node_or_null("Main/Map/ScrapLayer")
	map_node = get_tree().get_root().get_node_or_null("Main/Map")

func _process(_delta):
	if player:
		# Prati playera - centruiraj minimap na njega
		var player_tile_pos = player.global_position / tile_size
		var minimap_center = size / 2
		minimap_offset = minimap_center - (player_tile_pos * minimap_zoom * tile_size)
		queue_redraw()

func _draw():
	if player == null or wall_layer == null or scrap_layer == null:
		return

	var minimap_rect = Rect2(Vector2.ZERO, size)
	var tile_size_minimap = tile_size * minimap_zoom

	# 1. Crtaj tlo - zeleno/smeđe
	draw_rect(minimap_rect, Color(0.4, 0.35, 0.2, 1))

	# Izračunaj vidljive tile-ove (samo ove crtaj)
	var visible_x_min = max(0, int(-minimap_offset.x / tile_size_minimap))
	var visible_y_min = max(0, int(-minimap_offset.y / tile_size_minimap))
	var visible_x_max = min(map_w, int((-minimap_offset.x + size.x) / tile_size_minimap) + 2)
	var visible_y_max = min(map_h, int((-minimap_offset.y + size.y) / tile_size_minimap) + 2)

	# 2. Crtaj walls - sivi blokovi (puni tile)
	for x in range(visible_x_min, visible_x_max):
		for y in range(visible_y_min, visible_y_max):
			var cell_id = wall_layer.get_cell_source_id(Vector2i(x, y))
			if cell_id != -1:  # Ima wall-a
				var minimap_pos = tile_to_minimap(Vector2i(x, y))
				draw_rect(Rect2(minimap_pos, Vector2(tile_size_minimap, tile_size_minimap)), Color(0.4, 0.4, 0.4, 1))

	# 3. Crtaj scrap - obojani blokovi po tipu
	for x in range(visible_x_min, visible_x_max):
		for y in range(visible_y_min, visible_y_max):
			var cell_id = scrap_layer.get_cell_source_id(Vector2i(x, y))
			if cell_id != -1:  # Ima scrapa
				var minimap_pos = tile_to_minimap(Vector2i(x, y))
				var scrap_color = scrap_colors.get(cell_id, Color(0.5, 0.5, 0.5, 1))
				draw_rect(Rect2(minimap_pos, Vector2(tile_size_minimap, tile_size_minimap)), scrap_color)

	# 4. Crtaj neprijatelje - crvene točkiced
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		var minimap_pos = world_to_minimap(enemy.global_position)
		if minimap_rect.has_point(minimap_pos):
			draw_circle(minimap_pos, 2.5, Color(1, 0.2, 0.2, 1))

	# 5. Crtaj co-op igrače - zelene točkice
	var all_players = get_tree().get_nodes_in_group("player")
	for p in all_players:
		if p != player:
			var minimap_pos = world_to_minimap(p.global_position)
			if minimap_rect.has_point(minimap_pos):
				draw_circle(minimap_pos, 2, Color(0.2, 1, 0.2, 1))

	# 6. Crtaj playera - velika bijela točkica u centru
	var player_minimap_pos = size / 2
	draw_circle(player_minimap_pos, 4, Color(1, 1, 1, 1))

func tile_to_minimap(tile_pos: Vector2i) -> Vector2:
	var world_pos = tile_pos * tile_size
	return world_to_minimap(world_pos)

func world_to_minimap(world_pos: Vector2) -> Vector2:
	var scaled_pos = world_pos * minimap_zoom
	return scaled_pos + minimap_offset
