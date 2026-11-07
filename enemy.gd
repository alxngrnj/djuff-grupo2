extends CharacterBody2D
## Slime do mapa: persegue o jogador e, ao encostar nele, abre a batalha.
## Para criar um inimigo mais forte, coloque outra cópia desta cena no mapa e
## mude "Enemy Ids" e "Tint" no Inspetor (ids do EnemyDatabase, ex.: "slime", "slime_red").

## Quais inimigos aparecem na batalha.
@export var enemy_ids: Array[String] = ["slime"]
## Cor do slime no mapa (para diferenciar o mais forte).
@export var tint: Color = Color.WHITE
## Distância (em pixels) a partir da qual a batalha começa.
@export var contact_distance: float = 14.0

var speed = 40
var player_chase = false
var player = null
var _in_battle := false


func _ready() -> void:
	$AnimatedSprite2D.modulate = tint


func _physics_process(delta):
	if _in_battle:
		return

	if player_chase and is_instance_valid(player):
		position += (player.position - position)/speed

		$AnimatedSprite2D.play("walk")

		if (player.position.x - position.x) < 0:
			$AnimatedSprite2D.flip_h = true
		else:
			$AnimatedSprite2D.flip_h = false

		# Encostou no jogador: começa a batalha.
		if global_position.distance_to(player.global_position) <= contact_distance:
			_start_battle()
	else:
		$AnimatedSprite2D.play("idle")


func _start_battle() -> void:
	_in_battle = true
	$AnimatedSprite2D.play("idle")
	var encounter := BattleEncounter.new()
	encounter.enemy_ids = enemy_ids
	var result: String = await BattleLauncher.start_battle(encounter)
	if result == "victory":
		queue_free() # o slime derrotado some do mapa
	else:
		_in_battle = false


## O jogador é quem está no grupo "player" (ou o nó se chama "player").
func _is_player(body: Node) -> bool:
	return body != self and (body.is_in_group("player") or String(body.name).to_lower() == "player")


func _on_detection_area_body_entered(body: Node2D) -> void:
	if _is_player(body):
		player = body
		player_chase = true


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		player_chase = false
