class_name BattlerData extends Resource
@export var nome := "Player 1"
## Folha de sprites no MESMO layout do player.png (48x48 por quadro).
## Vazio = usa o sprite padrão do herói, com uma cor de teste diferente para cada personagem.
@export var sheet: Texture2D
## Cor aplicada ao sprite (só vale quando "sheet" está preenchido).
@export var tint := Color.WHITE
@export var textura: Texture2D
@export var hp_max := 20
@export var fp_max := 8
@export var ataque: AttackData
