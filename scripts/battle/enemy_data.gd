class_name EnemyData
extends Resource
## Dados de um tipo de inimigo.

@export var id: String = ""
@export var display_name: String = ""
@export var max_hp: int = 5
@export var attack: int = 2
@export var defense: int = 0
## Tempo de "preparacao" antes do ataque (o "!" aparece aqui).
@export var windup: float = 0.7
@export var tint: Color = Color.WHITE
@export var sprite_scale: float = 1.0
