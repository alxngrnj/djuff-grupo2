extends Node

@onready var dialogue_manager = $DialogueManager
@onready var encerrar_cena: Label = $EncerrarCena

@onready var input_lena: Sprite2D = $Characters/Lena/SpriteInputLena
@onready var input_p1: Sprite2D = $Characters/P1/SpriteInputP1
@onready var input_p2: Sprite2D = $Characters/P2/SpriteInputP2
@onready var input_p3: Sprite2D = $Characters/P3/SpriteInputP3

#inserir o caminho de "Crafting.tscn" aqui:
var proxima_cena: String = "null"

func _ready() -> void:
	show_buttons(true)

func _process(_delta: float) -> void:
	#verifica se está acontecendo um dialogo; se não, volta a mostrar os botões na tela.
	if not input_p1.visible and not dialogue_manager.is_dialogue_active:
		show_buttons(true)


func _unhandled_input(event: InputEvent) -> void:
	# Se o diálogo já estiver aberto, bloqueia qualquer seleção de personagem
	if dialogue_manager.is_dialogue_active:
		return

	# 2. Verifica se o evento é uma tecla do teclado sendo pressionada
	if event is InputEventKey and event.pressed:
		# A chama o P1
		if event.keycode == KEY_A:
			inicializar_conversas("P1")
			
		# S chama o P2
		elif event.keycode == KEY_S:
			inicializar_conversas("P2")
			
		# D chama o P3
		elif event.keycode == KEY_D:
			inicializar_conversas("P3")
			
		# F chama Lena
		elif event.keycode == KEY_F:
			inicializar_conversas("Lena")
			
		# encerra a cena se clicar ENTER
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			encerrar_fogueira()

func inicializar_conversas(id_personagem: String) -> void:
	# Esconde os botoes enquanto um dialogo acontece
	show_buttons(false)
	#chama a função de iniciar o dialogo em dialogue_manager.gd
	dialogue_manager.start_dialogue(id_personagem)


#quando o dialogo está acontecendo, os botoes desaparecem. A função abaixo os torna visíveis novamente.
func show_buttons(estado: bool) -> void:
	if input_lena: 
		input_lena.visible = estado
	if input_p1: 
		input_p1.visible = estado
	if input_p2: 
		input_p2.visible = estado
	if input_p3: 
		input_p3.visible = estado
	if encerrar_cena:
		encerrar_cena.visible = estado

func encerrar_fogueira() -> void:
	Global.fogueira_concluida = true
	#muda para cena de crafting
	#get_tree().change_scene_to_file(proxima_cena) 
