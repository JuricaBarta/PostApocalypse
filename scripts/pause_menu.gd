extends CanvasLayer

var is_paused := false
var current_tab := 0
var player: Node2D = null

# UI reference
var overlay: ColorRect
var tab_container: Control
var content_container: Control
var tab_buttons := []
var tab_names := ["Stats", "Weapons", "Inventory", "Settings", "Exit"]

# Boje
const COLOR_BG = Color(0.08, 0.08, 0.12, 0.95)
const COLOR_TAB_ACTIVE = Color(0.9, 0.3, 0.2, 1.0)
const COLOR_TAB_INACTIVE = Color(0.3, 0.3, 0.35, 1.0)
const COLOR_TAB_HOVER = Color(0.5, 0.5, 0.55, 1.0)
const COLOR_TEXT = Color(0.9, 0.9, 0.9, 1.0)
const COLOR_TEXT_DIM = Color(0.6, 0.6, 0.65, 1.0)
const COLOR_VALUE = Color(1.0, 0.85, 0.3, 1.0)
const COLOR_SEPARATOR = Color(0.25, 0.25, 0.3, 1.0)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	build_ui()
	hide_menu()

func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		toggle_pause()

func toggle_pause():
	is_paused = !is_paused
	if is_paused:
		player = get_tree().get_root().get_node_or_null("Main/Player")
		show_menu()
	else:
		hide_menu()

func show_menu():
	overlay.show()
	switch_tab(0)
	get_tree().paused = true

func hide_menu():
	overlay.hide()
	get_tree().paused = false

# =============================================
#  BUILD UI
# =============================================
func build_ui():
	# Overlay
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = COLOR_BG
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	# Main container — centrirano, max 1100px širine
	var main = VBoxContainer.new()
	main.anchor_left   = 0.5
	main.anchor_right  = 0.5
	main.anchor_top    = 0.05
	main.anchor_bottom = 0.95
	main.offset_left   = -550
	main.offset_right  = 550
	main.offset_top    = 0
	main.offset_bottom = 0
	overlay.add_child(main)

	# X button — unutar panel-a (desni rub main-a)
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.anchor_left   = 0.5
	close_btn.anchor_right  = 0.5
	close_btn.anchor_top    = 0.05
	close_btn.anchor_bottom = 0.05
	close_btn.offset_left   = 495
	close_btn.offset_right  = 550
	close_btn.offset_top    = 5
	close_btn.offset_bottom = 55
	close_btn.add_theme_font_size_override("font_size", 32)
	close_btn.add_theme_color_override("font_color", COLOR_TEXT)
	close_btn.pressed.connect(toggle_pause)
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(0, 0, 0, 0)
	close_btn.add_theme_stylebox_override("normal", close_style)
	var close_hover = StyleBoxFlat.new()
	close_hover.bg_color = Color(0.8, 0.15, 0.1, 0.8)
	close_hover.set_corner_radius_all(6)
	close_btn.add_theme_stylebox_override("hover", close_hover)
	close_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	overlay.add_child(close_btn)

	# Title
	var title = Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	main.add_child(title)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	main.add_child(spacer1)

	# Tab bar
	tab_container = HBoxContainer.new()
	tab_container.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_container.add_theme_constant_override("separation", 8)
	main.add_child(tab_container)

	for i in range(tab_names.size()):
		var btn = Button.new()
		btn.text = tab_names[i]
		btn.custom_minimum_size = Vector2(140, 40)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(switch_tab.bind(i))

		# Style
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = COLOR_TAB_INACTIVE
		style_normal.set_corner_radius_all(6)
		var style_hover = StyleBoxFlat.new()
		style_hover.bg_color = COLOR_TAB_HOVER
		style_hover.set_corner_radius_all(6)
		var style_pressed = StyleBoxFlat.new()
		style_pressed.bg_color = COLOR_TAB_ACTIVE
		style_pressed.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_pressed)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

		tab_container.add_child(btn)
		tab_buttons.append(btn)

	# Separator
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = COLOR_SEPARATOR
	main.add_child(sep)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	main.add_child(spacer2)

	# Content area
	content_container = Control.new()
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(content_container)

