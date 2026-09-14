class_name TacticalGrid
extends RefCounted

## Motor lógico y matemático de la cuadrícula táctica (independiente de la vista).
## Maneja posiciones, pathfinding A* ortogonal, cálculo de cobertura y registro de entidades.

const WIDTH = 24
const HEIGHT = 18

var _cells = {} # Vector2i -> Enums.CellType
var units_by_pos = {} # Vector2i -> Dictionary
var pos_by_unit_id = {} # String -> Vector2i

func _init():
	_cells.clear()
	units_by_pos.clear()
	pos_by_unit_id.clear()

func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < WIDTH and pos.y >= 0 and pos.y < HEIGHT

func is_walkable(pos: Vector2i, ignore_unit_at: Vector2i = Vector2i(-1, -1)) -> bool:
	if not is_in_bounds(pos): return false
	if get_cell_type(pos) == Enums.CellType.WALL: return false
	if units_by_pos.has(pos) and pos != ignore_unit_at:
		var unit = units_by_pos[pos]
		if unit.get("is_alive", true): return false
	return true

func get_cell_type(pos: Vector2i) -> Enums.CellType:
	return _cells.get(pos, Enums.CellType.FLOOR)

func set_cell_type(pos: Vector2i, type: Enums.CellType) -> void:
	if is_in_bounds(pos):
		_cells[pos] = type

func get_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

## Comprueba si hay un obstáculo o muro entre el atacante y el defensor que otorgue cobertura (+2 CA)
func has_diagonal_cover(attacker_pos: Vector2i, target_pos: Vector2i) -> bool:
	var dx = target_pos.x - attacker_pos.x
	var dy = target_pos.y - attacker_pos.y
	# Comprobar esquinas intermedias si el ataque es diagonal
	if abs(dx) >= 1 and abs(dy) >= 1:
		var corner_a = Vector2i(attacker_pos.x + sign(dx), attacker_pos.y)
		var corner_b = Vector2i(attacker_pos.x, attacker_pos.y + sign(dy))
		if get_cell_type(corner_a) == Enums.CellType.WALL or get_cell_type(corner_b) == Enums.CellType.WALL:
			return true
	return false

func get_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var deltas := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for d in deltas:
		var n = pos + d
		if is_in_bounds(n):
			neighbors.append(n)
	return neighbors

func find_path(start: Vector2i, goal: Vector2i, max_distance: int = 999) -> Array[Vector2i]:
	if not is_walkable(goal, start): return []
	if start == goal: return [start]

	var frontier: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: null}
	var cost_so_far: Dictionary = {start: 0}

	while not frontier.is_empty():
		frontier.sort_custom(func(a, b):
			var f_a = cost_so_far[a] + get_distance(a, goal)
			var f_b = cost_so_far[b] + get_distance(b, goal)
			return f_a < f_b
		)
		var current = frontier.pop_front()

		if current == goal:
			break

		for next in get_neighbors(current):
			if not is_walkable(next, start) and next != goal:
				continue
			var new_cost = cost_so_far[current] + 1
			if new_cost > max_distance:
				continue
			if not cost_so_far.has(next) or new_cost < cost_so_far[next]:
				cost_so_far[next] = new_cost
				came_from[next] = current
				frontier.append(next)

	if not came_from.has(goal):
		return []

	var path: Array[Vector2i] = []
	var curr = goal
	while curr != null:
		path.append(curr)
		curr = came_from[curr]
	path.reverse()
	return path

func register_unit(unit_data: Dictionary, pos: Vector2i) -> void:
	if not is_in_bounds(pos):
		return
	
	var u_id = unit_data.get("id")
	if u_id == null: return
	
	if pos_by_unit_id.has(u_id):
		var old_pos = pos_by_unit_id[u_id]
		units_by_pos.erase(old_pos)
	
	units_by_pos[pos] = unit_data
	pos_by_unit_id[u_id] = pos

func move_unit(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if not units_by_pos.has(from_pos): return false
	if not is_in_bounds(to_pos): return false
	if get_cell_type(to_pos) == Enums.CellType.WALL: return false
	if units_by_pos.has(to_pos) and to_pos != from_pos: return false
	
	var unit = units_by_pos[from_pos]
	var u_id = unit["id"]
	
	units_by_pos.erase(from_pos)
	units_by_pos[to_pos] = unit
	pos_by_unit_id[u_id] = to_pos
	
	return true

func get_unit_at(pos: Vector2i) -> Dictionary:
	return units_by_pos.get(pos, {})

