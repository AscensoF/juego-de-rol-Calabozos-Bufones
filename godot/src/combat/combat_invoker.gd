class_name CombatInvoker
extends RefCounted

## Gestor de Ejecución de Comandos Tácticos (Invoker).
## Administra el encolado de órdenes, animaciones y el soporte estricto de 'Deshacer Movimiento' (Undo Move).

var command_history: Array[CombatCommand] = []
var pending_move_command: MoveCommand = null

func execute_command(command: CombatCommand) -> bool:
	if not command:
		return false

	var success: bool = command.execute()
	if not success:
		return false

	command_history.append(command)

	if command is MoveCommand:
		pending_move_command = command
		if EventBus:
			EventBus.action_economy_updated.emit(true, command.actor.get("has_acted", false), true)
	else:
		# Cualquier acción principal sella el turno y revoca la opción de deshacer el movimiento
		pending_move_command = null
		if EventBus:
			EventBus.action_economy_updated.emit(command.actor.get("has_moved", false), true, false)

	return true

func undo_last_move() -> bool:
	if not pending_move_command:
		return false

	if pending_move_command.can_undo():
		var actor: Dictionary = pending_move_command.actor
		var success: bool = pending_move_command.undo()
		if success:
			pending_move_command = null
			if EventBus:
				EventBus.action_economy_updated.emit(false, actor.get("has_acted", false), false)
			return true

	return false

func clear_turn_context() -> void:
	pending_move_command = null
