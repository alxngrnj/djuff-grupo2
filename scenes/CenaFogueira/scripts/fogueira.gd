extends Node

@onready var dialogue_manager = $DialogueManager
@onready var encerrar_cena: Label = $EncerrarCena

@onready var input_lena: Sprite2D = $Characters/Lena/SpriteInputLena
@onready var input_p1: Sprite2D = $Characters/P1/SpriteInputP1
@onready var input_p2: Sprite2D = $Characters/P2/SpriteInputP2
@onready var input_p3: Sprite2D = $Characters/P3/SpriteInputP3

#inserir o caminho de "Crafting.tscn" aqui:
var proxima_cena: String = "null"

var em_conversas: bool = false


func _ready() -> void:
	show_buttons(true)


func _process(_delta: float) -> void:
	#verifica se está acontecendo um dialogo; se não, volta a mostrar os botões na tela.
	if em_conversas and not dialogue_manager.is_dialogue_active:
		em_conversas = false
		show_buttons(true)


func _unhandled_input(event: InputEvent) -> void:
	# Se o diálogo já estiver aberto, bloqueia qualquer seleção de personagem
	if dialogue_manager.is_dialogue_active:
		return

	# 2. Verifica se o evento é uma tecla do teclado sendo pressionada
	if event is InputEventKey and event.pressed:
		# A chama o P1
		if event.keycode == KEY_A:
			inicializar_conversas("Kai")
			
		# S chama o P2
		elif event.keycode == KEY_S:
			inicializar_conversas("Sebastiao")
			
		# D chama o P3
		elif event.keycode == KEY_D:
			inicializar_conversas("Sera")
			
		# F chama Lena
		elif event.keycode == KEY_F:
			inicializar_conversas("Lena")
			
		# encerra a cena se clicar ENTER
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			encerrar_fogueira()


#colocar dialogos nessa função
func inicializar_conversas(id_personagem: String) -> void:
	em_conversas = true
	# Esconde os botoes enquanto um dialogo acontece
	show_buttons(false)
	
	var falas: Array = []
	
	if id_personagem == "Kai":
		falas = [
			{"nome": "Kai", "texto": "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Proin euismod vel magna ac imperdiet. Curabitur sit amet arcu at felis imperdiet egestas. In eget ultricies dui. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Donec tempor dignissim sapien, nec lobortis leo suscipit id. Donec lacinia, tellus et porttitor interdum, justo ipsum efficitur urna, at aliquet leo arcu vel mauris. Donec tristique commodo nibh luctus tempus. Aenean fermentum, magna nec vestibulum malesuada, augue leo elementum mauris, at cursus diam urna eget metus. Cras et elit ipsum. Proin maximus ipsum libero, molestie vulputate massa mollis vel. Nunc in est massa. Maecenas justo quam, consectetur non mollis ut, finibus quis est. Maecenas cursus sem ut dictum commodo. Nulla sed neque laoreet arcu auctor condimentum eu rutrum dui. Vestibulum maximus ut ex et feugiat. "}
		]
	elif id_personagem == "Sebastiao":
		falas = [
			{"nome": "Sebastião", "texto": "Quisque ultricies accumsan arcu a scelerisque. Quisque eleifend dapibus pellentesque. Mauris ut purus vehicula, commodo mauris eget, mattis risus. Phasellus elit lectus, faucibus nec dignissim at, sodales non nisl. Nam feugiat neque a semper mattis. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus facilisis elit vitae ex accumsan, vitae scelerisque tellus viverra. Suspendisse posuere orci a sodales imperdiet. Phasellus vel semper leo, quis pharetra nibh. Etiam bibendum justo ipsum, eu lacinia metus dictum et. Donec at nibh nisl. Ut euismod nulla vel libero cursus, quis posuere ligula maximus. "}
		]
	elif id_personagem == "Sera":
		falas = [
			{"nome": "Sera", "texto": "Suspendisse efficitur risus vel ex mollis, quis dapibus metus cursus. Fusce vitae mauris congue, mattis ante sed, pretium turpis. Donec molestie ultrices tortor aliquet mollis. Aliquam convallis sapien eget auctor condimentum. Duis tempor pellentesque mi quis posuere. Donec ultricies lacus ultrices convallis iaculis. Donec arcu nunc, vestibulum quis suscipit non, commodo vitae erat. "}
		]
	elif id_personagem == "Lena":
		falas = [
			{"nome": "Lena", "texto": "Phasellus non diam turpis. Phasellus sit amet dui vehicula justo luctus malesuada. Pellentesque non bibendum magna. Nulla ultrices a libero quis vehicula. Donec ac orci non elit molestie elementum a non felis. Phasellus ultricies mollis enim non pulvinar. Pellentesque fermentum varius hendrerit. Cras lacinia eleifend quam, vitae elementum justo scelerisque vitae. Suspendisse potenti. "}
		]

	#chama a função de iniciar o dialogo em dialogue_manager.gd
	dialogue_manager.start_dialogue(falas)


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
