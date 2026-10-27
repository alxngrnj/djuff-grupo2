extends Node
## Cena de batalha por turnos com action commands (estilo Paper Mario).
##
## Não há menu de ações: cada ação está ligada a um botão (A/B/X/Y), escolhido
## antes no menu do personagem (PlayerData.slots). No turno do jogador, basta
## apertar o botão da ação. Esquerda/direita trocam o alvo.
##
## Tudo é montado por código; a cena battle.tscn só tem este script.

signal battle_finished(result: String)
signal action_chosen(action: BattleAction)

enum State { BUSY, WAIT_PLAYER }

const PLAYER_TEXTURE := "res://assets/mystic_woods_free_2.2/sprites/characters/player.png"
const SLIME_TEXTURE := "res://assets/mystic_woods_free_2.2/sprites/characters/slime.png"

# nome: [linha no spritesheet, qtd de frames, fps, loop]
const PLAYER_ANIMS := {
	"idle": [1, 6, 6.0, true],
	"move": [4, 6, 12.0, true],
	"attack": [7, 4, 8.0, false],
	"death": [9, 3, 5.0, false],
}
const SLIME_ANIMS := {
	"idle": [1, 4, 6.0, true],
	"move": [4, 6, 10.0, true],
	"attack": [7, 7, 10.0, false],
	"hurt": [10, 3, 8.0, false],
	"death": [12, 5, 8.0, false],
}

const SWORD_HIT_TIME := 0.125 # frame 1 da animação de ataque a 8 fps
const FP_REGEN_PER_TURN := 1
const DEATH_TIME := 0.95

const SLOT_COLOR := Color(0.05, 0.07, 0.12, 0.85)
const BUTTON_COLORS := {
	"battle_btn_a": Color(0.30, 0.69, 0.31),
	"battle_btn_b": Color(0.90, 0.22, 0.21),
	"battle_btn_x": Color(0.12, 0.53, 0.90),
	"battle_btn_y": Color(0.99, 0.85, 0.21),
}

var encounter: BattleEncounter = null
var player: Battler = null
var enemies: Array[Battler] = []

var _state: State = State.BUSY
var _target_index: int = 0
var _current_button: String = ""
var _vp: Vector2 = Vector2(640.0, 360.0)
var _ground_y: float = 240.0

var _canvas: CanvasLayer
var _stage: Node2D
var _hud: Control
var _command: ActionCommand
var _cursor: Polygon2D
var _fade_rect: ColorRect
var _banner: Label
var _target_label: Label
var _hp_label: Label
var _fp_label: Label
var _hp_fill: ColorRect
var _fp_fill: ColorRect
var _slots: Dictionary = {}
var _charge_tween: Tween = null


## Chame ANTES de adicionar a cena à árvore.
func setup(new_encounter: BattleEncounter) -> void:
	encounter = new_encounter


func _ready() -> void:
	if encounter == null:
		# Rodando a cena sozinha (F6): encontro de teste.
		encounter = BattleEncounter.new()
		encounter.enemy_ids = ["slime", "slime", "slime_red"]
	_vp = get_viewport().get_visible_rect().size
	_ground_y = _vp.y * 0.66
	_build_layers()
	_build_hud()
	_spawn_player()
	_spawn_enemies()
	_refresh_hud()
	_run_battle()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# ===========================================================================
# Fluxo principal
# ===========================================================================
func _run_battle() -> void:
	await _intro()
	var result := "victory"
	while true:
		await _player_turn()
		if _alive_enemies().is_empty():
			result = "victory"
			break
		await _enemy_turn()
		if not player.is_alive():
			result = "defeat"
			break
	await _outro(result)
	_finish(result)


func _intro() -> void:
	_fade_rect.modulate.a = 1.0
	for e in enemies:
		e.position.x = _vp.x + 30.0
	_fade(0.0, 0.4)
	for e in enemies:
		e.move_to(e.home_position, 0.6)
		await _wait(0.12)
	await _wait(0.6)
	for e in enemies:
		e.play_anim("idle")
	_show_banner("BATALHA!", Color.WHITE)
	await _wait(0.9)
	_hide_banner()


