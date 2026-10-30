extends Node
## Autoload "BattleLauncher": abre a cena de batalha POR CIMA do mundo atual,
## congela o mundo enquanto dura e devolve o resultado ("victory" ou "defeat").
##
## Uso:  var result: String = await BattleLauncher.start_battle(encounter)

signal battle_started
signal battle_ended(result: String)

const BATTLE_SCENE_PATH := "res://scenes/battle/battle.tscn"

var in_battle: bool = false

var _battle = null # sem tipo: usamos o sinal/método da cena por nome


func start_battle(encounter: BattleEncounter) -> String:
	if in_battle:
		return ""
	in_battle = true

	var world: Node = get_tree().current_scene
	if world != null:
		world.process_mode = Node.PROCESS_MODE_DISABLED

	var packed: PackedScene = load(BATTLE_SCENE_PATH)
	_battle = packed.instantiate()
	_battle.setup(encounter)
	get_tree().root.add_child(_battle)
	battle_started.emit()

	var result: String = await _battle.battle_finished

	_battle.queue_free()
	_battle = null
	in_battle = false

	if result == "defeat":
		PlayerData.reset_after_defeat()
		get_tree().change_scene_to_file(Global.SCENE_MAIN_MENU)
	elif world != null and is_instance_valid(world):
		world.process_mode = Node.PROCESS_MODE_INHERIT

	battle_ended.emit(result)
	return result
