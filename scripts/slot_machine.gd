extends Control

enum Mode { LEVELUP, WAVE_REWARD, WEAPON_MILESTONE }

var player: Node = null
var rng = RandomNumberGenerator.new()
var current_mode: Mode = Mode.LEVELUP

var levels_since_legendary := 0
const PITY_THRESHOLD := 10

const COLOR_COMMON    = Color(0.6, 0.6, 0.6, 1.0)
const COLOR_UNCOMMON  = Color(0.2, 0.8, 0.3, 1.0)
const COLOR_RARE      = Color(0.5, 0.2, 0.9, 1.0)
const COLOR_LEGENDARY = Color(0.9, 0.1, 0.1, 1.0)
const COLOR_SCRAP     = Color(0.9, 0.7, 0.2, 1.0)
const COLOR_MILESTONE = Color(1.0, 0.75, 0.0, 1.0)

const UPGRADES = {
	"common": [
		{"id": "damage",        "name": "Damage+",       "desc": "+15% damage",          "icon": "💥"},
		{"id": "fire_rate",     "name": "Fire Rate+",    "desc": "+15% fire rate",       "icon": "🔫"},
		{"id": "speed",         "name": "Speed+",        "desc": "+15% move speed",      "icon": "👟"},
		{"id": "max_hp",        "name": "Max HP+",       "desc": "+20 max HP",           "icon": "❤️"},
		{"id": "mining_speed",  "name": "Scraper+",      "desc": "+5% scraping speed",   "icon": "⛏️", "mult": 1.05},
	],
	"uncommon": [
		{"id": "range",         "name": "Range+",        "desc": "+25% shoot range",     "icon": "🎯"},
		{"id": "damage",        "name": "Damage++",      "desc": "+25% damage",          "icon": "💥"},
		{"id": "fire_rate",     "name": "Fire Rate++",   "desc": "+25% fire rate",       "icon": "🔫"},
		{"id": "pickup",        "name": "Magnet+",       "desc": "+30% pickup radius",   "icon": "🧲"},
		{"id": "max_hp",        "name": "Max HP++",      "desc": "+30 max HP",           "icon": "❤️"},
		{"id": "mining_speed",  "name": "Scraper++",     "desc": "+10% scraping speed",  "icon": "⛏️", "mult": 1.10},
	],
	"rare": [
		{"id": "range",         "name": "Range++",       "desc": "+50% shoot range",     "icon": "🎯"},
		{"id": "proj_speed",    "name": "Velocity+",     "desc": "+40% bullet speed",    "icon": "⚡"},
		{"id": "vampire",       "name": "Vampirism",     "desc": "Heal 5 HP per kill",   "icon": "🧛"},
		{"id": "max_hp",        "name": "Fortify",       "desc": "+50 max HP",           "icon": "🛡️"},
		{"id": "mining_speed",  "name": "Drill Master",  "desc": "+15% scraping speed",  "icon": "🔩", "mult": 1.15},
	],
	"legendary": [
		{"id": "explosive",     "name": "Explosive",     "desc": "AoE bullet damage",    "icon": "💣"},
		{"id": "shield",        "name": "Shield",        "desc": "Block 1 hit",          "icon": "🔰"},
		{"id": "speed_demon",   "name": "Speed Demon",   "desc": "+50% speed & fire",    "icon": "👹"},
		{"id": "mining_speed",  "name": "Nanodriller",   "desc": "+20% scraping speed",  "icon": "⚙️", "mult": 1.20},
	],
}

const WAVE_UPGRADES = {
	"common": [
		{"id": "damage",       "name": "Damage+",      "desc": "+15% damage",         "icon": "💥", "cost": 400,  "cost_type": "generic"},
		{"id": "fire_rate",    "name": "Fire Rate+",   "desc": "+15% fire rate",      "icon": "🔫", "cost": 400,  "cost_type": "generic"},
		{"id": "speed",        "name": "Speed+",       "desc": "+15% move speed",     "icon": "👟", "cost": 400,  "cost_type": "generic"},
		{"id": "heal",         "name": "Heal",         "desc": "Restore 20 HP",       "icon": "💊", "cost": 400,  "cost_type": "generic"},
		{"id": "max_hp",       "name": "Max HP+",      "desc": "+20 max HP",          "icon": "❤️", "cost": 400,  "cost_type": "generic"},
		{"id": "mining_speed", "name": "Scraper+",     "desc": "+5% scraping speed",  "icon": "⛏️", "cost": 400,  "cost_type": "generic", "mult": 1.05},
	],
	"uncommon": [
		{"id": "range",        "name": "Range+",       "desc": "+25% shoot range",    "icon": "🎯", "cost": 700,  "cost_type": "generic"},
		{"id": "damage",       "name": "Damage++",     "desc": "+25% damage",         "icon": "💥", "cost": 700,  "cost_type": "generic"},
		{"id": "fire_rate",    "name": "Fire Rate++",  "desc": "+25% fire rate",      "icon": "🔫", "cost": 700,  "cost_type": "generic"},
		{"id": "pickup",       "name": "Magnet+",      "desc": "+30% pickup radius",  "icon": "🧲", "cost": 700,  "cost_type": "generic"},
		{"id": "big_heal",     "name": "Big Heal",     "desc": "Restore 40 HP",       "icon": "💉", "cost": 700,  "cost_type": "generic"},
		{"id": "mining_speed", "name": "Scraper++",    "desc": "+10% scraping speed", "icon": "⛏️", "cost": 700,  "cost_type": "generic", "mult": 1.10},
	],
	"rare": [
		{"id": "proj_speed",   "name": "Velocity+",   "desc": "+40% bullet speed",   "icon": "⚡", "cost": 1300, "cost_type": "generic"},
		{"id": "vampire",      "name": "Vampirism",   "desc": "Heal 5 HP per kill",   "icon": "🧛", "cost": 1300, "cost_type": "generic"},
		{"id": "max_hp",       "name": "Fortify",     "desc": "+50 max HP",           "icon": "🛡️", "cost": 1300, "cost_type": "generic"},
		{"id": "full_heal",    "name": "Full Heal",   "desc": "Restore full HP",      "icon": "🩺", "cost": 1300, "cost_type": "generic"},
		{"id": "mining_speed", "name": "Drill Master","desc": "+15% scraping speed",  "icon": "🔩", "cost": 1300, "cost_type": "generic", "mult": 1.15},
	],
	"legendary": [
		{"id": "explosive",    "name": "Explosive",   "desc": "AoE bullet damage",    "icon": "💣", "cost": 2500, "cost_type": "generic"},
		{"id": "shield",       "name": "Shield",      "desc": "Block 1 hit",          "icon": "🔰", "cost": 2500, "cost_type": "generic"},
		{"id": "speed_demon",  "name": "Speed Demon", "desc": "+50% speed & fire",    "icon": "👹", "cost": 2500, "cost_type": "generic"},
		{"id": "mining_speed", "name": "Nanodriller", "desc": "+20% scraping speed",  "icon": "⚙️", "cost": 2500, "cost_type": "generic", "mult": 1.20},
	],
}

