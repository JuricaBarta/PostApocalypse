extends Node2D

# === LAYER REFERENCES ===
@onready var ground = $GroundLayer
@onready var shadows = $ShadowLayer  # koristimo kao outline layer
@onready var walls = $WallLayer
@onready var scrap = $ScrapLayer

# === TILE SIZE ===
const TS = 16  # tile size in pixels

# === GROUND SOURCE IDS ===
const SAND_1 = 0
const SAND_2 = 1
const SAND_3 = 2
const SAND_4 = 3
const ROAD_1 = 4
const ROAD_2 = 5
const ROAD_MARK = 6
const RUBBLE_1 = 7
const RUBBLE_2 = 8
const RUBBLE_3 = 9

# === WALL SOURCE IDS ===
const WALL_CONCRETE_1 = 0
const WALL_CONCRETE_2 = 1
const WALL_CONCRETE_3 = 2
const WALL_BRICK = 3
const WALL_METAL = 4
const WALL_DANGER = 5
const WALL_FENCE = 6
const WALL_SKULL = 7

# === SCRAP SOURCE IDS ===
const SCRAP_GENERIC_1 = 0
const SCRAP_GENERIC_2 = 1
const SCRAP_GENERIC_3 = 2
const SCRAP_METAL_1 = 3
const SCRAP_METAL_2 = 4
const SCRAP_COPPER_1 = 5
const SCRAP_COPPER_2 = 6
const SCRAP_CIRCUIT_1 = 7
const SCRAP_CIRCUIT_2 = 8
const SCRAP_BIOGEL_1 = 9
const SCRAP_BIOGEL_2 = 10
const SCRAP_POWERCELL_1 = 11
const SCRAP_POWERCELL_2 = 12
const SCRAP_NANOCHIP_1 = 13
const SCRAP_NANOCHIP_2 = 14

# === SHADOW/OUTLINE ===
const SHADOW = 0

# === MAP CONFIG ===
@export var map_w := 280
@export var map_h := 280

var rng = RandomNumberGenerator.new()

enum Cell { EMPTY, SAND, ROAD_H, ROAD_V, CROSSROAD, SIDEWALK, WALL, SCRAP }

var grid = []
var wall_type_map = []
var scrap_type_map = []
var shape_noise = FastNoiseLite.new()
var scrap_hp := {}

func _ready():
	ground.clear()
	shadows.clear()
	walls.clear()
	scrap.clear()
	rng.randomize()

	shape_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	shape_noise.seed = rng.randi()
	shape_noise.frequency = 0.15  # Viša frequency za glađe, veće varijacije

	grid.resize(map_w)
	wall_type_map.resize(map_w)
	scrap_type_map.resize(map_w)
	for x in range(map_w):
		grid[x] = []
		grid[x].resize(map_h)
		wall_type_map[x] = []
		wall_type_map[x].resize(map_h)
		scrap_type_map[x] = []
		scrap_type_map[x].resize(map_h)
		for y in range(map_h):
			grid[x][y] = Cell.EMPTY
			wall_type_map[x][y] = -1
			scrap_type_map[x][y] = -1

	generate_roads()
	generate_ruins()
	generate_scrap_deposits()
	generate_border()
	generate_roads()
	generate_ruins()
	fill_remaining_sand()
	apply_to_tilemap()

	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	bake_navigation()

# =============================================
#  MAP SHAPE
# =============================================
func is_in_map(x: int, y: int) -> bool:
	var cx = float(x) / map_w - 0.5
	var cy = float(y) / map_h - 0.5
	var dist = sqrt(cx * cx + cy * cy)
	var n = shape_noise.get_noise_2d(x, y) * 0.02  # Minimalan šum - gotovo čist krug
	return dist + n < 0.42

