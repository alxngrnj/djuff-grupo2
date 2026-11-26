extends CanvasLayer
## Menu do personagem (versão simples): escolhe qual ação fica em cada botão de batalha.
##
##   Cima/Baixo ........ escolhe o botão
##   Esquerda/Direita .. troca a ação (ou aperte confirmar para avançar)
##   Esc / Tab ......... fecha
##
## Troque este menu pelo seu: basta chamar PlayerData.assign(botao, id_da_acao)
## ou PlayerData.cycle(botao, 1).

signal closed

var _rows: Dictionary = {}
var _desc: Label
var _status: Label


func _ready() -> void:
	layer = 50
	_build()
	_refresh()
	var first: Button = _rows[PlayerData.BUTTONS[0]]
	first.grab_focus()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Botões de batalha"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)

	for btn: String in PlayerData.BUTTONS:
		var row := Button.new()
		row.custom_minimum_size = Vector2(300.0, 0.0)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.pressed.connect(_on_row_pressed.bind(btn))
		row.focus_entered.connect(_update_desc.bind(btn))
		box.add_child(row)
		_rows[btn] = row

	_desc = Label.new()
	_desc.custom_minimum_size = Vector2(300.0, 40.0)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_desc)

	var hint := Label.new()
	hint.text = "< > troca a ação   |   Esc / Tab fecha"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _refresh() -> void:
	_status.text = "HP %d/%d    FP %d/%d" % [PlayerData.hp, PlayerData.max_hp, PlayerData.fp, PlayerData.max_fp]
	for btn: String in PlayerData.BUTTONS:
		var row: Button = _rows[btn]
		var action: BattleAction = PlayerData.get_action_for(btn)
		var name_text := "(vazio)"
		if action != null:
			name_text = action.display_name
			if action.fp_cost > 0:
				name_text += "  (%d FP)" % action.fp_cost
		row.text = "Botão %s  [%s]    %s" % [PlayerData.button_label(btn), PlayerData.button_hint(btn), name_text]
	var focus := get_viewport().gui_get_focus_owner()
	for btn: String in PlayerData.BUTTONS:
		if _rows[btn] == focus:
			_update_desc(btn)


func _update_desc(btn: String) -> void:
	var action: BattleAction = PlayerData.get_action_for(btn)
	if action == null:
		_desc.text = "Nenhuma ação neste botão."
	else:
		_desc.text = action.description


func _on_row_pressed(btn: String) -> void:
	PlayerData.cycle(btn, 1)
	_refresh()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("character_menu"):
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()
		return
	var dir := 0
	if event.is_action_pressed("ui_left"):
		dir = -1
	elif event.is_action_pressed("ui_right"):
		dir = 1
	if dir == 0:
		return
	var focus := get_viewport().gui_get_focus_owner()
	for btn: String in PlayerData.BUTTONS:
		if _rows[btn] == focus:
			PlayerData.cycle(btn, dir)
			_refresh()
			get_viewport().set_input_as_handled()
			return