# All weapons in the game. Used for discovery offers and texture lookup.
const ALL_WEAPONS := {
	"pistol":   {"scene": "res://scenes/weapons/weapon_pistol.tscn",   "name": "Pistol",   "desc": "Add Pistol to weapon slot",   "icon": "🔫"},
	"shotgun":  {"scene": "res://scenes/weapons/weapon_shotgun.tscn",  "name": "Shotgun",  "desc": "Add Shotgun to weapon slot",  "icon": "💥"},
	"minigun":  {"scene": "res://scenes/weapons/weapon_minigun.tscn",  "name": "Minigun",  "desc": "Add Minigun to weapon slot",  "icon": "🌀"},
	"uzi":      {"scene": "res://scenes/weapons/weapon_uzi.tscn",      "name": "Uzi",      "desc": "Add Uzi to weapon slot",      "icon": "🎯"},
	"sniper":   {"scene": "res://scenes/weapons/weapon_sniper.tscn",   "name": "Sniper",   "desc": "Add Sniper to weapon slot",   "icon": "🔭"},
	"revolver": {"scene": "res://scenes/weapons/weapon_revolver.tscn", "name": "Revolver", "desc": "Add Revolver to weapon slot", "icon": "🔫"},
	"ak77":     {"scene": "res://scenes/weapons/weapon_ak77.tscn",     "name": "AK-77",    "desc": "Add AK-77 to weapon slot",    "icon": "🔫"},
	"dbs":      {"scene": "res://scenes/weapons/weapon_dbs.tscn",      "name": "DBS",      "desc": "Add DBS to weapon slot",      "icon": "💥"},
	"rocket":   {"scene": "res://scenes/weapons/weapon_rocket.tscn",   "name": "Rocket",   "desc": "Add Rocket Launcher to slot", "icon": "💣"},
}

# At these player levels the levelup screen shows weapon-discovery cards instead
# of the usual skill upgrades — pick 1 of up to 3 still-unowned weapons.
const WEAPON_DISCOVERY_LEVELS := [6, 12, 18]

const WEAPON_TEXTURES = {
	"pistol":   "res://Images/art/guns/CommonWeapons/CommonPistolImage.png",
	"shotgun":  "res://Images/art/guns/CommonWeapons/CommonPumpShotgunImage.png",
	"minigun":  "res://Images/art/guns/CommonWeapons/CommonMinigunImage.png",
	"uzi":      "res://Images/art/guns/CommonWeapons/CommonUziImage.png",
	"sniper":   "res://Images/art/guns/CommonWeapons/CommonSniperRifleImage.png",
	"revolver": "res://Images/art/guns/CommonWeapons/CommonRevolverImage.png",
	"ak77":     "res://Images/art/guns/CommonWeapons/CommonAK77Image.png",
	"dbs":      "res://Images/art/guns/CommonWeapons/CommonCutOffDoubleBarellShotgunImage.png",
	"rocket":   "res://Images/art/guns/CommonWeapons/CommonRocketLauncherImage.png",
}
const WEAPON_TEXTURE_FALLBACK := "res://Images/art/guns/CommonWeapons/CommonPistolImage.png"

const WAVE_WEAPON_COSTS := {"common": 400, "uncommon": 700, "rare": 1300, "legendary": 2500}

var reroll_cost := {"amount": 100, "type": "generic"}

var current_offers = []
var _reroll_count := 0
var _spent_indices: Array = []
var _reroll_btn: Button = null
var _title_label: Label = null
var _scrap_label: Label = null

# === STREAK / MOMENTUM ===
var _streak_category := ""   # "weapon:pistol", "damage", "mining_speed", itd.
var _streak_power := 0.0     # 0.0–1.0, šansa da streak offer padne

var _weapon_milestone_queue: Array = []
var _current_milestone_weapon: Node = null
var _post_milestone_levelups := 0
var _post_milestone_routemap := false

func _ready():
	_update_safe_zone()
	get_viewport().size_changed.connect(_update_safe_zone)
	rng.randomize()
	visible = false
	_connect_buttons()