# =============================================
#  BORDER — ograda oko ruba mape
# =============================================
func generate_border():
	for x in range(map_w):
		for y in range(map_h):
			if not is_in_map(x, y):
				continue
			# Provjeri jel TOCNO rubni — ovaj tile je unutra, ali bar jedan susjed je vani
			var has_outside_neighbor = false
			for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var nx = x + dir.x
				var ny = y + dir.y
				if nx < 0 or nx >= map_w or ny < 0 or ny >= map_h:
					has_outside_neighbor = true
					break
				if not is_in_map(nx, ny):
					has_outside_neighbor = true
					break
			if not has_outside_neighbor:
				continue
			# Provjeri da svi UNUTARNJI susjedi nisu već border
			# Ovo osigurava samo 1 tile debljinu
			var inner_neighbors = 0
			for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var nx = x + dir.x
				var ny = y + dir.y
				if nx >= 0 and nx < map_w and ny >= 0 and ny < map_h:
					if is_in_map(nx, ny):
						inner_neighbors += 1
			if inner_neighbors < 2:
				continue  # preskoci izolirane piksele

			grid[x][y] = Cell.WALL
			var roll = rng.randf()
			if roll < 0.02:
				wall_type_map[x][y] = WALL_SKULL
			elif roll < 0.10:
				wall_type_map[x][y] = WALL_DANGER
			else:
				wall_type_map[x][y] = WALL_FENCE

# =============================================
#  ROADS
# =============================================
func generate_roads():
	var main_h = rng.randi_range(map_h / 3, map_h * 2 / 3)
	var main_v = rng.randi_range(map_w / 3, map_w * 2 / 3)
	carve_road_h(0, main_h, map_w)
	carve_road_v(main_v, 0, map_h)

	for _i in range(rng.randi_range(5, 10)):
		var y = rng.randi_range(8, map_h - 8)
		var sx = rng.randi_range(0, map_w / 3)
		var ex = rng.randi_range(map_w * 2 / 3, map_w)
		if rng.randf() > 0.4:
			sx = rng.randi_range(map_w / 4, map_w / 2)
		carve_road_h(sx, y, ex - sx)

	for _i in range(rng.randi_range(5, 10)):
		var x = rng.randi_range(8, map_w - 8)
		var sy = rng.randi_range(0, map_h / 3)
		var ey = rng.randi_range(map_h * 2 / 3, map_h)
		if rng.randf() > 0.4:
			sy = rng.randi_range(map_h / 4, map_h / 2)
		carve_road_v(x, sy, ey - sy)

	for _i in range(rng.randi_range(8, 16)):
		if rng.randf() > 0.5:
			var y = rng.randi_range(8, map_h - 8)
			var x = rng.randi_range(5, map_w - 15)
			carve_road_h(x, y, rng.randi_range(5, 15))
		else:
			var x = rng.randi_range(8, map_w - 8)
			var y = rng.randi_range(5, map_h - 15)
			carve_road_v(x, y, rng.randi_range(5, 15))

	for x in range(1, map_w - 1):
		for y in range(1, map_h - 1):
			if grid[x][y] == Cell.ROAD_H or grid[x][y] == Cell.ROAD_V:
				var has_h = false
				var has_v = false
				for dx in [-1, 0, 1]:
					for dy in [-1, 0, 1]:
						var nx = x + dx
						var ny = y + dy
						if nx >= 0 and nx < map_w and ny >= 0 and ny < map_h:
							if grid[nx][ny] == Cell.ROAD_H:
								has_h = true
							if grid[nx][ny] == Cell.ROAD_V:
								has_v = true
				if has_h and has_v:
					grid[x][y] = Cell.CROSSROAD

func carve_road_h(x: int, y: int, length: int):
	for i in range(length):
		var tx = x + i
		if tx < 0 or tx >= map_w:
			continue
		for dy in [0, 1]:
			var ty = y + dy
			if ty >= 0 and ty < map_h and is_in_map(tx, ty):
				if grid[tx][ty] == Cell.EMPTY:
					grid[tx][ty] = Cell.ROAD_H

func carve_road_v(x: int, y: int, length: int):
	for i in range(length):
		var ty = y + i
		if ty < 0 or ty >= map_h:
			continue
		for dx in [0, 1]:
			var tx = x + dx
			if tx >= 0 and tx < map_w and is_in_map(tx, ty):
				if grid[tx][ty] == Cell.EMPTY:
					grid[tx][ty] = Cell.ROAD_V

