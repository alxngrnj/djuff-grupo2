extends Area2D
## Inimigo no mundo: ao tocar o jogador, inicia a batalha.
## Se o jogador vencer, o inimigo some do mundo.
##
## Arraste scenes/world/overworld_enemy.tscn para qualquer mapa e, no Inspetor,
## edite `enemy_ids` para escolher quem aparece na batalha
## (ids em scripts/battle/enemy_database.gd).

@export var enemy_ids: Array[String] = ["slime", "slime_red"]

signal defeated

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

## Multiplicador de vida dos inimigos desta batalha (2.0 = o dobro de vida).
@export var hp_multiplier: float = 1.0
## Defesa extra: cada ponto tira 1 de dano dos seus golpes (o dano mínimo continua sendo 1).
@export var defense_bonus: int = 0

func _start_battle() -> void:
	var encounter := BattleEncounter.new()
	encounter.enemy_ids.assign(enemy_ids)
	encounter.set_meta("hp_mult", hp_multiplier)
	encounter.set_meta("defense_bonus", defense_bonus)
	var result: String = await BattleLauncher.start_battle(encounter)
	if result == "victory":
		defeated.emit()
		queue_free()
	else:
		_triggered = false
