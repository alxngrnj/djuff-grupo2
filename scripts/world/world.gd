extends Node2D
## Script da cena do mundo: abre o menu do personagem (Tab / botão Select).

const CHARACTER_MENU_PATH := "res://scenes/character_menu/character_menu.tscn"

var _menu_open: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if _menu_open or BattleLauncher.in_battle:
		return
	if event.is_action_pressed("character_menu"):
		get_viewport().set_input_as_handled()
		_open_menu()


func _open_menu() -> void:
	_menu_open = true
	process_mode = Node.PROCESS_MODE_DISABLED # congela o mundo
	var packed: PackedScene = load(CHARACTER_MENU_PATH)
	var menu = packed.instantiate() # sem tipo: usamos o sinal `closed` por nome
	get_tree().root.add_child(menu)
	await menu.closed
	process_mode = Node.PROCESS_MODE_INHERIT
	_menu_open = false

var camera: Camera2D

func _ready():
	camera = get_viewport().get_camera_2d()

	var camada: TileMapLayer = $TileMap/ground
	var used: Rect2i = camada.get_used_rect()

	var cliff: TileMapLayer = $TileMap/cliff
	if cliff.get_used_rect().has_area():
		used = used.merge(cliff.get_used_rect())

	var tam = camada.tile_set.tile_size
	camera.limit_left   = used.position.x * tam.x
	camera.limit_top    = used.position.y * tam.y
	camera.limit_right  = used.end.x * tam.x
	camera.limit_bottom = used.end.y * tam.y
