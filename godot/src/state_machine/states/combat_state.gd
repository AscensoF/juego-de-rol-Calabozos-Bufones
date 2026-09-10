class_name CombatState
extends State

## Estado de Combate Táctico: Iniciativa d20, economía de acciones por turno y condiciones de victoria/derrota.

var combat_heroes: Array[Dictionary] = []
var combat_enemies: Array[Dictionary] = []
var initiative_order: Array[Dictionary] = []
var current_turn_index: int = 0

# Economía de acción del turno activo
var current_unit: Dictionary = {}
var has_moved: bool = false
var has_acted: bool = false
var can_undo_move: bool = true

func _init() -> void:
	state_enum = Enums.GameFlowState.COMBAT

func enter(params: Dictionary = {}) -> void:
	if EventBus:
		EventBus.combat_started.emit()
		EventBus.status_panel_updated.emit("¡COMBATE! Tirando iniciativa...")
		EventBus.combat_log_appended.emit("<b>¡Comienza el combate! Prepárate para la táctica y la pifia.</b>", "game")

	_setup_combatants(params)
	roll_initiative()
	start_turn(0)

func exit() -> void:
	initiative_order.clear()
	current_unit.clear()

func _setup_combatants(params: Dictionary) -> void:
	combat_heroes.clear()
	combat_enemies.clear()

	var heroes: Array = params.get("heroes", [])
	for h in heroes:
		if h is HeroData:
			combat_heroes.append({
				"id": h.id,
				"name": h.hero_name,
				"is_hero": true,
				"data": h,
				"hp": h.base_hp,
				"hp_max": h.base_hp,
				"res": h.base_resource,
				"res_max": h.base_resource,
				"ac": h.base_ac,
				"speed": h.speed,
				"dex_mod": h.attributes.get_dex_mod() if h.attributes else 0,
				"buffs": [],
				"is_alive": true
			})

	var enemies: Array = params.get("enemies", [])
	for e in enemies:
		if e is EnemyData:
			combat_enemies.append({
				"id": e.id + "_" + str(randi() % 1000),
				"name": e.enemy_name,
				"is_hero": false,
				"data": e,
				"hp": e.base_hp,
				"hp_max": e.base_hp,
				"ac": e.armor_class,
				"speed": e.speed,
				"init_bonus": e.initiative_bonus,
				"buffs": [],
				"is_alive": true
			})

func roll_initiative() -> void:
	initiative_order.clear()

	# Tirada de Iniciativa: d20 + Modificador de Destreza / Bono
	for hero in combat_heroes:
		if hero["is_alive"]:
			var roll: int = (randi() % 20) + 1
			var total: int = roll + hero["dex_mod"]
			initiative_order.append({
				"id": hero["id"],
				"name": hero["name"],
				"is_hero": true,
				"roll": total,
				"unit_ref": hero
			})

	for enemy in combat_enemies:
		if enemy["is_alive"]:
			var roll: int = (randi() % 20) + 1
			var total: int = roll + enemy["init_bonus"]
			initiative_order.append({
				"id": enemy["id"],
				"name": enemy["name"],
				"is_hero": false,
				"roll": total,
				"unit_ref": enemy
			})

	# Ordenar de mayor a menor iniciativa
	initiative_order.sort_custom(func(a, b): return a["roll"] > b["roll"])

	if EventBus:
		EventBus.initiative_rolled.emit(initiative_order)
		for entry in initiative_order:
			EventBus.combat_log_appended.emit(
				"Iniciativa: %s obtiene %d" % [entry["name"], entry["roll"]], "info"
			)

func start_turn(index: int) -> void:
	if initiative_order.is_empty():
		return

	current_turn_index = index % initiative_order.size()
	current_unit = initiative_order[current_turn_index]["unit_ref"]

	if not current_unit.get("is_alive", false):
		next_turn()
		return

	has_moved = false
	has_acted = false
	can_undo_move = true

	if EventBus:
		EventBus.turn_started.emit(current_unit)
		EventBus.action_economy_updated.emit(has_moved, has_acted, can_undo_move)
		EventBus.status_panel_updated.emit("Turno de %s" % current_unit["name"])

func next_turn() -> void:
	if check_battle_end():
		return

	# Reducir duración de buffs/debuffs de la unidad saliente
	_tick_status_effects(current_unit)

	if EventBus:
		EventBus.turn_ended.emit(current_unit)

	start_turn(current_turn_index + 1)

func _tick_status_effects(unit: Dictionary) -> void:
	var buffs: Array = unit.get("buffs", [])
	var remaining: Array = []
	for b in buffs:
		b["duration"] -= 1
		if b["duration"] > 0:
			remaining.append(b)
		else:
			if EventBus:
				EventBus.status_removed.emit(unit["id"], b["type"])
	unit["buffs"] = remaining

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
		# Derrota del grupo
		if EventBus:
			EventBus.combat_ended.emit(false)
			EventBus.combat_log_appended.emit("<b>Todo el grupo ha caído... GAME OVER.</b>", "damage")
		state_machine.change_state(Enums.GameFlowState.GAME_OVER, {"victory": false})
		return true

	if not any_enemy_alive:
		# Victoria del combate
		var total_xp: int = 0
		for e in combat_enemies:
			var data: EnemyData = e.get("data")
			if data:
				total_xp += data.xp_reward

		if EventBus:
			EventBus.combat_ended.emit(true)
			EventBus.combat_log_appended.emit("<b>¡Victoria! Enemigos derrotados. Ganáis %d XP.</b>" % total_xp, "heal")

		state_machine.change_state(Enums.GameFlowState.EXPLORATION, {"xp_earned": total_xp})
		return true

	return false
