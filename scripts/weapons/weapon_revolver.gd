class_name WeaponRevolver
extends WeaponBase

const WEAPON_ID = "revolver"

const WEAPON_UPGRADES = {
	"common": [
		{"id": "revolver_damage_c",    "target": "revolver", "kind": "damage",    "mult": 1.10, "name": "Revolver Damage+",    "desc": "+10% damage",      "icon": "💥"},
		{"id": "revolver_fire_rate_c", "target": "revolver", "kind": "fire_rate", "mult": 1.10, "name": "Revolver Fire Rate+", "desc": "+10% fire rate",   "icon": "🔫"},
		{"id": "revolver_reload_c",    "target": "revolver", "kind": "reload",    "mult": 0.90, "name": "Revolver Reload+",    "desc": "-10% reload time", "icon": "⏱️"},
	],
	"uncommon": [
		{"id": "revolver_damage_u",    "target": "revolver", "kind": "damage",    "mult": 1.20, "name": "Revolver Damage++",   "desc": "+20% damage",    "icon": "💥"},
		{"id": "revolver_range_u",     "target": "revolver", "kind": "range",     "mult": 1.25, "name": "Revolver Range+",     "desc": "+25% range",     "icon": "🎯"},
		{"id": "revolver_pierce_u",    "target": "revolver", "kind": "pierce",    "amount": 1,  "name": "Hollow Point",        "desc": "+1 pierce",      "icon": "👁️"},
	],
	"rare": [
		{"id": "revolver_damage_r",    "target": "revolver", "kind": "damage",    "mult": 1.40, "name": "Revolver Damage+++",  "desc": "+40% damage",      "icon": "💥"},
		{"id": "revolver_fire_rate_r", "target": "revolver", "kind": "fire_rate", "mult": 1.30, "name": "Revolver Fire Rate++","desc": "+30% fire rate",   "icon": "🔫"},
		{"id": "revolver_reload_r",    "target": "revolver", "kind": "reload",    "mult": 0.70, "name": "Revolver Reload++",   "desc": "-30% reload time", "icon": "⏱️"},
		{"id": "revolver_burst_r",     "target": "revolver", "kind": "proj_count","amount": 1,  "name": "Fan the Hammer",      "desc": "+1 projectile",    "icon": "✨"},
	],
	"legendary": [
		{"id": "revolver_damage_l",    "target": "revolver", "kind": "damage",    "mult": 1.60, "name": "Revolver Magnum",     "desc": "+60% damage",     "icon": "🌟"},
		{"id": "revolver_pierce_l",    "target": "revolver", "kind": "pierce",    "amount": 2,  "name": "AP Rounds",           "desc": "+2 pierce",       "icon": "💎"},
		{"id": "revolver_range_l",     "target": "revolver", "kind": "range",     "mult": 1.60, "name": "Long Barrel",         "desc": "+60% range",      "icon": "🔭"},
		{"id": "revolver_triburst_l",  "target": "revolver", "kind": "proj_count","amount": 2,  "name": "Triple Draw",         "desc": "+2 projectiles",  "icon": "🌟"},
	],
}

const MILESTONE_UPGRADES = [
	{"id": "revolver_quick_draw", "target": "revolver", "ability": "quick_draw", "kind": "fire_rate", "mult": 1.6,
		"name": "Quick Draw", "desc": "+60% fire rate", "icon": "⚡"},
	{"id": "revolver_penetrator", "target": "revolver", "ability": "penetrator", "kind": "pierce", "amount": 2,
		"name": "Penetrator",  "desc": "+2 pierce on every shot", "icon": "💎"},
	{"id": "revolver_dead_shot",  "target": "revolver", "ability": "dead_shot",
		"name": "Dead Shot",   "desc": "First bullet of each mag deals 3× damage", "icon": "💀"},
]

var quick_draw  := false
var penetrator  := false
var dead_shot   := false

var _mag_ready      := true
var _was_reloading  := false

func _ready():
	if not stats_restored:
		init_stats()
	_setup_sprite("res://Images/art/guns/CommonWeapons/CommonRevolverImage.png", Vector2(0.18, 0.18))

func init_stats():
	damage       = 4.0
	max_ammo     = 6
	current_ammo = 6
	reload_time  = 1.6
	fire_rate    = 0.65
	pierce_bonus = 0

func _process(delta):
	super._process(delta)
	if dead_shot:
		if _was_reloading and not is_reloading:
			_mag_ready = true
		_was_reloading = is_reloading

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
	var spread_rad = deg_to_rad(5.0 * spread_multiplier)

	for i in range(proj_count):
		var dir = base_dir
		if proj_count > 1:
			var offset = -spread_rad / 2.0 + spread_rad * (float(i) / float(proj_count - 1))
			dir = base_dir.rotated(offset)
		var p = projectile_scene.instantiate()
		p.position = muzzle_pos
		p.direction = dir
		p.damage    = damage * player.stats.damage
		p.speed     = 700.0 * player.stats.projectile_speed
		p.pierce_bonus = pierce_bonus + (2 if penetrator else 0)
		p.full_pierce  = false
		p.explosive    = player.stats.explosive
		if dead_shot and _mag_ready and i == 0:
			p.headshot_mult = 3.0
			_mag_ready = false
		get_tree().current_scene.add_child(p)
