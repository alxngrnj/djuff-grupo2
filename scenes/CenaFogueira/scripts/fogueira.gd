extends Node

@onready var opcoes_final: Control = $Botoes/OpcoesFinal
@onready var btn_opcao_1: Button = $Botoes/OpcoesFinal/Opcao1
@onready var btn_opcao_2: Button = $Botoes/OpcoesFinal/Opcao2

@onready var anim_bonfire = $Background/Objects/Fogueira
@onready var anim_characters = $Characters/AnimatedSprite2D

@onready var dialogue_manager = $DialogueManager
@onready var encerrar_cena: Label = $Botoes/EncerrarCena

@onready var botoes = $Botoes
@onready var input_lena: Sprite2D = $Botoes/Lena/SpriteInputLena
@onready var input_p1: Sprite2D = $Botoes/P1/SpriteInputP1
@onready var input_p2: Sprite2D = $Botoes/P2/SpriteInputP2
@onready var input_p3: Sprite2D = $Botoes/P3/SpriteInputP3

@onready var camera = $Camera2D
@onready var fade_rect = $Camera2D/FadeLayer/ColorRect
@onready var luz = $PointLight2D

@onready var som_ambiente: AudioStreamPlayer = $SomAmbiente

# Inserir os caminhos dos finais aqui
@export_file("*.tscn") var proxima_cena: String = "res://scenes/final1.tscn" 
@export_file("*.tscn") var cena_final_opcao_1: String = "res://scenes/final1.tscn" 
@export_file("*.tscn") var cena_final_opcao_2: String = "res://scenes/final2.tscn" 
@export_file("*.tscn") var cena_final_grupo: String = "res://scenes/final3.tscn"

@export var min_amigos_para_escolha: int = 2

# Trava os comandos do jogador até a transição inicial terminar
var intro_concluida: bool = false

var personagens_conversados: Array[String] = [] 
var em_conversa_grupo: bool = false
var escolhendo_final: bool = false
var transicionando: bool = false

var em_conversas: bool = false

var base_energy: float = 1.0 # Ajuste para a força base da sua luz
var noise = FastNoiseLite.new()
var time_passed: float = 0.0

# Referência para o texto de debug na tela
var debug_label: Label

# Bloqueia inputs durante o intervalo antes da conversa em grupo
var aguardando_grupo: bool = false