func _update_safe_zone():
	var vp := get_viewport_rect().size
	var ox := (vp.x - 1280.0) * 0.5
	var oy := (vp.y - 720.0) * 0.5
	# Root: fiksna 1280×720 safe zona, centrirana
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(1280, 720)
	position = Vector2(ox, oy)
	# Background: širi se na cijeli viewport da pokrije i ultrawide strane
	var bg := get_node_or_null("Background") as ColorRect
	if bg:
		bg.position = Vector2(-ox, -oy)
		bg.size = vp

func _connect_buttons():
	var cards = [
		$CardsContainer/Card1,
		$CardsContainer/Card2,
		$CardsContainer/Card3,
	]
	for i in range(3):
		var btn = cards[i].get_node("SelectButton")
		btn.pressed.connect(_on_card_selected.bind(i))

# =============================================
#  SHOW FUNCTIONS
# =============================================
func show_for_player(p: Node):
	current_mode = Mode.LEVELUP
	player = p
	current_offers = generate_offers()
	_reroll_count = 0
	populate_cards()
	_update_header()
	_ensure_reroll_button()
	if _scrap_label:
		_scrap_label.hide()
	reroll_cost["amount"] = 100
	visible = true
	get_tree().paused = true

func show_wave_reward(p: Node):
	current_mode = Mode.WAVE_REWARD
	player = p
	current_offers = generate_wave_offers()
	_reroll_count = 0
	_spent_indices = []
	_weapon_milestone_queue = []
	populate_cards()
	_update_header()
	_ensure_reroll_button()
	_ensure_next_button()
	_update_scrap_display()
	_set_game_hud_visible(false)
	reroll_cost["amount"] = 400
	visible = true
	get_tree().paused = true

func _set_game_hud_visible(v: bool):
	var hud = get_tree().get_root().get_node_or_null("Main/UI/HUD")
	if hud:
		hud.visible = v
	var weapon_hud = get_tree().get_root().get_node_or_null("Main/Player/WeaponHUD")
	if weapon_hud:
		weapon_hud.visible = v

# =============================================
#  WEAPON MILESTONE
# =============================================
func _check_weapon_milestone(weapon_id: String):
	var weapon = _get_weapon(weapon_id)
	if weapon == null:
		return
	weapon.weapon_level += 1
	if weapon.weapon_level in [6, 12, 18]:
		_enqueue_milestone(weapon_id, weapon)

func _get_milestone_pool(weapon: Node) -> Array:
	# Each weapon script declares a MILESTONE_UPGRADES const; pull from there
	# so adding a new weapon doesn't require touching this file.
	if "MILESTONE_UPGRADES" in weapon:
		return weapon.MILESTONE_UPGRADES.duplicate()
	return []

func _enqueue_milestone(weapon_id: String, weapon: Node):
	var pool := _get_milestone_pool(weapon)
	var choices = pool.filter(func(c): return not _weapon_has_ability(weapon, c))
	if choices.size() > 0:
		_weapon_milestone_queue.append({weapon_id = weapon_id, choices = choices, weapon = weapon})

func _weapon_has_ability(weapon: Node, milestone: Dictionary) -> bool:
	var ability = milestone.get("ability", "")
	if ability == "" or not ability in weapon:
		return false
	return weapon.get(ability) == true

func _show_next_milestone():
	if _weapon_milestone_queue.size() == 0:
		_after_all_milestones()
		return
	var entry = _weapon_milestone_queue.pop_front()
	_current_milestone_weapon = entry["weapon"]
	current_mode = Mode.WEAPON_MILESTONE
	current_offers = []
	for c in entry["choices"]:
		current_offers.append({upgrade = c, rarity = "milestone"})
	if _title_label == null:
		_title_label = get_node_or_null("Title")
	if _title_label:
		_title_label.text = "🏆 %s MASTERY — CHOOSE AN ABILITY" % entry["weapon_id"].to_upper()
	populate_cards()
	visible = true
	get_tree().paused = true

func _after_all_milestones():
	if _post_milestone_routemap:
		_post_milestone_routemap = false
		_do_go_to_routemap()
	elif _post_milestone_levelups > 0:
		var p = player
		_post_milestone_levelups = 0
		await get_tree().create_timer(0.2).timeout
		show_for_player(p)
	else:
		_set_game_hud_visible(true)

func _do_go_to_routemap():
	reroll_cost["amount"] = 400
	var p = get_tree().get_root().get_node_or_null("Main/Player")
	if p:
		GameManager.save_player_state(p)
	if GameManager.is_run_complete():
		GameManager.end_run(true)
		GameManager.start_new_run()
	get_tree().change_scene_to_file("res://scenes/route_map.tscn")

func _apply_weapon_ability(upgrade: Dictionary):
	var weapon = _current_milestone_weapon
	if weapon == null:
		return
	var ability = upgrade.get("ability", "")
	if ability != "" and ability in weapon:
		weapon.set(ability, true)
	# Some milestones also carry an immediate stat change (kind + mult/amount)
	if upgrade.has("kind"):
		match upgrade["kind"]:
			"damage":     weapon.damage *= upgrade.get("mult", 1.0)
			"fire_rate":  weapon.fire_rate_multiplier *= upgrade.get("mult", 1.0)
			"reload":     weapon.reload_multiplier *= upgrade.get("mult", 1.0)
			"range":      weapon.range_multiplier *= upgrade.get("mult", 1.0)
			"spread":     weapon.spread_multiplier *= upgrade.get("mult", 1.0)
			"pierce":     weapon.pierce_bonus += int(upgrade.get("amount", 1))
			"proj_count": weapon.proj_count += int(upgrade.get("amount", 1))

# =============================================
#  HEADER / SCRAP DISPLAY
# =============================================
func _offers_are_weapon_discovery() -> bool:
	if current_offers.is_empty():
		return false
	var first = current_offers[0]
	if not first.has("upgrade"):
		return false
	var upg = first["upgrade"]
	return upg.has("weapon_scene") and upg.get("id", "").begins_with("weapon_")

