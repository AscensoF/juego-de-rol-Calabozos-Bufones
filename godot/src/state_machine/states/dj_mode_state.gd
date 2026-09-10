class_name DJModeState
extends State

## Estado Director del Caos (Modo DJ): Edición de mapa en tiempo real, invocación y depuración.

var selected_paint_cell: Enums.CellType = Enums.CellType.WALL
var selected_enemy_to_spawn: Enums.EnemyKind = Enums.EnemyKind.GOBLIN_BUROCRATA
var fog_disabled: bool = false

func _init() -> void:
	state_enum = Enums.GameFlowState.DJ_MODE

func enter(_params: Dictionary = {}) -> void:
	if EventBus:
		EventBus.dj_mode_toggled.emit(true)
		EventBus.status_panel_updated.emit("MODO DJ ACTIVO: Pinta celdas, invoca monstruos y manipula la realidad.")
		EventBus.combat_log_appended.emit("[Modo DJ] Modo Director del Caos habilitado.", "game")
		EventBus.cell_clicked.connect(_on_cell_clicked)

func exit() -> void:
	if EventBus:
		EventBus.dj_mode_toggled.emit(false)
		if EventBus.cell_clicked.is_connected(_on_cell_clicked):
			EventBus.cell_clicked.disconnect(_on_cell_clicked)
		EventBus.combat_log_appended.emit("[Modo DJ] Modo Director del Caos desactivado.", "info")

func _on_cell_clicked(grid_pos: Vector2i) -> void:
	paint_cell_at(grid_pos, selected_paint_cell)

func paint_cell_at(grid_pos: Vector2i, cell_type: Enums.CellType) -> void:
	if EventBus:
		EventBus.dj_cell_painted.emit(cell_type, grid_pos)
		EventBus.combat_log_appended.emit("[DJ] Pintada celda %s en (%d, %d)." % [cell_type, grid_pos.x, grid_pos.y], "info")

func spawn_enemy_at(grid_pos: Vector2i, enemy_kind: Enums.EnemyKind) -> void:
	if EventBus:
		EventBus.dj_enemy_spawned.emit(enemy_kind, grid_pos)
		EventBus.combat_log_appended.emit("[DJ] Invocado enemigo tipo %d en (%d, %d)." % [enemy_kind, grid_pos.x, grid_pos.y], "crit")

func toggle_fog_of_war() -> void:
	fog_disabled = not fog_disabled
	if EventBus:
		EventBus.dj_fog_cleared.emit(fog_disabled)
		EventBus.combat_log_appended.emit("[DJ] Niebla de guerra: %s" % ("Desactivada" if fog_disabled else "Activada"), "info")

func return_to_game() -> void:
	state_machine.revert_to_previous_state()