# =============================================
#  RUINS
# =============================================
func generate_ruins():
	for _attempt in range(rng.randi_range(40, 80)):
		var cx = rng.randi_range(10, map_w - 10)
		var cy = rng.randi_range(10, map_h - 10)
		if not is_in_map(cx, cy):
			continue
		if grid[cx][cy] != Cell.EMPTY:
			continue

		var bw = rng.randi_range(3, 8)
		var bh = rng.randi_range(3, 6)

		var ok = true
		for bx in range(cx - 1, cx + bw + 1):
			for by in range(cy - 1, cy + bh + 1):
				if bx < 0 or bx >= map_w or by < 0 or by >= map_h:
					ok = false
					break
				if grid[bx][by] != Cell.EMPTY:
					ok = false
					break
			if not ok:
				break
		if not ok:
			continue

		var wtype = rng.randi_range(0, 4)

		for bx in range(cx, cx + bw):
			for by in range(cy, cy + bh):
				var is_edge = bx == cx or bx == cx + bw - 1 or by == cy or by == cy + bh - 1
				if is_edge:
					grid[bx][by] = Cell.WALL
					wall_type_map[bx][by] = wtype
				else:
					if rng.randf() > 0.5:
						grid[bx][by] = Cell.SIDEWALK

		var damage_count = rng.randi_range(1, bw + bh)
		for _d in range(damage_count):
			var dx = rng.randi_range(cx, cx + bw - 1)
			var dy = rng.randi_range(cy, cy + bh - 1)
			if grid[dx][dy] == Cell.WALL:
				grid[dx][dy] = Cell.SIDEWALK

# =============================================
#  SCRAP DEPOSITS
# =============================================
func generate_scrap_deposits():
	var cluster_noise = FastNoiseLite.new()
	cluster_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	cluster_noise.seed = rng.randi()
	cluster_noise.frequency = 0.08

	var num_clusters = rng.randi_range(120, 180)

	for _c in range(num_clusters):
		var cx = rng.randi_range(15, map_w - 15)
		var cy = rng.randi_range(15, map_h - 15)
		if not is_in_map(cx, cy):
			continue
		if grid[cx][cy] != Cell.EMPTY:
			continue

		var cluster_radius = rng.randi_range(5, 18)

		for dx in range(-cluster_radius, cluster_radius + 1):
			for dy in range(-cluster_radius, cluster_radius + 1):
				var tx = cx + dx
				var ty = cy + dy
				if tx < 0 or tx >= map_w or ty < 0 or ty >= map_h:
					continue
				if not is_in_map(tx, ty):
					continue
				if grid[tx][ty] != Cell.EMPTY:
					continue

				var dist = sqrt(float(dx * dx + dy * dy))
				var n = cluster_noise.get_noise_2d(tx * 3, ty * 3) * 3.0
				if dist + n < cluster_radius * 0.7:
					grid[tx][ty] = Cell.SCRAP
					scrap_type_map[tx][ty] = [SCRAP_GENERIC_1, SCRAP_GENERIC_2, SCRAP_GENERIC_3][rng.randi_range(0, 2)]
					scrap_hp[Vector2i(tx, ty)] = 1

	carve_pathways()

	var metal_veins = rng.randi_range(5, 8)
	for _v in range(metal_veins):
		place_vein("metal", rng.randi_range(8, 20))

	var copper_veins = rng.randi_range(3, 5)
	for _v in range(copper_veins):
		place_vein("copper", rng.randi_range(5, 12))

