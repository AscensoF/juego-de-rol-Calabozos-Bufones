class_name AbilityCommand
extends CombatCommand

## Comando de Ejecución de Habilidad de Clase o Criatura.
## Gestiona deducción de recursos, requisitos posicionales, rebotes mágicos y efectos en área.

var ability: AbilityData
var target: Dictionary
var target_pos: Vector2i
var grid: TacticalGrid
var all_units: Array[Dictionary] = []

func _init(
	p_actor: Dictionary,
	p_ability: AbilityData,
	p_target: Dictionary,
	p_target_pos: Vector2i,
	p_grid: TacticalGrid,
	p_all_units: Array[Dictionary] = []
) -> void:
	command_name = p_ability.ability_name
	actor = p_actor
	ability = p_ability
	target = p_target
	target_pos = p_target_pos
	grid = p_grid
	all_units = p_all_units

func execute() -> bool:
	# 1. Comprobación de recurso (Furia, Maná, Astucia, Fe)
	var current_res: int = actor.get("res", 0)
	if current_res < ability.cost:
		if EventBus:
			EventBus.combat_log_appended.emit("Recurso insuficiente para usar %s." % ability.ability_name, "info")
		return false

	# 2. Comprobación de uso único por combate
	if ability.once_per_combat and actor.get("used_" + ability.id, false):
		if EventBus:
			EventBus.combat_log_appended.emit("%s ya ha usado %s en este combate." % [actor["name"], ability.ability_name], "info")
		return false

	# 3. Comprobación de aliado contiguo (Ataque Furtivo de Pícaro)
	if ability.requires_adjacent_ally:
		var has_ally: bool = grid.has_ally_adjacent_to(target.get("pos", Vector2i.ZERO), actor["id"], actor.get("is_hero", true))
		if not has_ally:
			if EventBus:
				EventBus.combat_log_appended.emit("Ataque Furtivo requiere un aliado contiguo al enemigo.", "info")
			return false

	# Deducción de recurso
	actor["res"] -= ability.cost
	if ability.once_per_combat:
		actor["used_" + ability.id] = true

	if EventBus:
		EventBus.resource_updated.emit(actor["id"], actor["res"], actor["res_max"], "")
		EventBus.combat_log_appended.emit("<b>%s activa: %s</b>" % [actor["name"], ability.ability_name], "crit")

	# 4. Ejecución según tipo de habilidad
	_execute_ability_logic()

	actor["has_acted"] = true
	return true