func _outro(result: String) -> void:
	_state = State.BUSY
	_update_slots()
	_update_target_label()
	if result == "victory":
		player.play_anim("idle")
		_show_banner("VITÓRIA!", Color.GOLD)
	else:
		await player.die(false)
		_show_banner("DERROTA...", Color(1.0, 0.4, 0.4))
	await _wait(1.4)
	await _fade(1.0, 0.4)


func _finish(result: String) -> void:
	PlayerData.hp = player.hp
	PlayerData.fp = player.fp
	Engine.time_scale = 1.0
	battle_finished.emit(result)
	if get_tree().current_scene == self:
		# Cena rodando sozinha (F6): reinicia para testar de novo.
		await _wait(0.3)
		PlayerData.heal_full()
		get_tree().reload_current_scene()


# ===========================================================================
# Turno do jogador
# ===========================================================================
func _player_turn() -> void:
	player.fp = mini(player.fp + FP_REGEN_PER_TURN, player.max_fp)
	_refresh_hud()
	var action: BattleAction = await _wait_for_action()
	await _execute_action(action)


func _wait_for_action() -> BattleAction:
	_state = State.WAIT_PLAYER
	_update_slots()
	_update_target_label()
	var chosen: BattleAction = await action_chosen
	_state = State.BUSY
	_update_slots()
	_update_target_label()
	return chosen


func _unhandled_input(event: InputEvent) -> void:
	if _state != State.WAIT_PLAYER:
		return
	if event.is_action_pressed("ui_left"):
		_change_target(-1)
	elif event.is_action_pressed("ui_right"):
		_change_target(1)
	else:
		for btn: String in PlayerData.BUTTONS:
			if event.is_action_pressed(btn):
				_try_action(btn)
				break


func _try_action(btn: String) -> void:
	var action: BattleAction = PlayerData.get_action_for(btn)
	if action == null:
		return
	if action.fp_cost > player.fp:
		_pulse_slot(btn, Color(0.9, 0.2, 0.2))
		player.float_text("Sem FP!", Color(1.0, 0.5, 0.5))
		return
	_current_button = btn
	_pulse_slot(btn, Color(1.0, 1.0, 0.6))
	get_viewport().set_input_as_handled()
	action_chosen.emit(action)


func _change_target(dir: int) -> void:
	var alive := _alive_enemies()
	if alive.size() <= 1:
		return
	_target_index = posmod(_target_index + dir, alive.size())
	_update_target_label()


func _execute_action(action: BattleAction) -> void:
	player.fp -= action.fp_cost
	_refresh_hud()
	_command.set_buttons([_current_button])
	match action.style:
		BattleAction.Style.JUMP:
			await _do_jump(action)
		BattleAction.Style.MELEE:
			await _do_melee(action)
		BattleAction.Style.RANGED:
			await _do_ranged(action)
		BattleAction.Style.SUPPORT:
			await _do_support(action)
	player.play_anim("idle")


# --- Pulo: SYNC (aperta ao pousar) ------------------------------------------
func _do_jump(action: BattleAction) -> void:
	var target := _selected_enemy()
	if target == null:
		return
	await player.move_to(target.position + Vector2(-64.0, 0.0), 0.45)
	player.hold_pose("attack", 0)
	var land := target.position + Vector2(0.0, -target.head_height)
	# Sem await: o pulo acontece enquanto o command espera o aperto.
	player.hop_to(land, 0.55, 56.0, true)
	var result: ActionCommand.Resultado = await _command.timing_sincronizado(player.impact)
	_hit_enemy(target, _player_damage(action, result, target), result)
	await _hitstop(0.05)
	await player.hop_to(player.home_position, 0.5, 30.0)
	player.play_anim("idle")
	await _resolve_deaths()


