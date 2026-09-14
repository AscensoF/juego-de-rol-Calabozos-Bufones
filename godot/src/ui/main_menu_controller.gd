extends Control

var play_button: Button

func _ready():
	play_button = _find_button_by_name(self, "PlayButton")
	if play_button:
		play_button.pressed.connect(_on_play_button_pressed)

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
