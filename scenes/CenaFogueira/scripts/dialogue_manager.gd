extends CanvasLayer

@onready var dialogue_box: Control = $DialogueBox
@onready var dialogue_text: Label = $DialogueBox/DialogueText
@onready var name_text: Label = $DialogueBox/NameText

#nome dos personagens; substituir depois
var character_names = {
	"Lena" : "Lena",
	"P1" : "Personagem 1",
	"P2" : "Personagem 2",
	"P3" : "Personagem 3"
}

# Dialogos de cada personagem; adicionar dialogos aqui
var character_dialogues = {
	"Lena" : [
		"Frase Lena"
	],
	"P1" : [
		"Frase P1", "Outra Frase P1"
	],
	"P2" : [
		"Frase P2"
	],
	"P3" : [
		"Frase P3"
	]
}

var dialogue_lines = []
var current_line_index: int = 0 #indica o dialogo atual
var is_dialogue_active: bool = false 

func _ready() -> void:
	dialogue_box.visible = false #caixa de texto invisível de inicio.
	

func start_dialogue(character_id: String) -> void: #envia como parametro o personagem selecionado na cena
	get_tree().paused = true #pausa o jogo enquanto o dialogo acontece
	dialogue_lines = character_dialogues[character_id]
	
	name_text.text = character_names.get(character_id, character_id)
	
	current_line_index = 0
	is_dialogue_active = true
	dialogue_box.visible = true #caixa de texto aparece
	dialogue_text.text = dialogue_lines[current_line_index] 
	
func _input(event):
	#dialogo não está ativado
	if not is_dialogue_active: #verifica se o dialogo está ativo
		return
	#se estiver ativo, espera o jogador apertar o botão esquerdo do mouse para passar a fala
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance_dialogue() 
		
func advance_dialogue():
	if current_line_index < dialogue_lines.size() - 1:
		current_line_index += 1
		dialogue_text.text = dialogue_lines[current_line_index]
	else:
		get_tree().paused = false #despausa o jogo
		is_dialogue_active = false 
		dialogue_box.visible = false #caixa de texto desaparece
