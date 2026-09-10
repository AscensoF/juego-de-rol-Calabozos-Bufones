extends Control

func _ready():
	print("--- UI MAIN MENU READY ---")
	var play_button = $VBoxContainer/MarginContainer/PlayButton
	if play_button:
		play_button.pressed.connect(_on_play_button_pressed)
		
		# 🤖 Inyección de IA: Si corro en headless, simulo el click automáticamente
		if "--headless" in OS.get_cmdline_args():
			print("🤖 IA AUTO-TEST: Simulando clic humano en JUGAR...")
			call_deferred("_on_play_button_pressed")

func _on_play_button_pressed():
	print("Menú Principal: ¡Botón JUGAR pulsado!")
	var state_machine = get_tree().get_root().get_node_or_null("MainGame/StateMachine")
	if state_machine and state_machine.has_node("MainMenuState"):
		var menu_state = state_machine.get_node("MainMenuState")
		if menu_state.has_method("start_new_game"):
			print("Menú Principal: Ejecutando transición de estado...")
			menu_state.start_new_game()
			hide()
	else:
		print("Error: No se encontró StateMachine en la ruta esperada.")

