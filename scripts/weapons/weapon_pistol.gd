class_name WeaponPistol
extends WeaponBase

const WEAPON_ID = "pistol"
const WEAPON_UPGRADES = {
	"common": [
		{"id": "pistol_damage_c",    "target": "pistol", "kind": "damage",    "mult": 1.10, "name": "Pistol Damage+",     "desc": "+10% damage",      "icon": "💥"},
		{"id": "pistol_fire_rate_c", "target": "pistol", "kind": "fire_rate", "mult": 1.10, "name": "Pistol Fire Rate+",  "desc": "+10% fire rate",   "icon": "🔫"},
		{"id": "pistol_reload_c",    "target": "pistol", "kind": "reload",    "mult": 0.90, "name": "Pistol Reload+",     "desc": "-10% reload time", "icon": "⏱️"},
	],
	"uncommon": [
		{"id": "pistol_damage_u",    "target": "pistol", "kind": "damage", "mult": 1.20, "name": "Pistol Damage++", "desc": "+20% damage", "icon": "💥"},
		{"id": "pistol_range_u",     "target": "pistol", "kind": "range",  "mult": 1.25, "name": "Pistol Range+",   "desc": "+25% range",  "icon": "🎯"},
		{"id": "pistol_pierce_u",    "target": "pistol", "kind": "pierce", "amount": 1,  "name": "Pistol Pierce",   "desc": "+1 pierce",   "icon": "👁️"},
	],
	"rare": [
		{"id": "pistol_damage_r",    "target": "pistol", "kind": "damage",     "mult": 1.35, "name": "Pistol Damage+++",  "desc": "+35% damage",      "icon": "💥"},
		{"id": "pistol_fire_rate_r", "target": "pistol", "kind": "fire_rate",  "mult": 1.30, "name": "Pistol Fire Rate++","desc": "+30% fire rate",   "icon": "🔫"},
		{"id": "pistol_reload_r",    "target": "pistol", "kind": "reload",     "mult": 0.75, "name": "Pistol Reload++",   "desc": "-25% reload time", "icon": "⏱️"},
		{"id": "pistol_burst_r",     "target": "pistol", "kind": "proj_count", "amount": 1,  "name": "Pistol Burst",      "desc": "+1 projectile",    "icon": "✨"},
	],
	"legendary": [
		{"id": "pistol_damage_l",    "target": "pistol", "kind": "damage",     "mult": 1.50, "name": "Pistol Overload",   "desc": "+50% damage",      "icon": "🌟"},
		{"id": "pistol_fire_rate_l", "target": "pistol", "kind": "fire_rate",  "mult": 1.50, "name": "Pistol Frenzy",     "desc": "+50% fire rate",   "icon": "👹"},
		{"id": "pistol_pierce_l",    "target": "pistol", "kind": "pierce",     "amount": 2,  "name": "Pistol Pierce++",   "desc": "+2 pierce",        "icon": "💎"},
		{"id": "pistol_range_l",     "target": "pistol", "kind": "range",      "mult": 1.50, "name": "Pistol Sniper",     "desc": "+50% range",       "icon": "🔭"},
		{"id": "pistol_triburst_l",  "target": "pistol", "kind": "proj_count", "amount": 2,  "name": "Pistol Tri-Burst",  "desc": "+2 projectiles",   "icon": "🌟"},
	],
}

const MILESTONE_UPGRADES = [
	{"id": "pistol_full_pierce", "target": "pistol", "ability": "full_pierce", "name": "Piercing Rounds", "desc": "Bullets pierce all enemies until wall", "icon": "🔱"},
	{"id": "pistol_wavy",        "target": "pistol", "ability": "wavy_fire",   "name": "Wavy Shot",       "desc": "Bullets follow a sine wave path",       "icon": "〰️"},
]

var full_pierce := false
var wavy_fire := false

func _ready():
	if not stats_restored:
		init_stats()
	_setup_sprite("res://Images/art/guns/CommonWeapons/CommonPistolImage.png", Vector2(0.18, 0.18))

func init_stats():
	damage = 1.0
	max_ammo = 16
	current_ammo = 16
	reload_time = 1.2
	fire_rate = 0.3
	pierce_bonus = 0

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
	var count = proj_count
	var muzzle_pos = $Muzzle.global_position
	var base_dir = (current_target.global_position - muzzle_pos).normalized()
	var actual_spread = deg_to_rad(10 * spread_multiplier)
	for i in range(count):
		var projectile = projectile_scene.instantiate()
		projectile.position = muzzle_pos
		if count == 1:
			projectile.direction = base_dir
		else:
			var offset = -actual_spread / 2.0 + actual_spread * (float(i) / float(count - 1))
			projectile.direction = base_dir.rotated(offset)
		projectile.damage = damage * player.stats.damage
		projectile.speed = 600.0 * player.stats.projectile_speed
		projectile.pierce_bonus = pierce_bonus
		projectile.full_pierce = full_pierce
		projectile.wavy = wavy_fire
		projectile.explosive = player.stats.explosive
		get_tree().current_scene.add_child(projectile)
