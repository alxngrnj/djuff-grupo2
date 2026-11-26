class_name AttackData extends Resource
enum Alvo { INIMIGO, ALIADO, TODOS_INIMIGOS }
@export var nome := "Espada"
@export var dano := 5          # número negativo = cura
@export var custo_fp := 0
@export var alvo: Alvo = Alvo.INIMIGO
