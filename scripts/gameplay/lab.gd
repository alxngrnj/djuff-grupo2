extends Node2D

const NEXT_SCENE := "res://scenes/world.tscn"

var friends_called: Array[String] = []
var supplies_collected := false
var mission_read := false
var active_interaction := ""
var contacts_box: VBoxContainer
var computer_navigation: HBoxContainer
var computer_back_button: Button
var close_button: Button
var prompt: Label
var player: CharacterBody2D
var interactables: Dictionary
@onready var dialogue_manager: DialogueManager = $DialogueManager

func _ready() -> void:
	player = $PlayerLena
	_register_interactables()
	_create_interface()

func _process(_delta: float) -> void:
	if active_interaction != "":
		return

	var closest_name := ""
	var closest_distance := INF
	for object_name in interactables:
		if not _is_interactable_available(object_name):
			continue
		var distance: float = player.global_position.distance_to(interactables[object_name].position)
		if distance < closest_distance:
			closest_distance = distance
			closest_name = object_name

	if closest_distance <= 100.0:
		prompt.text = "Pressione E ou Espaço para interagir: " + interactables[closest_name].label
		prompt.visible = true
	else:
		prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if active_interaction != "":
		return
	if event.is_action_pressed("interagir"):
		var target := _nearby_interactable()
		if target != "":
			_interact(target)

func _nearby_interactable() -> String:
	var closest_name := ""
	var closest_distance := 100.0
	for object_name in interactables:
		if not _is_interactable_available(object_name):
			continue
		var distance: float = player.global_position.distance_to(interactables[object_name].position)
		if distance <= closest_distance:
			closest_distance = distance
			closest_name = object_name
	return closest_name

func _is_interactable_available(object_name: String) -> bool:
	if object_name == "ingredients":
		return mission_read and friends_called.size() == 3
	return true

func _register_interactables() -> void:
	for object_node in $Interactables.get_children():
		if object_node is Sprite2D and object_node.has_meta("interaction_label"):
			interactables[object_node.name.to_lower()] = {
				"position": object_node.position,
				"label": object_node.get_meta("interaction_label"),
				"sprite": object_node
			}

func _create_interface() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	prompt = Label.new()
	prompt.position = Vector2(250, 670)
	prompt.size = Vector2(780, 35)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.visible = false
	layer.add_child(prompt)

	contacts_box = VBoxContainer.new()
	contacts_box.position = Vector2(25, 210)
	contacts_box.size = Vector2(730, 120)
	dialogue_manager.dialogue_box.add_child(contacts_box)

	computer_navigation = HBoxContainer.new()
	computer_navigation.position = Vector2(25, 210)
	computer_navigation.size = Vector2(730, 45)
	dialogue_manager.dialogue_box.add_child(computer_navigation)

	var quest_button := Button.new()
	quest_button.text = "Pedido da missão"
	quest_button.pressed.connect(_show_quest)
	computer_navigation.add_child(quest_button)

	var contacts_button := Button.new()
	contacts_button.text = "Contatos"
	contacts_button.pressed.connect(_show_contacts)
	computer_navigation.add_child(contacts_button)

	computer_back_button = Button.new()
	computer_back_button.text = "Voltar ao computador"
	computer_back_button.position = Vector2(25, 210)
	computer_back_button.size = Vector2(250, 45)
	computer_back_button.pressed.connect(_show_computer)
	computer_back_button.visible = false
	dialogue_manager.dialogue_box.add_child(computer_back_button)

	close_button = Button.new()
	close_button.text = "Fechar (Esc)"
	close_button.position = Vector2(570, 325)
	close_button.size = Vector2(180, 45)
	close_button.pressed.connect(_close_interaction)
	dialogue_manager.dialogue_box.add_child(close_button)

func _interact(target: String) -> void:
	match target:
		"computer":
			_show_computer()
		"ingredients":
			_collect_supplies()
		"portrait":
			var portrait_position: Vector2 = interactables["computer"].position + Vector2(0, 70)
			interactables["portrait"].sprite.position = portrait_position
			interactables["portrait"].position = portrait_position
			$Interactables/PortraitLabel.position = portrait_position + Vector2(-80, 55)
			interactables.erase("portrait")
			_show_message("Porta-retrato", "Uma lembrança dos seus amigos. É hora de reunir todos para a missão.")
		"door":
			_use_door()

func _show_computer() -> void:
	active_interaction = "computer"
	dialogue_manager.show_interaction("Computador", "Selecione uma opção para continuar.")
	contacts_box.hide()
	computer_navigation.show()
	computer_back_button.hide()
	close_button.show()
	prompt.visible = false

func _show_quest() -> void:
	mission_read = true
	dialogue_manager.update_interaction("Pedido da missão", "Reúna Kai, Sebastião e Sera. Depois, pegue os suprimentos na mesa de ingredientes.")
	contacts_box.hide()
	computer_navigation.hide()
	computer_back_button.position = Vector2(25, 210)
	computer_back_button.show()

func _show_contacts() -> void:
	dialogue_manager.update_interaction("Contatos", "Escolha um contato para convidá-lo para a missão:")
	computer_navigation.hide()
	computer_back_button.position = Vector2(25, 325)
	computer_back_button.show()
	contacts_box.show()
	for child in contacts_box.get_children():
		child.queue_free()
	for contact in ["Kai", "Sebastião", "Sera"]:
		var button := Button.new()
		button.text = contact + (" (convidado)" if contact in friends_called else " - convidar para a quest")
		button.disabled = contact in friends_called
		button.pressed.connect(_invite_friend.bind(contact))
		contacts_box.add_child(button)

func _invite_friend(contact: String) -> void:
	if contact not in friends_called:
		friends_called.append(contact)
	_show_contacts()

func _collect_supplies() -> void:
	if supplies_collected:
		_show_message("Mesa de ingredientes", "Você já pegou todos os suprimentos.")
		return
	if not mission_read:
		_show_message("Mesa de ingredientes", "Leia o pedido da missão no computador antes de pegar os suprimentos.")
		return
	if friends_called.size() < 3:
		_show_message("Mesa de ingredientes", "Ainda falta chamar todos os amigos antes de preparar os suprimentos.")
		return
	supplies_collected = true
	_show_message("Mesa de ingredientes", "Você separou os ingredientes necessários para a missão.")

func _use_door() -> void:
	if friends_called.size() < 3 or not supplies_collected:
		_show_message("Porta", "A porta está fechada. Chame os três amigos e pegue os suprimentos.")
		return
	get_tree().change_scene_to_file(NEXT_SCENE)

func _show_message(title: String, message: String) -> void:
	active_interaction = "message"
	dialogue_manager.show_interaction(title, message)
	contacts_box.hide()
	computer_navigation.hide()
	computer_back_button.hide()
	close_button.show()
	prompt.visible = false

func _close_interaction() -> void:
	active_interaction = ""
	dialogue_manager.close_interaction()

func _input(event: InputEvent) -> void:
	if active_interaction != "" and event.is_action_pressed("ui_cancel"):
		_close_interaction()
