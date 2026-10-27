class_name ActionCommand
extends CanvasLayer
## Action Commands estilo Paper Mario (Godot 4.x).
##
## Não precisa de cena: a interface é criada por código.
## Basta adicionar este script a um nó CanvasLayer dentro da cena de batalha
## e criar a ação "confirmar" em Projeto > Configurações do Projeto > Mapa de Entrada.
##
## Tipos de command:
##   timing_barra()         -> barra com cursor e zona de acerto (ataques simples)
##   timing_sincronizado()  -> aperta na hora do impacto da animação (pulo, martelada)
##   defender()             -> aperta um pouco ANTES do golpe inimigo (guard)
##   apertar_varias()       -> mash de botão (golpes especiais)

enum Resultado { ERRO, BOM, PERFEITO }

const ACAO := "confirmar"
const LARGURA := 420.0
const ALTURA := 26.0
const TIMEOUT := 5.0 # segurança: nunca trava se o sinal de impacto não vier

## Posição na tela (em pixels) onde aparece o "!" de alerta.
## Ajuste para ficar em cima do inimigo.
@export var posicao_alerta := Vector2(576, 180)

var _raiz: Control
var _barra: ColorRect
var _zona_boa: ColorRect
var _zona_perfeita: ColorRect
var _cursor: ColorRect
var _alerta: Label
var _texto: Label
var _t_impacto := -1.0


func _ready() -> void:
	layer = 10
	_construir_ui()
	_esconder_tudo()


# ---------------------------------------------------------------------------
# 1) TIMING EM BARRA
# Um cursor atravessa a barra. Aperte quando estiver na zona dourada.
# ---------------------------------------------------------------------------
func timing_barra(
		duracao := 1.2,
		centro := 0.75,         # posição ideal na barra (0.0 a 1.0)
		meia_perfeita := 0.05,  # meia-largura da zona perfeita
		meia_boa := 0.12        # meia-largura da zona boa
) -> Resultado:
	_posicionar()
	_configurar_zona(_zona_boa, centro, meia_boa)
	_configurar_zona(_zona_perfeita, centro, meia_perfeita)
	_cursor.position.x = -_cursor.size.x / 2.0
	_barra.show()

	var resultado := Resultado.ERRO
	var inicio := _agora()
	while true:
		await get_tree().process_frame # espera 1 frame: ignora o aperto do menu
		var p := (_agora() - inicio) / duracao
		if p > 1.0:
			break
		_cursor.position.x = p * LARGURA - _cursor.size.x / 2.0
		if Input.is_action_just_pressed(ACAO):
			var d := absf(p - centro)
			if d <= meia_perfeita:
				resultado = Resultado.PERFEITO
			elif d <= meia_boa:
				resultado = Resultado.BOM
			break

	_barra.hide()
	_mostrar_resultado(resultado)
	return resultado


# ---------------------------------------------------------------------------
# 2) TIMING SINCRONIZADO COM ANIMAÇÃO
# O AnimationPlayer emite um sinal no frame do impacto (Call Method Track).
# O jogador aperta perto desse momento (antes ou depois, dentro da margem).
# ---------------------------------------------------------------------------
func timing_sincronizado(
		impacto: Signal,
		meia_perfeita := 0.08,
		meia_boa := 0.20
) -> Resultado:
	_t_impacto = -1.0
	impacto.connect(_ao_impacto, CONNECT_ONE_SHOT)

	var t_aperto := -1.0
	var inicio := _agora()
	while _agora() - inicio < TIMEOUT:
		await get_tree().process_frame
		if t_aperto < 0.0 and Input.is_action_just_pressed(ACAO):
			t_aperto = _agora()
		if _t_impacto >= 0.0 and _agora() > _t_impacto + meia_boa:
			break # passou da janela, não adianta esperar mais

	_desconectar(impacto)

	var resultado := Resultado.ERRO
	if t_aperto >= 0.0 and _t_impacto >= 0.0:
		var d := absf(t_aperto - _t_impacto)
		if d <= meia_perfeita:
			resultado = Resultado.PERFEITO
		elif d <= meia_boa:
			resultado = Resultado.BOM

	_mostrar_resultado(resultado)
	return resultado


# ---------------------------------------------------------------------------
# 3) DEFESA (GUARD)
# Aperte um pouco ANTES do golpe acertar. Apertar cedo demais ou tarde
# demais não funciona, como no Paper Mario.
# ---------------------------------------------------------------------------
func defender(
		impacto: Signal,
		janela := 0.25,        # quanto tempo antes do golpe ainda vale
		meia_perfeita := 0.07  # "Super Guard": apertar bem em cima da hora
) -> Resultado:
	_t_impacto = -1.0
	impacto.connect(_ao_impacto, CONNECT_ONE_SHOT)

	var t_aperto := -1.0
	var inicio := _agora()
	while _t_impacto < 0.0 and _agora() - inicio < TIMEOUT:
		await get_tree().process_frame
		if t_aperto < 0.0 and Input.is_action_just_pressed(ACAO):
			t_aperto = _agora()

	_desconectar(impacto)

	var resultado := Resultado.ERRO
	if t_aperto >= 0.0 and _t_impacto >= 0.0:
		var d := _t_impacto - t_aperto # positivo = apertou antes do golpe
		if d >= -0.03 and d <= meia_perfeita:  # -0.03 = tolerância de 1~2 frames
			resultado = Resultado.PERFEITO
		elif d >= -0.03 and d <= janela:
			resultado = Resultado.BOM

	_mostrar_resultado(resultado)
	return resultado