# =============================================
#  TAB SWITCHING
# =============================================
func switch_tab(index: int):
	current_tab = index

	# Update tab button colors
	for i in range(tab_buttons.size()):
		var style = StyleBoxFlat.new()
		if i == index:
			style.bg_color = COLOR_TAB_ACTIVE
		else:
			style.bg_color = COLOR_TAB_INACTIVE
		style.set_corner_radius_all(6)
		tab_buttons[i].add_theme_stylebox_override("normal", style)

	# Clear content
	for child in content_container.get_children():
		child.queue_free()

	# Build tab content
	match index:
		0: build_stats_tab()
		1: build_weapons_tab()
		2: build_inventory_tab()
		3: build_settings_tab()
		4: build_exit_tab()

# =============================================
#  STATS TAB
# =============================================
func build_stats_tab():
	var scroll = ScrollContainer.new()
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	content_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	if player == null:
		add_label(vbox, "Player not found!", COLOR_TEXT)
		return

	var s = player.stats

	add_section_header(vbox, "⚔️  COMBAT")
	add_stat_row(vbox, "Damage", "%.1f" % s.damage)
	add_stat_row(vbox, "Fire Rate", "%.2f" % s.fire_rate)
	add_stat_row(vbox, "Projectiles", "%d" % s.projectile_count)
	add_stat_row(vbox, "Proj. Speed", "%.1f" % s.projectile_speed)
	add_stat_row(vbox, "Shoot Range", "%.0f px" % s.shoot_range)

	add_section_header(vbox, "❤️  SURVIVAL")
	add_stat_row(vbox, "HP", "%d / %d" % [player.hp, s.max_hp])
	add_stat_row(vbox, "Move Speed", "%.2f" % s.move_speed)
	add_stat_row(vbox, "Pickup Radius", "%.1f" % s.pickup_radius)
	add_stat_row(vbox, "Invincible", "Yes" if player.invincible else "No")

	add_section_header(vbox, "🎯  PERKS")
	add_stat_row(vbox, "Vampire", "✅" if s.vampire else "❌")
	add_stat_row(vbox, "Explosive", "✅" if s.explosive else "❌")
	add_stat_row(vbox, "Shield", "✅" if s.shield else "❌")

	add_section_header(vbox, "📊  PROGRESS")
	add_stat_row(vbox, "Level", "%d" % player.level)
	add_stat_row(vbox, "XP", "%d / %d" % [player.xp, player.xp_per_level])
	
func build_weapons_tab():
	var scroll = ScrollContainer.new()
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	content_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	if player == null:
		add_label(vbox, "Player not found!", COLOR_TEXT)
		return

	for slot in player.weapon_slots:
		if slot.get_child_count() == 0:
			continue
		var w = slot.get_child(0)
		var name = w.WEAPON_ID.to_upper() if "WEAPON_ID" in w else "UNKNOWN"
		add_section_header(vbox, "🔫  " + name)
		add_stat_row(vbox, "Damage", "%.2f" % w.damage)
		add_stat_row(vbox, "Fire Rate Mult", "%.2f" % w.fire_rate_multiplier)
		add_stat_row(vbox, "Reload Mult", "%.2f" % w.reload_multiplier)
		add_stat_row(vbox, "Range Mult", "%.2f" % w.range_multiplier)
		add_stat_row(vbox, "Spread Mult", "%.2f" % w.spread_multiplier)
		add_stat_row(vbox, "Pierce Bonus", "%d" % w.pierce_bonus)
		add_stat_row(vbox, "Max Ammo", "%d" % w.max_ammo)

# =============================================
#  INVENTORY TAB
# =============================================
func build_inventory_tab():
	var scroll = ScrollContainer.new()
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	content_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	if player == null:
		add_label(vbox, "Player not found!", COLOR_TEXT)
		return

	add_section_header(vbox, "🔩  RESOURCES")

	var resource_icons = {
		"generic": "🗑️",
		"metal": "⚙️",
		"copper": "🔶",
		"circuit": "💾",
		"biogel": "🧪",
		"powercell": "🔋",
		"nanochip": "💎",
	}

	var total = 0
	for key in player.scrap_inventory:
		var amount = player.scrap_inventory[key]
		total += amount
		var icon = resource_icons.get(key, "📦")
		add_stat_row(vbox, "%s  %s" % [icon, key.capitalize()], "%d" % amount)

	add_section_header(vbox, "📦  TOTAL")
	add_stat_row(vbox, "All Resources", "%d" % total)