func carve_pathways():
	var y = rng.randi_range(8, 15)
	while y < map_h - 8:
		var path_width = rng.randi_range(2, 4)
		for x in range(map_w):
			for pw in range(path_width):
				var py = y + pw
				if py >= 0 and py < map_h and is_in_map(x, py):
					if grid[x][py] == Cell.SCRAP:
						grid[x][py] = Cell.EMPTY
						scrap_type_map[x][py] = -1
						scrap_hp.erase(Vector2i(x, py))
		y += rng.randi_range(15, 25)

	var x = rng.randi_range(8, 15)
	while x < map_w - 8:
		var path_width = rng.randi_range(2, 4)
		for yy in range(map_h):
			for pw in range(path_width):
				var px = x + pw
				if px >= 0 and px < map_w and is_in_map(px, yy):
					if grid[px][yy] == Cell.SCRAP:
						grid[px][yy] = Cell.EMPTY
						scrap_type_map[px][yy] = -1
						scrap_hp.erase(Vector2i(px, yy))
		x += rng.randi_range(15, 25)

	for _d in range(rng.randi_range(4, 8)):
		var sx = rng.randi_range(0, map_w - 1)
		var sy = rng.randi_range(0, map_h - 1)
		var dx = rng.randi_range(-1, 1)
		var dy = rng.randi_range(-1, 1)
		if dx == 0 and dy == 0:
			dx = 1
		var length = rng.randi_range(30, 80)
		for _i in range(length):
			for pw in range(-1, 2):
				var cx = sx + pw * (1 if dx == 0 else 0)
				var cy = sy + pw * (1 if dy == 0 else 0)
				if cx >= 0 and cx < map_w and cy >= 0 and cy < map_h:
					if grid[cx][cy] == Cell.SCRAP:
						grid[cx][cy] = Cell.EMPTY
						scrap_type_map[cx][cy] = -1
						scrap_hp.erase(Vector2i(cx, cy))
			sx += dx
			sy += dy
			if rng.randf() > 0.7:
				sx += rng.randi_range(-1, 1)
			if rng.randf() > 0.7:
				sy += rng.randi_range(-1, 1)
			sx = clampi(sx, 0, map_w - 1)
			sy = clampi(sy, 0, map_h - 1)

	var center_x = map_w / 2
	var center_y = map_h / 2
	for dx in range(-8, 9):
		for dy in range(-8, 9):
			var tx = center_x + dx
			var ty = center_y + dy
			if tx >= 0 and tx < map_w and ty >= 0 and ty < map_h:
				if grid[tx][ty] == Cell.SCRAP:
					grid[tx][ty] = Cell.EMPTY
					scrap_type_map[tx][ty] = -1
					scrap_hp.erase(Vector2i(tx, ty))

func place_vein(type: String, size: int):
	var start_x = 0
	var start_y = 0
	var found = false
	for _attempt in range(100):
		start_x = rng.randi_range(15, map_w - 15)
		start_y = rng.randi_range(15, map_h - 15)
		if is_in_map(start_x, start_y) and grid[start_x][start_y] == Cell.SCRAP:
			found = true
			break
	if not found:
		return

	var vein_tiles = [Vector2i(start_x, start_y)]
	var placed = 0

	while placed < size and vein_tiles.size() > 0:
		var idx = rng.randi_range(0, vein_tiles.size() - 1)
		var current = vein_tiles[idx]
		var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
		dirs.shuffle()
		var expanded = false

		for dir in dirs:
			var nx = current.x + dir.x
			var ny = current.y + dir.y
			if nx < 0 or nx >= map_w or ny < 0 or ny >= map_h:
				continue
			if not is_in_map(nx, ny):
				continue
			if grid[nx][ny] != Cell.SCRAP:
				continue
			if scrap_type_map[nx][ny] != SCRAP_GENERIC_1 and \
			   scrap_type_map[nx][ny] != SCRAP_GENERIC_2 and \
			   scrap_type_map[nx][ny] != SCRAP_GENERIC_3:
				continue

			var new_pos = Vector2i(nx, ny)
			match type:
				"metal":
					scrap_type_map[nx][ny] = [SCRAP_METAL_1, SCRAP_METAL_2][rng.randi_range(0, 1)]
					scrap_hp[new_pos] = 5
				"copper":
					scrap_type_map[nx][ny] = [SCRAP_COPPER_1, SCRAP_COPPER_2][rng.randi_range(0, 1)]
					scrap_hp[new_pos] = 8

			vein_tiles.append(new_pos)
			placed += 1
			expanded = true
			break

		if not expanded:
			vein_tiles.remove_at(idx)