# --- Espada: BAR (cursor na zona dourada) -----------------------------------
func _do_melee(action: BattleAction) -> void:
	var target := _selected_enemy()
	if target == null:
		return
	await player.move_to(target.position + Vector2(-34.0, 0.0), 0.4)
	player.play_anim("idle")
	var result: ActionCommand.Resultado = await _command.timing_barra(1.1, 0.72, 0.045, 0.11)
	player.play_anim("attack")
	await _wait(SWORD_HIT_TIME)
	_hit_enemy(target, _player_damage(action, result, target), result)
	await _hitstop(0.05)
	await _wait(0.35)
	await player.move_to(player.home_position, 0.4)
	player.play_anim("idle")
	await _resolve_deaths()


# --- Rajada: MASH em todos os inimigos --------------------------------------
func _do_ranged(action: BattleAction) -> void:
	var targets := _alive_enemies()
	if targets.is_empty():
		return
	player.hold_pose("attack", 0)
	_start_charge_effect()
	var result: ActionCommand.Resultado = await _command.apertar_varias(2.0, 12)
	_stop_charge_effect()
	player.play_anim("attack")
	await _wait(SWORD_HIT_TIME)
	for t in targets:
		_fire_projectile(t)
	await _wait(0.32)
	for t in targets:
		_hit_enemy(t, _player_damage(action, result, t), result)
	await _hitstop(0.06)
	await _wait(0.4)
	player.play_anim("idle")
	await _resolve_deaths()


# --- Curar: BAR em si mesmo -------------------------------------------------
func _do_support(action: BattleAction) -> void:
	player.play_anim("idle")
	await _wait(0.25)
	var result: ActionCommand.Resultado = await _command.timing_barra(1.4, 0.7, 0.07, 0.16)
	var amount := action.power + _bonus(result)
	player.heal(amount)
	player.flash(Color(0.5, 1.0, 0.6), 0.5)
	player.float_text("+%d" % amount, Color(0.5, 1.0, 0.6))
	await _wait(0.7)


# ===========================================================================
# Turno dos inimigos
# ===========================================================================
func _enemy_turn() -> void:
	await _wait(0.3)
	for e in _alive_enemies():
		if not player.is_alive():
			break
		await _enemy_attack(e)
		await _wait(0.2)


func _enemy_attack(e: Battler) -> void:
	var contact := player.position + Vector2(26.0, 0.0)
	_command.set_buttons(PlayerData.BUTTONS) # qualquer botão de batalha defende
	_command.posicao_alerta = e.position + Vector2(0.0, -(e.head_height + 20.0))
	_command.piscar_alerta(e.data.windup)
	await e.squash(e.data.windup)
	# Sem await: o salto acontece enquanto o jogador tenta defender.
	e.hop_attack(contact)
	var guard: ActionCommand.Resultado = await _command.defender(e.impact, 0.22, 0.07)

	var damage := maxi(0, e.attack - PlayerData.defense)
	match guard:
		ActionCommand.Resultado.PERFEITO:
			damage = 0
		ActionCommand.Resultado.BOM:
			damage = maxi(0, damage - 1)
	_hit_player(damage, guard)
	await _hitstop(0.06)

	await _wait(0.25)
	await e.hop_to(e.home_position, 0.35, 26.0)
	e.play_anim("idle")


# ===========================================================================
# Dano e efeitos
# ===========================================================================
func _bonus(result: ActionCommand.Resultado) -> int:
	match result:
		ActionCommand.Resultado.PERFEITO:
			return 2
		ActionCommand.Resultado.BOM:
			return 1
	return 0


func _player_damage(action: BattleAction, result: ActionCommand.Resultado, target: Battler) -> int:
	return maxi(1, action.power + _bonus(result) + PlayerData.attack_bonus - target.defense)


func _hit_enemy(target: Battler, damage: int, result: ActionCommand.Resultado) -> void:
	target.take_damage(damage)
	target.play_hit()
	var color := Color.WHITE
	if result == ActionCommand.Resultado.PERFEITO:
		color = Color(1.0, 0.92, 0.35)
	target.float_text(str(damage), color)
	_shake(2.0 + damage * 0.6, 0.18)


