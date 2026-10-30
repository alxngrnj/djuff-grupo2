extends Node2D
## Script da cena do mundo: abre o menu do personagem (Tab / botão Select).

const CHARACTER_MENU_PATH := "res://scenes/character_menu/character_menu.tscn"
const CAMPFIRE_SCENE_PATH := "res://scenes/CenaFogueira/Fogueira.tscn"

var _menu_open: bool = false
var _transitioning_to_campfire := false


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
	for enemy in get_tree().get_nodes_in_group("overworld_enemy"):
		enemy.defeated.connect(_on_enemy_defeated)

	camera = $TileMap/player/Camera2D

	var camada: TileMapLayer = $TileMap/ground
	var used: Rect2i = camada.get_used_rect()

	var cliff: TileMapLayer = $TileMap/cliff
	if cliff.get_used_rect().has_area():
		used = used.merge(cliff.get_used_rect())

	var tam = camada.tile_set.tile_size
	var map_rect := Rect2(
		Vector2(used.position) * Vector2(tam),
		Vector2(used.size) * Vector2(tam)
	)
	camera.position = Vector2.ZERO
	camera.enabled = true
	camera.limit_left = map_rect.position.x
	camera.limit_top = map_rect.position.y
	camera.limit_right = map_rect.end.x
	camera.limit_bottom = map_rect.end.y
	_create_world_boundaries(map_rect)

func _create_world_boundaries(map_rect: Rect2) -> void:
	var bounds: StaticBody2D = $WorldBounds
	var thickness := 32.0
	var walls := [
		[Vector2(map_rect.get_center().x, map_rect.position.y - thickness / 2.0),
			Vector2(map_rect.size.x + thickness * 2.0, thickness)],
		[Vector2(map_rect.get_center().x, map_rect.end.y + thickness / 2.0),
			Vector2(map_rect.size.x + thickness * 2.0, thickness)],
		[Vector2(map_rect.position.x - thickness / 2.0, map_rect.get_center().y),
			Vector2(thickness, map_rect.size.y)],
		[Vector2(map_rect.end.x + thickness / 2.0, map_rect.get_center().y),
			Vector2(thickness, map_rect.size.y)]
	]
	for wall in walls:
		var shape_node := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = wall[1]
		shape_node.position = wall[0]
		shape_node.shape = shape
		bounds.add_child(shape_node)

func _on_enemy_defeated() -> void:
	if _transitioning_to_campfire:
		return
	call_deferred("_check_remaining_enemies")

func _check_remaining_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("overworld_enemy"):
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			return

	if not _transitioning_to_campfire:
		_transitioning_to_campfire = true
		get_tree().change_scene_to_file(CAMPFIRE_SCENE_PATH)