# ---------------------------------------------------------------------------
# 4) MASH DE BOTÃO
# Retorna de 0.0 a 1.0 (1.0 = bateu a meta). Use como multiplicador de dano.
# ---------------------------------------------------------------------------
func apertar_varias(duracao := 2.0, meta := 15) -> float:
	_posicionar()
	var contagem := 0
	var inicio := _agora()
	_texto.modulate.a = 1.0
	_texto.add_theme_color_override("font_color", Color.WHITE)
	_texto.text = "0 / %d" % meta
	_texto.show()

	while _agora() - inicio < duracao:
		await get_tree().process_frame
		if Input.is_action_just_pressed(ACAO):
			contagem += 1
			_texto.text = "%d / %d" % [contagem, meta]

	_texto.hide()
	var proporcao := clampf(float(contagem) / float(meta), 0.0, 1.0)
	_mostrar_resultado(Resultado.PERFEITO if proporcao >= 1.0 else
			(Resultado.BOM if proporcao >= 0.5 else Resultado.ERRO))
	return proporcao


# ---------------------------------------------------------------------------
# "!" de alerta: chame na hora em que o inimigo vai atacar
# (por exemplo, com uma Call Method Track na animação do inimigo).
# ---------------------------------------------------------------------------
func piscar_alerta(duracao := 0.3) -> void:
	_alerta.position = posicao_alerta
	_alerta.show()
	var tw := create_tween()
	tw.tween_interval(duracao)
	tw.tween_callback(_alerta.hide)


# ===========================================================================
# Internos
# ===========================================================================
func _ao_impacto() -> void:
	_t_impacto = _agora()


func _desconectar(sinal: Signal) -> void:
	if sinal.is_connected(_ao_impacto):
		sinal.disconnect(_ao_impacto)


func _agora() -> float:
	return Time.get_ticks_msec() / 1000.0


func _configurar_zona(zona: ColorRect, centro: float, meia: float) -> void:
	zona.position = Vector2((centro - meia) * LARGURA, 0.0)
	zona.size = Vector2(meia * 2.0 * LARGURA, ALTURA)


func _posicionar() -> void:
	var vp := get_viewport().get_visible_rect().size
	_barra.position = Vector2((vp.x - LARGURA) / 2.0, vp.y - 110.0)
	_texto.position = Vector2((vp.x - _texto.size.x) / 2.0, vp.y / 2.0 - 60.0)


func _mostrar_resultado(r: Resultado) -> void:
	var textos := {
		Resultado.PERFEITO: ["EXCELENTE!", Color.GOLD],
		Resultado.BOM: ["BOM", Color.LIME_GREEN],
		Resultado.ERRO: ["...", Color.LIGHT_GRAY],
	}
	_posicionar()
	_texto.text = textos[r][0]
	_texto.add_theme_color_override("font_color", textos[r][1])
	_texto.modulate.a = 1.0
	_texto.show()
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(_texto, "modulate:a", 0.0, 0.3)
	tw.tween_callback(_texto.hide)


func _esconder_tudo() -> void:
	_barra.hide()
	_alerta.hide()
	_texto.hide()


func _construir_ui() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	_barra = ColorRect.new()
	_barra.color = Color(0.08, 0.08, 0.1, 0.9)
	_barra.size = Vector2(LARGURA, ALTURA)
	_raiz.add_child(_barra)

	_zona_boa = ColorRect.new()
	_zona_boa.color = Color(0.2, 0.7, 0.3)
	_barra.add_child(_zona_boa)

	_zona_perfeita = ColorRect.new()
	_zona_perfeita.color = Color.GOLD
	_barra.add_child(_zona_perfeita)

	_cursor = ColorRect.new()
	_cursor.color = Color.WHITE
	_cursor.size = Vector2(6.0, ALTURA + 12.0)
	_cursor.position.y = -6.0
	_barra.add_child(_cursor)

	_alerta = Label.new()
	_alerta.text = "!"
	_alerta.add_theme_font_size_override("font_size", 72)
	_alerta.add_theme_color_override("font_color", Color.RED)
	_alerta.add_theme_color_override("font_outline_color", Color.WHITE)
	_alerta.add_theme_constant_override("outline_size", 10)
	_raiz.add_child(_alerta)

	_texto = Label.new()
	_texto.size = Vector2(400.0, 60.0)
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.add_theme_font_size_override("font_size", 40)
	_texto.add_theme_color_override("font_outline_color", Color.BLACK)
	_texto.add_theme_constant_override("outline_size", 8)
	_raiz.add_child(_texto)