func _hit_player(damage: int, guard: ActionCommand.Resultado) -> void:
	if guard == ActionCommand.Resultado.PERFEITO:
		player.flash(Color(1.0, 1.0, 0.7), 0.3)
		player.float_text("SUPER GUARDA!", Color(1.0, 0.92, 0.35))
		_shake(1.5, 0.1)
		return
	player.take_damage(damage)
	player.play_hit()
	if guard == ActionCommand.Resultado.BOM:
		player.float_text("GUARDA -%d" % damage, Color(0.6, 1.0, 0.6))
	else:
		player.float_text("-%d" % damage, Color(1.0, 0.4, 0.4))
	_shake(2.0 + damage * 0.8, 0.2)


func _resolve_deaths() -> void:
	var dying: Array[Battler] = []
	for e in enemies:
		if not e.is_alive():
			dying.append(e)
	if dying.is_empty():
		return
	for e in dying:
		enemies.erase(e)
		e.die()
	await _wait(DEATH_TIME)


func _shake(strength: float, duration: float) -> void:
	var tw := create_tween()
	var steps := 6
	for i in steps:
		var off := Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		tw.tween_property(_stage, "position", off, duration / steps)
	tw.tween_property(_stage, "position", Vector2.ZERO, 0.03)


func _hitstop(duration: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func _start_charge_effect() -> void:
	_stop_charge_effect()
	_charge_tween = create_tween().set_loops()
	_charge_tween.tween_property(player.sprite, "modulate", Color(1.0, 0.9, 0.3), 0.12)
	_charge_tween.tween_property(player.sprite, "modulate", Color.WHITE, 0.12)


func _stop_charge_effect() -> void:
	if _charge_tween != null:
		_charge_tween.kill()
		_charge_tween = null
	if player != null and player.sprite != null:
		player.sprite.modulate = Color.WHITE


func _fire_projectile(target: Battler) -> void:
	var shot := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 12:
		var angle := TAU * i / 12.0
		points.append(Vector2(cos(angle), sin(angle)) * 5.0)
	shot.polygon = points
	shot.color = Color(1.0, 0.65, 0.15)
	shot.z_index = 70
	shot.position = player.position + Vector2(14.0, -player.head_height * 0.6)
	_stage.add_child(shot)
	var end := target.position + Vector2(0.0, -target.head_height * 0.5)
	var tw := shot.create_tween()
	tw.tween_property(shot, "position", end, 0.3)
	tw.tween_callback(shot.queue_free)


# ===========================================================================
# Utilidades
# ===========================================================================
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _alive_enemies() -> Array[Battler]:
	var result: Array[Battler] = []
	for e in enemies:
		if e.is_alive():
			result.append(e)
	return result


func _selected_enemy() -> Battler:
	var alive := _alive_enemies()
	if alive.is_empty():
		return null
	_target_index = clampi(_target_index, 0, alive.size() - 1)
	return alive[_target_index]


func _fade(to_alpha: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade_rect, "modulate:a", to_alpha, duration)
	await tw.finished


func _process(_delta: float) -> void:
	if _cursor == null:
		return
	var target: Battler = null
	if _state == State.WAIT_PLAYER:
		target = _selected_enemy()
	_cursor.visible = target != null
	if target != null:
		var bob := sin(Time.get_ticks_msec() / 1000.0 * 7.0) * 2.5
		_cursor.position = target.position + Vector2(0.0, -(target.head_height + 14.0) + bob)


# ===========================================================================
# Montagem da cena (tudo por código)
# ===========================================================================
func _build_layers() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 20
	add_child(_canvas)

	var horizon := _vp.y * 0.42
	var sky := ColorRect.new()
	sky.color = Color(0.60, 0.82, 0.94)
	sky.size = Vector2(_vp.x, horizon)
	_canvas.add_child(sky)
	var grass := ColorRect.new()
	grass.color = Color(0.36, 0.64, 0.30)
	grass.position = Vector2(0.0, horizon)
	grass.size = Vector2(_vp.x, _vp.y - horizon)
	_canvas.add_child(grass)
	var edge := ColorRect.new()
	edge.color = Color(0.25, 0.48, 0.22)
	edge.position = Vector2(0.0, horizon)
	edge.size = Vector2(_vp.x, 3.0)
	_canvas.add_child(edge)
	var lane := ColorRect.new()
	lane.color = Color(0.42, 0.70, 0.35)
	lane.position = Vector2(0.0, _ground_y - 14.0)
	lane.size = Vector2(_vp.x, 44.0)
	_canvas.add_child(lane)

	_stage = Node2D.new()
	_stage.y_sort_enabled = true
	_canvas.add_child(_stage)

	_cursor = Polygon2D.new()
	_cursor.polygon = PackedVector2Array([Vector2(-6.0, -9.0), Vector2(6.0, -9.0), Vector2(0.0, 0.0)])
	_cursor.color = Color(1.0, 0.9, 0.2)
	_cursor.z_index = 60
	_cursor.visible = false
	_stage.add_child(_cursor)

	_hud = Control.new()
	_hud.size = _vp
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_hud)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.size = _vp
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_fade_rect)

	# O command precisa ficar numa camada acima da batalha.
	_command = ActionCommand.new()
	_command.camada = 25
	add_child(_command)


