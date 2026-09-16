class_name AbilityCommand
extends CombatCommand

## Comando de Ejecución de Habilidad de Warhammer Fantasy (Old World).
## Soporta Vientos de Aqshy, Disfunciones de la Disformidad, Armas de Pólvora y Plegarias de Sigmar.

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
	var current_res: int = actor.get("res", 0)
	if current_res < ability.cost:
		if EventBus:
			EventBus.combat_log_appended.emit("Recurso insuficiente (%s) para activar %s." % [actor.get("res_name", "Recurso"), ability.ability_name], "info")
		return false

	# Deducción de recurso
	actor["res"] -= ability.cost
	if EventBus:
		EventBus.resource_updated.emit(actor["id"], actor["res"], actor.get("res_max", 10), actor.get("res_name", ""))
		EventBus.combat_log_appended.emit("<b>%s activa: %s</b>" % [actor["name"], ability.ability_name], "crit")

	_execute_warhammer_ability()
	actor["has_acted"] = true
	return true

func _execute_warhammer_ability() -> void:
	match ability.id:
		"ab_golpe_matador":
			# Tajo de Gromril (Gotreksson): Daño masivo y chequeo de crítico
			var res := CombatRules.resolve_attack(actor, target, grid, 2, 6, 3)
			if res["is_hit"]:
				_apply_damage_to_target(target, res["damage"], res["is_crit"])
				if EventBus: EventBus.combat_log_appended.emit("¡El hacha de Gromril hiende la carne del enemigo infligiendo %d de daño!" % res["damage"], "damage")

		"ab_disparo_polvora":
			# Virote de Plata & Pólvora (Kallina): Disparo perforante
			var res := CombatRules.resolve_attack(actor, target, grid, 1, 10, 4)
			if res["is_hit"]:
				_apply_damage_to_target(target, res["damage"], res["is_crit"])
				if EventBus: EventBus.combat_log_appended.emit("¡Disparo certero de pólvora bendita! %d de daño perforante a %s." % [res["damage"], target.get("name", "el enemigo")], "crit")

		"ab_llama_aqshy":
			# Furia de Aqshy (Valtieri): Fuego mágico con riesgo de Disfunción de la Disformidad.
			# Fase 3: números desde datos (antes hardcodeados y con campos inexistentes que crasheaban).
			var d20: int = (randi() % 20) + 1
			if d20 <= maxi(1, ability.backlash_threshold):
				# ¡Pifia de la Disformidad!
				var miscast_msg = CombatRules.resolve_warp_miscast(actor, all_units, grid)
				if EventBus: EventBus.combat_log_appended.emit(miscast_msg, "damage")
			else:
				# Llama en área
				var dmg: int = DiceRoller.roll_dice(ability.damage_dice_count, ability.damage_dice_sides) + ability.damage_flat_bonus
				var radius: int = maxi(1, ability.area_radius)
				for u in all_units:
					if not u.get("is_hero", false) and u.get("is_alive", false):
						if grid.get_distance(target_pos, u.get("pos", Vector2i(-1, -1))) <= radius:
							_apply_damage_to_target(u, dmg, d20 == 20)
				if EventBus: EventBus.combat_log_appended.emit("¡Llamas de Aqshy calcinan a los enemigos en el área infligiendo %d de daño de fuego!" % dmg, "crit")

		"ab_plegaria_sigmar":
			# Plegaria de Sanación (Hermana Beryl): Curación grupal y valor.
			# Fase 3: números desde datos (antes hardcodeados y con campo inexistente que crasheaba).
			var heal_amount: int = DiceRoller.roll_dice(ability.heal_dice_count, ability.heal_dice_sides) + ability.heal_flat_bonus
			var heal_radius: int = maxi(1, ability.area_radius)
			for u in all_units:
				if u.get("is_hero", false) and u.get("is_alive", false):
					if grid.get_distance(actor.get("pos", Vector2i.ZERO), u.get("pos", Vector2i(-1, -1))) <= heal_radius:
						_apply_heal_to_target(u, heal_amount)
			if EventBus: EventBus.combat_log_appended.emit("¡Por la Gracia de Sigmar! La Hermana Beryl restaura %d heridas a los aliados cercanos." % heal_amount, "heal")

		# Fase 3: segundos kits del roster canon (números siempre desde datos).
		"ab_desafio_slayer":
			# Desafío del Matador: mandoble giratorio a todos los enemigos adyacentes.
			var spin_dmg: int = DiceRoller.roll_dice(ability.damage_dice_count, ability.damage_dice_sides) + ability.damage_flat_bonus
			var spin_radius: int = maxi(1, ability.area_radius)
			var enemies_hit := 0
			for u in all_units:
				if not u.get("is_hero", false) and u.get("is_alive", false):
					if grid.get_distance(actor.get("pos", Vector2i.ZERO), u.get("pos", Vector2i(-1, -1))) <= spin_radius:
						_apply_damage_to_target(u, spin_dmg, false)
						enemies_hit += 1
			if EventBus: EventBus.combat_log_appended.emit("¡Desafío del Matador! El mandoble alcanza a %d enemigos (%d de daño)." % [enemies_hit, spin_dmg], "damage")

		"ab_bomba_polvora":
			# Bomba de Pólvora (Kallina): explosión en área sobre la posición objetivo.
			var blast_dmg: int = DiceRoller.roll_dice(ability.damage_dice_count, ability.damage_dice_sides) + ability.damage_flat_bonus
			var blast_radius: int = maxi(1, ability.area_radius)
			for u in all_units:
				if not u.get("is_hero", false) and u.get("is_alive", false):
					if grid.get_distance(target_pos, u.get("pos", Vector2i(-1, -1))) <= blast_radius:
						_apply_damage_to_target(u, blast_dmg, false)
			if EventBus: EventBus.combat_log_appended.emit("¡Bomba de Pólvora! La explosión inflige %d de daño en área." % blast_dmg, "crit")

		"ab_vientos_aqshy":
			# Vientos de Aqshy (Valtieri): área amplia con Disfunción en 1-2.
			var wind_d20: int = (randi() % 20) + 1
			if wind_d20 <= maxi(1, ability.backlash_threshold):
				var wind_miscast = CombatRules.resolve_warp_miscast(actor, all_units, grid)
				if EventBus: EventBus.combat_log_appended.emit(wind_miscast, "damage")
			else:
				var wind_dmg: int = DiceRoller.roll_dice(ability.damage_dice_count, ability.damage_dice_sides) + ability.damage_flat_bonus
				var wind_radius: int = maxi(1, ability.area_radius)
				for u in all_units:
					if not u.get("is_hero", false) and u.get("is_alive", false):
						if grid.get_distance(target_pos, u.get("pos", Vector2i(-1, -1))) <= wind_radius:
							_apply_damage_to_target(u, wind_dmg, wind_d20 == 20)
				if EventBus: EventBus.combat_log_appended.emit("¡Los Vientos de Aqshy arrasan la zona infligiendo %d de daño de fuego!" % wind_dmg, "crit")

		"ab_escudo_fe":
			# Escudo de Fe (Beryl): sana al objetivo y le otorga postura defensiva (+4 CA).
			var ward_heal: int = DiceRoller.roll_dice(ability.heal_dice_count, ability.heal_dice_sides) + ability.heal_flat_bonus
			_apply_heal_to_target(target, ward_heal)
			var ward_rounds: int = maxi(1, ability.status_duration_turns)
			var t_buffs: Array = target.get("buffs", [])
			t_buffs.append({"type": Enums.StatusEffectType.DEFENDING, "duration": ward_rounds})
			target["buffs"] = t_buffs
			if EventBus: EventBus.combat_log_appended.emit("¡Escudo de Fe! %s recupera %d PV y queda defendido (+4 CA, %d turnos)." % [target.get("name", "el aliado"), ward_heal, ward_rounds], "heal")

		"ab_mofa":
			# Mofa Bufonesca (innata, coste 0): provoca al enemigo — +2 ataque
			# pero -2 CA para él (furia ciega, ver CombatRules). Contenido clipeable.
			var mofas := [
				"¡Tu armadura la forjó un herrero ciego!",
				"¡He visto limos con mejor linaje que el tuyo!",
				"¿Eso es un hacha o un abanico?",
				"¡El Narrador me ha contado tu final y es vergonzoso!",
			]
			var mofa_text: String = mofas[randi() % mofas.size()]
			var e_buffs: Array = target.get("buffs", [])
			e_buffs.append({"type": Enums.StatusEffectType.TAUNTED, "duration": maxi(1, ability.status_duration_turns)})
			target["buffs"] = e_buffs
			if EventBus: EventBus.combat_log_appended.emit("🤡 %s se burla de %s: «%s» ¡Enloquece de furia!" % [actor.get("name", "El héroe"), target.get("name", "el enemigo"), mofa_text], "crit")

		_:
			var res := CombatRules.resolve_attack(actor, target, grid, ability.damage_dice_count, ability.damage_dice_sides, ability.damage_flat_bonus)
			if res["is_hit"]:
				_apply_damage_to_target(target, res["damage"], res["is_crit"])

func _apply_damage_to_target(t: Dictionary, dmg: int, is_crit: bool) -> void:
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
		EventBus.floating_text_requested.emit("+%d HP" % amount, Color.GREEN, t.get("pos", Vector2i.ZERO))
		EventBus.heal_resolved.emit(actor["name"], t["name"], amount)

func undo() -> bool: return false
func can_undo() -> bool: return false
