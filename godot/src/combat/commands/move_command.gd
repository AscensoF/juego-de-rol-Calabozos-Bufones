class_name MoveCommand
extends CombatCommand

## Comando de Movimiento con soporte nativo de Deshacer (Undo Move).

var grid: TacticalGrid
var from_pos: Vector2i
var to_pos: Vector2i
var is_executed: bool = false

func _init(p_actor: Dictionary, p_to_pos: Vector2i, p_grid: TacticalGrid) -> void:
	command_name = "Mover"
	actor = p_actor
	grid = p_grid
	to_pos = p_to_pos
	
	# Buscamos la posición del actor en el Grid al instanciar el comando
	var u_id = actor.get("id")
	if u_id != null and grid.pos_by_unit_id.has(u_id):
		from_pos = grid.pos_by_unit_id[u_id]
	else:
		from_pos = actor.get("pos", Vector2i.ZERO)

func execute() -> bool:
	# Comprobamos con get_cell_type si es caminable (no es pared)
	if grid.get_cell_type(to_pos) == Enums.CellType.WALL:
		return false

	var success: bool = grid.move_unit(from_pos, to_pos)
	if success:
		actor["has_moved"] = true
		is_executed = true
		if EventBus:
			EventBus.unit_moved.emit(actor["id"], from_pos, to_pos)
			EventBus.combat_log_appended.emit("%s se mueve a (%d, %d)." % [actor["name"], to_pos.x, to_pos.y], "info")
		return true
	return false

func undo() -> bool:
	if not is_executed:
		return false

	var success: bool = grid.move_unit(to_pos, from_pos)
	if success:
		actor["has_moved"] = false
		is_executed = false
		if EventBus:
			EventBus.unit_move_undone.emit(actor["id"], from_pos)
			EventBus.combat_log_appended.emit("%s deshace su movimiento y regresa a (%d, %d)." % [actor["name"], from_pos.x, from_pos.y], "info")
		return true
	return false

func can_undo() -> bool:
	return is_executed