func _execute_ability_logic() -> void:
	match ability.id:
		"inmortal":
			actor["buffs"].append({"type": Enums.StatusEffectType.INVULNERABLE, "duration": 2})
			if EventBus:
				EventBus.status_applied.emit(actor["id"], Enums.StatusEffectType.INVULNERABLE, 2)
				EventBus.combat_log_appended.emit("¡%s se vuelve invulnerable!" % actor["name"], "crit")

		"grito_desafiante":
			actor["buffs"].append({"type": Enums.StatusEffectType.DEFENDING, "duration": 3, "ac": 2})
			for u in all_units:
				if not u.get("is_hero", false) and u.get("is_alive", false):
					if grid.get_distance(actor["pos"], u["pos"]) <= 3:
						u["buffs"].append({"type": Enums.StatusEffectType.TAUNTED, "duration": 2, "target_id": actor["id"]})
						if EventBus:
							EventBus.status_applied.emit(u["id"], Enums.StatusEffectType.TAUNTED, 2)

		"misil_magico":
			var dmg: int = DiceRoller.roll_dice(2, 4)
			_apply_damage_to_target(target, dmg, false, false)

		"tormenta_sarcasmo":
			for u in all_units:
				if not u.get("is_hero", false) and u.get("is_alive", false):
					if grid.get_distance(target_pos, u["pos"]) <= ability.area_radius:
						var dmg: int = DiceRoller.roll_dice(2, 8)
						_apply_damage_to_target(u, dmg, false, false)
						u["buffs"].append({"type": Enums.StatusEffectType.CONFUSED, "duration": 2})
						if EventBus:
							EventBus.status_applied.emit(u["id"], Enums.StatusEffectType.CONFUSED, 2)

		"singularidad_caotica":
			var dmg: int = DiceRoller.roll_dice(5, 6)
			_apply_damage_to_target(target, dmg, true, false)
			# Riesgo de autodestrucción/rebote si d20 <= 5
			var backlash_roll: int = (randi() % 20) + 1
			if backlash_roll <= ability.backlash_threshold:
				var self_dmg: int = maxi(1, int(dmg / 2))
				actor["hp"] = maxi(0, actor["hp"] - self_dmg)
				if EventBus:
					EventBus.health_updated.emit(actor["id"], actor["hp"], actor["hp_max"], -self_dmg)
					EventBus.combat_log_appended.emit("¡Rebote caótico! %s sufre %d de daño." % [actor["name"], self_dmg], "damage")

		"bolsillos_ajenos":
			var target_buffs: Array = target.get("buffs", [])
			if not target_buffs.is_empty():
				var stolen_buff: Dictionary = target_buffs.pop_back()
				actor["buffs"].append(stolen_buff)
				if EventBus:
					EventBus.combat_log_appended.emit("%s roba un estado beneficioso de %s." % [actor["name"], target["name"]], "heal")
			else:
				var dmg: int = DiceRoller.roll_dice(1, 4) + 2
				_apply_damage_to_target(target, dmg, false, false)

		"acto_desaparicion":
			actor["buffs"].append({"type": Enums.StatusEffectType.GUARANTEED_CRIT, "duration": 99})
			grid.move_unit_on_grid(actor["pos"], target_pos)
			if EventBus:
				EventBus.unit_moved.emit(actor["id"], actor["pos"], target_pos)
				EventBus.combat_log_appended.emit("%s se desvanece y prepara un golpe crítico garantizado." % actor["name"], "crit")

		"curar":
			var heal: int = DiceRoller.roll_dice(2, 4)
			var wis_mod: int = actor["data"].attributes.get_wis_mod() if actor.has("data") else 0
			heal += maxi(0, wis_mod)
			_apply_heal_to_target(target, heal)

		"intervencion_divina":
			var heal: int = DiceRoller.roll_dice(4, 8) + 5
			_apply_heal_to_target(target, heal)
			target["buffs"].append({"type": Enums.StatusEffectType.DIVINE_MIGHT, "duration": 2})
			if EventBus:
				EventBus.status_applied.emit(target["id"], Enums.StatusEffectType.DIVINE_MIGHT, 2)

		"palabra_divina":
			var radius: int = 4
			for u in all_units:
				if u.get("is_alive", false) and grid.get_distance(actor["pos"], u["pos"]) <= radius:
					if u.get("is_hero", false):
						var heal: int = DiceRoller.roll_dice(2, 8)
						_apply_heal_to_target(u, heal)
					else:
						var dmg: int = DiceRoller.roll_dice(2, 8)
						_apply_damage_to_target(u, dmg, false, false)

		_:
			# Habilidad estándar con tirada de combate regular
			var res := CombatRules.resolve_attack(
				actor, target, grid,
				ability.damage_dice_count,
				ability.damage_dice_sides,
				ability.damage_flat_bonus
			)
			if res["is_hit"]:
				_apply_damage_to_target(target, res["damage"], res["is_crit"], res["is_fumble"])

func _apply_damage_to_target(t: Dictionary, dmg: int, is_crit: bool, _is_fumble: bool) -> void:
	t["hp"] = maxi(0, t["hp"] - dmg)
	if EventBus:
		EventBus.health_updated.emit(t["id"], t["hp"], t["hp_max"], -dmg)
		EventBus.floating_text_requested.emit("-%d" % dmg, Color.GOLD if is_crit else Color.CORAL, t.get("pos", Vector2i.ZERO))
	if t["hp"] <= 0:
		t["is_alive"] = false
		if EventBus:
			EventBus.unit_defeated.emit(t["id"], t.get("is_hero", false), t.get("data", {}).xp_reward if t.has("data") else 0)

func _apply_heal_to_target(t: Dictionary, amount: int) -> void:
	t["hp"] = mini(t["hp_max"], t["hp"] + amount)
	if EventBus:
		EventBus.health_updated.emit(t["id"], t["hp"], t["hp_max"], amount)
		EventBus.floating_text_requested.emit("+%d" % amount, Color.GREEN, t.get("pos", Vector2i.ZERO))
		EventBus.heal_resolved.emit(actor["name"], t["name"], amount)
		EventBus.combat_log_appended.emit("%s cura %d PV a %s." % [actor["name"], amount, t["name"]], "heal")

func undo() -> bool:
	return false

func can_undo() -> bool:
	return false
