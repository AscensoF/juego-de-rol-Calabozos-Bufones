class_name GameOverState
extends State

## Estado de Fin de Partida: Maneja pantallas modales de Game Over o Victoria con opciones interactivas.

var is_victory: bool = false
var modal_panel: PanelContainer

func _init() -> void:
	state_enum = Enums.GameFlowState.GAME_OVER

func enter(params: Dictionary = {}) -> void:
	is_victory = params.get("victory", false)

	if EventBus:
		if is_victory:
			EventBus.status_panel_updated.emit("¡VICTORIA ÉPICA! Habéis triunfado.")
			EventBus.combat_log_appended.emit("<b>¡CAMPAÑA COMPLETADA! El caos ha sido contenido.</b>", "heal")
		else:
			EventBus.status_panel_updated.emit("GAME OVER: La pifia fue demasiado grande.")
			EventBus.combat_log_appended.emit("<b>Todos vuestros héroes yacen derrotados.</b>", "damage")

	_build_modal_ui()

func _build_modal_ui() -> void:
	var gm = state_machine.get_parent()
	if not gm: return
	var canvas = gm.get_node_or_null("CanvasLayer")
	if not canvas: return

	modal_panel = PanelContainer.new()
	modal_panel.name = "GameOverModal"
	modal_panel.set_anchors_preset(Control.PRESET_CENTER)
	modal_panel.custom_minimum_size = Vector2(400, 260)
	modal_panel.position = Vector2(-200, -130)
	canvas.add_child(modal_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	modal_panel.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "¡VICTORIA!" if is_victory else "GAME OVER"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 32)
	title_lbl.add_theme_color_override("font_color", Color.GOLD if is_victory else Color.CORAL)
	vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = "¡Habéis derrotado a las amenazas del calabozo!" if is_victory else "Vuestro grupo ha sucumbido en la oscuridad..."
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(desc_lbl)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	var retry_btn := Button.new()
	retry_btn.text = "🔄 Reintentar"
	retry_btn.custom_minimum_size = Vector2(140, 42)
	retry_btn.pressed.connect(func():
		_cleanup_modal()
		retry_from_checkpoint()
	)
	hbox.add_child(retry_btn)

	var menu_btn := Button.new()
	menu_btn.text = "🏠 Menú Principal"
	menu_btn.custom_minimum_size = Vector2(140, 42)
	menu_btn.pressed.connect(func():
		_cleanup_modal()
		return_to_main_menu()
	)
	hbox.add_child(menu_btn)

func _cleanup_modal() -> void:
	if modal_panel and is_instance_valid(modal_panel):
		modal_panel.queue_free()
		modal_panel = null

func retry_from_checkpoint() -> void:
	var gm = state_machine.get_parent()
	if gm and gm.has_method("_setup_initial_board"):
		gm._setup_initial_board()
	state_machine.change_state(Enums.GameFlowState.EXPLORATION, {"retry": true})

func return_to_main_menu() -> void:
	state_machine.change_state(Enums.GameFlowState.MAIN_MENU)

func exit() -> void:
	_cleanup_modal()

