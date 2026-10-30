class_name BattleAction
extends Resource
## Uma ação que o jogador pode ligar a um botão (pulo, espada, cura...).

## Tipo de action command usado pela ação.
enum Command { SYNC, BAR, MASH }
## Em quem a ação atua.
enum Target { ENEMY_SINGLE, ENEMY_ALL, SELF }
## Como o jogador se move/anima ao executar.
enum Style { JUMP, MELEE, RANGED, SUPPORT }

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var fp_cost: int = 0
## Dano base (ou cura base, se Target.SELF).
@export var power: int = 1
@export var command: Command = Command.SYNC
@export var target: Target = Target.ENEMY_SINGLE
@export var style: Style = Style.JUMP
