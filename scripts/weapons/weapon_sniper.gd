class_name WeaponSniper
extends WeaponBase

const WEAPON_ID = "sniper"

const WEAPON_UPGRADES = {
	"common": [
		{"id": "sniper_damage_c",    "target": "sniper", "kind": "damage",    "mult": 1.10, "name": "Sniper Damage+",    "desc": "+10% damage",      "icon": "💥"},
		{"id": "sniper_fire_rate_c", "target": "sniper", "kind": "fire_rate", "mult": 1.10, "name": "Sniper Fire Rate+", "desc": "+10% fire rate",   "icon": "🔫"},
		{"id": "sniper_reload_c",    "target": "sniper", "kind": "reload",    "mult": 0.90, "name": "Sniper Reload+",    "desc": "-10% reload time", "icon": "⏱️"},
	],
	"uncommon": [
		{"id": "sniper_damage_u", "target": "sniper", "kind": "damage", "mult": 1.20, "name": "Sniper Damage++",  "desc": "+20% damage",        "icon": "💥"},
		{"id": "sniper_range_u",  "target": "sniper", "kind": "range",  "mult": 1.20, "name": "Long Barrel",      "desc": "+20% range",         "icon": "🎯"},
		{"id": "sniper_pierce_u", "target": "sniper", "kind": "pierce", "amount": 1,  "name": "Sniper Pierce",    "desc": "+1 pierce",          "icon": "👁️"},
	],
	"rare": [
		{"id": "sniper_damage_r",    "target": "sniper", "kind": "damage",    "mult": 1.40, "name": "Sniper Damage+++",   "desc": "+40% damage",       "icon": "💥"},
		{"id": "sniper_fire_rate_r", "target": "sniper", "kind": "fire_rate", "mult": 1.30, "name": "Sniper Fire Rate++", "desc": "+30% fire rate",    "icon": "🔫"},
		{"id": "sniper_reload_r",    "target": "sniper", "kind": "reload",    "mult": 0.70, "name": "Sniper Reload++",    "desc": "-30% reload time",  "icon": "⏱️"},
	],
	"legendary": [
		{"id": "sniper_damage_l",    "target": "sniper", "kind": "damage",     "mult": 1.75, "name": "Sniper Overload",    "desc": "+75% damage",       "icon": "🌟"},
		{"id": "sniper_pierce_l",    "target": "sniper", "kind": "pierce",     "amount": 2,  "name": "Armor Piercer",      "desc": "+2 pierce",         "icon": "💎"},
		{"id": "sniper_range_l",     "target": "sniper", "kind": "range",      "mult": 1.5,  "name": "Scope Mod",          "desc": "+50% range",        "icon": "🔭"},
		{"id": "sniper_fire_rate_l", "target": "sniper", "kind": "fire_rate",  "mult": 1.5,  "name": "Trigger Discipline", "desc": "+50% fire rate",    "icon": "👹"},
		{"id": "sniper_dual_l",      "target": "sniper", "kind": "proj_count", "amount": 1,  "name": "Dual Shot",          "desc": "+1 projectile",     "icon": "✨"},
	],
}

const MILESTONE_UPGRADES = [
	{"id": "sniper_headshot", "target": "sniper", "ability": "headshot", "name": "Headshot",    "desc": "First enemy hit takes triple damage", "icon": "🎯"},
	{"id": "sniper_railgun",  "target": "sniper", "ability": "railgun",  "name": "Railgun",     "desc": "Bullets pierce all enemies",          "icon": "⚡"},
]

var headshot := false
var railgun := false

func _ready():
	if not stats_restored:
		init_stats()
	_setup_sprite("res://Images/art/guns/CommonWeapons/CommonSniperRifleImage.png", Vector2(0.18, 0.18))

func init_stats():
	damage = 8.0
	max_ammo = 4
	current_ammo = 4
	reload_time = 2.8
	fire_rate = 1.4
	range_multiplier = 2.5  # extreme range
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

	var muzzle_pos = $Muzzle.global_position
	var base_dir = (current_target.global_position - muzzle_pos).normalized()
	var spread_rad = deg_to_rad(3.0 * (proj_count - 1))
	for i in range(proj_count):
		var dir = base_dir
		if proj_count > 1:
			var offset = -spread_rad / 2.0 + spread_rad * (float(i) / float(proj_count - 1))
			dir = base_dir.rotated(offset)
		var p = projectile_scene.instantiate()
		p.position = muzzle_pos
		p.direction = dir
		p.damage = damage * player.stats.damage
		p.size = 1.8
		p.speed = 1400.0 * player.stats.projectile_speed
		p.lifetime = 1.5
		p.full_pierce = railgun
		p.pierce_bonus = pierce_bonus
		if headshot:
			p.headshot_mult = 3.0
		p.explosive = player.stats.explosive
		get_tree().current_scene.add_child(p)
