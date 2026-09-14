class_name DialogueBox
extends Control

## Sistema de Diálogos Satíricos de Calabozos & Bufones.
## Muestra retratos de personajes, nombres estilizados y efecto máquina de escribir (typewriter).

var panel_container: PanelContainer
var portrait_rect: TextureRect
var speaker_label: Label
var text_label: RichTextLabel
var next_btn: Button

var dialog_lines: Array = []
var current_line_idx: int = 0
var is_typing: bool = false
var full_current_text: String = ""
var typewriter_tween: Tween

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	visible = false
	_build_ui()
	if EventBus:
		EventBus.dialogue_requested.connect(start_dialogue)

func _build_ui() -> void:
	panel_container = PanelContainer.new()
	panel_container.name = "DialoguePanel"
	panel_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel_container.offset_left = 32
	panel_container.offset_top = -220
	panel_container.offset_right = -32
	panel_container.offset_bottom = -20
	panel_container.mouse_filter = MOUSE_FILTER_STOP
	add_child(panel_container)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_theme_constant_override("separation", 20)
	panel_container.add_child(hbox)

	# 1. Retrato del hablante
	portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(120, 120)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(portrait_rect)

	# 2. Contenedor de Texto y Nombre
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	hbox.add_child(vbox)

	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 20)
	speaker_label.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(speaker_label)

	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.add_theme_font_size_override("normal_font_size", 16)
	text_label.custom_minimum_size = Vector2(0, 70)
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.scroll_active = false
	vbox.add_child(text_label)

	# 3. Botón de avanzar
	next_btn = Button.new()
	next_btn.text = "Continuar ⏩"
	next_btn.custom_minimum_size = Vector2(130, 40)
	next_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_btn.pressed.connect(_on_next_pressed)
	hbox.add_child(next_btn)

func start_dialogue(lines: Array) -> void:
	if lines.is_empty(): return
	dialog_lines = lines
	current_line_idx = 0
	visible = true
	_show_current_line()

func _show_current_line() -> void:
	if current_line_idx >= dialog_lines.size():
		_finish_dialogue()
		return

	var line_data: Dictionary = dialog_lines[current_line_idx]
	var speaker: String = line_data.get("speaker", "Narrador")
	var text: String = line_data.get("text", "")
	var portrait_path: String = line_data.get("portrait", "")

	speaker_label.text = speaker
	full_current_text = text
	text_label.text = text
	text_label.visible_characters = 0

	# Cargar retrato
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		portrait_rect.texture = load(portrait_path)
		portrait_rect.visible = true
	else:
		# Retrato por defecto según el nombre
		var default_path = _get_default_portrait(speaker)
		if default_path != "" and ResourceLoader.exists(default_path):
			portrait_rect.texture = load(default_path)
			portrait_rect.visible = true
		else:
			portrait_rect.visible = false

	# Efecto typewriter
	if typewriter_tween and typewriter_tween.is_valid():
		typewriter_tween.kill()

	is_typing = true
	var duration: float = float(text.length()) * 0.022
	typewriter_tween = create_tween()
	typewriter_tween.tween_property(text_label, "visible_characters", text.length(), duration)
	typewriter_tween.tween_callback(func(): is_typing = false)

func _get_default_portrait(speaker_name: String) -> String:
	var s = speaker_name.to_lower()
	if "throg" in s: return "res://assets/sprites/characters/heroes/throg.png"
	elif "elowen" in s: return "res://assets/sprites/characters/heroes/elowen.png"
	elif "grimble" in s: return "res://assets/sprites/characters/heroes/grimble.png"
	elif "beryl" in s: return "res://assets/sprites/characters/heroes/beryl.png"
	elif "goblin" in s: return "res://assets/sprites/characters/enemies/goblin.png"
	elif "esqueleto" in s: return "res://assets/sprites/characters/enemies/esqueleto.png"
	elif "orco" in s: return "res://assets/sprites/characters/enemies/rey_orco.png"
	return "res://assets/sprites/ui/logo.png"

func _on_next_pressed() -> void:
	if is_typing:
		# Completar texto inmediatamente al tocar
		if typewriter_tween and typewriter_tween.is_valid():
			typewriter_tween.kill()
		text_label.visible_characters = full_current_text.length()
		is_typing = false
	else:
		current_line_idx += 1
		_show_current_line()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_next_pressed()

func _finish_dialogue() -> void:
	visible = false
	dialog_lines.clear()
	if EventBus:
		EventBus.dialogue_finished.emit()