func get_scrap_hp(source_id: int) -> int:
	match source_id:
		SCRAP_GENERIC_1, SCRAP_GENERIC_2, SCRAP_GENERIC_3:
			return 1
		SCRAP_METAL_1, SCRAP_METAL_2:
			return 5
		SCRAP_COPPER_1, SCRAP_COPPER_2:
			return 8
		SCRAP_CIRCUIT_1, SCRAP_CIRCUIT_2:
			return 12
		SCRAP_BIOGEL_1, SCRAP_BIOGEL_2:
			return 15
		SCRAP_POWERCELL_1, SCRAP_POWERCELL_2:
			return 20
		SCRAP_NANOCHIP_1, SCRAP_NANOCHIP_2:
			return 25
	return 1

# =============================================
#  FILL REMAINING
# =============================================
func fill_remaining_sand():
	for x in range(map_w):
		for y in range(map_h):
			if grid[x][y] == Cell.EMPTY:
				grid[x][y] = Cell.SAND

# =============================================
#  APPLY TO TILEMAP (bez shadowsa)
# =============================================
func apply_to_tilemap():
	for x in range(map_w):
		for y in range(map_h):
			var pos = Vector2i(x, y)

			var sand_id = rng.randi_range(SAND_1, SAND_4)
			ground.set_cell(pos, sand_id, Vector2i(0, 0))

			var cell = grid[x][y]
			match cell:
				Cell.ROAD_H, Cell.ROAD_V:
					var road_id = ROAD_1 if rng.randf() > 0.3 else ROAD_2
					ground.set_cell(pos, road_id, Vector2i(0, 0))

				Cell.CROSSROAD:
					ground.set_cell(pos, ROAD_MARK, Vector2i(0, 0))

				Cell.SIDEWALK:
					var rubble_id = [RUBBLE_1, RUBBLE_2, RUBBLE_3][rng.randi_range(0, 2)]
					ground.set_cell(pos, rubble_id, Vector2i(0, 0))

				Cell.WALL:
					var wtype = wall_type_map[x][y]
					if wtype < 0:
						wtype = 0
					walls.set_cell(pos, wtype, Vector2i(0, 0))

				Cell.SCRAP:
					var stype = scrap_type_map[x][y]
					if stype >= 0:
						scrap.set_cell(pos, stype, Vector2i(0, 0))

			# Outline — ako je prazan tile uz wall/scrap
			if cell != Cell.WALL and cell != Cell.SCRAP:
				var is_border = false
				for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var nx = x + dir.x
					var ny = y + dir.y
					if nx >= 0 and nx < map_w and ny >= 0 and ny < map_h:
						var ng = grid[nx][ny]
						if ng == Cell.WALL or ng == Cell.SCRAP:
							is_border = true
							break
				if is_border:
					shadows.set_cell(pos, SHADOW, Vector2i(0, 0))

func refresh_outline_around(pos: Vector2i):
	# Refreshaj 3x3 okolinu oko uništenog tilea
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var tx = pos.x + dx
			var ty = pos.y + dy
			if tx < 0 or tx >= map_w or ty < 0 or ty >= map_h:
				continue
			# Makni stari outline na ovom tileu
			shadows.set_cell(Vector2i(tx, ty), -1)
			# Ako je prazan tile uz scrap/wall, dodaj outline
			if grid[tx][ty] != Cell.WALL and grid[tx][ty] != Cell.SCRAP:
				for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var nx = tx + dir.x
					var ny = ty + dir.y
					if nx < 0 or nx >= map_w or ny < 0 or ny >= map_h:
						continue
					if grid[nx][ny] == Cell.WALL or grid[nx][ny] == Cell.SCRAP:
						shadows.set_cell(Vector2i(tx, ty), SHADOW, Vector2i(0, 0))
						break

