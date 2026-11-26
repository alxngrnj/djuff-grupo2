extends Node
## Autoload "PlayerData": status de batalha do jogador + configuração dos botões.
##
## Os 4 botões de batalha (A, B, X, Y) são registrados no InputMap por código
## (se você já criou as ações battle_btn_* em Projeto > Mapa de Entrada, as suas
## têm prioridade). Cada botão recebe UMA ação, escolhida no menu do personagem.

signal loadout_changed

const LOADOUT_FILE := "user://loadout.cfg"
const LOADOUT_SECTION := "loadout"

## Ordem em que os botões aparecem na tela.
const BUTTONS: Array[String] = ["battle_btn_a", "battle_btn_b", "battle_btn_x", "battle_btn_y"]

const BUTTON_INFO := {
	"battle_btn_a": {"label": "A", "keys": [KEY_J, KEY_Z], "joy": JOY_BUTTON_A, "hint": "J / Z"},
	"battle_btn_b": {"label": "B", "keys": [KEY_K, KEY_X], "joy": JOY_BUTTON_B, "hint": "K / X"},
	"battle_btn_x": {"label": "X", "keys": [KEY_U, KEY_C], "joy": JOY_BUTTON_X, "hint": "U / C"},
	"battle_btn_y": {"label": "Y", "keys": [KEY_I, KEY_V], "joy": JOY_BUTTON_Y, "hint": "I / V"},
}

# --- Status persistentes entre batalhas ---
var max_hp: int = 20
var hp: int = 20
var max_fp: int = 8
var fp: int = 8
var attack_bonus: int = 0
var defense: int = 0

## Os 4 personagens da party (um por botão A/B/X/Y). Se mover os .tres de pasta, ajuste os caminhos.
const PARTY_PATHS: Array[String] = [
	"res://player_1.tres",
	"res://player_2.tres",
	"res://player_3.tres",
	"res://player_4.tres",
]

var party_data: Array[BattlerData] = []
var party_hp: Array[int] = []
var party_fp: Array[int] = []

## Ações que o jogador já desbloqueou (adicione ids aqui ao dar novas habilidades).
var unlocked_actions: Array[String] = ["jump", "sword", "burst", "heal"]

## botão -> id da ação ("" = botão vazio)
var slots: Dictionary = {}


func _ready() -> void:
	_load_party()
	_register_inputs()
	_set_default_slots()
	load_loadout()


# ---------------------------------------------------------------------------
# Botões / entrada
# ---------------------------------------------------------------------------
func _register_inputs() -> void:
	for btn in BUTTONS:
		if InputMap.has_action(btn):
			continue
		InputMap.add_action(btn, 0.5)
		var info: Dictionary = BUTTON_INFO[btn]
		for key: int in info["keys"]:
			var key_event := InputEventKey.new()
			key_event.physical_keycode = key as Key
			InputMap.action_add_event(btn, key_event)
		var joy_event := InputEventJoypadButton.new()
		joy_event.button_index = int(info["joy"]) as JoyButton
		InputMap.action_add_event(btn, joy_event)

	# Abre o menu do personagem fora da batalha.
	if not InputMap.has_action("character_menu"):
		InputMap.add_action("character_menu", 0.5)
		var tab_event := InputEventKey.new()
		tab_event.physical_keycode = KEY_TAB
		InputMap.action_add_event("character_menu", tab_event)
		var back_event := InputEventJoypadButton.new()
		back_event.button_index = JOY_BUTTON_BACK
		InputMap.action_add_event("character_menu", back_event)


func button_label(btn: String) -> String:
	return str(BUTTON_INFO[btn]["label"])


func button_hint(btn: String) -> String:
	return str(BUTTON_INFO[btn]["hint"])


# ---------------------------------------------------------------------------
# Loadout (qual ação está em qual botão)
# ---------------------------------------------------------------------------
func _set_default_slots() -> void:
	slots.clear()
	for i in BUTTONS.size():
		slots[BUTTONS[i]] = unlocked_actions[i] if i < unlocked_actions.size() else ""


func get_action_id(btn: String) -> String:
	return str(slots.get(btn, ""))


func get_action_for(btn: String) -> BattleAction:
	var id := get_action_id(btn)
	if id == "":
		return null
	return ActionDatabase.get_action(id)


## Coloca a ação no botão. Se ela já estava em outro botão, os dois trocam de lugar.
func assign(btn: String, action_id: String) -> void:
	var previous: String = get_action_id(btn)
	for other: String in BUTTONS:
		if other != btn and get_action_id(other) == action_id and action_id != "":
			slots[other] = previous
	slots[btn] = action_id
	loadout_changed.emit()
	save_loadout()


## Passa para a próxima (dir = 1) ou anterior (dir = -1) ação disponível naquele botão.
func cycle(btn: String, dir: int) -> void:
	var options: Array[String] = [""]
	options.append_array(unlocked_actions)
	var index := options.find(get_action_id(btn))
	if index == -1:
		index = 0
	index = posmod(index + dir, options.size())
	assign(btn, options[index])


func save_loadout() -> void:
	var config := ConfigFile.new()
	for btn in BUTTONS:
		config.set_value(LOADOUT_SECTION, btn, get_action_id(btn))
	config.save(LOADOUT_FILE)


func load_loadout() -> void:
	var config := ConfigFile.new()
	if config.load(LOADOUT_FILE) != OK:
		return
	for btn in BUTTONS:
		var id: String = str(config.get_value(LOADOUT_SECTION, btn, get_action_id(btn)))
		if id == "" or (unlocked_actions.has(id) and ActionDatabase.get_action(id) != null):
			slots[btn] = id


# ---------------------------------------------------------------------------
# Status
# ---------------------------------------------------------------------------
func heal_full() -> void:
	hp = max_hp
	fp = max_fp
	for i in party_data.size():
		party_hp[i] = party_data[i].hp_max
		party_fp[i] = party_data[i].fp_max


## Carrega os 4 BattlerData. Se um arquivo não existir, cria um personagem padrão.
func _load_party() -> void:
	party_data.clear()
	party_hp.clear()
	party_fp.clear()
	for i in PARTY_PATHS.size():
		var d: BattlerData = null
		if ResourceLoader.exists(PARTY_PATHS[i]):
			d = load(PARTY_PATHS[i]) as BattlerData
		if d == null:
			d = BattlerData.new()
			d.nome = "Player %d" % (i + 1)
		party_data.append(d)
		party_hp.append(d.hp_max)
		party_fp.append(d.fp_max)
	max_hp = party_data[0].hp_max
	hp = max_hp
	max_fp = party_data[0].fp_max
	fp = max_fp


func reset_after_defeat() -> void:
	heal_full()