func _update_header():
	if _title_label == null:
		_title_label = get_node_or_null("Title")
	if _title_label:
		match current_mode:
			Mode.LEVELUP:
				if _offers_are_weapon_discovery():
					_title_label.text = "🎁 CHOOSE A NEW WEAPON"
				else:
					_title_label.text = "LEVEL UP"
			Mode.WAVE_REWARD:  _title_label.text = "⚡ WAVE COMPLETE — SPEND YOUR SCRAP"
			Mode.WEAPON_MILESTONE: _title_label.text = "🏆 WEAPON MASTERY"

func _update_scrap_display():
	if player == null:
		return
	if _scrap_label == null:
		_scrap_label = get_node_or_null("ScrapLabel")
		if _scrap_label == null:
			_scrap_label = Label.new()
			_scrap_label.name = "ScrapLabel"
			_scrap_label.add_theme_font_size_override("font_size", 24)
			_scrap_label.add_theme_color_override("font_color", COLOR_SCRAP)
			_scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_scrap_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
			_scrap_label.offset_top = 76
			_scrap_label.offset_bottom = 124
			add_child(_scrap_label)
			move_child(_scrap_label, 2)

	_scrap_label.show()
	var inv = player.scrap_inventory
	_scrap_label.text = "⚙️ %d    🔶 %d    💾 %d    🧪 %d    🔋 %d    💎 %d    🗑️ %d" % [
		inv.get("metal", 0), inv.get("copper", 0), inv.get("circuit", 0),
		inv.get("biogel", 0), inv.get("powercell", 0), inv.get("nanochip", 0),
		inv.get("generic", 0)
	]

func _ensure_reroll_button():
	if _reroll_btn != null:
		return
	_reroll_btn = Button.new()
	_reroll_btn.name = "RerollButton"
	_reroll_btn.anchor_left = 0.5
	_reroll_btn.anchor_right = 0.5
	_reroll_btn.anchor_top = 1.0
	_reroll_btn.anchor_bottom = 1.0
	_reroll_btn.offset_left = -230
	_reroll_btn.offset_right = -10
	_reroll_btn.offset_top = -255
	_reroll_btn.offset_bottom = -215
	_reroll_btn.text = "🎲 Reroll (%d 🗑️)" % reroll_cost.amount
	_reroll_btn.custom_minimum_size = Vector2(100, 40)
	_reroll_btn.add_theme_font_size_override("font_size", 18)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.1, 1)
	style.set_corner_radius_all(8)
	_reroll_btn.add_theme_stylebox_override("normal", style)
	var style_h = StyleBoxFlat.new()
	style_h.bg_color = Color(0.5, 0.5, 0.15, 1)
	style_h.set_corner_radius_all(8)
	_reroll_btn.add_theme_stylebox_override("hover", style_h)
	_reroll_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_reroll_btn.pressed.connect(_on_reroll_pressed)
	add_child(_reroll_btn)

func _ensure_next_button():
	var existing = get_node_or_null("NextButton")
	if existing:
		return
	var btn = Button.new()
	btn.anchor_left = 0.5
	btn.anchor_right = 0.5
	btn.anchor_top = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_left = 10
	btn.offset_right = 230
	btn.offset_top = -255
	btn.offset_bottom = -215
	btn.name = "NextButton"
	btn.text = "NEXT LEVEL →"
	btn.custom_minimum_size = Vector2(100, 40)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.6, 0.3, 1)
	style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", style)
	var style_h = StyleBoxFlat.new()
	style_h.bg_color = Color(0.3, 0.75, 0.4, 1)
	style_h.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("hover", style_h)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(_on_next_pressed)
	add_child(btn)

# =============================================
#  RARITY ROLL
# =============================================
func roll_rarity() -> String:
	var plevel = 1
	if player:
		plevel = player.level

	levels_since_legendary += 1
	if plevel >= 13 and levels_since_legendary >= PITY_THRESHOLD:
		levels_since_legendary = 0
		return "legendary"

	var available_rarities = ["common"]
	if plevel >= 4:
		available_rarities.append("uncommon")
	if plevel >= 8:
		available_rarities.append("rare")
	if plevel >= 13:
		available_rarities.append("legendary")

	var weights = {"common": 70.0, "uncommon": 25.0, "rare": 5.0, "legendary": 1.0}

	if plevel >= 8:
		weights["common"] = 58.0; weights["uncommon"] = 32.0; weights["rare"] = 10.0
	if plevel >= 13:
		weights["common"] = 45.0; weights["uncommon"] = 35.0; weights["rare"] = 17.0; weights["legendary"] = 3.0
	if plevel >= 20:
		weights["common"] = 30.0; weights["uncommon"] = 35.0; weights["rare"] = 28.0; weights["legendary"] = 7.0
	if plevel >= 30:
		weights["common"] = 15.0; weights["uncommon"] = 28.0; weights["rare"] = 42.0; weights["legendary"] = 15.0

	var total = 0.0
	for r in available_rarities:
		total += weights[r]

	var roll = rng.randf() * total
	var cumulative = 0.0
	for r in available_rarities:
		cumulative += weights[r]
		if roll < cumulative:
			if r == "legendary":
				levels_since_legendary = 0
			return r
	return "common"

# =============================================
#  GENERATE OFFERS
# =============================================
func _is_weapon_discovery_level() -> bool:
	if player == null:
		return false
	return int(player.level) in WEAPON_DISCOVERY_LEVELS

func _owned_weapon_ids() -> Dictionary:
	var owned := {}
	if player == null:
		return owned
	for slot in player.weapon_slots:
		if slot.get_child_count() > 0:
			var w = slot.get_child(0)
			if "WEAPON_ID" in w:
				owned[w.WEAPON_ID] = true
	return owned

