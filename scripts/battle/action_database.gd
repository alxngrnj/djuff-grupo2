class_name ActionDatabase
extends RefCounted
## Catálogo de ações. Para criar uma ação nova, adicione uma linha em _build().

static var _actions: Dictionary = {}


static func get_action(id: String) -> BattleAction:
	if _actions.is_empty():
		_build()
	if _actions.has(id):
		return _actions[id]
	return null


static func all_ids() -> Array[String]:
	if _actions.is_empty():
		_build()
	var ids: Array[String] = []
	for key: String in _actions:
		ids.append(key)
	return ids


static func _add(id: String, display_name: String, description: String, fp_cost: int, power: int,
		command: BattleAction.Command, target: BattleAction.Target, style: BattleAction.Style) -> void:
	var a := BattleAction.new()
	a.id = id
	a.display_name = display_name
	a.description = description
	a.fp_cost = fp_cost
	a.power = power
	a.command = command
	a.target = target
	a.style = style
	_actions[id] = a


static func _build() -> void:
	_add("jump", "Pulo",
		"Pule na cabeça do inimigo. Aperte o botão ao pousar.",
		0, 2, BattleAction.Command.SYNC, BattleAction.Target.ENEMY_SINGLE, BattleAction.Style.JUMP)
	_add("sword", "Espada",
		"Corte um inimigo. Aperte quando o cursor estiver na zona dourada.",
		0, 3, BattleAction.Command.BAR, BattleAction.Target.ENEMY_SINGLE, BattleAction.Style.MELEE)
	_add("burst", "Rajada",
		"Atinge TODOS os inimigos. Aperte o botão várias vezes!",
		3, 2, BattleAction.Command.MASH, BattleAction.Target.ENEMY_ALL, BattleAction.Style.RANGED)
	_add("heal", "Curar",
		"Recupera HP. Aperte quando o cursor estiver na zona dourada.",
		2, 5, BattleAction.Command.BAR, BattleAction.Target.SELF, BattleAction.Style.SUPPORT)
