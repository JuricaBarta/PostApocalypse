class_name WeaponUzi
extends WeaponBase

const WEAPON_ID = "uzi"

const WEAPON_UPGRADES = {
	"common": [
		{"id": "uzi_damage_c",    "target": "uzi", "kind": "damage",    "mult": 1.10, "name": "Uzi Damage+",    "desc": "+10% damage",      "icon": "💥"},
		{"id": "uzi_fire_rate_c", "target": "uzi", "kind": "fire_rate", "mult": 1.10, "name": "Uzi Fire Rate+", "desc": "+10% fire rate",   "icon": "🔫"},
		{"id": "uzi_reload_c",    "target": "uzi", "kind": "reload",    "mult": 0.90, "name": "Uzi Reload+",    "desc": "-10% reload time", "icon": "⏱️"},
	],
	"uncommon": [
		{"id": "uzi_damage_u", "target": "uzi", "kind": "damage", "mult": 1.20, "name": "Uzi Damage++", "desc": "+20% damage", "icon": "💥"},
		{"id": "uzi_range_u",  "target": "uzi", "kind": "range",  "mult": 1.25, "name": "Uzi Range+",   "desc": "+25% range",  "icon": "🎯"},
		{"id": "uzi_spread_u", "target": "uzi", "kind": "spread", "mult": 0.80, "name": "Uzi Focus",    "desc": "-20% spread", "icon": "🎯"},
	],
	"rare": [
		{"id": "uzi_damage_r",    "target": "uzi", "kind": "damage",    "mult": 1.35, "name": "Uzi Damage+++",   "desc": "+35% damage",      "icon": "💥"},
		{"id": "uzi_fire_rate_r", "target": "uzi", "kind": "fire_rate", "mult": 1.30, "name": "Uzi Fire Rate++", "desc": "+30% fire rate",   "icon": "🔫"},
		{"id": "uzi_pierce_r",    "target": "uzi", "kind": "pierce",    "amount": 1,  "name": "Uzi Pierce",      "desc": "+1 pierce",        "icon": "👁️"},
	],
	"legendary": [
		{"id": "uzi_damage_l",    "target": "uzi", "kind": "damage",    "mult": 1.50, "name": "Uzi Overload",  "desc": "+50% damage",      "icon": "🌟"},
		{"id": "uzi_fire_rate_l", "target": "uzi", "kind": "fire_rate", "mult": 1.50, "name": "Uzi Frenzy",    "desc": "+50% fire rate",   "icon": "👹"},
		{"id": "uzi_pierce_l",    "target": "uzi", "kind": "pierce",    "amount": 2,  "name": "Hollow Points", "desc": "+2 pierce",        "icon": "💎"},
		{"id": "uzi_reload_l",    "target": "uzi", "kind": "reload",    "mult": 0.5,  "name": "Quick Mag",     "desc": "-50% reload time", "icon": "⏱️"},
	],
}

const MILESTONE_UPGRADES = [
	{"id": "uzi_akimbo",     "target": "uzi", "ability": "akimbo",     "name": "Akimbo",     "desc": "Fire two parallel bullets per shot",       "icon": "🔫"},
	{"id": "uzi_adrenaline", "target": "uzi", "ability": "adrenaline", "name": "Adrenaline", "desc": "Sustained fire ramps up to +50% rate",     "icon": "⚡"},
]

const ADRENALINE_RAMP_PER_SEC := 0.25
const ADRENALINE_DECAY_PER_SEC := 0.6
const ADRENALINE_MAX := 0.5

var akimbo := false
var adrenaline := false
var _adrenaline_charge := 0.0

func _ready():
	if not stats_restored:
		init_stats()
	_setup_sprite("res://Images/art/guns/CommonWeapons/CommonUziImage.png", Vector2(0.18, 0.18))

func init_stats():
	damage = 0.55
	max_ammo = 32
	current_ammo = 32
	reload_time = 1.5
	fire_rate = 0.085  # ~12 shots/sec
	pierce_bonus = 0

func _process(delta):
	super._process(delta)
	# Adrenaline decays when not firing
	if adrenaline:
		# In auto-shoot model, "firing" = ammo dropped recently. We approximate
		# with: if reloading or no target, decay; otherwise charge.
		if is_reloading or current_target == null:
			_adrenaline_charge = max(0.0, _adrenaline_charge - ADRENALINE_DECAY_PER_SEC * delta)
		else:
			_adrenaline_charge = min(ADRENALINE_MAX, _adrenaline_charge + ADRENALINE_RAMP_PER_SEC * delta)
		fire_rate_bonus = 1.0 + _adrenaline_charge
	else:
		fire_rate_bonus = 1.0

func _spawn_bullet(scene: PackedScene, pos: Vector2, dir: Vector2, dmg: float, pspeed: float, explosive: bool):
	var p = scene.instantiate()
	p.position = pos
	p.direction = dir
	p.damage = dmg
	p.speed = 650.0 * pspeed
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

	var muzzle_pos = $Muzzle.global_position
	var base_dir = (current_target.global_position - muzzle_pos).normalized()
	var spread_rad = deg_to_rad(18 * spread_multiplier)
	var jitter = randf_range(-spread_rad / 2.0, spread_rad / 2.0)
	var dir = base_dir.rotated(jitter)
	var dmg = damage * player.stats.damage
	var pspeed = player.stats.projectile_speed
	var explo = player.stats.explosive

	if akimbo:
		var perp = dir.rotated(PI / 2.0)
		_spawn_bullet(projectile_scene, muzzle_pos + perp * 6.0, dir, dmg, pspeed, explo)
		_spawn_bullet(projectile_scene, muzzle_pos - perp * 6.0, dir, dmg, pspeed, explo)
	else:
		_spawn_bullet(projectile_scene, muzzle_pos, dir, dmg, pspeed, explo)
