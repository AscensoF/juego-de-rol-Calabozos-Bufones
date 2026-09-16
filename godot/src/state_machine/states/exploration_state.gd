class_name ExplorationState
extends State

## Estado de Exploración: Selección táctil de héroe, pathfinding A*, cálculo de celdas alcanzables, movimiento interactivo y niebla de guerra.

var current_act: ActData
var party_heroes: Array = []
var selected_hero_id: String = "hero_0"

const GRID_WIDTH: int = 24
const GRID_HEIGHT: int = 18
const VISION_RADIUS: int = 6

var is_moving_hero: bool = false

func _init() -> void:
	state_enum = Enums.GameFlowState.EXPLORATION

func enter(params: Dictionary = {}) -> void:
	print("ExplorationState: Entrando en fase de Exploración...")
	if params.has("party"):
		party_heroes = params["party"]

	if EventBus:
		var hud = state_machine.get_parent().get_node_or_null("CanvasLayer/CombatHUD")
		if hud and hud.has_method("show_ui"): hud.show_ui()
		EventBus.cell_clicked.connect(_on_cell_clicked)

	# Seleccionar por defecto al primer héroe
	select_hero(selected_hero_id)

func exit() -> void:
	if EventBus and EventBus.cell_clicked.is_connected(_on_cell_clicked):
		EventBus.cell_clicked.disconnect(_on_cell_clicked)
	_clear_highlights()
	is_moving_hero = false

func select_hero(hero_id: String) -> void:
	if is_moving_hero: return
	selected_hero_id = hero_id
	var game_manager = state_machine.get_parent()
	if not game_manager or not game_manager.tactical_grid: return
	var grid = game_manager.tactical_grid
	var pos = grid.pos_by_unit_id.get(hero_id, Vector2i(-1, -1))
	
	if pos == Vector2i(-1, -1): return
	var unit = grid.get_unit_at(pos)
	var h_name = unit.get("name", "Héroe")

	# Actualizar iluminación en el GridRenderer
	if game_manager.grid_renderer:
		game_manager.grid_renderer.selected_cell = pos
		game_manager.grid_renderer.reachable_cells = _get_reachable_cells(pos, unit.get("speed", 4))
		game_manager.grid_renderer.current_path.clear()
		game_manager.grid_renderer.queue_redraw()

	if EventBus:
		EventBus.status_panel_updated.emit("Héroe activo: %s. Toca una casilla verde para trazar la ruta." % h_name)

func _clear_highlights() -> void:
	var game_manager = state_machine.get_parent()
	if game_manager and game_manager.grid_renderer:
		game_manager.grid_renderer.selected_cell = Vector2i(-1, -1)
		game_manager.grid_renderer.reachable_cells.clear()
		game_manager.grid_renderer.current_path.clear()
		game_manager.grid_renderer.queue_redraw()

func _get_reachable_cells(start_pos: Vector2i, max_speed: int) -> Array[Vector2i]:
	var game_manager = state_machine.get_parent()
	var grid = game_manager.tactical_grid
	var reachable: Array[Vector2i] = []
	
	for dy in range(-max_speed, max_speed + 1):
		for dx in range(-max_speed, max_speed + 1):
			var p := Vector2i(start_pos.x + dx, start_pos.y + dy)
			if p == start_pos: continue
			if grid.is_in_bounds(p):
				if grid.get_cell_type(p) != Enums.CellType.WALL:
					# Comprobar que existe un camino A* válido dentro de la distancia máxima
					var path = grid.find_path(start_pos, p, max_speed)
					if path.size() > 1 and (path.size() - 1) <= max_speed:
						if not grid.units_by_pos.has(p):
							reachable.append(p)
	return reachable

func _on_cell_clicked(grid_pos: Vector2i) -> void:
	# Fase 5c: el DJ coloca antes que cualquier lógica de héroe.
	if EventBus and EventBus.dj_spawn_path != "":
		_dj_place_at(grid_pos)
		return
	if is_moving_hero: return
	if grid_pos.x < 0 or grid_pos.x >= GRID_WIDTH or grid_pos.y < 0 or grid_pos.y >= GRID_HEIGHT: return

	var game_manager = state_machine.get_parent()
	if not game_manager or not game_manager.tactical_grid: return
	var grid = game_manager.tactical_grid

	# 1. ¿Tocó a otra unidad/héroe?
	var clicked_unit = grid.get_unit_at(grid_pos)
	if not clicked_unit.is_empty():
		if clicked_unit.get("is_hero", false):
			select_hero(clicked_unit["id"])
			return

	# 2. Mover al héroe seleccionado actualmente a través del camino A*
	var current_pos = grid.pos_by_unit_id.get(selected_hero_id, Vector2i(-1, -1))
	if current_pos == Vector2i(-1, -1): return
	
	var unit = grid.get_unit_at(current_pos)
	var max_speed = unit.get("speed", 4)

	if grid.get_cell_type(grid_pos) == Enums.CellType.WALL:
		EventBus.combat_log_appended.emit("El camino está bloqueado por un muro.", "info")
		return

	var path = grid.find_path(current_pos, grid_pos, max_speed)
	if path.size() > 1 and (path.size() - 1) <= max_speed and not grid.units_by_pos.has(grid_pos):
		_execute_hero_path(path, unit)

