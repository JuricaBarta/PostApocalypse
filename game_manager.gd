extends Node

# =============================================
#  GameManager — Autoload singleton
#  Naziv u Project Settings: "GameManager"
# =============================================

# === TRENUTNI RUN — resetira se na novi run ===
var player_stats: PlayerStats = null
var hp := 10
var level := 1
var xp := 0
var xp_per_level := 100
var pending_levelups := 0
var equipped_weapons := []  # lista weapon scene pathova
var weapon_stats := []  # lista Dictionary s weapon statsima

# All boolean ability flags across all weapons (added/removed via milestones).
# Adding a new weapon? Add its ability flag names here.
const WEAPON_ABILITY_FLAGS := [
	"parallel_fire", "reverse_fire",            # pistol
	"full_pierce", "wavy_fire",                 # shotgun
	"heat_sink", "bullet_storm",                # minigun
	"akimbo", "adrenaline",                     # uzi
	"headshot", "railgun",                      # sniper
	"quick_draw", "penetrator", "dead_shot",    # revolver
	"quick_mag", "steady_burst", "overcharged", # ak77
	"choke_mod", "slug_round", "dual_blast",    # dbs
	"heavy_warhead", "warhead_plus", "barrage", # rocket
]

var scrap_inventory := {
	"generic": 0,
	"metal": 0,
	"copper": 0,
	"circuit": 0,
	"biogel": 0,
	"powercell": 0,
	"nanochip": 0,
}

# === TRENUTNA POZICIJA U RUNU ===
var current_level := 0       # koji smo level u runu
var total_levels := 7        # 6 combat + 1 boss
var run_active := false

# === PERMANENT — nikad se ne resetira ===
var permanent_scrap := 0
var permanent_upgrades := []  # lista id-eva kupljenih permanent upgradea

const SAVE_PATH = "user://permanent.sav"

# =============================================
#  INIT
# =============================================
func _ready():
	load_permanent()

# =============================================
#  RUN MANAGEMENT
# =============================================
func start_new_run():
	player_stats = PlayerStats.new()
	hp = player_stats.max_hp
	level = 1
	xp = 0
	xp_per_level = player_stats.xp_per_level
	pending_levelups = 0
	current_level = 0
	run_active = true
	for key in scrap_inventory:
		scrap_inventory[key] = 0
	print("[GameManager] Novi run started")
	reset_route()

func end_run(success: bool):
	run_active = false
	if success:
		# Prebaci dio session scrapa u permanent
		var bonus = scrap_inventory.get("generic", 0) / 2
		permanent_scrap += bonus
		print("[GameManager] Run završen! Permanent scrap +%d" % bonus)
	save_permanent()
	print("[GameManager] Run ended, success=%s" % success)

func advance_level():
	current_level += 1
	print("[GameManager] Level %d / %d" % [current_level, total_levels])

func is_run_complete() -> bool:
	return current_level >= total_levels

# =============================================
#  SYNC: Player → GameManager
#  Pozovi ovo PRIJE promjene scene
# =============================================
func save_player_state(player: Node):
	player_stats = player.stats
	hp = player.hp
	level = player.level
	xp = player.xp
	xp_per_level = player.xp_per_level
	pending_levelups = player.pending_levelups
	
	for key in scrap_inventory:
		scrap_inventory[key] = player.scrap_inventory.get(key, 0)
	
	equipped_weapons.clear()
	for slot in player.weapon_slots:
		if slot.get_child_count() > 0:
			var weapon = slot.get_child(0)
			equipped_weapons.append(weapon.scene_file_path)
		else:
			equipped_weapons.append("")
	
	weapon_stats.clear()
	for slot in player.weapon_slots:
		if slot.get_child_count() > 0:
			var w = slot.get_child(0)
			var d := {
				"damage": w.damage,
				"fire_rate_multiplier": w.fire_rate_multiplier,
				"reload_multiplier": w.reload_multiplier,
				"range_multiplier": w.range_multiplier,
				"spread_multiplier": w.spread_multiplier,
				"pierce_bonus": w.pierce_bonus,
				"max_ammo": w.max_ammo,
				"fire_rate": w.fire_rate,
				"weapon_level": w.weapon_level if "weapon_level" in w else 0,
				"proj_count": w.proj_count if "proj_count" in w else 1,
			}
			for flag in WEAPON_ABILITY_FLAGS:
				if flag in w:
					d[flag] = w.get(flag)
			weapon_stats.append(d)
		else:
			weapon_stats.append({})
	
	print("[GameManager] Player state saved")
# =============================================
#  SYNC: GameManager → Player
#  Pozovi ovo NAKON učitavanja nove scene
# =============================================
func restore_player_state(player: Node):
	if player_stats == null:
		player_stats = PlayerStats.new()
		hp = player_stats.max_hp
	player.stats = player_stats
	player.hp = hp
	player.level = level
	player.xp = xp
	player.xp_per_level = xp_per_level
	player.pending_levelups = pending_levelups
	for key in scrap_inventory:
		player.scrap_inventory[key] = scrap_inventory.get(key, 0)
	print("[GameManager] Player state restored")
	
	for i in range(equipped_weapons.size()):
		if i >= player.weapon_slots.size():
			break
		var path = equipped_weapons[i]
		if path == "":
			continue
		var slot = player.weapon_slots[i]
		var scene = load(path)
		if scene == null:
			continue
		# Makni postojeći weapon
		for child in slot.get_children():
			child.queue_free()
		var weapon = scene.instantiate()
		if i < weapon_stats.size() and not weapon_stats[i].is_empty():
			var s = weapon_stats[i]
			weapon.stats_restored = true
			weapon.set("damage", s.get("damage", 1.0))
			weapon.set("fire_rate_multiplier", s.get("fire_rate_multiplier", 1.0))
			weapon.set("reload_multiplier", s.get("reload_multiplier", 1.0))
			weapon.set("range_multiplier", s.get("range_multiplier", 1.0))
			weapon.set("spread_multiplier", s.get("spread_multiplier", 1.0))
			weapon.set("pierce_bonus", s.get("pierce_bonus", 0))
			weapon.set("max_ammo", s.get("max_ammo", 6))
			weapon.set("current_ammo", weapon.get("max_ammo"))
			weapon.set("fire_rate", s.get("fire_rate", 1.0))
			weapon.set("weapon_level", s.get("weapon_level", 0))
			if "proj_count" in weapon:
				weapon.set("proj_count", s.get("proj_count", 1))
			for flag in WEAPON_ABILITY_FLAGS:
				if flag in weapon and s.get(flag, false):
					weapon.set(flag, true)
		slot.add_child(weapon)

# =============================================
#  PERMANENT SAVE / LOAD
# =============================================
func save_permanent():
	var data = {
		"permanent_scrap": permanent_scrap,
		"permanent_upgrades": permanent_upgrades,
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()
		print("[GameManager] Permanent saved")

func load_permanent():
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var data = file.get_var()
		file.close()
		if data is Dictionary:
			permanent_scrap = data.get("permanent_scrap", 0)
			permanent_upgrades = data.get("permanent_upgrades", [])
			print("[GameManager] Permanent loaded, scrap=%d" % permanent_scrap)

# === ROUTE MAP STATE ===
var route_nodes       := []
var route_connections := []
var route_generated   := false

func reset_route():
	route_nodes       = []
	route_connections = []
	route_generated   = false
