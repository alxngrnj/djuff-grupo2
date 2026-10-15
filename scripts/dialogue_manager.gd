extends CanvasLayer

@onready var dialogue_box: Control = $DialogueBox
@onready var dialogue_text: Label = $DialogueBox/DialogueText

# Dialogos de cada personagem
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
	dialogue_box.visible = false 
	
	start_dialogue("P1")

func start_dialogue(character_id: String) -> void: #envia como parametro o personagem selecionado na cena
	get_tree().paused = true
	dialogue_lines = character_dialogues[character_id]
	
	current_line_index = 0
	is_dialogue_active = true
	dialogue_box.visible = true
	dialogue_text.text = dialogue_lines[current_line_index]
	
func _input(event):
	if not is_dialogue_active:
		return
	if event.is_action_pressed("ui_accept"):
		advance_dialogue()
		
func advance_dialogue():
	if current_line_index < dialogue_lines.size() - 1:
		current_line_index += 1
		dialogue_text.text = dialogue_lines[current_line_index]
	else:
		get_tree().paused = false
		is_dialogue_active = false
		dialogue_box.visible = false
