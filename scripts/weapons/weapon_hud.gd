extends CanvasLayer

@onready var slot_uis = [
	$SlotsContainer/SlotUI1,
	$SlotsContainer/SlotUI2,
	$SlotsContainer/SlotUI3,
	$SlotsContainer/SlotUI4,
	$SlotsContainer/SlotUI5,
]

const WEAPON_DISPLAY_NAMES := {
	"ak77": "AK-77",
}

var player: Node = null
var _reload_fills: Array = []
var _top_bar_fills: Array = []
var _level_bar_groups: Array = []
var _level_bar_row: Control = null
var _weapon_icon_rects: Array = []

func _ready():
	for i in range(1, slot_uis.size()):
		slot_uis[i].visible = false
	_init_reload_overlays()
	_init_level_bar_row()

func _init_reload_overlays():
	for slot_ui in slot_uis:
		# Keep top bar visible and store its fill ref for animation
		var top_fill = slot_ui.get_node_or_null("VBoxContainer/ReloadBarContainer/ReloadBarFill")
		if top_fill:
			top_fill.color = Color(0.2, 0.8, 0.2, 1.0)
			top_fill.layout_mode = 1
			top_fill.anchor_right = 1.0
			_top_bar_fills.append(top_fill)
		else:
			_top_bar_fills.append(null)

		# Semi-transparent full-slot overlay
		var fill = ColorRect.new()
		fill.layout_mode = 0
		fill.position = Vector2.ZERO
		fill.size = Vector2(0, 80)
		fill.color = Color(0.2, 0.8, 0.2, 0.28)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.clip_contents = true
		slot_ui.add_child(fill)
		slot_ui.move_child(fill, 0)
		_reload_fills.append(fill)

		# Weapon icon — placed behind VBoxContainer so text renders on top
		var icon_rect = TextureRect.new()
		icon_rect.layout_mode = 0
		icon_rect.position = Vector2(0, 16)
		icon_rect.size = Vector2(80, 42)
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.modulate = Color(1, 1, 1, 0.7)
		slot_ui.add_child(icon_rect)
		# Keep behind VBoxContainer (which is the last pre-existing child at index 0,
		# pushed to index 1 when fill was moved to 0; icon goes at index 1 → VBox at 2)
		slot_ui.move_child(icon_rect, 1)
		_weapon_icon_rects.append(icon_rect)

func _init_level_bar_row():
	var slots = $SlotsContainer
	_level_bar_row = HBoxContainer.new()
	_level_bar_row.name = "LevelBarRow"
	_level_bar_row.anchor_left  = 0.5
	_level_bar_row.anchor_top   = 1.0
	_level_bar_row.anchor_right = 0.5
	_level_bar_row.anchor_bottom = 1.0
	_level_bar_row.offset_left   = slots.offset_left
	_level_bar_row.offset_right  = slots.offset_right
	_level_bar_row.offset_top    = slots.offset_bottom + 4
	_level_bar_row.offset_bottom = slots.offset_bottom + 18
	_level_bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_level_bar_row.add_theme_constant_override("separation", 10)
	add_child(_level_bar_row)

	for _i in range(5):
		var group = HBoxContainer.new()
		group.alignment = BoxContainer.ALIGNMENT_CENTER
		group.add_theme_constant_override("separation", 1)
		group.custom_minimum_size = Vector2(80, 0)
		group.visible = false
		for _j in range(18):
			var rect = ColorRect.new()
			rect.custom_minimum_size = Vector2(4, 10)
			rect.color = Color(0.22, 0.22, 0.22, 0.85)
			group.add_child(rect)
		_level_bar_row.add_child(group)
		_level_bar_groups.append(group)

func _process(_delta):
	if player == null:
		player = get_tree().get_root().get_node_or_null("Main/Player")
		return

	for i in range(slot_uis.size()):
		var slot_ui = slot_uis[i]
		var active = i < player.weapon_slots.size() and player.weapon_slots[i].get_child_count() > 0

		slot_ui.visible = active
		if i < _level_bar_groups.size():
			_level_bar_groups[i].visible = active

		if not active:
			if i < _reload_fills.size():
				_reload_fills[i].size = Vector2(0, 80)
			if i < _top_bar_fills.size() and _top_bar_fills[i] != null:
				_top_bar_fills[i].anchor_right = 0.0
			continue

		var weapon = player.weapon_slots[i].get_child(0)

		# Labels
		slot_ui.get_node("VBoxContainer/AmmoLabel").text = "%d/%d" % [weapon.current_ammo, weapon.max_ammo]
		var wid = weapon.WEAPON_ID if "WEAPON_ID" in weapon else ""
		slot_ui.get_node("VBoxContainer/WeaponNameLabel").text = \
			WEAPON_DISPLAY_NAMES.get(wid, wid.to_upper()) if wid != "" else "???"

		# Weapon icon — pulled from the sprite the weapon set up itself
		if i < _weapon_icon_rects.size():
			var icon_rect = _weapon_icon_rects[i]
			var spr = weapon.get_node_or_null("WeaponSprite")
			if spr and spr.texture:
				icon_rect.texture = spr.texture
			icon_rect.visible = icon_rect.texture != null

		# Compute shared ammo/reload progress
		var progress: float
		if weapon.is_reloading:
			progress = 1.0 - clamp(weapon.reload_timer / (weapon.reload_time * weapon.reload_multiplier), 0.0, 1.0)
		else:
			progress = float(weapon.current_ammo) / float(weapon.max_ammo)

		# Semi-transparent full-slot overlay
		if i < _reload_fills.size():
			_reload_fills[i].size = Vector2((slot_ui.size.x - 4) * progress, slot_ui.size.y)

		# Solid top bar (eye-catcher)
		if i < _top_bar_fills.size() and _top_bar_fills[i] != null:
			_top_bar_fills[i].anchor_right = progress

		# Level bar dots
		if i < _level_bar_groups.size():
			var group = _level_bar_groups[i]
			var wlevel = weapon.weapon_level if "weapon_level" in weapon else 0
			for j in range(group.get_child_count()):
				var rect = group.get_child(j)
				if j < wlevel:
					if j >= 12:
						rect.color = Color(1.0, 0.75, 0.0, 1.0)
					elif j >= 6:
						rect.color = Color(0.55, 0.2, 0.9, 1.0)
					else:
						rect.color = Color(0.2, 0.82, 0.3, 1.0)
				else:
					rect.color = Color(0.22, 0.22, 0.22, 0.85)
