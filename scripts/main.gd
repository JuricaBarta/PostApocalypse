extends Node2D
@onready var player = $Player
@onready var wave_manager = $WaveManager
#var pause_menu_script = preload("res://pause_menu.gd")

func _ready():
	NavigationServer2D.set_debug_enabled(false)
	print("Main ready, WaveManager instance:", wave_manager)
	
	var pause_menu = CanvasLayer.new()
	pause_menu.name = "PauseMenu"
	#pause_menu.set_script(pause_menu_script)
	add_child(pause_menu)