func _build_hud() -> void:
	var panel := ColorRect.new()
	panel.color = Color(0.0, 0.0, 0.0, 0.55)
	panel.position = Vector2(6.0, 6.0)
	panel.size = Vector2(128.0, 46.0)
	_hud.add_child(panel)
	_hp_label = _make_label(panel, "", 11, Color.WHITE, Vector2(6.0, 1.0))
	_hp_fill = _make_bar(panel, Vector2(6.0, 17.0), 116.0, Color(0.9, 0.25, 0.25))
	_fp_label = _make_label(panel, "", 11, Color.WHITE, Vector2(6.0, 23.0))
	_fp_fill = _make_bar(panel, Vector2(6.0, 39.0), 116.0, Color(0.3, 0.6, 1.0))

	# Os 4 botões de ação (parte de baixo)
	var count := PlayerData.BUTTONS.size()
	var gap := 6.0
	var width := (_vp.x - 12.0 - gap * (count - 1)) / count
	for i in count:
		var btn: String = PlayerData.BUTTONS[i]
		var slot := ColorRect.new()
		slot.position = Vector2(6.0 + i * (width + gap), _vp.y - 40.0)
		slot.size = Vector2(width, 34.0)
		slot.color = SLOT_COLOR
		_hud.add_child(slot)
		var strip := ColorRect.new()
		strip.color = BUTTON_COLORS[btn]
		strip.size = Vector2(4.0, 34.0)
		slot.add_child(strip)
		var label := _make_label(slot, "", 11, Color.WHITE, Vector2(9.0, 1.0))
		_slots[btn] = {"panel": slot, "label": label}

	_target_label = _make_label(_hud, "", 12, Color.WHITE, Vector2(0.0, _vp.y - 60.0))
	_target_label.custom_minimum_size = Vector2(_vp.x, 0.0)
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_banner = _make_label(_hud, "", 30, Color.WHITE, Vector2(0.0, _vp.y * 0.28))
	_banner.custom_minimum_size = Vector2(_vp.x, 0.0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.modulate.a = 0.0


func _make_label(parent: Node, text: String, font_size: int, color: Color, pos: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	parent.add_child(label)
	return label


func _make_bar(parent: Node, pos: Vector2, width: float, color: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.7)
	bg.position = pos
	bg.size = Vector2(width, 5.0)
	parent.add_child(bg)
	var fill := ColorRect.new()
	fill.color = color
	fill.size = Vector2(width, 5.0)
	fill.set_meta("full_width", width)
	bg.add_child(fill)
	return fill


func _set_bar(fill: ColorRect, ratio: float) -> void:
	var full: float = fill.get_meta("full_width")
	fill.size.x = full * clampf(ratio, 0.0, 1.0)


func _refresh_hud() -> void:
	if player == null:
		return
	_hp_label.text = "HP  %d / %d" % [player.hp, player.max_hp]
	_set_bar(_hp_fill, float(player.hp) / float(maxi(player.max_hp, 1)))
	_fp_label.text = "FP  %d / %d" % [player.fp, player.max_fp]
	_set_bar(_fp_fill, float(player.fp) / float(maxi(player.max_fp, 1)))
	_update_slots()


func _update_slots() -> void:
	for btn: String in PlayerData.BUTTONS:
		var entry: Dictionary = _slots[btn]
		var label: Label = entry["label"]
		var panel: ColorRect = entry["panel"]
		var action: BattleAction = PlayerData.get_action_for(btn)
		var head := "[%s] " % PlayerData.button_label(btn)
		if action == null:
			label.text = head + "-\n" + PlayerData.button_hint(btn)
			panel.modulate.a = 0.3
			continue
		var cost := ""
		if action.fp_cost > 0:
			cost = "   %d FP" % action.fp_cost
		label.text = head + action.display_name + "\n" + PlayerData.button_hint(btn) + cost
		var usable := player != null and action.fp_cost <= player.fp
		if _state == State.WAIT_PLAYER and usable:
			panel.modulate.a = 1.0
		else:
			panel.modulate.a = 0.45


func _pulse_slot(btn: String, color: Color) -> void:
	var entry: Dictionary = _slots[btn]
	var panel: ColorRect = entry["panel"]
	panel.color = color
	var tw := create_tween()
	tw.tween_property(panel, "color", SLOT_COLOR, 0.25)


func _update_target_label() -> void:
	var t := _selected_enemy()
	if _state != State.WAIT_PLAYER or t == null:
		_target_label.text = ""
		return
	var info := "%s   %d/%d" % [t.display_name, t.hp, t.max_hp]
	if _alive_enemies().size() > 1:
		info = "<   " + info + "   >"
	_target_label.text = info


func _show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.15)


func _hide_banner() -> void:
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 0.0, 0.25)


