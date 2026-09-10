class_name GameOverState
extends State

## Estado de Fin de Partida: Maneja pantallas de Game Over o Victoria final de campaña.

var is_victory: bool = false

func _init() -> void:
	state_enum = Enums.GameFlowState.GAME_OVER

func enter(params: Dictionary = {}) -> void:
	is_victory = params.get("victory", false)

	if EventBus:
		if is_victory:
			EventBus.status_panel_updated.emit("¡VICTORIA ÉPICA! Has salvado la realidad.")
			EventBus.combat_log_appended.emit("<b>¡CAMPAÑA COMPLETADA! El caos ha sido contenido... por ahora.</b>", "heal")
		else:
			EventBus.status_panel_updated.emit("GAME OVER: La pifia fue demasiado grande.")
			EventBus.combat_log_appended.emit("<b>Todos vuestros héroes yacen derrotados.</b>", "damage")

func retry_from_checkpoint() -> void:
	state_machine.change_state(Enums.GameFlowState.EXPLORATION, {"retry": true})

func return_to_main_menu() -> void:
	state_machine.change_state(Enums.GameFlowState.MAIN_MENU)

func exit() -> void:
	pass
