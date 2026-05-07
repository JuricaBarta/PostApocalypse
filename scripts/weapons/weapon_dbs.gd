class_name WeaponDBS
extends WeaponBase

const WEAPON_ID  = "dbs"
const PELLET_COUNT := 6
const SPREAD_DEG   := 42.0

const WEAPON_UPGRADES = {
	"common": [
		{"id": "dbs_damage_c",    "target": "dbs", "kind": "damage",    "mult": 1.10, "name": "DBS Damage+",    "desc": "+10% damage",      "icon": "💥"},
		{"id": "dbs_fire_rate_c", "target": "dbs", "kind": "fire_rate", "mult": 1.10, "name": "DBS Fire Rate+", "desc": "+10% fire rate",   "icon": "🔫"},
		{"id": "dbs_reload_c",    "target": "dbs", "kind": "reload",    "mult": 0.90, "name": "DBS Reload+",    "desc": "-10% reload time", "icon": "⏱️"},
	],
	"uncommon": [
		{"id": "dbs_damage_u",   "target": "dbs", "kind": "damage", "mult": 1.25, "name": "DBS Damage++",  "desc": "+25% damage",  "icon": "💥"},
		{"id": "dbs_spread_u",   "target": "dbs", "kind": "spread", "mult": 0.70, "name": "Choke Mod",     "desc": "-30% spread",  "icon": "🎯"},
		{"id": "dbs_pierce_u",   "target": "dbs", "kind": "pierce", "amount": 1,  "name": "DBS Pierce",    "desc": "+1 pierce",    "icon": "👁️"},
	],
	"rare": [
		{"id": "dbs_damage_r",   "target": "dbs", "kind": "damage",    "mult": 1.40, "name": "DBS Damage+++",  "desc": "+40% damage",      "icon": "💥"},
		{"id": "dbs_spread_r",   "target": "dbs", "kind": "spread",    "mult": 0.55, "name": "Tight Choke",    "desc": "-45% spread",      "icon": "🎯"},
		{"id": "dbs_reload_r",   "target": "dbs", "kind": "reload",    "mult": 0.70, "name": "DBS Reload++",   "desc": "-30% reload time", "icon": "⏱️"},
	],
	"legendary": [
		{"id": "dbs_damage_l",   "target": "dbs", "kind": "damage",    "mult": 1.60, "name": "DBS Overload",   "desc": "+60% damage",     "icon": "🌟"},
		{"id": "dbs_spread_l",   "target": "dbs", "kind": "spread",    "mult": 0.40, "name": "Laser Choke",    "desc": "-60% spread",     "icon": "🔭"},
		{"id": "dbs_pierce_l",   "target": "dbs", "kind": "pierce",    "amount": 2,  "name": "Slug Prep",      "desc": "+2 pierce",       "icon": "💎"},
		{"id": "dbs_fire_rate_l","target": "dbs", "kind": "fire_rate", "mult": 1.50, "name": "Hair Trigger",   "desc": "+50% fire rate",  "icon": "👹"},
	],
}

const MILESTONE_UPGRADES = [
	{"id": "dbs_choke_mod",  "target": "dbs", "ability": "choke_mod", "kind": "spread", "mult": 0.35,
		"name": "Choke Barrel", "desc": "-65% spread — tight buckshot", "icon": "🎯"},
	{"id": "dbs_slug_round", "target": "dbs", "ability": "slug_round",
		"name": "Slug Round",   "desc": "Single massive slug (all pellet damage combined)", "icon": "💎"},
	{"id": "dbs_dual_blast", "target": "dbs", "ability": "dual_blast",
		"name": "Dual Blast",   "desc": "Fire both barrels simultaneously (uses 2 ammo)", "icon": "💥"},
]

var choke_mod  := false
var slug_round := false
var dual_blast := false

func _ready():
	if not stats_restored:
		init_stats()
	_setup_sprite("res://Images/art/guns/CommonWeapons/CommonCutOffDoubleBarellShotgunImage.png", Vector2(0.18, 0.18))

func init_stats():
	damage       = 1.2
	max_ammo     = 2
	current_ammo = 2
	reload_time  = 1.4
	fire_rate    = 0.35
	pierce_bonus = 0
	spread_multiplier = 1.0

func _fire_volley(projectile_scene: PackedScene, muzzle_pos: Vector2, base_dir: Vector2,
		dmg: float, pspeed: float, explo: bool, pierce: int) -> void:
	if slug_round:
		var p = projectile_scene.instantiate()
		p.position  = muzzle_pos
		p.direction = base_dir
		p.damage    = dmg * PELLET_COUNT
		p.size      = 2.5
		p.speed     = 700.0 * pspeed
		p.pierce_bonus = pierce + 2
		p.explosive    = explo
		get_tree().current_scene.add_child(p)
		return

	var spread_rad = deg_to_rad(SPREAD_DEG * spread_multiplier)
	for i in range(PELLET_COUNT):
		var offset = -spread_rad / 2.0 + spread_rad * (float(i) / float(PELLET_COUNT - 1))
		var p = projectile_scene.instantiate()
		p.position  = muzzle_pos
		p.direction = base_dir.rotated(offset)
		p.damage    = dmg
		p.size      = 1.4
		p.speed     = 580.0 * pspeed
		p.pierce_bonus = pierce
		p.explosive    = explo
		get_tree().current_scene.add_child(p)

func shoot(projectile_scene: PackedScene, _player_pos: Vector2):
	if not is_instance_valid(current_target):
		current_target = null
		return
	if projectile_scene == null or current_target == null:
		return

	if dual_blast:
		if current_ammo < 2:
			if not is_reloading:
				is_reloading = true
				reload_timer = reload_time * reload_multiplier
			return
		current_ammo -= 2
	else:
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
	var explo      = player.stats.explosive
	var pierce     = pierce_bonus

	_fire_volley(projectile_scene, muzzle_pos, base_dir, dmg, pspeed, explo, pierce)
	if dual_blast:
		_fire_volley(projectile_scene, muzzle_pos, base_dir, dmg, pspeed, explo, pierce)