func generate_weapon_discovery_offers() -> Array:
	var offers = []
	var owned := _owned_weapon_ids()
	# All weapons the player still doesn't have
	var available: Array = []
	for wid in ALL_WEAPONS.keys():
		if not owned.has(wid):
			available.append(wid)
	# Out of free slots? Nothing to show — drop back to a regular levelup.
	if player == null or player.get_next_free_slot() == null or available.is_empty():
		return []
	available.shuffle()
	var pick_count = min(3, available.size())
	for i in range(pick_count):
		var wid = available[i]
		var info = ALL_WEAPONS[wid]
		offers.append({
			"upgrade": {
				"id": "weapon_" + wid,
				"name": info["name"],
				"desc": info["desc"],
				"icon": info["icon"],
				"weapon_scene": info["scene"],
			},
			"rarity": "legendary",
		})
	return offers

func generate_offers() -> Array:
	# Discovery levels: only show weapons (no skill upgrades).
	if _is_weapon_discovery_level():
		var disco = generate_weapon_discovery_offers()
		if not disco.is_empty():
			return disco
		# Fall through to normal levelup if there's nothing to discover

	var offers = []
	var used_ids = []
	var has_useful = false

	var weapon_pools = {}
	if player:
		for slot in player.weapon_slots:
			if slot.get_child_count() > 0:
				var weapon = slot.get_child(0)
				if weapon.get_script() and "WEAPON_UPGRADES" in weapon and "WEAPON_ID" in weapon:
					weapon_pools[weapon.WEAPON_ID] = weapon.WEAPON_UPGRADES

	while offers.size() < 3:
		var rarity = roll_rarity()
		var pick = null
		if weapon_pools.size() > 0 and rng.randf() < 0.5:
			var weapon_ids = weapon_pools.keys()
			var wid = weapon_ids[rng.randi_range(0, weapon_ids.size() - 1)]
			var pool = weapon_pools[wid][rarity].duplicate()
			pool = pool.filter(func(u): return not used_ids.has(u["id"]))
			if not pool.is_empty():
				pick = pool[rng.randi_range(0, pool.size() - 1)]
		if pick == null:
			var pool = UPGRADES[rarity].duplicate()
			pool = pool.filter(func(u): return not used_ids.has(u["id"]))
			if pool.is_empty():
				pool = UPGRADES[rarity].duplicate()
			pick = pool[rng.randi_range(0, pool.size() - 1)]

		used_ids.append(pick["id"])
		offers.append({"upgrade": pick, "rarity": rarity})
		if rarity != "common":
			has_useful = true

	if not has_useful and player and player.level >= 4:
		var uncommon_pool = UPGRADES["uncommon"].duplicate()
		uncommon_pool = uncommon_pool.filter(func(u): return not used_ids.has(u["id"]))
		if not uncommon_pool.is_empty():
			var pick = uncommon_pool[rng.randi_range(0, uncommon_pool.size() - 1)]
			offers[offers.size() - 1] = {"upgrade": pick, "rarity": "uncommon"}

	offers = _try_apply_streak(offers, used_ids)
	return offers

func generate_wave_offers() -> Array:
	var offers = []
	var used_ids = []

	var weapon_pools = {}
	if player:
		for slot in player.weapon_slots:
			if slot.get_child_count() > 0:
				var weapon = slot.get_child(0)
				if weapon.get_script() and "WEAPON_UPGRADES" in weapon and "WEAPON_ID" in weapon:
					weapon_pools[weapon.WEAPON_ID] = weapon.WEAPON_UPGRADES

	for _i in range(4):
		var rarity = roll_rarity()
		var pick = null

		# 40% šansa za weapon-specific upgrade u shopu
		if weapon_pools.size() > 0 and rng.randf() < 0.4:
			var weapon_ids = weapon_pools.keys()
			var wid = weapon_ids[rng.randi_range(0, weapon_ids.size() - 1)]
			var pool = weapon_pools[wid][rarity].duplicate()
			pool = pool.filter(func(u): return not used_ids.has(u["id"]))
			if pool.is_empty():
				pool = weapon_pools[wid][rarity].duplicate()
			if not pool.is_empty():
				pick = pool[rng.randi_range(0, pool.size() - 1)].duplicate()
				pick["cost"] = WAVE_WEAPON_COSTS[rarity]
				pick["cost_type"] = "generic"

		if pick == null:
			var pool = WAVE_UPGRADES[rarity].duplicate()
			pool = pool.filter(func(u): return not used_ids.has(u["id"]))
			if pool.is_empty():
				pool = WAVE_UPGRADES[rarity].duplicate()
			pick = pool[rng.randi_range(0, pool.size() - 1)]

		used_ids.append(pick["id"])
		offers.append({"upgrade": pick, "rarity": rarity})

	return offers

# =============================================
#  STREAK / MOMENTUM
# =============================================
func _get_upgrade_category(upgrade: Dictionary) -> String:
	if upgrade.has("target"):
		return "weapon:" + upgrade["target"]
	return upgrade.get("id", "misc")

func _update_streak(category: String) -> void:
	if category == _streak_category and _streak_power > 0.05:
		# Re-pick istog: zadrži elevaciju, ali ne ide na max
		_streak_power = minf(0.80, _streak_power * 0.65 + 0.30)
	else:
		# Novi izbor: svježi streak
		_streak_category = category
		_streak_power = 0.65

