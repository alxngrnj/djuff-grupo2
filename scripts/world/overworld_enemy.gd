extends Area2D
## Inimigo no mundo: ao tocar o jogador, inicia a batalha.
## Se o jogador vencer, o inimigo some do mundo.
##
## Arraste scenes/world/overworld_enemy.tscn para qualquer mapa e, no Inspetor,
## edite `enemy_ids` para escolher quem aparece na batalha
## (ids em scripts/battle/enemy_database.gd).

@export var enemy_ids: Array[String] = ["slime", "slime_red"]

var _triggered: bool = false


func _ready() -> void:
	_build_sprite()
	body_entered.connect(_on_body_entered)


func _build_sprite() -> void:
	var texture: Texture2D = load("res://assets/mystic_woods_free_2.2/sprites/characters/slime.png")
	var frames := SpriteSheet.build_frames(texture, 32, {"idle": [0, 4, 6.0, true]})
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.offset = Vector2(0.0, -8.0)
	add_child(sprite)
	sprite.play("idle")


func _on_body_entered(body: Node2D) -> void:
	if _triggered or BattleLauncher.in_battle:
		return
	if not (body is CharacterBody2D):
		return
	_triggered = true
	_start_battle.call_deferred() # fora do callback de física


func _start_battle() -> void:
	var encounter := BattleEncounter.new()
	encounter.enemy_ids.assign(enemy_ids)
	var result: String = await BattleLauncher.start_battle(encounter)
	if result == "victory":
		queue_free()
	else:
		_triggered = false