# ===========================================================================
# Personagens
# ===========================================================================
func _make_frames(texture_path: String, frame_size: int, anims: Dictionary) -> SpriteFrames:
	var texture: Texture2D = load(texture_path)
	return SpriteSheet.build_frames(texture, frame_size, anims)


func _spawn_player() -> void:
	player = Battler.new()
	player.display_name = "Herói"
	player.is_player = true
	player.max_hp = PlayerData.max_hp
	player.hp = clampi(PlayerData.hp, 1, PlayerData.max_hp)
	player.max_fp = PlayerData.max_fp
	player.fp = PlayerData.fp
	player.defense = PlayerData.defense
	player.head_height = 21.0
	player.home_position = Vector2(_vp.x * 0.2, _ground_y + 6.0)
	player.position = player.home_position
	_stage.add_child(player)
	player.setup_sprite(_make_frames(PLAYER_TEXTURE, 48, PLAYER_ANIMS), -19.0, false)
	player.hp_changed.connect(_refresh_hud)


func _spawn_enemies() -> void:
	var slime_frames := _make_frames(SLIME_TEXTURE, 32, SLIME_ANIMS)
	var count := encounter.enemy_ids.size()
	for i in count:
		var data: EnemyData = EnemyDatabase.get_enemy(encounter.enemy_ids[i])
		var e := Battler.new()
		e.data = data
		e.display_name = data.display_name
		e.max_hp = data.max_hp
		e.hp = data.max_hp
		e.attack = data.attack
		e.defense = data.defense
		e.head_height = 12.0 * data.sprite_scale
		e.home_position = Vector2(_vp.x * 0.58 + i * 58.0, _ground_y + 6.0 + (i % 2) * 10.0)
		e.position = e.home_position
		_stage.add_child(e)
		e.setup_sprite(slime_frames, -8.0, true, data.tint, data.sprite_scale)
		e.create_hp_bar(28.0, -(e.head_height + 8.0))
		enemies.append(e)