func _build_streak_offer(used_ids: Array = []) -> Variant:
	var rarity = roll_rarity()

	# Weapon streak
	if _streak_category.begins_with("weapon:"):
		var weapon_id = _streak_category.substr(7)
		if player:
			for slot in player.weapon_slots:
				if slot.get_child_count() == 0:
					continue
				var w = slot.get_child(0)
				if not ("WEAPON_ID" in w and w.WEAPON_ID == weapon_id and "WEAPON_UPGRADES" in w):
					continue
				var pool: Array = w.WEAPON_UPGRADES[rarity].duplicate()
				pool = pool.filter(func(u): return not used_ids.has(u["id"]))
				if not pool.is_empty():
					return {"upgrade": pool[rng.randi_range(0, pool.size() - 1)], "rarity": rarity}
		return null

	# Global stat streak
	var pool: Array = UPGRADES[rarity].filter(func(u): return u["id"] == _streak_category and not used_ids.has(u["id"]))
	if pool.is_empty():
		pool = UPGRADES[rarity].filter(func(u): return not used_ids.has(u["id"]))
	if not pool.is_empty():
		return {"upgrade": pool[rng.randi_range(0, pool.size() - 1)], "rarity": rarity}
	return null

func _try_apply_streak(offers: Array, used_ids: Array = []) -> Array:
	if _streak_power < 0.08 or _streak_category == "":
		_streak_power = maxf(0.0, _streak_power - 0.20)
		return offers
	var current_power = _streak_power
	_streak_power = maxf(0.0, _streak_power - 0.20)
	if rng.randf() >= current_power:
		return offers
	var streaked = _build_streak_offer(used_ids)
	if streaked == null:
		return offers
	offers[rng.randi_range(0, offers.size() - 1)] = streaked
	return offers

func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common":    return COLOR_COMMON
		"uncommon":  return COLOR_UNCOMMON
		"rare":      return COLOR_RARE
		"legendary": return COLOR_LEGENDARY
		"milestone": return COLOR_MILESTONE
	return COLOR_COMMON

func _can_afford(upgrade: Dictionary) -> bool:
	if current_mode in [Mode.LEVELUP, Mode.WEAPON_MILESTONE]:
		return true
	var cost = upgrade.get("cost", 0)
	var cost_type = upgrade.get("cost_type", "generic")
	return player.scrap_inventory.get(cost_type, 0) >= cost

func _deduct_cost(upgrade: Dictionary):
	if current_mode != Mode.WAVE_REWARD:
		return
	var cost = upgrade.get("cost", 0)
	var cost_type = upgrade.get("cost_type", "generic")
	player.scrap_inventory[cost_type] = max(0, player.scrap_inventory.get(cost_type, 0) - cost)

func _set_card_icon(card: Control, upgrade: Dictionary):
	var icon_label = card.get_node("CardBox/Icon")
	var tex_rect = card.get_node_or_null("CardBox/WeaponTexture")

	# Match against the full weapon roster so weapon-prefixed upgrade ids
	# ("minigun_damage_a") and weapon-discovery ids ("weapon_minigun") both
	# resolve. Weapons without a dedicated image use the pistol art as a
	# placeholder until proper textures are added.
	var weapon_key = ""
	for k in ALL_WEAPONS.keys():
		if upgrade["id"].begins_with(k + "_") or upgrade["id"] == "weapon_" + k:
			weapon_key = k
			break

	if weapon_key != "":
		icon_label.visible = false
		if tex_rect == null:
			tex_rect = TextureRect.new()
			tex_rect.name = "WeaponTexture"
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.layout_mode = 0
			tex_rect.position = Vector2(20, 60)
			tex_rect.size = Vector2(200, 100)
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.get_node("CardBox").add_child(tex_rect)
		var tex_path = WEAPON_TEXTURES.get(weapon_key, WEAPON_TEXTURE_FALLBACK)
		tex_rect.texture = load(tex_path)
		tex_rect.visible = true
	else:
		icon_label.visible = true
		if tex_rect:
			tex_rect.visible = false

