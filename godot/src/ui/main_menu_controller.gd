extends Control

var play_button: Button
var continue_button: Button

func _ready():
	play_button = _find_button_by_name(self, "PlayButton")
	if play_button:
		play_button.pressed.connect(_on_play_button_pressed)
	_build_continue_button()

# Fase 5c: botón Continuar (solo si hay autosave de campaña).
func _build_continue_button() -> void:
	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "📜 CONTINUAR CAMPAÑA"
	continue_button.custom_minimum_size = Vector2(280, 48)
	continue_button.add_theme_font_size_override("font_size", 18)
	continue_button.pressed.connect(_on_continue_button_pressed)
	var vbox := _find_vbox()
	if vbox:
		vbox.add_child(continue_button)
		vbox.move_child(continue_button, 4)
	refresh_continue_visibility()

func _find_vbox() -> VBoxContainer:
	var candidate := _find_button_by_name(self, "PlayButton")
	if candidate:
		var parent = candidate.get_parent()
		if parent is VBoxContainer:
			return parent
	return null

func refresh_continue_visibility() -> void:
	if continue_button == null:
		return
	continue_button.visible = SaveSystem.has_campaign_save()

func _on_continue_button_pressed():
	var state_machine = get_tree().get_root().get_node_or_null("MainGame/StateMachine")
	if state_machine and state_machine.has_node("MainMenuState"):
		if state_machine.get_node("MainMenuState").continue_from_campaign():
			hide()
		else:
			refresh_continue_visibility()

func _find_button_by_name(node: Node, target_name: String) -> Button:
	if node is Button and node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_button_by_name(child, target_name)
		if found: return found
	return null

func _on_play_button_pressed():
	var state_machine = get_tree().get_root().get_node_or_null("MainGame/StateMachine")
	if state_machine and state_machine.has_node("MainMenuState"):
		state_machine.get_node("MainMenuState").start_new_game()
		hide()
