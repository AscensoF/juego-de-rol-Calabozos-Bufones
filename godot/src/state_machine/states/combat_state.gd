class_name CombatState
extends State

## Estado de Combate Táctico con Pacing Deliberado (Baldur's Gate / WFRP):
## - Barra de Iniciativa superior activa.
## - Banner de Anuncio de Turno con pausas claras.
## - Acciones enemigas secuenciadas y legibles sin abrumar.

var combat_heroes: Array = []
var combat_enemies: Array = []
var initiative_order: Array = []
var current_turn_index: int = 0

var current_unit: Dictionary = {}
var has_moved: bool = false
var has_acted: bool = false
var is_resolving: bool = false

func _init() -> void:
	state_enum = Enums.GameFlowState.COMBAT

func enter(params: Dictionary = {}) -> void:
	print("CombatState: ¡COMBATE! Tirando iniciativa...")
	_setup_combatants(params)
	roll_initiative()

	var gm = state_machine.get_parent()
	if gm and gm.has_method("focus_camera_on"):
		gm.focus_camera_on(_compute_combat_centroid(), 2.2)

	if EventBus:
		EventBus.combat_started.emit()
		EventBus.status_panel_updated.emit("¡COMBATE! Se ha tirado la iniciativa.")
		EventBus.cell_clicked.connect(_on_cell_clicked)

	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree(): return
	start_turn(0)

func exit() -> void:
	if EventBus and EventBus.cell_clicked.is_connected(_on_cell_clicked):
		EventBus.cell_clicked.disconnect(_on_cell_clicked)
	_clear_highlights()
	initiative_order.clear()
	combat_heroes.clear()
	combat_enemies.clear()
	current_unit.clear()

func _setup_combatants(params: Dictionary) -> void:
	combat_heroes.clear()
	combat_enemies.clear()

	var heroes: Array = params.get("heroes", [])
	for h in heroes:
		if h == null: continue
		var data = h.get("data")
		if data == null: continue
		var pos = h.get("pos", Vector2i.ZERO)
		var dex_mod := 2
		combat_heroes.append({
			"id": "hero_" + str(combat_heroes.size()),
			"name": data.get("hero_name") if data.get("hero_name") != null else "Héroe",
			"is_hero": true,
			"data": data,
			"pos": pos,
			"hp": data.get("base_hp") if data.get("base_hp") != null else 12,
			"hp_max": data.get("base_hp") if data.get("base_hp") != null else 12,
			"res": data.get("base_resource") if data.get("base_resource") != null else 4,
			"res_max": data.get("base_resource") if data.get("base_resource") != null else 4,
			"res_name": data.get("resource_name") if data.get("resource_name") != null else "Furia",
			"ac": data.get("base_ac") if data.get("base_ac") != null else 12,
			"speed": data.get("speed") if data.get("speed") != null else 4,
			"dex_mod": dex_mod,
			"buffs": [],
			"has_acted": false,
			"is_alive": true
		})

	var enemies: Array = params.get("enemies", [])
	for e in enemies:
		if e == null: continue
		var edata = e.get("data")
		if edata == null: continue
		var epos = e.get("pos", Vector2i.ZERO)
		combat_enemies.append({
			"id": "enemy_" + str(combat_enemies.size()),
			"name": edata.get("enemy_name") if edata.get("enemy_name") != null else "Enemigo",
			"is_hero": false,
			"data": edata,
			"pos": epos,
			"hp": edata.get("base_hp") if edata.get("base_hp") != null else 8,
			"hp_max": edata.get("base_hp") if edata.get("base_hp") != null else 8,
			"ac": edata.get("armor_class") if edata.get("armor_class") != null else 10,
			"speed": edata.get("speed") if edata.get("speed") != null else 3,
			"init_bonus": edata.get("initiative_bonus") if edata.get("initiative_bonus") != null else 0,
			"buffs": [],
			"has_acted": false,
			"is_alive": true
		})