# =============================================
#  POPULATE CARDS
# =============================================
func populate_cards():
	$CardsContainer.modulate = Color(1, 1, 1, 1)

	var card_nodes = [
		$CardsContainer/Card1,
		$CardsContainer/Card2,
		$CardsContainer/Card3,
	]

	# Card4 — only in WAVE_REWARD
	var card4 = $CardsContainer.get_node_or_null("Card4")
	if current_mode == Mode.WAVE_REWARD:
		if card4 == null:
			card4 = $CardsContainer/Card1.duplicate()
			card4.name = "Card4"
			$CardsContainer.add_child(card4)
			var btn4 = card4.get_node("SelectButton")
			for c in btn4.pressed.get_connections():
				btn4.pressed.disconnect(c["callable"])
			btn4.pressed.connect(_on_card_selected.bind(3))
		card4.visible = true
		card_nodes.append(card4)
	else:
		if card4:
			card4.visible = false

	# WEAPON_MILESTONE — only 2 cards
	if current_mode == Mode.WEAPON_MILESTONE:
		card_nodes[2].visible = false
		card_nodes = card_nodes.slice(0, 2)
	else:
		card_nodes[2].visible = true

	# Hide cards without a corresponding offer — e.g. weapon discovery at L18
	# when only 1–2 unowned weapons remain.
	for i in range(card_nodes.size()):
		if i >= current_offers.size():
			card_nodes[i].visible = false

	var transparent_style = StyleBoxEmpty.new()

	for i in range(current_offers.size()):
		if i >= card_nodes.size():
			break
		var card = card_nodes[i]
		var card_box = card.get_node("CardBox")

		# Blank (spent) card
		if current_mode == Mode.WAVE_REWARD and i in _spent_indices:
			card.add_theme_stylebox_override("panel", transparent_style)
			var blank_style = StyleBoxFlat.new()
			blank_style.bg_color = Color(0.12, 0.12, 0.12, 0.7)
			blank_style.border_color = Color(0.25, 0.25, 0.25, 0.8)
			blank_style.set_border_width_all(2)
			blank_style.set_corner_radius_all(8)
			card_box.add_theme_stylebox_override("panel", blank_style)
			card.modulate = Color(1, 1, 1, 1)
			card.get_node("NameLabel").text = ""
			card.get_node("CardBox/Icon").text = ""
			card.get_node("DescLabel").text = ""
			card.get_node("SelectButton").disabled = true
			var btn_blank = StyleBoxFlat.new()
			btn_blank.bg_color = Color(0, 0, 0, 0)
			card.get_node("SelectButton").add_theme_stylebox_override("normal", btn_blank)
			card.get_node("SelectButton").add_theme_stylebox_override("hover", btn_blank)
			continue

		var offer = current_offers[i]
		var upgrade = offer["upgrade"]
		var rarity = offer["rarity"]
		var color = get_rarity_color(rarity)
		var can_afford = _can_afford(upgrade)

		card.modulate = Color(1, 1, 1, 1) if can_afford else Color(0.5, 0.5, 0.5, 1)
		card.add_theme_stylebox_override("panel", transparent_style)

		var style = StyleBoxFlat.new()
		style.bg_color = Color(color.r, color.g, color.b, 0.18)
		style.border_color = color
		style.set_border_width_all(3)
		style.set_corner_radius_all(8)
		card_box.add_theme_stylebox_override("panel", style)

		var btn = card.get_node("SelectButton")
		btn.disabled = not can_afford
		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = Color(0, 0, 0, 0)
		var btn_hover = StyleBoxFlat.new()
		btn_hover.bg_color = Color(color.r, color.g, color.b, 0.25)
		btn_hover.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("normal", btn_normal)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

		card.get_node("NameLabel").add_theme_color_override("font_color", color)
		card.get_node("NameLabel").add_theme_font_size_override("font_size", 17)
		card.get_node("NameLabel").text = upgrade["name"]
		card.get_node("CardBox/Icon").add_theme_font_size_override("font_size", 56)
		card.get_node("CardBox/Icon").text = upgrade["icon"]
		_set_card_icon(card, upgrade)
		card.get_node("DescLabel").add_theme_font_size_override("font_size", 13)
		card.get_node("DescLabel").add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

		var desc = upgrade["desc"]
		if current_mode == Mode.WAVE_REWARD:
			var cost = upgrade.get("cost", 0)
			var ctype = upgrade.get("cost_type", "generic")
			var icons = {"generic":"🗑️","metal":"⚙️","copper":"🔶","circuit":"💾","biogel":"🧪","powercell":"🔋","nanochip":"💎"}
			var icon_str = icons.get(ctype, "🗑️")
			desc += "\n%s %d %s" % [icon_str, cost, ctype.capitalize()]
			if not can_afford:
				desc += "\n[NOT ENOUGH]"
		card.get_node("DescLabel").text = desc

	_focused_card = 0
	_refresh_card_focus()

# =============================================
#  CARD SELECTED
# =============================================
func _on_card_selected(index: int):
	if player == null:
		return
	if index >= current_offers.size():
		return

	var upgrade = current_offers[index]["upgrade"]

	# WEAPON_MILESTONE
	if current_mode == Mode.WEAPON_MILESTONE:
		_apply_weapon_ability(upgrade)
		visible = false
		get_tree().paused = false
		await get_tree().create_timer(0.2).timeout
		_show_next_milestone()
		return

	# WAVE_REWARD
	if current_mode == Mode.WAVE_REWARD:
		if not _can_afford(upgrade):
			return
		_deduct_cost(upgrade)
		_update_streak(_get_upgrade_category(upgrade))
		apply_upgrade(upgrade)
		_spent_indices.append(index)
		_update_scrap_display()
		populate_cards()
		return

	# LEVELUP
	_update_streak(_get_upgrade_category(upgrade))
	apply_upgrade(upgrade)
	player.pending_levelups -= 1
	visible = false
	get_tree().paused = false
	_set_game_hud_visible(true)

	if _weapon_milestone_queue.size() > 0:
		_post_milestone_levelups = player.pending_levelups
		player.pending_levelups = 0
		await get_tree().create_timer(0.2).timeout
		_show_next_milestone()
		return

	if player.pending_levelups > 0:
		await get_tree().create_timer(0.2).timeout
		show_for_player(player)

func _on_reroll_pressed():
	if player == null:
		return
	var cost = reroll_cost.amount
	var ctype = reroll_cost.type
	if player.scrap_inventory.get(ctype, 0) < cost:
		return
	player.scrap_inventory[ctype] -= cost
	_reroll_count += 1
	_spent_indices = []
	if current_mode == Mode.LEVELUP:
		current_offers = generate_offers()
	else:
		current_offers = generate_wave_offers()
	populate_cards()
	_update_scrap_display()
	reroll_cost["amount"] += 200
	if _reroll_btn:
		_reroll_btn.text = "🎲 Reroll (%d 🗑️)" % reroll_cost.amount

func _on_next_pressed():
	visible = false
	get_tree().paused = false
	_set_game_hud_visible(true)
	if _weapon_milestone_queue.size() > 0:
		_post_milestone_routemap = true
		await get_tree().create_timer(0.2).timeout
		_show_next_milestone()
		return
	_do_go_to_routemap()

