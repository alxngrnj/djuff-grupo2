class_name ActionCommand
extends CanvasLayer
## Action Commands estilo Paper Mario (Godot 4.x).
##
## A interface é criada por código. Quem usa (a cena de batalha) diz quais botões
## valem com set_buttons([...]) antes de chamar um command.
##
##   timing_barra()         -> barra com cursor e zona de acerto
##   timing_sincronizado()  -> aperta na hora do impacto de uma animação/pulo
##   defender()             -> aperta um pouco ANTES do golpe inimigo (guard)
##   apertar_varias()       -> mash de botão (retorna Resultado; veja ultima_proporcao)

enum Resultado { ERRO, BOM, PERFEITO }

const LARGURA := 360.0
const ALTURA := 22.0
const TIMEOUT := 5.0 # segurança: nunca trava se o sinal de impacto não vier

## Camada de desenho (precisa ser maior que a da cena que a usa).
@export var camada: int = 100
## Distância da barra até o topo da tela.
@export var margem_topo: float = 26.0
## Posição (em pixels da tela) do "!" de alerta. Ajuste antes de piscar_alerta().
@export var posicao_alerta: Vector2 = Vector2(320.0, 120.0)

## Proporção (0.0 a 1.0) alcançada no último apertar_varias().
var ultima_proporcao: float = 0.0
## Ações do InputMap que contam como "aperto" neste momento.
var acoes_entrada: Array[String] = ["battle_btn_a", "battle_btn_b", "battle_btn_x", "battle_btn_y"]

var _raiz: Control
var _barra: ColorRect
var _zona_boa: ColorRect
var _zona_perfeita: ColorRect
var _cursor: ColorRect
var _progresso: ColorRect
var _alerta: Label
var _texto: Label
var _t_impacto := -1.0


func _ready() -> void:
	layer = camada
	_construir_ui()
	_esconder_tudo()


## Define quais ações do InputMap valem como aperto.
func set_buttons(botoes: Array) -> void:
	acoes_entrada.clear()
	for b in botoes:
		acoes_entrada.append(str(b))


# ---------------------------------------------------------------------------
# 1) TIMING EM BARRA
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
	_zona_boa.show()
	_zona_perfeita.show()
	_progresso.hide()
	_cursor.show()
	_cursor.position.x = -_cursor.size.x / 2.0
	_barra.show()

	var resultado := Resultado.ERRO
	var frame_inicio := Engine.get_process_frames()
	var inicio := _agora()
	while true:
		await get_tree().process_frame
		var p := (_agora() - inicio) / duracao
		if p > 1.0:
			break
		_cursor.position.x = p * LARGURA - _cursor.size.x / 2.0
		if _pressionou(frame_inicio):
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
# Chame ANTES do impacto. O resultado sai assim que o aperto E o impacto
# aconteceram (não precisa esperar a janela inteira).
# ---------------------------------------------------------------------------
func timing_sincronizado(
		impacto: Signal,
		meia_perfeita := 0.08,
		meia_boa := 0.20
) -> Resultado:
	_t_impacto = -1.0
	impacto.connect(_ao_impacto, CONNECT_ONE_SHOT)

	var t_aperto := -1.0
	var frame_inicio := Engine.get_process_frames()
	var inicio := _agora()
	while _agora() - inicio < TIMEOUT:
		await get_tree().process_frame
		if t_aperto < 0.0 and _pressionou(frame_inicio):
			t_aperto = _agora()
		if _t_impacto >= 0.0 and t_aperto >= 0.0:
			break # já dá para julgar
		if _t_impacto >= 0.0 and _agora() > _t_impacto + meia_boa:
			break # passou da janela e ninguém apertou

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
# Aperte um pouco ANTES do golpe acertar. Só o PRIMEIRO aperto conta:
# apertar cedo demais (ou martelar o botão) não funciona.
# ---------------------------------------------------------------------------
func defender(
		impacto: Signal,
		janela := 0.25,        # quanto tempo antes do golpe ainda vale
		meia_perfeita := 0.07  # "Super Guard": apertar bem em cima da hora
) -> Resultado:
	_t_impacto = -1.0
	impacto.connect(_ao_impacto, CONNECT_ONE_SHOT)

	var t_aperto := -1.0
	var frame_inicio := Engine.get_process_frames()
	var inicio := _agora()
	while _t_impacto < 0.0 and _agora() - inicio < TIMEOUT:
		await get_tree().process_frame
		if t_aperto < 0.0 and _pressionou(frame_inicio):
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
# Retorna PERFEITO (bateu a meta), BOM (>= metade) ou ERRO.
# A proporção exata fica em ultima_proporcao.
# ---------------------------------------------------------------------------
func apertar_varias(duracao := 2.0, meta := 12) -> Resultado:
	_posicionar()
	var contagem := 0
	var frame_inicio := Engine.get_process_frames()
	var inicio := _agora()

	_zona_boa.hide()
	_zona_perfeita.hide()
	_cursor.hide()
	_progresso.size.x = 0.0
	_progresso.show()
	_barra.show()
	_texto.modulate.a = 1.0
	_texto.add_theme_color_override("font_color", Color.WHITE)
	_texto.text = "0 / %d" % meta
	_texto.show()

	while _agora() - inicio < duracao:
		await get_tree().process_frame
		if _pressionou(frame_inicio):
			contagem += 1
			_texto.text = "%d / %d" % [contagem, meta]
			_progresso.size.x = LARGURA * clampf(float(contagem) / float(meta), 0.0, 1.0)

	_barra.hide()
	_progresso.hide()
	_texto.hide()
	ultima_proporcao = clampf(float(contagem) / float(meta), 0.0, 1.0)
	var resultado := Resultado.ERRO
	if ultima_proporcao >= 1.0:
		resultado = Resultado.PERFEITO
	elif ultima_proporcao >= 0.5:
		resultado = Resultado.BOM
	_mostrar_resultado(resultado)
	return resultado