# =============================================
#  SETTINGS TAB
# =============================================
func build_settings_tab():
	var scroll = ScrollContainer.new()
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	content_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	# ── AUDIO ──────────────────────────────
	add_section_header(vbox, "🔊  AUDIO")

	var vol_row = HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 10)
	vbox.add_child(vol_row)
	var vol_label = Label.new()
	vol_label.text = "Master Volume"
	vol_label.add_theme_font_size_override("font_size", 20)
	vol_label.add_theme_color_override("font_color", COLOR_TEXT)
	vol_label.custom_minimum_size = Vector2(200, 0)
	vol_row.add_child(vol_label)
	var vol_slider = HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 1.0
	vol_slider.step = 0.05
	var bus_idx = AudioServer.get_bus_index("Master")
	vol_slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx)) if bus_idx >= 0 else 1.0
	vol_slider.custom_minimum_size = Vector2(300, 30)
	vol_slider.value_changed.connect(_on_volume_changed)
	vol_row.add_child(vol_slider)

	# ── DISPLAY ────────────────────────────
	add_section_header(vbox, "🖥️  DISPLAY")

	# Fullscreen
	var fs_row = HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 10)
	vbox.add_child(fs_row)
	var fs_label = Label.new()
	fs_label.text = "Fullscreen"
	fs_label.add_theme_font_size_override("font_size", 20)
	fs_label.add_theme_color_override("font_color", COLOR_TEXT)
	fs_label.custom_minimum_size = Vector2(200, 0)
	fs_row.add_child(fs_label)
	var fs_check = CheckButton.new()
	fs_check.button_pressed = RenderingManager.fullscreen
	fs_check.toggled.connect(_on_fullscreen_toggled)
	fs_row.add_child(fs_check)

	# Resolution dropdown
	var res_row = HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 10)
	vbox.add_child(res_row)
	var res_label = Label.new()
	res_label.text = "Resolution"
	res_label.add_theme_font_size_override("font_size", 20)
	res_label.add_theme_color_override("font_color", COLOR_TEXT)
	res_label.custom_minimum_size = Vector2(200, 0)
	res_row.add_child(res_label)
	var res_opt = OptionButton.new()
	res_opt.add_theme_font_size_override("font_size", 18)
	var screen_size = DisplayServer.screen_get_size()
	for i in range(RenderingManager.RESOLUTIONS.size()):
		var r = RenderingManager.RESOLUTIONS[i]
		if r.x <= screen_size.x and r.y <= screen_size.y:
			res_opt.add_item("%d × %d" % [r.x, r.y], i)
	if res_opt.item_count == 0:
		for i in range(RenderingManager.RESOLUTIONS.size()):
			var r = RenderingManager.RESOLUTIONS[i]
			res_opt.add_item("%d × %d" % [r.x, r.y], i)
	for i in range(res_opt.item_count):
		if res_opt.get_item_id(i) == RenderingManager.resolution_index:
			res_opt.selected = i
			break
	res_opt.disabled = RenderingManager.fullscreen
	res_opt.modulate = Color(1, 1, 1, 0.4) if RenderingManager.fullscreen else Color(1, 1, 1, 1)
	res_opt.item_selected.connect(func(idx): RenderingManager.set_resolution(res_opt.get_item_id(idx)))
	fs_check.toggled.connect(func(p):
		res_opt.disabled = p
		res_opt.modulate = Color(1, 1, 1, 0.4) if p else Color(1, 1, 1, 1)
	)
	res_row.add_child(res_opt)

	# ── WORLD SCALING ──────────────────────
	add_section_header(vbox, "🌍  WORLD SCALING")

	# Ultrawide mode
	var wm_row = HBoxContainer.new()
	wm_row.add_theme_constant_override("separation", 10)
	vbox.add_child(wm_row)
	var wm_label = Label.new()
	wm_label.text = "Ultrawide Mode"
	wm_label.add_theme_font_size_override("font_size", 20)
	wm_label.add_theme_color_override("font_color", COLOR_TEXT)
	wm_label.custom_minimum_size = Vector2(200, 0)
	wm_row.add_child(wm_label)
	var wm_opt = OptionButton.new()
	wm_opt.add_theme_font_size_override("font_size", 18)
	wm_opt.add_item("Widescreen  (više mape)", 1)
	wm_opt.add_item("16:9  (black bars)", 0)
	for i in range(wm_opt.item_count):
		if wm_opt.get_item_id(i) == RenderingManager.stretch_mode:
			wm_opt.selected = i
			break
	wm_opt.item_selected.connect(func(idx): RenderingManager.set_stretch_mode(wm_opt.get_item_id(idx)))
	wm_row.add_child(wm_opt)

	# Pixel Perfect
	var pp_row = HBoxContainer.new()
	pp_row.add_theme_constant_override("separation", 10)
	vbox.add_child(pp_row)
	var pp_label = Label.new()
	pp_label.text = "Pixel Perfect"
	pp_label.add_theme_font_size_override("font_size", 20)
	pp_label.add_theme_color_override("font_color", COLOR_TEXT)
	pp_label.custom_minimum_size = Vector2(200, 0)
	pp_row.add_child(pp_label)
	var pp_desc = Label.new()
	pp_desc.text = "(integer scale, no blur)"
	pp_desc.add_theme_font_size_override("font_size", 14)
	pp_desc.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	pp_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pp_row.add_child(pp_desc)
	var pp_check = CheckButton.new()
	pp_check.button_pressed = RenderingManager.pixel_perfect
	pp_check.toggled.connect(_on_pixel_perfect_toggled)
	pp_row.add_child(pp_check)