# =============================================
#  SCRAP MINING
# =============================================
func mine_scrap(tile_pos: Vector2i, damage: int) -> Dictionary:
	if not scrap_hp.has(tile_pos):
		return {"destroyed": false, "scrap_type": "", "amount": 0}

	scrap_hp[tile_pos] -= damage
	if scrap_hp[tile_pos] <= 0:
		var source_id = scrap_type_map[tile_pos.x][tile_pos.y]
		var result = get_scrap_reward(source_id)

		# Ukloni scrap tile
		scrap.set_cell(tile_pos, -1)

		# Update grid
		grid[tile_pos.x][tile_pos.y] = Cell.SAND
		scrap_type_map[tile_pos.x][tile_pos.y] = -1
		scrap_hp.erase(tile_pos)

		# Refreshaj outline oko uništenog tilea
		refresh_outline_around(tile_pos)

		return result

	return {"destroyed": false, "scrap_type": "", "amount": 0}

func get_scrap_reward(source_id: int) -> Dictionary:
	match source_id:
		SCRAP_GENERIC_1, SCRAP_GENERIC_2, SCRAP_GENERIC_3:
			return {"destroyed": true, "scrap_type": "generic", "amount": rng.randi_range(1, 3)}
		SCRAP_METAL_1, SCRAP_METAL_2:
			return {"destroyed": true, "scrap_type": "metal", "amount": rng.randi_range(1, 2)}
		SCRAP_COPPER_1, SCRAP_COPPER_2:
			return {"destroyed": true, "scrap_type": "copper", "amount": rng.randi_range(1, 2)}
		SCRAP_CIRCUIT_1, SCRAP_CIRCUIT_2:
			return {"destroyed": true, "scrap_type": "circuit", "amount": rng.randi_range(1, 2)}
		SCRAP_BIOGEL_1, SCRAP_BIOGEL_2:
			return {"destroyed": true, "scrap_type": "biogel", "amount": 1}
		SCRAP_POWERCELL_1, SCRAP_POWERCELL_2:
			return {"destroyed": true, "scrap_type": "powercell", "amount": 1}
		SCRAP_NANOCHIP_1, SCRAP_NANOCHIP_2:
			return {"destroyed": true, "scrap_type": "nanochip", "amount": 1}
	return {"destroyed": true, "scrap_type": "generic", "amount": 1}

# =============================================
#  NAVIGATION
# =============================================
func bake_navigation():
	var nav_region = get_tree().get_root().get_node_or_null("Main/NavigationRegion2D")
	if not nav_region:
		print("No NavigationRegion2D found!")
		return

	var nav_poly = NavigationPolygon.new()
	var outline = PackedVector2Array([
		Vector2(0, 0),
		Vector2(map_w * TS, 0),
		Vector2(map_w * TS, map_h * TS),
		Vector2(0, map_h * TS)
	])
	nav_poly.add_outline(outline)

	for y in range(map_h):
		var x = 0
		while x < map_w:
			if grid[x][y] == Cell.WALL or grid[x][y] == Cell.SCRAP:
				var start_x = x
				while x < map_w and (grid[x][y] == Cell.WALL or grid[x][y] == Cell.SCRAP):
					x += 1
				var end_x = x
				var margin = 1.0
				var hole = PackedVector2Array([
					Vector2(start_x * TS - margin, y * TS + TS + margin),
					Vector2(end_x * TS + margin, y * TS + TS + margin),
					Vector2(end_x * TS + margin, y * TS - margin),
					Vector2(start_x * TS - margin, y * TS - margin)
				])
				nav_poly.add_outline(hole)
			else:
				x += 1

	nav_poly.make_polygons_from_outlines()
	nav_region.navigation_polygon = nav_poly
	nav_region.bake_navigation_polygon()
	print("Navigation baked!")
	
