class_name WeaponAK77
extends WeaponBase

const WEAPON_ID = "ak77"

const WEAPON_UPGRADES = {
	"common": [
		{"id": "ak77_damage_c",    "target": "ak77", "kind": "damage",    "mult": 1.10, "name": "AK-77 Damage+",    "desc": "+10% damage",      "icon": "💥"},
		{"id": "ak77_fire_rate_c", "target": "ak77", "kind": "fire_rate", "mult": 1.10, "name": "AK-77 Fire Rate+", "desc": "+10% fire rate",   "icon": "🔫"},
		{"id": "ak77_reload_c",    "target": "ak77", "kind": "reload",    "mult": 0.90, "name": "AK-77 Reload+",    "desc": "-10% reload time", "icon": "⏱️"},
	],
	"uncommon": [
		{"id": "ak77_damage_u",    "target": "ak77", "kind": "damage",     "mult": 1.20, "name": "AK-77 Damage++",  "desc": "+20% damage",    "icon": "💥"},
		{"id": "ak77_range_u",     "target": "ak77", "kind": "range",      "mult": 1.20, "name": "AK-77 Range+",    "desc": "+20% range",     "icon": "🎯"},
		{"id": "ak77_spread_u",    "target": "ak77", "kind": "spread",     "mult": 0.75, "name": "Iron Sight",      "desc": "-25% spread",    "icon": "🎯"},
	],
	"rare": [
		{"id": "ak77_damage_r",    "target": "ak77", "kind": "damage",     "mult": 1.35, "name": "AK-77 Damage+++",  "desc": "+35% damage",      "icon": "💥"},
		{"id": "ak77_fire_rate_r", "target": "ak77", "kind": "fire_rate",  "mult": 1.30, "name": "AK-77 Fire Rate++","desc": "+30% fire rate",   "icon": "🔫"},
		{"id": "ak77_reload_r",    "target": "ak77", "kind": "reload",     "mult": 0.75, "name": "AK-77 Reload++",   "desc": "-25% reload time", "icon": "⏱️"},
		{"id": "ak77_burst_r",     "target": "ak77", "kind": "proj_count", "amount": 1,  "name": "Burst Fire",       "desc": "+1 projectile",    "icon": "✨"},
	],
	"legendary": [
		{"id": "ak77_damage_l",    "target": "ak77", "kind": "damage",     "mult": 1.50, "name": "AK-77 Overload",  "desc": "+50% damage",     "icon": "🌟"},
		{"id": "ak77_fire_rate_l", "target": "ak77", "kind": "fire_rate",  "mult": 1.50, "name": "AK-77 Frenzy",    "desc": "+50% fire rate",  "icon": "👹"},
		{"id": "ak77_pierce_l",    "target": "ak77", "kind": "pierce",     "amount": 1,  "name": "FMJ Rounds",      "desc": "+1 pierce",       "icon": "💎"},
		{"id": "ak77_spread_l",    "target": "ak77", "kind": "spread",     "mult": 0.50, "name": "Collimator",      "desc": "-50% spread",     "icon": "🔭"},
	],
}

const MILESTONE_UPGRADES = [
	{"id": "ak77_quick_mag",    "target": "ak77", "ability": "quick_mag",    "kind": "reload", "mult": 0.55,
		"name": "Quick Mag",     "desc": "-45% reload time", "icon": "⏱️"},
	{"id": "ak77_steady_burst", "target": "ak77", "ability": "steady_burst",
		"name": "Steady Burst",  "desc": "Consecutive shots tighten spread by up to 50%", "icon": "🎯"},
	{"id": "ak77_overcharged",  "target": "ak77", "ability": "overcharged",
		"name": "Overcharged",   "desc": "Every 5th shot deals 3× damage", "icon": "⚡"},
]

var quick_mag    := false
var steady_burst := false
var overcharged  := false

var _consecutive_shots := 0
var _overcharge_counter := 0

func _ready():
	if not stats_restored:
		init_stats()
	_setup_sprite("res://Images/art/guns/CommonWeapons/CommonAK77Image.png", Vector2(0.18, 0.18))

func init_stats():
	damage       = 1.3
	max_ammo     = 30
	current_ammo = 30
	reload_time  = 2.2
	fire_rate    = 0.11
	pierce_bonus = 0

func _process(delta):
	super._process(delta)
	if steady_burst:
		if is_reloading or current_target == null:
			_consecutive_shots = max(0, _consecutive_shots - int(20.0 * delta))

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
			_consecutive_shots = 0
		return
	current_ammo -= 1
	var player = _get_player()
	if player == null:
		return

	if steady_burst:
		_consecutive_shots = min(20, _consecutive_shots + 1)

	var muzzle_pos = $Muzzle.global_position
	var base_dir   = (current_target.global_position - muzzle_pos).normalized()
	var spread_deg = 14.0 * spread_multiplier
	if steady_burst:
		spread_deg *= max(0.50, 1.0 - _consecutive_shots * 0.025)
	var spread_rad = deg_to_rad(spread_deg)

	for i in range(proj_count):
		var dir = base_dir
		if proj_count > 1:
			var offset = -spread_rad / 2.0 + spread_rad * (float(i) / float(proj_count - 1))
			dir = base_dir.rotated(offset)
		else:
			dir = base_dir.rotated(randf_range(-spread_rad / 2.0, spread_rad / 2.0))

		var p = projectile_scene.instantiate()
		p.position  = muzzle_pos
		p.direction = dir
		p.damage    = damage * player.stats.damage
		p.speed     = 660.0 * player.stats.projectile_speed
		p.pierce_bonus = pierce_bonus
		p.explosive    = player.stats.explosive

		if overcharged:
			_overcharge_counter += 1
			if _overcharge_counter >= 5:
				p.headshot_mult = 3.0
				_overcharge_counter = 0

		get_tree().current_scene.add_child(p)