func _execute_hero_path(path: Array[Vector2i], unit: Dictionary) -> void:
	is_moving_hero = true
	var game_manager = state_machine.get_parent()
	var grid = game_manager.tactical_grid
	
	var current_step_pos = path[0]
	for i in range(1, path.size()):
		var next_pos = path[i]
		grid.move_unit(current_step_pos, next_pos)
		reveal_fog_around(next_pos, VISION_RADIUS)
		EventBus.unit_moved.emit(selected_hero_id, current_step_pos, next_pos)
		current_step_pos = next_pos
		await get_tree().create_timer(0.08).timeout
		if not is_inside_tree(): return

	var final_pos = path[-1]
	_check_cell_interaction(final_pos, unit)
	is_moving_hero = false
	select_hero(selected_hero_id)
	# Fase 3: autosave tras cada movimiento (antes de posible transición a combate).
	if EventBus: EventBus.turn_ended.emit(unit)
	_check_for_combat(final_pos)

func _check_cell_interaction(pos: Vector2i, unit: Dictionary) -> void:
	var game_manager = state_machine.get_parent()
	if not game_manager or not game_manager.tactical_grid: return
	var grid = game_manager.tactical_grid
	var cell_type = grid.get_cell_type(pos)
	var h_name = unit.get("name", "Héroe")
	var u_id = unit.get("id", "hero_0")
	
	match cell_type:
		Enums.CellType.TRAP:
			var dmg: int = (randi() % 6) + 1
			unit["hp"] = maxi(0, unit.get("hp", 10) - dmg)
			grid.set_cell_type(pos, Enums.CellType.FLOOR)
			if EventBus:
				EventBus.health_updated.emit(u_id, unit["hp"], unit.get("hp_max", 10), -dmg)
				EventBus.floating_text_requested.emit("-%d Trampa" % dmg, Color.CORAL, pos)
				EventBus.combat_log_appended.emit("¡%s pisó una trampa oculta y sufrió %d de daño!" % [h_name, dmg], "damage")

		Enums.CellType.CHEST:
			grid.set_cell_type(pos, Enums.CellType.FLOOR)
			if EventBus:
				EventBus.floating_text_requested.emit("+1 Poción de Vida", Color.GOLD, pos)
				EventBus.combat_log_appended.emit("¡%s abrió un cofre misterioso y encontró una Poción de Curación!" % h_name, "heal")

		Enums.CellType.ALTAR:
			grid.set_cell_type(pos, Enums.CellType.FLOOR)
			for p in grid.units_by_pos:
				var u = grid.units_by_pos[p]
				if u.get("is_hero", false) and u.get("is_alive", false):
					var heal: int = (randi() % 8) + 5
					u["hp"] = mini(u.get("hp_max", 10), u.get("hp", 10) + heal)
					if EventBus:
						EventBus.health_updated.emit(u.get("id", ""), u["hp"], u.get("hp_max", 10), heal)
						EventBus.floating_text_requested.emit("+%d HP" % heal, Color.GREEN, p)
			if EventBus:
				EventBus.combat_log_appended.emit("¡%s reza en el Altar Antiguo! Una luz celestial sana a todo el grupo." % h_name, "heal")

		Enums.CellType.BOOKSHELF:
			grid.set_cell_type(pos, Enums.CellType.FLOOR)
			if EventBus:
				EventBus.floating_text_requested.emit("+15 XP", Color.CYAN, pos)
				EventBus.combat_log_appended.emit("¡%s examina la Librería Olvidada y descubre un tomo arcano! (+15 XP)" % h_name, "crit")

func _check_for_combat(hero_pos: Vector2i) -> void:
	var game_manager = state_machine.get_parent()
	if not game_manager or not game_manager.tactical_grid: return
	var grid = game_manager.tactical_grid

	var nearby_enemy: Dictionary = {}
	var trigger: bool = false
	for pos in grid.units_by_pos:
		var unit = grid.units_by_pos[pos]
		if unit.get("is_hero", false): continue
		if not unit.get("is_alive", false): continue
		if grid.get_distance(hero_pos, pos) <= 2:
			trigger = true
			nearby_enemy = unit
			break

	if not trigger: return

	var heroes: Array = []
	var enemies: Array = []
	for pos in grid.units_by_pos:
		var unit = grid.units_by_pos[pos]
		if unit.get("data") == null: continue
		if unit.get("is_hero", false):
			heroes.append({"data": unit["data"], "pos": pos})
		else:
			enemies.append({"data": unit["data"], "pos": pos})

	print("ExplorationState: ¡Enemigo a la vista! Iniciando combate...")
	EventBus.combat_log_appended.emit("¡%s os ha detectado! ¡A las armas!" % nearby_enemy.get("name", "El enemigo"), "crit")
	state_machine.change_state(Enums.GameFlowState.COMBAT, {"heroes": heroes, "enemies": enemies})

# Fase 5c: colocación DJ con click (consume el intercept).
func _dj_place_at(grid_pos: Vector2i) -> void:
	var game_manager = state_machine.get_parent()
	var grid = game_manager.tactical_grid if game_manager else null
	if grid == null:
		return
	var token := ActLoader.spawn_enemy_at(grid, EventBus.dj_spawn_path, grid_pos)
	EventBus.dj_spawn_path = ""
	if token.is_empty():
		if EventBus: EventBus.combat_log_appended.emit("[DJ] Celda no válida para invocar.", "info")
		return
	if EventBus:
		EventBus.combat_log_appended.emit("[DJ] Invocado %s en [%d, %d]." % [token["name"], grid_pos.x, grid_pos.y], "crit")
		EventBus.redraw_requested.emit()

func reveal_fog_around(center: Vector2i, radius: int) -> void:
	if EventBus: EventBus.tile_revealed.emit(center, radius)