# =============================================
#  APPLY UPGRADE
# =============================================
func apply_upgrade(upgrade: Dictionary):
	if player == null:
		return
	var s = player.stats

	# Data-driven weapon upgrades — used by all weapons
	if upgrade.has("target") and upgrade.has("kind"):
		var w = _get_weapon(upgrade["target"])
		if w == null:
			return
		match upgrade["kind"]:
			"damage":     w.damage *= upgrade.get("mult", 1.0)
			"fire_rate":  w.fire_rate_multiplier *= upgrade.get("mult", 1.0)
			"reload":     w.reload_multiplier *= upgrade.get("mult", 1.0)
			"range":      w.range_multiplier *= upgrade.get("mult", 1.0)
			"spread":     w.spread_multiplier *= upgrade.get("mult", 1.0)
			"pierce":     w.pierce_bonus += int(upgrade.get("amount", 1))
			"proj_count": w.proj_count += int(upgrade.get("amount", 1))
		_check_weapon_milestone(upgrade["target"])
		return

	# Generic player-stat upgrades
	match upgrade["id"]:
		"damage":
			s.damage *= 1.15 if upgrade["name"].ends_with("+") else 1.25
		"fire_rate":
			s.fire_rate *= 1.15 if upgrade["name"].ends_with("+") else 1.25
		"speed":
			s.move_speed *= 1.15
		"max_hp":
			var bonus = 20
			if upgrade.get("name", "") == "Max HP++": bonus = 30
			elif upgrade.get("name", "") == "Fortify": bonus = 50
			s.max_hp += bonus
			player.hp = min(player.hp + bonus, s.max_hp)
		"heal":
			player.hp = min(player.hp + 20, s.max_hp)
		"big_heal":
			player.hp = min(player.hp + 40, s.max_hp)
		"full_heal":
			player.hp = s.max_hp
		"pickup":
			s.pickup_radius *= 1.3
		"range":
			s.shoot_range *= 1.25 if upgrade.get("name", "") == "Range+" else 1.5
		"dual_shot":
			s.projectile_count = max(s.projectile_count, 2)
		"proj_speed":
			s.projectile_speed *= 1.4
		"vampire":
			s.vampire = true
		"triple_shot":
			s.projectile_count = max(s.projectile_count, 3)
		"explosive":
			s.explosive = true
		"shield":
			s.shield = true
		"speed_demon":
			s.move_speed *= 1.5
			s.fire_rate *= 1.5
		"mining_speed":
			s.mining_speed *= upgrade.get("mult", 1.05)
		_:
			# Weapon-discovery upgrades use {"id": "weapon_<id>", "weapon_scene": "..."}
			if upgrade["id"].begins_with("weapon_") and upgrade.has("weapon_scene"):
				_grant_weapon(upgrade["weapon_scene"])

func _grant_weapon(scene_path: String) -> void:
	if player == null:
		return
	var slot = player.get_next_free_slot()
	if slot == null:
		return
	var weapon_scene = load(scene_path)
	if weapon_scene == null:
		return
	var weapon = weapon_scene.instantiate()
	slot.add_child(weapon)

func _get_weapon(weapon_id: String) -> Node:
	if player == null:
		return null
	for slot in player.weapon_slots:
		if slot.get_child_count() > 0:
			var w = slot.get_child(0)
			if "WEAPON_ID" in w and w.WEAPON_ID == weapon_id:
				return w
	return null

# =============================================
#  KEYBOARD NAVIGATION
# =============================================
var _focused_card := 0

func _get_active_card_count() -> int:
	if current_mode == Mode.WEAPON_MILESTONE:
		return 2
	if current_mode == Mode.WAVE_REWARD:
		return 4
	# Weapon-discovery may have fewer than 3 unowned weapons left.
	if _offers_are_weapon_discovery():
		return current_offers.size()
	return 3

func _get_card_node(i: int) -> Control:
	match i:
		0: return $CardsContainer/Card1
		1: return $CardsContainer/Card2
		2: return $CardsContainer/Card3
		3: return $CardsContainer.get_node_or_null("Card4")
	return null

func _set_focused_card(index: int):
	var count = _get_active_card_count()
	_focused_card = clamp(index, 0, count - 1)
	_refresh_card_focus()

func _refresh_card_focus():
	var count = _get_active_card_count()
	for i in range(count):
		var card = _get_card_node(i)
		if card == null:
			continue
		var card_box = card.get_node_or_null("CardBox")
		if card_box == null:
			continue
		if i == _focused_card:
			var focus_style = StyleBoxFlat.new()
			var offer = current_offers[i] if i < current_offers.size() else null
			var color = COLOR_COMMON
			if offer:
				color = get_rarity_color(offer["rarity"])
			focus_style.bg_color = Color(color.r, color.g, color.b, 0.18)
			focus_style.border_color = Color(1, 1, 1, 1)
			focus_style.set_border_width_all(4)
			focus_style.set_corner_radius_all(8)
			card_box.add_theme_stylebox_override("panel", focus_style)
		else:
			_repaint_card(i)

func _repaint_card(i: int):
	if i in _spent_indices:
		return
	if i >= current_offers.size():
		return
	var card = _get_card_node(i)
	if card == null:
		return
	var card_box = card.get_node_or_null("CardBox")
	if card_box == null:
		return
	var offer = current_offers[i]
	var color = get_rarity_color(offer["rarity"])
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.18)
	style.border_color = color
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	card_box.add_theme_stylebox_override("panel", style)

func _unhandled_input(event: InputEvent):
	if not visible:
		return
	var count = _get_active_card_count()
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down") \
			or (event is InputEventKey and event.pressed and event.keycode == KEY_D):
		_set_focused_card((_focused_card + 1) % count)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up") \
			or (event is InputEventKey and event.pressed and event.keycode == KEY_A):
		_set_focused_card((_focused_card - 1 + count) % count)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_on_card_selected(_focused_card)
		get_viewport().set_input_as_handled()
