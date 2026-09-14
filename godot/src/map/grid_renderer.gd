class_name GridRenderer
extends Node2D

@export var tile_size: float = 32.0
@export var grid_origin: Vector2 = Vector2(100, 50)

var tactical_grid: TacticalGrid
var fog_matrix: Dictionary = {}
var reachable_cells: Array[Vector2i] = []
var hovered_cell: Vector2i = Vector2i(-1, -1)
var selected_cell: Vector2i = Vector2i(-1, -1)
var current_path: Array[Vector2i] = []
var fog_disabled: bool = false
var loaded_textures: Dictionary = {}

var floating_texts: Array = []
var fog_reveal_times: Dictionary = {}
var last_fog_reveal_ms: int = 0
var flash_units: Dictionary = {}

# Paleta y estilos visuales 2.5D
const COLOR_FLOOR_A := Color(0.14, 0.17, 0.24, 1.0)
const COLOR_FLOOR_B := Color(0.12, 0.15, 0.21, 1.0)
const COLOR_WALL_TOP := Color(0.32, 0.38, 0.48, 1.0)
const COLOR_WALL_FRONT := Color(0.20, 0.24, 0.32, 1.0)
const COLOR_WALL_BORDER := Color(0.10, 0.12, 0.16, 1.0)

const COLOR_DOOR := Color(0.55, 0.28, 0.10, 1.0)
const COLOR_TRAP := Color(0.75, 0.15, 0.15, 0.85)
const COLOR_CHEST := Color(0.90, 0.60, 0.10, 1.0)
const COLOR_ALTAR := Color(0.10, 0.65, 0.80, 1.0)
const COLOR_BOOKSHELF := Color(0.60, 0.35, 0.15, 1.0)

const COLOR_FOG := Color(0.02, 0.03, 0.05, 0.98)
const COLOR_GRID_LINE := Color(0.0, 0.0, 0.0, 0.25)
const COLOR_HIGHLIGHT := Color(0.15, 0.80, 0.40, 0.35)
const COLOR_PATH_LINE := Color(0.25, 0.85, 1.0, 0.85)
const FOG_FADE_DURATION := 0.6

var torch_time: float = 0.0

func _ready() -> void:
	_init_fog()
	_subscribe_events()

func _init_fog() -> void:
	for y in 18:
		for x in 24:
			fog_matrix[Vector2i(x, y)] = true

func _subscribe_events() -> void:
	if not EventBus: return
	EventBus.tile_revealed.connect(_on_tile_revealed)
	EventBus.dj_fog_cleared.connect(_on_dj_fog_cleared)
	EventBus.dj_cell_painted.connect(_on_dj_cell_painted)
	EventBus.unit_moved.connect(func(_id, _from, _to): queue_redraw())
	EventBus.floating_text_requested.connect(_on_floating_text_requested)
	EventBus.health_updated.connect(_on_health_updated_flash)

func _on_health_updated_flash(unit_id: String, _hp: int, _hp_max: int, delta_hp: int) -> void:
	if delta_hp < 0:
		flash_units[unit_id] = 0.35

func _process(delta: float) -> void:
	torch_time += delta * 3.0
	var needs_redraw := true
	
	if not floating_texts.is_empty():
		var remove_indices: Array = []
		for i in floating_texts.size():
			var ft: Dictionary = floating_texts[i]
			ft["age"] = ft["age"] + delta
			ft["pos"] = ft["pos"] + Vector2(0.0, -40.0 * delta)
			if ft["age"] >= ft["lifetime"]:
				remove_indices.append(i)
		for i in range(remove_indices.size() - 1, -1, -1):
			floating_texts.remove_at(remove_indices[i])

	if not flash_units.is_empty():
		var expired: Array = []
		for uid in flash_units.keys():
			flash_units[uid] -= delta
			if flash_units[uid] <= 0.0:
				expired.append(uid)
		for uid in expired:
			flash_units.erase(uid)
	
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := world_to_grid(event.position)
		if cell != hovered_cell:
			hovered_cell = cell
			_update_hover_path()
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := world_to_grid(event.position)
		if tactical_grid and tactical_grid.is_in_bounds(cell):
			if EventBus: EventBus.cell_clicked.emit(cell)
			queue_redraw()

func _update_hover_path() -> void:
	if not tactical_grid or selected_cell == Vector2i(-1, -1) or hovered_cell == Vector2i(-1, -1):
		current_path.clear()
		return
	
	if reachable_cells.has(hovered_cell):
		current_path = tactical_grid.find_path(selected_cell, hovered_cell)
	else:
		current_path.clear()

func world_to_grid(pos: Vector2) -> Vector2i:
	var canvas_transform = get_canvas_transform()
	var local_pos = (canvas_transform.affine_inverse() * pos) - grid_origin
	return Vector2i(int(floor(local_pos.x / tile_size)), int(floor(local_pos.y / tile_size)))

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return grid_origin + Vector2(grid_pos.x * tile_size, grid_pos.y * tile_size)