# ---------------------------------------------------------------------------
# "!" de alerta (chame quando o inimigo começa a se preparar para atacar).
# ---------------------------------------------------------------------------
func piscar_alerta(duracao := 0.3) -> void:
	_alerta.position = posicao_alerta - Vector2(8.0, 34.0)
	_alerta.show()
	var tw := create_tween()
	tw.tween_interval(duracao)
	tw.tween_callback(_alerta.hide)


# ===========================================================================
# Internos
# ===========================================================================
## frame_ignorado: um aperto no MESMO frame em que o command começou é o aperto
## que escolheu a ação, então não conta.
func _pressionou(frame_ignorado: int) -> bool:
	if Engine.get_process_frames() == frame_ignorado:
		return false
	for acao in acoes_entrada:
		if Input.is_action_just_pressed(acao):
			return true
	return false


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
	_barra.position = Vector2((vp.x - LARGURA) / 2.0, margem_topo)
	_texto.position = Vector2((vp.x - _texto.size.x) / 2.0, margem_topo + ALTURA + 6.0)


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

	_progresso = ColorRect.new()
	_progresso.color = Color(1.0, 0.6, 0.15)
	_progresso.size = Vector2(0.0, ALTURA)
	_barra.add_child(_progresso)

	_cursor = ColorRect.new()
	_cursor.color = Color.WHITE
	_cursor.size = Vector2(4.0, ALTURA + 10.0)
	_cursor.position.y = -5.0
	_barra.add_child(_cursor)

	_alerta = Label.new()
	_alerta.text = "!"
	_alerta.z_index = 10
	_alerta.add_theme_font_size_override("font_size", 40)
	_alerta.add_theme_color_override("font_color", Color.RED)
	_alerta.add_theme_color_override("font_outline_color", Color.WHITE)
	_alerta.add_theme_constant_override("outline_size", 8)
	_raiz.add_child(_alerta)

	_texto = Label.new()
	_texto.custom_minimum_size = Vector2(300.0, 0.0)
	_texto.size = Vector2(300.0, 30.0)
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.add_theme_font_size_override("font_size", 22)
	_texto.add_theme_color_override("font_outline_color", Color.BLACK)
	_texto.add_theme_constant_override("outline_size", 6)
	_raiz.add_child(_texto)
