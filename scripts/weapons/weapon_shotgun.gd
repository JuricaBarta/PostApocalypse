class_name WeaponShotgun
extends WeaponBase

const PELLET_COUNT := 5
const SPREAD := 30.0

const SHOTGUN_PROJECTILE = preload("res://scenes/weapons/shotgun_projectile.tscn")

const WEAPON_ID = "shotgun"
const WEAPON_UPGRADES = {
	"common": [
		{"id": "shotgun_damage_c",    "target": "shotgun", "kind": "damage",    "mult": 1.10, "name": "Shotgun Damage+",     "desc": "+10% damage",      "icon": "💥"},
		{"id": "shotgun_fire_rate_c", "target": "shotgun", "kind": "fire_rate", "mult": 1.10, "name": "Shotgun Fire Rate+",  "desc": "+10% fire rate",   "icon": "🔫"},
		{"id": "shotgun_reload_c",    "target": "shotgun", "kind": "reload",    "mult": 0.90, "name": "Shotgun Reload+",     "desc": "-10% reload time", "icon": "⏱️"},
	],
	"uncommon": [
		{"id": "shotgun_damage_u",   "target": "shotgun", "kind": "damage", "mult": 1.20, "name": "Shotgun Damage++", "desc": "+20% damage", "icon": "💥"},
		{"id": "shotgun_range_u",    "target": "shotgun", "kind": "range",  "mult": 1.25, "name": "Shotgun Range+",   "desc": "+25% range",  "icon": "🎯"},
		{"id": "shotgun_pierce_u",   "target": "shotgun", "kind": "pierce", "amount": 1,  "name": "Shotgun Pierce",   "desc": "+1 pierce",   "icon": "👁️"},
	],
	"rare": [
		{"id": "shotgun_damage_r",    "target": "shotgun", "kind": "damage",    "mult": 1.35, "name": "Shotgun Damage+++",   "desc": "+35% damage",      "icon": "💥"},
		{"id": "shotgun_fire_rate_r", "target": "shotgun", "kind": "fire_rate", "mult": 1.30, "name": "Shotgun Fire Rate++", "desc": "+30% fire rate",   "icon": "🔫"},
		{"id": "shotgun_reload_r",    "target": "shotgun", "kind": "reload",    "mult": 0.75, "name": "Shotgun Reload++",    "desc": "-25% reload time", "icon": "⏱️"},
	],
	"legendary": [
		{"id": "shotgun_damage_l",    "target": "shotgun", "kind": "damage",    "mult": 1.50, "name": "Shotgun Overload",  "desc": "+50% damage",      "icon": "🌟"},
		{"id": "shotgun_fire_rate_l", "target": "shotgun", "kind": "fire_rate", "mult": 1.50, "name": "Shotgun Frenzy",    "desc": "+50% fire rate",   "icon": "👹"},
		{"id": "shotgun_pierce_l",    "target": "shotgun", "kind": "pierce",    "amount": 2,  "name": "Shotgun Pierce++",  "desc": "+2 pierce",        "icon": "💎"},
		{"id": "shotgun_spread_l",    "target": "shotgun", "kind": "spread",    "mult": 0.6,  "name": "Tight Choke",       "desc": "-40% spread",      "icon": "🎯"},
	],
}

const MILESTONE_UPGRADES = [
	{"id": "shotgun_parallel", "target": "shotgun", "ability": "parallel_fire", "name": "Parallel Barrage", "desc": "Pellets fly side by side — no spread", "icon": "🟰"},
	{"id": "shotgun_reverse",  "target": "shotgun", "ability": "reverse_fire",  "name": "Reverse Fire",     "desc": "Also fires a full volley backward",    "icon": "↔️"},
]

var parallel_fire := false
var reverse_fire := false

func _ready():
	if not stats_restored:
		init_stats()
	_setup_sprite("res://Images/art/guns/CommonWeapons/CommonPumpShotgunImage.png", Vector2(0.25, 0.25))

func init_stats():
	damage = 1.0
	max_ammo = 6
	current_ammo = 6
	reload_time = 3.5
	fire_rate = 1.5
	spread_multiplier = 1.0
	pierce_bonus = 1  # pellets pierce 1 enemy by default — feels right for shotgun

func _spawn_pellet(_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: float, proj_speed_mult: float, explosive: bool):
	var p = SHOTGUN_PROJECTILE.instantiate()
	p.position = pos
	p.direction = dir
	p.damage = dmg
	p.size = 1.5
	p.speed = 600.0 * proj_speed_mult
	p.pierce_bonus = pierce_bonus
	p.explosive = explosive
	get_tree().current_scene.add_child(p)

func shoot(projectile_scene: PackedScene, _player_pos: Vector2):
	if not is_instance_valid(current_target):
		current_target = null
		return
	if projectile_scene == null or current_target == null:
		return
	if current_ammo <= 0:
		if not is_reloading:
			is_reloading = true
			reload_timer = reload_time * reload_multiplier
		return
	current_ammo -= 1
	var player = _get_player()
	if player == null:
		return

	var actual_spread = deg_to_rad(SPREAD * spread_multiplier)
	var muzzle_pos = $Muzzle.global_position
	var base_dir = (current_target.global_position - muzzle_pos).normalized()
	var dmg = damage * player.stats.damage
	var pspeed = player.stats.projectile_speed
	var explo = player.stats.explosive

	if parallel_fire:
		# Pellets fly side-by-side, no angular spread
		var perp = base_dir.rotated(PI / 2.0)
		var spacing = 11.0
		var total_offset = (PELLET_COUNT - 1) * spacing
		for i in range(PELLET_COUNT):
			var lateral = -total_offset / 2.0 + spacing * i
			_spawn_pellet(projectile_scene, muzzle_pos + perp * lateral, base_dir, dmg, pspeed, explo)
	else:
		for i in range(PELLET_COUNT):
			var offset = -actual_spread / 2.0 + actual_spread * (float(i) / float(PELLET_COUNT - 1))
			_spawn_pellet(projectile_scene, muzzle_pos, base_dir.rotated(offset), dmg, pspeed, explo)

	if reverse_fire:
		var rev_dir = -base_dir
		for i in range(PELLET_COUNT):
			var offset = -actual_spread / 2.0 + actual_spread * (float(i) / float(PELLET_COUNT - 1))
			_spawn_pellet(projectile_scene, muzzle_pos, rev_dir.rotated(offset), dmg, pspeed, explo)
