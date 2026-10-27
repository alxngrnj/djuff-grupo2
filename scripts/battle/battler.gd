class_name Battler
extends Node2D
## Um combatente (jogador ou inimigo): sprite, vida, movimentos e efeitos visuais.
## A origem do nó fica nos PÉS do personagem.

## Emitido no instante em que um golpe/pouso "acerta" (usado pelos action commands).
signal impact
signal hp_changed

# Slime: agachar (2 frames) -> ar (3 frames) -> pouso (2 frames), a 10 fps.
const CROUCH_TIME := 0.2
const AIR_TIME := 0.3
const LAND_TIME := 0.2

var display_name: String = ""
var is_player: bool = false
var max_hp: int = 1
var hp: int = 1
var max_fp: int = 0
var fp: int = 0
var attack: int = 1
var defense: int = 0
var data: EnemyData = null
## Distância dos pés até o topo da cabeça (onde o jogador "pousa" no pulo).
var head_height: float = 20.0
var home_position: Vector2 = Vector2.ZERO
var default_face_left: bool = false
var is_dying: bool = false
var sprite: AnimatedSprite2D = null

var _tint: Color = Color.WHITE
var _base_scale: Vector2 = Vector2.ONE
var _bar_width: float = 28.0
var _bar_bg: ColorRect = null
var _bar_fill: ColorRect = null


# ---------------------------------------------------------------------------
# Montagem
# ---------------------------------------------------------------------------
func setup_sprite(frames: SpriteFrames, offset_y: float, face_left: bool,
		tint: Color = Color.WHITE, sprite_scale: float = 1.0) -> void:
	default_face_left = face_left
	_tint = tint
	_base_scale = Vector2(sprite_scale, sprite_scale)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.offset = Vector2(0.0, offset_y)
	sprite.flip_h = face_left
	sprite.modulate = tint
	sprite.scale = _base_scale
	add_child(sprite)
	play_anim("idle")


func create_hp_bar(width: float, y: float) -> void:
	_bar_width = width
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.0, 0.0, 0.0, 0.75)
	_bar_bg.position = Vector2(-width / 2.0 - 1.0, y - 1.0)
	_bar_bg.size = Vector2(width + 2.0, 6.0)
	add_child(_bar_bg)
	_bar_fill = ColorRect.new()
	_bar_fill.position = Vector2(1.0, 1.0)
	_bar_fill.size = Vector2(width, 4.0)
	_bar_bg.add_child(_bar_fill)
	_update_bar()


func _update_bar() -> void:
	if _bar_fill == null:
		return
	var ratio := clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	_bar_fill.size.x = _bar_width * ratio
	if ratio > 0.5:
		_bar_fill.color = Color(0.3, 0.85, 0.3)
	elif ratio > 0.25:
		_bar_fill.color = Color(0.95, 0.8, 0.2)
	else:
		_bar_fill.color = Color(0.9, 0.25, 0.25)


# ---------------------------------------------------------------------------
# Animação
# ---------------------------------------------------------------------------
func is_alive() -> bool:
	return hp > 0


func play_anim(anim_name: String) -> void:
	if sprite == null or not sprite.sprite_frames.has_animation(anim_name):
		return
	sprite.animation = anim_name
	sprite.frame = 0
	sprite.play(anim_name)


## Congela a animação num frame (ex.: pose de pulo).
func hold_pose(anim_name: String, frame: int) -> void:
	if sprite == null or not sprite.sprite_frames.has_animation(anim_name):
		return
	sprite.animation = anim_name
	sprite.frame = frame
	sprite.stop()


func anim_duration(anim_name: String) -> float:
	var frames: SpriteFrames = sprite.sprite_frames
	if not frames.has_animation(anim_name):
		return 0.0
	return float(frames.get_frame_count(anim_name)) / frames.get_animation_speed(anim_name)


func _face_towards(x: float) -> void:
	if sprite != null and absf(x - position.x) > 1.0:
		sprite.flip_h = x < position.x


func restore_facing() -> void:
	if sprite != null:
		sprite.flip_h = default_face_left


# ---------------------------------------------------------------------------
# Movimento (todas são corrotinas: use await)
# ---------------------------------------------------------------------------
func move_to(target: Vector2, duration: float, anim_name: String = "move") -> void:
	_face_towards(target.x)
	play_anim(anim_name)
	var tw := create_tween()
	tw.tween_property(self, "position", target, duration)
	await tw.finished
	restore_facing()


## Pulo em arco. Se emit_impact for true, emite `impact` ao pousar.
func hop_to(target: Vector2, duration: float, height: float, emit_impact: bool = false) -> void:
	_face_towards(target.x)
	var start := position
	var tw := create_tween()
	tw.tween_method(_hop_step.bind(start, target, height), 0.0, 1.0, duration)
	await tw.finished
	position = target
	restore_facing()
	if emit_impact:
		impact.emit()


func _hop_step(t: float, start: Vector2, target: Vector2, height: float) -> void:
	var p := start.lerp(target, t)
	p.y -= sin(t * PI) * height
	position = p


## Ataque do slime: agacha, salta até o alvo e emite `impact` ao pousar.
func hop_attack(contact: Vector2) -> void:
	_face_towards(contact.x)
	play_anim("attack")
	await get_tree().create_timer(CROUCH_TIME).timeout
	var tw := create_tween()
	tw.tween_property(self, "position", contact, AIR_TIME)
	await tw.finished
	impact.emit()
	await get_tree().create_timer(LAND_TIME).timeout


## Achata o sprite (antecipação do ataque).
func squash(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(sprite, "scale", _base_scale * Vector2(1.18, 0.78), duration) \
			.set_trans(Tween.TRANS_SINE)
	await tw.finished
	sprite.scale = _base_scale


# ---------------------------------------------------------------------------
# Vida e reações
# ---------------------------------------------------------------------------
func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
	_update_bar()
	hp_changed.emit()


func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	_update_bar()
	hp_changed.emit()


func play_hit() -> void:
	if sprite == null:
		return
	if sprite.sprite_frames.has_animation("hurt"):
		play_anim("hurt")
		get_tree().create_timer(anim_duration("hurt")).timeout.connect(_back_to_idle)
	var dir := 1.0 if default_face_left else -1.0
	var tw := create_tween()
	tw.tween_property(sprite, "position:x", dir * 6.0, 0.05)
	tw.tween_property(sprite, "position:x", 0.0, 0.12)
	flash(Color(1.0, 0.35, 0.35), 0.25)


func _back_to_idle() -> void:
	if is_inside_tree() and hp > 0 and not is_dying:
		play_anim("idle")


func flash(color: Color, duration: float = 0.2) -> void:
	if sprite == null:
		return
	sprite.modulate = color
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", _tint, duration)


func die(fade: bool = true) -> void:
	is_dying = true
	if _bar_bg != null:
		_bar_bg.hide()
	if sprite.sprite_frames.has_animation("death"):
		play_anim("death")
		await get_tree().create_timer(anim_duration("death")).timeout
	if fade:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		await tw.finished
		if not is_player:
			queue_free()


## Texto flutuante (dano, cura, avisos). Fica no pai, então não acompanha o movimento do battler.
func float_text(text: String, color: Color, y_offset: float = -10.0) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var label := Label.new()
	label.text = text
	label.z_index = 80
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	var start := position + Vector2(-label.get_minimum_size().x / 2.0, -(head_height + y_offset + 12.0))
	label.position = start
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", start.y - 22.0, 0.8)
	tw.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.4)
	tw.finished.connect(label.queue_free)