func _ready() -> void:
	anim_bonfire.play("bonfire")
	anim_characters.play("default")
	noise.frequency = 0.1 # Velocidade da tremulação da fogueira
	
	# Esconde o menu de escolhas e conecta os sinais de clique
	opcoes_final.visible = false
	
	show_buttons(true)
	
	fade_rect.color.a = 1.0 # Tela preta
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE # Impede o fade de bloquear cliques nos botões
	
	# Guarda o volume definido no Inspector e inicia o som bem baixo
	var volume_alvo: float = 0.0
	if som_ambiente:
		volume_alvo = som_ambiente.volume_db
		som_ambiente.volume_db = -40.0
	
	camera.position = Vector2(0, -300) # Câmera do jogo começa mostrando o céu aqui
	camera.zoom = Vector2(1, 1) # Câmera mais "aberta" no inicio
	
	botoes.modulate.a = 0.0
	
	var tween = create_tween()
	
	tween.tween_property(fade_rect, "color:a", 0.0, 3.0) #tela preta começa a sumir
	
	if som_ambiente:
		tween.parallel().tween_property(som_ambiente, "volume_db", volume_alvo, 3.0)
		
	# Inicia o movimento para baixo da câmera
	tween.tween_property(camera, "position", Vector2(0, 100), 3.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
		
	# Muda o zoom de 1 para 1.5 (câmera mais fechada nos personagens)
	tween.parallel().tween_property(camera, "zoom", Vector2(1.5, 1.5), 3.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
		
	#botões aparecem
	tween.finished.connect(show_buttons.bind(true, true)) 


func _process(_delta: float) -> void:

	# Intercepta o fim de cada diálogo para checar a contagem de quantos personagens o jogador conversou
	if em_conversas and not dialogue_manager.is_dialogue_active:
		em_conversas = false
		
		# 1. Se acabou a conversa em grupo, vai direto para o 3º final
		if em_conversa_grupo:
			Global.fogueira_concluida = true
			transicionar_para_cena(cena_final_grupo)
			return
			
		# 2. Se conversou com 4 amigos, inicia a conversa do grupo automaticamente
		if personagens_conversados.size() == 4:
			aguardando_grupo = true 
			get_tree().create_timer(1.5).timeout.connect(iniciar_conversa_grupo) # ALTERADO
			return
			
		# 3. Caso contrário (< 4), apenas reexibe os botões normais
		show_buttons(true)	
		
	time_passed += _delta * 60.0
	# Variação na luz da fogueira
	luz.energy = base_energy + (noise.get_noise_1d(time_passed) * 0.2)


func _unhandled_input(event: InputEvent) -> void:
	# Bloqueia inputs também durante a escolha de final
	if not intro_concluida or dialogue_manager.is_dialogue_active or transicionando or aguardando_grupo:
		return

	# 2. Verifica se o evento é uma tecla do teclado sendo pressionada
	if event is InputEventKey and event.pressed:
		# Se as opções de final estiverem na tela, escuta apenas as teclas das opções
		if escolhendo_final:
			if event.keycode == KEY_A:
				_on_opcao_1_pressed()
			elif event.keycode == KEY_D:
				_on_opcao_2_pressed()
			return
			
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
	# Evita contar o mesmo personagem mais de uma vez na lista de personagens conversados
	if not id_personagem in personagens_conversados:
		personagens_conversados.append(id_personagem)
		
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
func show_buttons(estado: bool = true, com_fade: bool = false) -> void:
	if com_fade:
		# Libera os botões assim que a transição inicial termina
		intro_concluida = true
		# Cria um novo tween apenas para os botões
		var tween_botoes = create_tween()
		
		# Faz os botões surgirem suavemente (fade in) em 1 segundo
		tween_botoes.tween_property(botoes, "modulate:a", 1.0, 1.0)

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
	var qtd_conversas = personagens_conversados.size()
	
	if qtd_conversas >= min_amigos_para_escolha:
		escolhendo_final = true
		show_buttons(false)
		opcoes_final.visible = true
	else:
		Global.fogueira_concluida = true
		transicionar_para_cena(proxima_cena) # ALTERADO


# Dispara o diálogo automático ao falar com os 4 personagens
#Colocar os dialogos da conversa em grupo aqui
func iniciar_conversa_grupo() -> void:
	em_conversas = true
	em_conversa_grupo = true
	show_buttons(false)
	
	var falas_grupo: Array = [
		{"nome": "Kai", "texto": "teste"},
		{"nome": "Lena", "texto": "teste2"},
		{"nome": "Sebastião", "texto": "teste3"}
	]
	
	dialogue_manager.start_dialogue(falas_grupo)


# Ações dos 2 botões de escolha
func _on_opcao_1_pressed() -> void:
	Global.fogueira_concluida = true
	transicionar_para_cena(cena_final_opcao_1)


func _on_opcao_2_pressed() -> void:
	Global.fogueira_concluida = true
	transicionar_para_cena(cena_final_opcao_2) # ALTERADO


func transicionar_para_cena(caminho_cena: String) -> void:
	if caminho_cena == "":
		return
		
	transicionando = true
	show_buttons(false)
	
	if opcoes_final: # Esconde as opções de final durante o fade-out
		opcoes_final.visible = false
	
	var tween_saida = create_tween()
	tween_saida.tween_property(fade_rect, "color:a", 1.0, 2.0)
	# Abaixa o volume em paralelo com o escurecimento da tela
	if som_ambiente:
		tween_saida.parallel().tween_property(som_ambiente, "volume_db", -80.0, 2.0)
	tween_saida.finished.connect(func(): get_tree().change_scene_to_file(caminho_cena))