func roll_initiative() -> void:
	initiative_order.clear()

	for hero in combat_heroes:
		if hero["is_alive"]:
			var roll: int = (randi() % 20) + 1
			initiative_order.append({
				"id": hero["id"], "name": hero["name"], "is_hero": true,
				"roll": roll + hero["dex_mod"], "unit_ref": hero
			})

	for enemy in combat_enemies:
		if enemy["is_alive"]:
			var roll: int = (randi() % 20) + 1
			initiative_order.append({
				"id": enemy["id"], "name": enemy["name"], "is_hero": false,
				"roll": roll + enemy["init_bonus"], "unit_ref": enemy
			})

	initiative_order.sort_custom(func(a, b): return a["roll"] > b["roll"])

	if EventBus:
		EventBus.initiative_rolled.emit(initiative_order)
		for entry in initiative_order:
			EventBus.combat_log_appended.emit(
				"Iniciativa: %s obtiene %d" % [entry["name"], entry["roll"]], "info"
			)

func start_turn(index: int) -> void:
	if check_battle_end(): return
	if initiative_order.is_empty(): return

	current_turn_index = index % initiative_order.size()
	current_unit = initiative_order[current_turn_index]["unit_ref"]

	if not current_unit.get("is_alive", false):
		start_turn(current_turn_index + 1)
		return

	current_unit["has_acted"] = false
	has_acted = false
	is_resolving = false

	_highlight_current_unit()

	var is_hero: bool = current_unit.get("is_hero", false)
	var u_name: String = current_unit.get("name", "Unidad")

	# Anuncio cinemático de cambio de turno con pausa clara
	if EventBus:
		EventBus.turn_started.emit(current_unit)
		if is_hero:
			EventBus.turn_banner_announced.emit("⚔️ TURNO DE TU HÉROE", u_name, true)
			EventBus.status_panel_updated.emit("Turno de %s — Selecciona una acción en la barra inferior o toca un objetivo." % u_name)
		else:
			EventBus.turn_banner_announced.emit("🐀 TURNO DEL ENEMIGO", u_name, false)
			EventBus.status_panel_updated.emit("Turno de %s (Pensando táctica...)" % u_name)

	if not is_hero:
		_execute_enemy_ai_turn()

func _highlight_current_unit() -> void:
	var gm = state_machine.get_parent()
	if gm and gm.grid_renderer:
		gm.grid_renderer.selected_cell = current_unit.get("pos", Vector2i(-1, -1))
		gm.grid_renderer.queue_redraw()

func _clear_highlights() -> void:
	var gm = state_machine.get_parent()
	if gm and gm.grid_renderer:
		gm.grid_renderer.selected_cell = Vector2i(-1, -1)
		gm.grid_renderer.queue_redraw()

func _execute_enemy_ai_turn() -> void:
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree(): return
	if not current_unit.get("is_alive", false): return

	var gm = state_machine.get_parent()
	var grid = gm.tactical_grid if gm else null
	if not grid:
		next_turn()
		return

	# 1. Encontrar al héroe vivo más cercano
	var target_hero: Dictionary = {}
	var min_dist: int = 9999
	var enemy_pos: Vector2i = current_unit.get("pos", Vector2i.ZERO)

	for h in combat_heroes:
		if h.get("is_alive", false):
			var d = grid.get_distance(enemy_pos, h.get("pos", Vector2i.ZERO))
			if d < min_dist:
				min_dist = d
				target_hero = h

	if target_hero.is_empty():
		next_turn()
		return

	var hero_pos: Vector2i = target_hero.get("pos", Vector2i.ZERO)

	# 2. Si el enemigo está a más de 1 casilla, se acerca usando A*
	if min_dist > 1:
		var speed: int = current_unit.get("speed", 3)
		var path = grid.find_path(enemy_pos, hero_pos, 20)
		if path.size() > 2:
			var steps = mini(speed, path.size() - 2)
			var new_pos = path[steps]
			grid.move_unit(enemy_pos, new_pos)
			current_unit["pos"] = new_pos
			if EventBus: EventBus.unit_moved.emit(current_unit["id"], enemy_pos, new_pos)
			_highlight_current_unit()
			await get_tree().create_timer(0.6).timeout
			if not is_inside_tree(): return
			enemy_pos = new_pos
			min_dist = grid.get_distance(enemy_pos, hero_pos)

	# 3. Si quedó a rango de ataque, asesta el golpe
	if min_dist <= 2:
		await get_tree().create_timer(0.3).timeout
		_resolve_attack(current_unit, target_hero)
		current_unit["has_acted"] = true
		await get_tree().create_timer(1.2).timeout # Pausa para que el jugador vea el resultado del daño
	else:
		if EventBus:
			EventBus.combat_log_appended.emit("%s se posiciona en las sombras." % current_unit["name"], "info")
		await get_tree().create_timer(0.8).timeout

	next_turn()

