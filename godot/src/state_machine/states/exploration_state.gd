class_name ExplorationState
extends State

## Estado de Exploración: Cuadrícula 24x18, Niebla de Guerra dinámica, cofres, trampas y eventos.

var current_act: ActData
var party_heroes: Array[HeroData] = []
var active_enemies: Array[EnemyData] = []

const GRID_WIDTH: int = 24
const GRID_HEIGHT: int = 18
const VISION_RADIUS: int = 5

func _init() -> void:
	state_enum = Enums.GameFlowState.EXPLORATION

func enter(params: Dictionary = {}) -> void:
	print("ExplorationState: Entrando en fase de Exploración...")
	if params.has("act"):
		current_act = params["act"]
	if params.has("party"):
		party_heroes = params["party"]

	if EventBus:
		# Mostramos la UI de combate (HUD) para ver información de héroes y eventos
		var hud = state_machine.get_parent().get_node_or_null("CanvasLayer/CombatHUD")
		if hud:
			hud.show()
		
		EventBus.status_panel_updated.emit("Fase de Exploración: Muévete con libertad e interactúa con el entorno.")
		EventBus.combat_log_appended.emit("Entrando en zona desconocida. La niebla oculta los peligros...", "info")
		EventBus.cell_clicked.connect(_on_cell_clicked)
		EventBus.dj_mode_toggled.connect(_on_dj_mode_toggled)

func exit() -> void:
	if EventBus:
		if EventBus.cell_clicked.is_connected(_on_cell_clicked):
			EventBus.cell_clicked.disconnect(_on_cell_clicked)
		if EventBus.dj_mode_toggled.is_connected(_on_dj_mode_toggled):
			EventBus.dj_mode_toggled.disconnect(_on_dj_mode_toggled)

func _on_cell_clicked(grid_pos: Vector2i) -> void:
	# Verificación de límites de la cuadrícula táctica
	if grid_pos.x < 0 or grid_pos.x >= GRID_WIDTH or grid_pos.y < 0 or grid_pos.y >= GRID_HEIGHT:
		return

	print("ExplorationState: Clic en celda ", grid_pos)
	
	# 1. Revelación de niebla alrededor de la nueva posición
	reveal_fog_around(grid_pos, VISION_RADIUS)
	
	# 2. Mover un héroe seleccionado a esa celda (simularemos mover el primer héroe por ahora)
	var game_manager = state_machine.get_parent()
	if game_manager and game_manager.tactical_grid:
		var grid = game_manager.tactical_grid
		# Buscamos la posición actual de nuestro primer héroe (Throg)
		for pos in grid.units_by_pos:
			var unit = grid.units_by_pos[pos]
			if unit.get("is_hero") == true:
				# Calculamos si está al alcance de un movimiento simple (heurística básica)
				var dist = grid.get_distance(pos, grid_pos)
				if dist <= unit.get("speed", 4):
					grid.move_unit(pos, grid_pos)
					print("Movido héroe a ", grid_pos)
					# Comprobamos interacciones en la nueva celda
					_check_cell_interaction(grid_pos, unit)
					# Y comprobamos si hemos revelado enemigos
					check_enemy_encounter()
					break

func _check_cell_interaction(pos: Vector2i, unit: Dictionary) -> void:
	var game_manager = state_machine.get_parent()
	if not game_manager or not game_manager.tactical_grid: return
	
	var cell_type = game_manager.tactical_grid.get_cell_type(pos)
	var hero_name = unit.get("name", "Héroe")
	
	match cell_type:
		Enums.CellType.TRAP:
			trigger_trap(hero_name, pos)
		Enums.CellType.CHEST:
			# Creamos un item temporal para simular el loot
			var dummy_item = ItemData.new()
			dummy_item.item_name = "Poción Misteriosa"
			interact_with_chest(hero_name, dummy_item, pos)
		Enums.CellType.ALTAR:
			interact_with_altar()
		Enums.CellType.BOOKSHELF:
			interact_with_bookshelf()

func reveal_fog_around(center: Vector2i, radius: int) -> void:
	if EventBus:
		EventBus.tile_revealed.emit(center, radius)

func trigger_trap(hero_name: String, pos: Vector2i) -> void:
	var damage: int = (randi() % 6) + 1 # 1d6 de daño por trampa
	if EventBus:
		EventBus.trap_triggered.emit(hero_name, damage, pos)
		EventBus.floating_text_requested.emit("-%d" % damage, Color.RED, pos)
		EventBus.combat_log_appended.emit("¡%s ha pisado una trampa oculta y sufre %d de daño!" % [hero_name, damage], "damage")

func interact_with_chest(hero_name: String, item: ItemData, pos: Vector2i) -> void:
	if EventBus:
		EventBus.chest_opened.emit(hero_name, item, pos)
		EventBus.combat_log_appended.emit("%s abre un cofre y encuentra: %s." % [hero_name, item.item_name], "heal")

func interact_with_altar() -> void:
	var dialogs := [
		"El altar de piedra está dedicado a una deidad menor del 'Caos Organizado'. Sientes propósito y confusión.",
		"Una inscripción reza: 'Por favor, no dejar ofrendas. El conserje está de vacaciones'. Dejas una moneda por si acaso.",
		"Al tocar el altar, una voz resuena: 'Hemos intentado contactarle acerca de la garantía extendida de su alma...'"
	]
	var chosen: String = dialogs[randi() % dialogs.size()]
	if EventBus:
		EventBus.altar_interacted.emit(chosen)
		EventBus.combat_log_appended.emit("[Altar] %s" % chosen, "info")

func interact_with_bookshelf() -> void:
	var dialogs := [
		"Encuentras manuales incomprensibles. Uno se titula: 'Cómo Fingir que Entiendes la Magia'.",
		"Libro de cocina: 'Estofado de Limo Nostálgico'. Promete sabor a infancia y arrepentimiento.",
		"Un tomo polvoriento se titula: 'Y entonces, todo salió terriblemente mal'."
	]
	var chosen: String = dialogs[randi() % dialogs.size()]
	if EventBus:
		EventBus.bookshelf_interacted.emit(chosen)
		EventBus.combat_log_appended.emit("[Librería] %s" % chosen, "info")

func check_enemy_encounter() -> void:
	# Simulación simple: si hay un enemigo cerca del héroe, entramos en combate.
	var game_manager = state_machine.get_parent()
	if not game_manager or not game_manager.tactical_grid: return
	
	var grid = game_manager.tactical_grid
	var enemies_in_sight = []
	var heroes = []
	
	for pos in grid.units_by_pos:
		var unit = grid.units_by_pos[pos]
		if unit.get("is_hero") == true:
			heroes.append(unit.get("data"))
		else:
			# Si el enemigo ya está revelado (sin niebla)
			if not game_manager.grid_renderer.fog_matrix.get(pos, true):
				enemies_in_sight.append(unit.get("data"))
	
	if enemies_in_sight.size() > 0:
		print("ExplorationState: Enemigo a la vista. ¡Iniciando Combate!")
		state_machine.change_state(Enums.GameFlowState.COMBAT, {
			"enemies": enemies_in_sight,
			"heroes": heroes
		})

func _on_dj_mode_toggled(is_active: bool) -> void:
	if is_active:
		state_machine.change_state(Enums.GameFlowState.DJ_MODE)

