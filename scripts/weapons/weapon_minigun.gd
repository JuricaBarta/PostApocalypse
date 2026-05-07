class_name WeaponMinigun
extends WeaponBase

const WEAPON_ID = "minigun"

# Spin-up: long reload, big mag, fast fire, spread builds with heat.
const HEAT_PER_SHOT := 1.0
const HEAT_DECAY_PER_SEC := 12.0
const HEAT_MAX := 30.0
const SPREAD_MIN_DEG := 4.0
const SPREAD_MAX_DEG := 22.0

const WEAPON_UPGRADES = {
	"common": [
		{"id": "minigun_damage_c",    "target": "minigun", "kind": "damage",    "mult": 1.10, "name": "Minigun Damage+",    "desc": "+10% damage",      "icon": "💥"},
		{"id": "minigun_fire_rate_c", "target": "minigun", "kind": "fire_rate", "mult": 1.10, "name": "Minigun Fire Rate+", "desc": "+10% fire rate",   "icon": "🔫"},
		{"id": "minigun_reload_c",    "target": "minigun", "kind": "reload",    "mult": 0.90, "name": "Minigun Reload+",    "desc": "-10% reload time", "icon": "⏱️"},
	],
	"uncommon": [
		{"id": "minigun_damage_u", "target": "minigun", "kind": "damage", "mult": 1.20, "name": "Minigun Damage++", "desc": "+20% damage", "icon": "💥"},
		{"id": "minigun_range_u",  "target": "minigun", "kind": "range",  "mult": 1.20, "name": "Minigun Range+",   "desc": "+20% range",  "icon": "🎯"},
		{"id": "minigun_spread_u", "target": "minigun", "kind": "spread", "mult": 0.80, "name": "Steady Aim",       "desc": "-20% spread", "icon": "🎯"},
	],
	"rare": [
		{"id": "minigun_damage_r",    "target": "minigun", "kind": "damage",    "mult": 1.35, "name": "Minigun Damage+++",   "desc": "+35% damage",      "icon": "💥"},
		{"id": "minigun_fire_rate_r", "target": "minigun", "kind": "fire_rate", "mult": 1.30, "name": "Minigun Fire Rate++", "desc": "+30% fire rate",   "icon": "🔫"},
		{"id": "minigun_reload_r",    "target": "minigun", "kind": "reload",    "mult": 0.75, "name": "Minigun Reload++",    "desc": "-25% reload time", "icon": "⏱️"},
	],
	"legendary": [
		{"id": "minigun_damage_l",    "target": "minigun", "kind": "damage",    "mult": 1.50, "name": "Minigun Overload",  "desc": "+50% damage",     "icon": "🌟"},
		{"id": "minigun_fire_rate_l", "target": "minigun", "kind": "fire_rate", "mult": 1.50, "name": "Minigun Frenzy",    "desc": "+50% fire rate",  "icon": "👹"},
		{"id": "minigun_pierce_l",    "target": "minigun", "kind": "pierce",    "amount": 1,  "name": "AP Rounds",         "desc": "+1 pierce",       "icon": "💎"},
		{"id": "minigun_spread_l",    "target": "minigun", "kind": "spread",    "mult": 0.5,  "name": "Laser Sight",       "desc": "-50% spread",     "icon": "🔭"},
	],
}

const MILESTONE_UPGRADES = [
	{"id": "minigun_heat_sink",    "target": "minigun", "ability": "heat_sink",    "name": "Heat Sink",    "desc": "Spread no longer grows with heat",  "icon": "❄️"},
	{"id": "minigun_bullet_storm", "target": "minigun", "ability": "bullet_storm", "name": "Bullet Storm", "desc": "+50% fire rate at full heat",       "icon": "🌪️"},
]

var heat := 0.0
var heat_sink := false
var bullet_storm := false

func _ready():
	if not stats_restored:
		init_stats()
	_setup_sprite("res://Images/art/guns/CommonWeapons/CommonMinigunImage.png", Vector2(0.18, 0.18))

func init_stats():
	damage = 0.7
	max_ammo = 100
	current_ammo = 100
	reload_time = 4.5
	fire_rate = 0.07  # ~14 shots/sec base
	pierce_bonus = 0

func _process(delta):
	super._process(delta)
	# Cool down heat
	heat = max(0.0, heat - HEAT_DECAY_PER_SEC * delta)
	# Bullet Storm: fire rate boost at full heat
	if bullet_storm and heat >= HEAT_MAX * 0.95:
		fire_rate_bonus = 1.5
	else:
		fire_rate_bonus = 1.0

func _current_spread_deg() -> float:
	if heat_sink:
		return SPREAD_MIN_DEG * spread_multiplier
	var t = clampf(heat / HEAT_MAX, 0.0, 1.0)
	return lerpf(SPREAD_MIN_DEG, SPREAD_MAX_DEG, t) * spread_multiplier

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

	heat = min(HEAT_MAX, heat + HEAT_PER_SHOT)

	var muzzle_pos = $Muzzle.global_position
	var base_dir = (current_target.global_position - muzzle_pos).normalized()
	var spread_rad = deg_to_rad(_current_spread_deg())
	var jitter = randf_range(-spread_rad / 2.0, spread_rad / 2.0)
	var dir = base_dir.rotated(jitter)

	var p = projectile_scene.instantiate()
	p.position = muzzle_pos
	p.direction = dir
	p.damage = damage * player.stats.damage
	p.speed = 700.0 * player.stats.projectile_speed
	p.pierce_bonus = pierce_bonus
	p.explosive = player.stats.explosive
	get_tree().current_scene.add_child(p)
