extends CanvasLayer
class_name DialogueManager

@onready var dialogue_box: Control = $DialogueBox
@onready var dialogue_text: Label = $DialogueBox/DialogueText
@onready var name_text: Label = $DialogueBox/NameText

var dialogue_lines: Array = []
var current_line_index: int = 0 #indica o dialogo atual
var is_dialogue_active: bool = false 
var is_interaction_active: bool = false


func _ready() -> void:
	#caixa de texto invisível de inicio.
	if dialogue_box:
		dialogue_box.visible = false 


func start_dialogue(lines: Array) -> void: #recebe as falas
	#caso a lista de falas estiver vazia, sai
	if lines.is_empty():
		return
	
	dialogue_lines = lines
	current_line_index = 0
	is_dialogue_active = true
	
	dialogue_box.visible = true #caixa de texto aparece
	get_tree().paused = true #pausa o jogo enquanto o dialogo acontece
	
	_atualizar_fala() 


func show_interaction(title: String, message: String) -> void:
	dialogue_lines.clear()
	current_line_index = 0
	is_dialogue_active = false
	is_interaction_active = true
	name_text.text = title
	dialogue_text.text = message
	dialogue_text.lines_skipped = 0
	dialogue_box.visible = true
	get_tree().paused = true


func update_interaction(title: String, message: String) -> void:
	if not is_interaction_active:
		return
	name_text.text = title
	dialogue_text.text = message
	dialogue_text.lines_skipped = 0


func close_interaction() -> void:
	if not is_interaction_active:
		return
	is_interaction_active = false
	dialogue_box.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if is_interaction_active:
		return
	#dialogo não está ativado
	if not is_dialogue_active: #verifica se o dialogo está ativo
		return
	#se estiver ativo, espera o jogador apertar o botão esquerdo do mouse para passar a fala
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance_dialogue() 


func advance_dialogue():
	### Paginação
	var total_linhas = dialogue_text.get_line_count()
	var limite_por_pagina = dialogue_text.max_lines_visible
	
	# Verifica se o texto atual ainda tem linhas para serem mostradas
	if dialogue_text.lines_skipped + limite_por_pagina < total_linhas:
		dialogue_text.lines_skipped += limite_por_pagina
		
	else: 
		# Se a fala atual já foi toda lida, verifica se ainda existem mais falas no array de diálogos
		if current_line_index < dialogue_lines.size() - 1:
			current_line_index += 1
			_atualizar_fala()
		
		else:
			# Chegou ao fim de todas as falas, fecha a caixa e despausa o jogo
			_encerrar_fala()


func _atualizar_fala() -> void:
	# Pega o dicionário com os dados da fala atual (nome e texto) baseado no índice
	var fala_atual = dialogue_lines[current_line_index]
	# Atualiza o Label do nome do personagem no jogo
	name_text.text = fala_atual["nome"]
	# Atualiza o Label com o texto do diálogo
	dialogue_text.text = fala_atual["texto"]
	# Reseta para começar a ler a nova fala
	dialogue_text.lines_skipped = 0


func _encerrar_fala() -> void:
	#dialogo nao esta ativo
	is_dialogue_active = false 
	dialogue_box.visible = false #caixa de texto desaparece
	get_tree().paused = false #despausa o jogo
