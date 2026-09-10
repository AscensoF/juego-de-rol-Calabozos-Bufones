class_name DiceVisualizer
extends Control

## Visualizador dinámico de tiradas D20 en pantalla con soporte para Críticos, Pifias y Fórmulas.

var panel_container: PanelContainer
var title_label: Label
var dice_number_label: Label
var breakdown_label: Label
var result_banner: Label
var hide_timer: Timer

var is_animating: bool = false
var target_number: int = 20

func _init() -> void:
	visible = false
	anchors_preset = PRESET_FULL_RECT
	mouse_filter = MOUSE_FILTER_PASS

	_build_ui()

func _ready() -> void:
	if EventBus:
		EventBus.dice_roll_requested.connect(_on_dice_roll_requested)
		EventBus.attack_resolved.connect(_on_attack_resolved)

func _build_ui() -> void:
	panel_container = PanelContainer.new()
	panel_container.custom_minimum_size = Vector2(320, 200)
	panel_container.anchors_preset = PRESET_CENTER
	panel_container.position = Vector2(-160, -100)
	panel_container.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(panel_container)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_container.add_child(vbox)

	title_label = Label.new()
	title_label.text = "Tirada de Ataque d20"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(title_label)

	dice_number_label = Label.new()
	dice_number_label.text = "20"
	dice_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_number_label.add_theme_font_size_override("font_size", 48)
	dice_number_label.add_theme_constant_override("outline_size", 6)
	dice_number_label.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox.add_child(dice_number_label)

	breakdown_label = Label.new()
	breakdown_label.text = "15 + 3 (Mod) = 18 vs CA 14"
	breakdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breakdown_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(breakdown_label)

	result_banner = Label.new()
	result_banner.text = "¡IMPACTO!"
	result_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_banner.add_theme_font_size_override("font_size", 20)
	vbox.add_child(result_banner)

	hide_timer = Timer.new()
	hide_timer.one_shot = true
	hide_timer.wait_time = 1.4
	hide_timer.timeout.connect(_hide_visualizer)
	add_child(hide_timer)

func _on_attack_resolved(
	attacker_name: String,
	target_name: String,
	d20_roll: int,
	attr_mod: int,
	total_attack: int,
	target_ac: int,
	is_hit: bool,
	is_crit: bool,
	is_fumble: bool,
	_damage: int
) -> void:
	show_roll(
		"%s ataca a %s" % [attacker_name, target_name],
		d20_roll,
		attr_mod,
		total_attack,
		target_ac,
		is_hit,
		is_crit,
		is_fumble
	)

func _on_dice_roll_requested(reason: String, _dice_sides: int, modifier: int, target_dc: int) -> void:
	title_label.text = reason
	breakdown_label.text = "Modificador: %+d | Dificultad: %d" % [modifier, target_dc]
	result_banner.text = "Tirando..."
	visible = true

func show_roll(
	title: String,
	roll: int,
	mod: int,
	total: int,
	target_ac: int,
	is_hit: bool,
	is_crit: bool,
	is_fumble: bool
) -> void:
	title_label.text = title
	target_number = roll
	visible = true

	# Breakdown de cálculo
	breakdown_label.text = "%d + %d = %d vs CA %d" % [roll, mod, total, target_ac]

	# Animación rápida de números aleatorios simulando giro de dado d20
	var tween := create_tween()
	for i in 6:
		var dummy_number: int = (randi() % 20) + 1
		tween.tween_callback(func(): dice_number_label.text = str(dummy_number)).set_delay(0.04)

	# Asentamiento final
	tween.tween_callback(func():
		dice_number_label.text = str(roll)
		_apply_outcome_styling(is_hit, is_crit, is_fumble)
	)

	hide_timer.start()

func _apply_outcome_styling(is_hit: bool, is_crit: bool, is_fumble: bool) -> void:
	if is_crit:
		dice_number_label.add_theme_color_override("font_color", Color.GOLD)
		result_banner.text = "¡20 NATURAL! ¡CRÍTICO!"
		result_banner.add_theme_color_override("font_color", Color.GOLD)
	elif is_fumble:
		dice_number_label.add_theme_color_override("font_color", Color.RED)
		result_banner.text = "¡PIFIA NATURAL! (1)"
		result_banner.add_theme_color_override("font_color", Color.RED)
	elif is_hit:
		dice_number_label.add_theme_color_override("font_color", Color.GREEN)
		result_banner.text = "¡IMPACTO!"
		result_banner.add_theme_color_override("font_color", Color.GREEN)
	else:
		dice_number_label.add_theme_color_override("font_color", Color.GRAY)
		result_banner.text = "FALLO"
		result_banner.add_theme_color_override("font_color", Color.GRAY)

func _hide_visualizer() -> void:
	visible = false
