class_name TacticalGrid
extends RefCounted

## Motor lógico y matemático de la cuadrícula táctica (independiente de la vista).
## Maneja posiciones, pathfinding básico (Manhattan/BFS) y registro de entidades (héroes/enemigos).

const WIDTH = 24
const HEIGHT = 18

var _cells = {} # Vector2i -> Enums.CellType
var units_by_pos = {} # Vector2i -> Dictionary (Datos de la unidad)
var pos_by_unit_id = {} # String (unit_id) -> Vector2i

func _init():
	_cells.clear()
	units_by_pos.clear()
	pos_by_unit_id.clear()

func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < WIDTH and pos.y >= 0 and pos.y < HEIGHT

func get_cell_type(pos: Vector2i) -> Enums.CellType:
	return _cells.get(pos, Enums.CellType.FLOOR)

func set_cell_type(pos: Vector2i, type: Enums.CellType) -> void:
	if is_in_bounds(pos):
		_cells[pos] = type

func get_distance(a: Vector2i, b: Vector2i) -> int:
	# Distancia de Manhattan (ideal para grids ortogonales sin diagonales gratis)
	return abs(a.x - b.x) + abs(a.y - b.y)

func register_unit(unit_data: Dictionary, pos: Vector2i) -> void:
	if not is_in_bounds(pos):
		return
	
	var u_id = unit_data.get("id")
	if u_id == null: return
	
	# Limpiar posición anterior si existe
	if pos_by_unit_id.has(u_id):
		var old_pos = pos_by_unit_id[u_id]
		units_by_pos.erase(old_pos)
	
	units_by_pos[pos] = unit_data
	pos_by_unit_id[u_id] = pos

func move_unit(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if not units_by_pos.has(from_pos): return false
	if not is_in_bounds(to_pos): return false
	if get_cell_type(to_pos) == Enums.CellType.WALL: return false
	if units_by_pos.has(to_pos): return false # Celda ocupada por otra unidad
	
	var unit = units_by_pos[from_pos]
	var u_id = unit["id"]
	
	units_by_pos.erase(from_pos)
	units_by_pos[to_pos] = unit
	pos_by_unit_id[u_id] = to_pos
	
	return true

func get_unit_at(pos: Vector2i) -> Dictionary:
	return units_by_pos.get(pos, {})

