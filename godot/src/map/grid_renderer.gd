class_name GridRenderer
extends Node2D

## Renderizador 2D procedimental de la cuadrícula táctica 24x18, niebla de guerra y tokens.
## Dibuja lo que dicta la lógica de TacticalGrid y maneja el input del ratón/dedo.

@export var tile_size: float = 32.0
@export var grid_origin: Vector2 = Vector2(100, 50) # Desplazado para centrar mejor en 1280x720

var tactical_grid: TacticalGrid
var fog_matrix: Dictionary = {} # Vector2i -> bool (true = oculto)
var reachable_cells: Array[Vector2i] = []
var hovered_cell: Vector2i = Vector2i(-1, -1)
var fog_disabled: bool = false # Para testing/DJ mode

# Paleta de colores táctica
const COLOR_FLOOR := Color(0.12, 0.16, 0.23, 1.0)
const COLOR_WALL := Color(0.28, 0.33, 0.41, 1.0)
const COLOR_DOOR := Color(0.47, 0.21, 0.06, 1.0)
const COLOR_TRAP := Color(0.72, 0.11, 0.11, 0.8)
const COLOR_CHEST := Color(0.85, 0.47, 0.02, 1.0)
const COLOR_ALTAR := Color(0.03, 0.57, 0.70, 1.0)
const COLOR_BOOKSHELF := Color(0.71, 0.33, 0.04, 1.0)
const COLOR_FOG := Color(0.04, 0.06, 0.10, 0.96)
const COLOR_HIGHLIGHT := Color(0.13, 0.77, 0.37, 0.4)

func _ready() -> void:
	print("GridRenderer: Inicializando vista del tablero...")
	_init_fog()
	_subscribe_events()

func _init_fog() -> void:
	# En TacticalGrid tenemos WIDTH=24, HEIGHT=18
	for y in 18:
		for x in 24:
			fog_matrix[Vector2i(x, y)] = true

func _subscribe_events() -> void:
	if not EventBus: return
	EventBus.tile_revealed.connect(_on_tile_revealed)
	EventBus.dj_fog_cleared.connect(_on_dj_fog_cleared)
	EventBus.dj_cell_painted.connect(_on_dj_cell_painted)
	EventBus.unit_moved.connect(func(_id, _from, _to): queue_redraw())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := world_to_grid(event.position)
		if cell != hovered_cell:
			hovered_cell = cell
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := world_to_grid(event.position)
		if tactical_grid and tactical_grid.is_in_bounds(cell):
			if EventBus:
				EventBus.cell_clicked.emit(cell)
			queue_redraw()

func world_to_grid(pos: Vector2) -> Vector2i:
	var local_pos := pos - grid_origin
	return Vector2i(int(floor(local_pos.x / tile_size)), int(floor(local_pos.y / tile_size)))

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return grid_origin + Vector2(grid_pos.x * tile_size, grid_pos.y * tile_size)

func _draw() -> void:
	if not tactical_grid: return

	# 1. Dibujar el mapa base (suelo, muros, cofres...)
	for y in tactical_grid.HEIGHT:
		for x in tactical_grid.WIDTH:
			var cell := Vector2i(x, y)
			var rect := Rect2(grid_to_world(cell), Vector2(tile_size - 1.0, tile_size - 1.0))
			var cell_type = tactical_grid.get_cell_type(cell)
			var cell_color = _get_cell_color(cell_type)
			draw_rect(rect, cell_color, true)

	# 2. Dibujar celdas alcanzables (movimiento táctico)
	for h_cell in reachable_cells:
		var h_rect := Rect2(grid_to_world(h_cell), Vector2(tile_size - 1.0, tile_size - 1.0))
		draw_rect(h_rect, COLOR_HIGHLIGHT, true)
		draw_rect(h_rect, Color.GREEN, false, 1.5)

	# 3. Dibujar Tokens (Héroes y Enemigos)
	for pos in tactical_grid.units_by_pos.keys():
		var unit = tactical_grid.units_by_pos[pos]
		if unit.get("is_alive", false):
			var center: Vector2 = grid_to_world(pos) + Vector2(tile_size * 0.5, tile_size * 0.5)
			var is_hero: bool = unit.get("is_hero", false)
			var token_color := Color.DODGER_BLUE if is_hero else Color.CRIMSON
			draw_circle(center, tile_size * 0.38, token_color)
			draw_arc(center, tile_size * 0.38, 0, TAU, 16, Color.WHITE, 1.5)
			
			# Mini barra de HP encima del token
			var hp_ratio = float(unit.get("hp", 1)) / float(unit.get("hp_max", 1))
			var bar_rect = Rect2(center.x - (tile_size*0.4), center.y - (tile_size*0.45), tile_size*0.8, 4)
			draw_rect(bar_rect, Color.BLACK, true)
			var fill_rect = Rect2(bar_rect.position, Vector2(bar_rect.size.x * hp_ratio, bar_rect.size.y))
			draw_rect(fill_rect, Color.GREEN if is_hero else Color.RED, true)

	# 4. Capa de Niebla (Fog of War)
	if not fog_disabled:
		for y in tactical_grid.HEIGHT:
			for x in tactical_grid.WIDTH:
				var cell := Vector2i(x, y)
				if fog_matrix.get(cell, true):
					var fog_rect := Rect2(grid_to_world(cell), Vector2(tile_size, tile_size))
					draw_rect(fog_rect, COLOR_FOG, true)

	# 5. Cursor Hover
	if tactical_grid.is_in_bounds(hovered_cell):
		var hover_rect := Rect2(grid_to_world(hovered_cell), Vector2(tile_size, tile_size))
		draw_rect(hover_rect, Color(1.0, 1.0, 0.4, 0.5), false, 2.0)

func _get_cell_color(type: int) -> Color:
	match type:
		Enums.CellType.WALL: return COLOR_WALL
		Enums.CellType.DOOR: return COLOR_DOOR
		Enums.CellType.TRAP: return COLOR_TRAP
		Enums.CellType.CHEST: return COLOR_CHEST
		Enums.CellType.ALTAR: return COLOR_ALTAR
		Enums.CellType.BOOKSHELF: return COLOR_BOOKSHELF
		_: return COLOR_FLOOR

func _on_tile_revealed(center: Vector2i, radius: int) -> void:
	# Matemática pura: Despejar un área cuadrada (ideal para móvil)
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var p := Vector2i(center.x + dx, center.y + dy)
			if tactical_grid and tactical_grid.is_in_bounds(p):
				# Distancia Chebyshev para un FOV cuadrado, o Manhattan para rombo
				if tactical_grid.get_distance(center, p) <= radius:
					fog_matrix[p] = false
	queue_redraw()

func _on_dj_fog_cleared(cleared: bool) -> void:
	fog_disabled = cleared
	queue_redraw()

func _on_dj_cell_painted(type: int, pos: Vector2i) -> void:
	if tactical_grid:
		tactical_grid.set_cell_type(pos, type as Enums.CellType)
		queue_redraw()