func _get_unit_texture(unit: Dictionary) -> Texture2D:
	var is_hero: bool = unit.get("is_hero", false)
	var u_name: String = unit.get("name", "").to_lower()
	var path := ""
	
	if is_hero:
		if "throg" in u_name: path = "res://assets/sprites/characters/heroes/throg.png"
		elif "elowen" in u_name: path = "res://assets/sprites/characters/heroes/elowen.png"
		elif "grimble" in u_name: path = "res://assets/sprites/characters/heroes/grimble.png"
		elif "beryl" in u_name: path = "res://assets/sprites/characters/heroes/beryl.png"
	else:
		if "goblin" in u_name: path = "res://assets/sprites/characters/enemies/goblin.png"
		elif "esqueleto" in u_name: path = "res://assets/sprites/characters/enemies/esqueleto.png"
		elif "orco" in u_name: path = "res://assets/sprites/characters/enemies/rey_orco.png"
	
	if path == "": return null
	if loaded_textures.has(path): return loaded_textures[path]
	
	var tex = load(path)
	if tex: loaded_textures[path] = tex
	return tex

func _draw() -> void:
	if not tactical_grid: return

	# 1. Base del mapa con textura procedural y relieve de muros
	for y in tactical_grid.HEIGHT:
		for x in tactical_grid.WIDTH:
			var cell := Vector2i(x, y)
			var rect := Rect2(grid_to_world(cell), Vector2(tile_size, tile_size))
			var cell_type = tactical_grid.get_cell_type(cell)
			
			if cell_type == Enums.CellType.WALL:
				# Muro con relieve 2.5D
				draw_rect(rect, COLOR_WALL_FRONT, true)
				var top_rect := Rect2(rect.position, Vector2(tile_size, tile_size * 0.7))
				draw_rect(top_rect, COLOR_WALL_TOP, true)
				draw_rect(rect, COLOR_WALL_BORDER, false, 1.0)
			else:
				# Suelo ajedrezado sutil
				var floor_col = COLOR_FLOOR_A if (x + y) % 2 == 0 else COLOR_FLOOR_B
				draw_rect(rect, floor_col, true)
				draw_rect(rect, COLOR_GRID_LINE, false, 0.8)
				
				# Elementos especiales
				_draw_special_cell_decor(cell_type, rect)

	# Celdas accesibles con resalte suave
	for h_cell in reachable_cells:
		var h_rect := Rect2(grid_to_world(h_cell), Vector2(tile_size, tile_size))
		draw_rect(h_rect, COLOR_HIGHLIGHT, true)
		draw_rect(h_rect, Color(0.2, 0.9, 0.4, 0.9), false, 1.5)

	# 2. Línea de Ruta A* con pulsación
	if current_path.size() > 1:
		for i in range(current_path.size() - 1):
			var p1 = grid_to_world(current_path[i]) + Vector2(tile_size * 0.5, tile_size * 0.5)
			var p2 = grid_to_world(current_path[i + 1]) + Vector2(tile_size * 0.5, tile_size * 0.5)
			draw_line(p1, p2, COLOR_PATH_LINE, 3.5, true)
			draw_circle(p2, 4.5, Color.CYAN)

	# 3. Luz cálida de antorcha alrededor de los héroes
	var torch_flicker = 1.0 + sin(torch_time) * 0.08
	for pos in tactical_grid.units_by_pos.keys():
		var unit = tactical_grid.units_by_pos[pos]
		if unit.get("is_hero", false) and unit.get("is_alive", false):
			var center = grid_to_world(pos) + Vector2(tile_size * 0.5, tile_size * 0.5)
			draw_circle(center, tile_size * 1.8 * torch_flicker, Color(1.0, 0.75, 0.3, 0.07))

	# 4. Sombras, Sprites y Destellos
	for pos in tactical_grid.units_by_pos.keys():
		var unit = tactical_grid.units_by_pos[pos]
		if unit.get("is_alive", false):
			var hidden_in_fog = fog_matrix.get(pos, true) and not fog_disabled
			if not unit.get("is_hero", false) and hidden_in_fog: continue

			var world_pos = grid_to_world(pos)
			var center = world_pos + Vector2(tile_size * 0.5, tile_size * 0.5)
			
			draw_circle(center + Vector2(0, tile_size * 0.3), tile_size * 0.28, Color(0, 0, 0, 0.45))
			
			var u_id: String = unit.get("id", "")
			if flash_units.has(u_id):
				var flash_alpha = clamp(flash_units[u_id] / 0.35, 0.0, 0.8)
				draw_circle(center, tile_size * 0.5, Color(1.0, 0.15, 0.15, flash_alpha))

			var tex = _get_unit_texture(unit)
			if tex:
				var tex_size = tex.get_size()
				var scale = (tile_size * 0.95) / max(tex_size.x, tex_size.y)
				var scaled_size = tex_size * scale
				var dest_rect = Rect2(world_pos + (Vector2(tile_size, tile_size) - scaled_size) / 2.0, scaled_size)
				draw_texture_rect(tex, dest_rect, false)
			
			var hp_ratio = float(unit.get("hp", 1)) / float(max(unit.get("hp_max", 1), 1))
			var bar_rect = Rect2(center.x - (tile_size*0.4), center.y - (tile_size*0.55), tile_size*0.8, 4)
			draw_rect(bar_rect, Color(0, 0, 0, 0.8), true)
			draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * hp_ratio, bar_rect.size.y)), Color(0.2, 0.85, 0.3) if unit.get("is_hero") else Color(0.9, 0.25, 0.25), true)

	# 5. Niebla de Guerra suave
	if not fog_disabled:
		var now := Time.get_ticks_msec()
		for y in tactical_grid.HEIGHT:
			for x in tactical_grid.WIDTH:
				var cell := Vector2i(x, y)
				if fog_matrix.get(cell, true):
					var fog_rect := Rect2(grid_to_world(cell), Vector2(tile_size, tile_size))
					draw_rect(fog_rect, COLOR_FOG, true)
				elif fog_reveal_times.has(cell):
					var elapsed := float(now - fog_reveal_times[cell]) / 1000.0
					var alpha := 1.0 - elapsed / FOG_FADE_DURATION
					if alpha > 0.0:
						var fog_rect := Rect2(grid_to_world(cell), Vector2(tile_size, tile_size))
						draw_rect(fog_rect, Color(COLOR_FOG.r, COLOR_FOG.g, COLOR_FOG.b, COLOR_FOG.a * alpha), true)

	# 6. Celda Seleccionada y Hover
	if tactical_grid.is_in_bounds(selected_cell):
		var sel_rect := Rect2(grid_to_world(selected_cell), Vector2(tile_size, tile_size))
		draw_rect(sel_rect, Color(1.0, 0.85, 0.2, 0.35), true)
		draw_rect(sel_rect, Color.GOLD, false, 2.5)

	if tactical_grid.is_in_bounds(hovered_cell) and not fog_matrix.get(hovered_cell, false):
		var hover_rect := Rect2(grid_to_world(hovered_cell), Vector2(tile_size, tile_size))
		draw_rect(hover_rect, Color(1.0, 1.0, 0.5, 0.5), false, 2.0)

	# 7. Textos flotantes
	var font := ThemeDB.fallback_font
	for ft in floating_texts:
		var alpha: float = clamp(1.0 - float(ft["age"]) / float(ft["lifetime"]), 0.0, 1.0)
		var col := Color(ft["color"].r, ft["color"].g, ft["color"].b, alpha)
		var outline := Color(0, 0, 0, alpha)
		var pos: Vector2 = ft["pos"]
		draw_string(font, pos + Vector2(1, 1), ft["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 18, outline)
		draw_string(font, pos, ft["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 18, col)

func _draw_special_cell_decor(type: int, rect: Rect2) -> void:
	var center = rect.get_center()
	match type:
		Enums.CellType.TRAP:
			draw_rect(Rect2(center - Vector2(6, 6), Vector2(12, 12)), COLOR_TRAP, true)
		Enums.CellType.CHEST:
			draw_rect(Rect2(center - Vector2(8, 6), Vector2(16, 12)), COLOR_CHEST, true)
			draw_rect(Rect2(center - Vector2(8, 6), Vector2(16, 12)), Color.BLACK, false, 1.0)
		Enums.CellType.ALTAR:
			draw_circle(center, 9.0, COLOR_ALTAR)
			draw_circle(center, 4.0, Color.WHITE)
		Enums.CellType.BOOKSHELF:
			draw_rect(Rect2(center - Vector2(10, 8), Vector2(20, 16)), COLOR_BOOKSHELF, true)
			draw_line(center - Vector2(8, 0), center + Vector2(8, 0), Color.BLACK, 2.0)

func _on_floating_text_requested(text: String, color: Color, grid_pos: Vector2i) -> void:
	var world_pos := grid_to_world(grid_pos) + Vector2(tile_size * 0.5, tile_size * 0.15)
	floating_texts.append({
		"text": text,
		"color": color,
		"pos": world_pos,
		"age": 0.0,
		"lifetime": 1.2
	})

func _on_tile_revealed(center: Vector2i, radius: int) -> void:
	var now := Time.get_ticks_msec()
	last_fog_reveal_ms = now
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var p := Vector2i(center.x + dx, center.y + dy)
			if tactical_grid and tactical_grid.is_in_bounds(p):
				if tactical_grid.get_distance(center, p) <= radius:
					fog_matrix[p] = false
					fog_reveal_times[p] = now
	queue_redraw()

func _on_dj_fog_cleared(cleared: bool) -> void:
	fog_disabled = cleared
	queue_redraw()

func _on_dj_cell_painted(type: int, pos: Vector2i) -> void:
	if tactical_grid:
		tactical_grid.set_cell_type(pos, type as Enums.CellType)
		queue_redraw()