# =============================================
#  EXIT TAB
# =============================================
func build_exit_tab():
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_top = 0.3
	vbox.anchor_bottom = 0.7
	vbox.offset_left = -150
	vbox.offset_right = 150
	vbox.add_theme_constant_override("separation", 20)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_container.add_child(vbox)

	var warn_label = Label.new()
	warn_label.text = "Are you sure?"
	warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_label.add_theme_font_size_override("font_size", 28)
	warn_label.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(warn_label)

	var hint_label = Label.new()
	hint_label.text = "Progress will be lost!"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3, 1))
	vbox.add_child(hint_label)

	var btn_exit = Button.new()
	btn_exit.text = "EXIT TO MENU"
	btn_exit.custom_minimum_size = Vector2(200, 50)
	btn_exit.add_theme_font_size_override("font_size", 22)
	btn_exit.pressed.connect(_on_exit_pressed)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.8, 0.15, 0.1, 1)
	style.set_corner_radius_all(8)
	btn_exit.add_theme_stylebox_override("normal", style)
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(1.0, 0.25, 0.15, 1)
	style_hover.set_corner_radius_all(8)
	btn_exit.add_theme_stylebox_override("hover", style_hover)
	btn_exit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	vbox.add_child(btn_exit)

	var btn_resume = Button.new()
	btn_resume.text = "RESUME GAME"
	btn_resume.custom_minimum_size = Vector2(200, 50)
	btn_resume.add_theme_font_size_override("font_size", 22)
	btn_resume.pressed.connect(toggle_pause)
	var style_resume = StyleBoxFlat.new()
	style_resume.bg_color = Color(0.2, 0.6, 0.3, 1)
	style_resume.set_corner_radius_all(8)
	btn_resume.add_theme_stylebox_override("normal", style_resume)
	var style_resume_hover = StyleBoxFlat.new()
	style_resume_hover.bg_color = Color(0.3, 0.75, 0.4, 1)
	style_resume_hover.set_corner_radius_all(8)
	btn_resume.add_theme_stylebox_override("hover", style_resume_hover)
	btn_resume.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	vbox.add_child(btn_resume)

# =============================================
#  HELPERS
# =============================================
func add_section_header(parent: Control, text: String):
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	parent.add_child(spacer)

	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", COLOR_TAB_ACTIVE)
	parent.add_child(label)

	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 1)
	sep.color = COLOR_SEPARATOR
	parent.add_child(sep)

func add_stat_row(parent: Control, label_text: String, value_text: String):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 18)
	value.add_theme_color_override("font_color", COLOR_VALUE)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size = Vector2(120, 0)
	row.add_child(value)

func add_label(parent: Control, text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)

# =============================================
#  CALLBACKS
# =============================================
func _on_volume_changed(value: float):
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))

func _on_pixel_perfect_toggled(pressed: bool):
	RenderingManager.set_pixel_perfect(pressed)

func _on_fullscreen_toggled(pressed: bool):
	RenderingManager.set_fullscreen(pressed)

func _on_exit_pressed():
	get_tree().paused = false
	get_tree().quit()