func mine_scrap_no_outline(tile_pos: Vector2i, damage: int) -> Dictionary:
	if not scrap_hp.has(tile_pos):
		return {"destroyed": false, "scrap_type": "", "amount": 0}

	scrap_hp[tile_pos] -= damage
	if scrap_hp[tile_pos] <= 0:
		var source_id = scrap_type_map[tile_pos.x][tile_pos.y]
		var result = get_scrap_reward(source_id)

		scrap.set_cell(tile_pos, -1)
		grid[tile_pos.x][tile_pos.y] = Cell.SAND
		scrap_type_map[tile_pos.x][tile_pos.y] = -1
		scrap_hp.erase(tile_pos)

		return result

	return {"destroyed": false, "scrap_type": "", "amount": 0}

func batch_refresh_outlines(positions: Array):
	# Skupi sve tileove koje treba provjeriti
	var to_check = {}
	for pos in positions:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var tx = pos.x + dx
				var ty = pos.y + dy
				if tx >= 0 and tx < map_w and ty >= 0 and ty < map_h:
					to_check[Vector2i(tx, ty)] = true

	# Jednom prođi sve
	for tile_pos in to_check:
		shadows.set_cell(tile_pos, -1)
		if grid[tile_pos.x][tile_pos.y] != Cell.WALL and grid[tile_pos.x][tile_pos.y] != Cell.SCRAP:
			for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var nx = tile_pos.x + dir.x
				var ny = tile_pos.y + dir.y
				if nx >= 0 and nx < map_w and ny >= 0 and ny < map_h:
					if grid[nx][ny] == Cell.WALL or grid[nx][ny] == Cell.SCRAP:
						shadows.set_cell(tile_pos, SHADOW, Vector2i(0, 0))
						break


func spawn_scrap_clump(world_pos: Vector2, scrap_type_id: int, radius: int = 4) -> void:
	var cx = int(world_pos.x / TS)
	var cy = int(world_pos.y / TS)
	var placed_tiles: Array = []
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var tx = cx + dx
			var ty = cy + dy
			if tx < 2 or tx >= map_w - 2 or ty < 2 or ty >= map_h - 2:
				continue
			if not is_in_map(tx, ty):
				continue
			if grid[tx][ty] != Cell.SAND:
				continue
			if rng.randf() < 0.55:
				var pos = Vector2i(tx, ty)
				grid[tx][ty] = Cell.SCRAP
				scrap_type_map[tx][ty] = scrap_type_id
				scrap_hp[pos] = get_scrap_hp(scrap_type_id)
				scrap.set_cell(pos, scrap_type_id, Vector2i(0, 0))
				placed_tiles.append(pos)
	if placed_tiles.size() > 0:
		batch_refresh_outlines(placed_tiles)

func find_safe_position(center: Vector2, min_radius: float, max_radius: float) -> Vector2:
	var rng2 = RandomNumberGenerator.new()
	rng2.randomize()
	
	for _attempt in range(200):
		var angle = rng2.randf_range(0.0, TAU)
		var dist = rng2.randf_range(min_radius, max_radius)
		var world_pos = center + Vector2(cos(angle), sin(angle)) * dist
		
		var tx = int(world_pos.x / TS)
		var ty = int(world_pos.y / TS)
		
		# Provjeri bounds
		if tx < 2 or tx >= map_w - 2 or ty < 2 or ty >= map_h - 2:
			continue
		
		# Provjeri je li unutar mape
		if not is_in_map(tx, ty):
			continue
		
		# Provjeri 3x3 okolinu – mora biti sve SAND ili ROAD
		var safe = true
		for dx in range(-3, 4):
			for dy in range(-3, 4):
				var cx2 = tx + dx
				var cy2 = ty + dy
				if cx2 < 0 or cx2 >= map_w or cy2 < 0 or cy2 >= map_h:
					safe = false
					break
				var cell = grid[cx2][cy2]
				if cell == Cell.WALL or cell == Cell.SCRAP:
					safe = false
					break
			if not safe:
				break
		
		if safe:
			return world_pos
	
	# Fallback – vrati centar mape
	push_warning("find_safe_position: nije nađena slobodna pozicija, koristim centar mape")
	return Vector2(map_w * TS * 0.5, map_h * TS * 0.5)
