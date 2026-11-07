class_name EnemyDatabase
extends RefCounted
## Catálogo de inimigos. Para criar um inimigo novo, adicione uma linha em _build().

static var _enemies: Dictionary = {}


static func get_enemy(id: String) -> EnemyData:
	if _enemies.is_empty():
		_build()
	if _enemies.has(id):
		return _enemies[id]
	push_warning("Inimigo desconhecido: %s (usando slime)" % id)
	return _enemies["slime"]


static func _add(id: String, display_name: String, hp: int, attack: int, defense: int,
		windup: float, tint: Color, sprite_scale: float) -> void:
	var e := EnemyData.new()
	e.id = id
	e.display_name = display_name
	e.max_hp = hp
	e.attack = attack
	e.defense = defense
	e.windup = windup
	e.tint = tint
	e.sprite_scale = sprite_scale
	_enemies[id] = e


static func _build() -> void:
	_add("slime", "Slime", 5, 2, 0, 0.7, Color.WHITE, 1.0)
	_add("slime_red", "Slime Vermelho", 8, 3, 0, 0.55, Color(1.0, 0.55, 0.55), 1.25)