func _on_cell_clicked(grid_pos: Vector2i) -> void:
	if not current_unit.get("is_hero", false): return
	if current_unit.get("has_acted", false): return
	if is_resolving: return

	var clicked_enemy: Dictionary = {}
	for e in combat_enemies:
		if e.get("is_alive", false) and e.get("pos") == grid_pos:
			clicked_enemy = e
			break

	var target = clicked_enemy if not clicked_enemy.is_empty() else _get_first_alive_enemy()
	if target.is_empty(): return

	_resolve_attack(current_unit, target)
	current_unit["has_acted"] = true
	
	# Pausa deliberada tras el ataque del héroe antes de cambiar de turno
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree(): return
	next_turn()

func _resolve_attack(attacker: Dictionary, target: Dictionary) -> void:
	is_resolving = true
	var game_manager = state_machine.get_parent()
	var hud = game_manager.get_node_or_null("CanvasLayer/CombatHUD") if game_manager else null
	var selected_ab: AbilityData = hud.selected_ability if hud else null
	var grid = game_manager.tactical_grid if game_manager else null

	if selected_ab != null:
		var all_units: Array[Dictionary] = []
		for h in combat_heroes: all_units.append(h)
		for e in combat_enemies: all_units.append(e)
		var cmd := AbilityCommand.new(attacker, selected_ab, target, target.get("pos", Vector2i.ZERO), grid, all_units)
		var ok = cmd.execute()
		if not ok:
			var fallback_cmd := AttackCommand.new(attacker, target, grid)
			fallback_cmd.execute()
		hud.selected_ability = null
	else:
		var cmd := AttackCommand.new(attacker, target, grid)
		cmd.execute()

func _compute_combat_centroid() -> Vector2i:
	var sum := Vector2i.ZERO
	var count := 0
	for h in combat_heroes:
		if h.has("pos"):
			sum += h["pos"]
			count += 1
	for e in combat_enemies:
		if e.has("pos"):
			sum += e["pos"]
			count += 1
	if count == 0: return Vector2i.ZERO
	return Vector2i(int(sum.x / count), int(sum.y / count))

func _get_first_alive_enemy() -> Dictionary:
	for e in combat_enemies:
		if e.get("is_alive", false):
			return e
	return {}

func _get_first_alive_hero() -> Dictionary:
	for h in combat_heroes:
		if h.get("is_alive", false):
			return h
	return {}

func next_turn() -> void:
	if check_battle_end(): return
	# Fase 3: autosave por turno (PRODUCT_BIBLE: cero fricción).
	if EventBus: EventBus.turn_ended.emit(current_unit)
	start_turn(current_turn_index + 1)

func check_battle_end() -> bool:
	var any_hero_alive: bool = false
	for h in combat_heroes:
		if h["is_alive"]:
			any_hero_alive = true
			break

	var any_enemy_alive: bool = false
	for e in combat_enemies:
		if e["is_alive"]:
			any_enemy_alive = true
			break

	if not any_hero_alive:
		if EventBus:
			EventBus.combat_ended.emit(false)
			EventBus.combat_log_appended.emit("<b>Todo el grupo ha caído... GAME OVER.</b>", "damage")
		state_machine.change_state(Enums.GameFlowState.GAME_OVER, {"victory": false})
		return true

	if not any_enemy_alive:
		var total_xp: int = 0
		for e in combat_enemies:
			var data = e.get("data")
			if data != null and data.get("xp_reward") != null:
				total_xp += data.xp_reward

		if EventBus:
			EventBus.combat_ended.emit(true)
			EventBus.combat_log_appended.emit("<b>¡Victoria! Amenazas purgadas. Ganáis %d XP.</b>" % total_xp, "heal")

		state_machine.change_state(Enums.GameFlowState.GAME_OVER, {"victory": true})
		return true

	return false

