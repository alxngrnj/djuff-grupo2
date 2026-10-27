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
