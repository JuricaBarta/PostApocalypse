class_name WeaponRocket
extends WeaponBase

const WEAPON_ID = "rocket"

const WEAPON_UPGRADES = {
	"common": [
		{"id": "rocket_damage_c",    "target": "rocket", "kind": "damage",    "mult": 1.10, "name": "Rocket Damage+",    "desc": "+10% damage",      "icon": "💥"},
		{"id": "rocket_fire_rate_c", "target": "rocket", "kind": "fire_rate", "mult": 1.10, "name": "Rocket Fire Rate+", "desc": "+10% fire rate",   "icon": "🔫"},
		{"id": "rocket_reload_c",    "target": "rocket", "kind": "reload",    "mult": 0.90, "name": "Rocket Reload+",    "desc": "-10% reload time", "icon": "⏱️"},
	],
	"uncommon": [
		{"id": "rocket_damage_u",    "target": "rocket", "kind": "damage",    "mult": 1.20, "name": "Rocket Damage++",   "desc": "+20% damage",    "icon": "💥"},
		{"id": "rocket_reload_u",    "target": "rocket", "kind": "reload",    "mult": 0.80, "name": "Rocket Reload++",   "desc": "-20% reload time","icon": "⏱️"},
		{"id": "rocket_pierce_u",    "target": "rocket", "kind": "pierce",    "amount": 1,  "name": "Penetrating Tip",   "desc": "+1 pierce",       "icon": "👁️"},
	],
	"rare": [
		{"id": "rocket_damage_r",    "target": "rocket", "kind": "damage",    "mult": 1.35, "name": "Rocket Damage+++",  "desc": "+35% damage",      "icon": "💥"},
		{"id": "rocket_fire_rate_r", "target": "rocket", "kind": "fire_rate", "mult": 1.30, "name": "Rapid Launch",      "desc": "+30% fire rate",   "icon": "🔫"},
		{"id": "rocket_reload_r",    "target": "rocket", "kind": "reload",    "mult": 0.70, "name": "Quick Load",        "desc": "-30% reload time", "icon": "⏱️"},
		{"id": "rocket_proj_r",      "target": "rocket", "kind": "proj_count","amount": 1,  "name": "Twin Tubes",        "desc": "+1 rocket",        "icon": "✨"},
	],
	"legendary": [
		{"id": "rocket_damage_l",    "target": "rocket", "kind": "damage",    "mult": 1.50, "name": "Warhead Mk.II",    "desc": "+50% damage",     "icon": "🌟"},
		{"id": "rocket_fire_rate_l", "target": "rocket", "kind": "fire_rate", "mult": 1.50, "name": "Rocket Frenzy",    "desc": "+50% fire rate",  "icon": "👹"},
		{"id": "rocket_pierce_l",    "target": "rocket", "kind": "pierce",    "amount": 2,  "name": "Bunker Buster",    "desc": "+2 pierce",       "icon": "💎"},
		{"id": "rocket_proj_l",      "target": "rocket", "kind": "proj_count","amount": 2,  "name": "Cluster Pack",     "desc": "+2 rockets",      "icon": "🔭"},
	],
}

const MILESTONE_UPGRADES = [
	{"id": "rocket_heavy_warhead", "target": "rocket", "ability": "heavy_warhead",
		"name": "Heavy Warhead",  "desc": "+80% explosion radius", "icon": "💣"},
	{"id": "rocket_warhead_plus",  "target": "rocket", "ability": "warhead_plus",  "kind": "damage", "mult": 1.50,
		"name": "Warhead Plus",   "desc": "+50% damage", "icon": "🌟"},
	{"id": "rocket_barrage",       "target": "rocket", "ability": "barrage",        "kind": "proj_count", "amount": 2,
		"name": "Barrage",        "desc": "Fire 3 rockets in a spread", "icon": "💥"},
]

var heavy_warhead := false
var warhead_plus  := false
var barrage       := false

var explosion_radius := 130.0

func _ready():
	if not stats_restored:
		init_stats()
	_setup_sprite("res://Images/art/guns/CommonWeapons/CommonRocketLauncherImage.png", Vector2(0.18, 0.18))

func init_stats():
	damage       = 15.0
	max_ammo     = 3
	current_ammo = 3
	reload_time  = 4.0
	fire_rate    = 2.0
	pierce_bonus = 0
	proj_count   = 1

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

	var muzzle_pos = $Muzzle.global_position
	var base_dir   = (current_target.global_position - muzzle_pos).normalized()
	var dmg        = damage * player.stats.damage
	var pspeed     = player.stats.projectile_speed
	var pierce     = pierce_bonus

	var total = proj_count
	var spread_rad = deg_to_rad(12.0 * (total - 1))

	for i in range(total):
		var dir = base_dir
		if total > 1:
			var offset = -spread_rad / 2.0 + spread_rad * (float(i) / float(total - 1))
			dir = base_dir.rotated(offset)

		var p = projectile_scene.instantiate()
		p.position     = muzzle_pos
		p.direction    = dir
		p.damage       = dmg
		p.speed        = 250.0 * pspeed
		p.pierce_bonus = pierce
		p.explosive    = true

		var radius = explosion_radius
		if heavy_warhead:
			radius *= 1.8
		if "explosion_radius" in p:
			p.explosion_radius = radius

		get_tree().current_scene.add_child(p)
