class_name CombatRules
extends RefCounted

## Lógica pura de reglas de combate táctico D20 / Warhammer Fantasy.
## Incluye Coberturas, Vientos de la Magia, Pifias de Disformidad y Armas de Pólvora.

static func calculate_effective_ac(target: Dictionary, attacker_pos: Vector2i, grid: TacticalGrid) -> Dictionary:
	var base_ac: int = target.get("ac", 10)
	var buff_bonus: int = 0
	var has_cover: bool = false

	if grid and target.has("pos"):
		has_cover = grid.has_diagonal_cover(attacker_pos, target["pos"])
		if has_cover:
			buff_bonus += 2

	for b in target.get("buffs", []):
		if b.get("type", -1) == Enums.StatusEffectType.DEFENDING:
			buff_bonus += 4
		elif b.get("type", -1) == Enums.StatusEffectType.TAUNTED:
			# Fase 5 (Mofa): el provocado baja la guardia (-2 CA, furia ciega).
			buff_bonus -= 2
		elif b.has("ac"):
			buff_bonus += b["ac"]

	var total_ac: int = base_ac + buff_bonus
	return {
		"total_ac": total_ac,
		"base_ac": base_ac,
		"has_cover": has_cover,
		"buff_bonus": buff_bonus
	}

static func get_attack_modifier(attacker: Dictionary) -> int:
	var mod: int = 0
	if attacker.get("is_hero", false) and attacker.has("data"):
		var h: HeroData = attacker["data"]
		match h.hero_class:
			Enums.HeroClass.GUERRERO: mod = 3 # Matador Enano (Alta HA)
			Enums.HeroClass.MAGO: mod = 2     # Hechicero Aqshy
			Enums.HeroClass.PICARO: mod = 3   # Cazadora de Brujas (Alta HP)
			Enums.HeroClass.CLERIGO: mod = 2  # Sacerdotisa Sigmar
	else:
		if attacker.has("data") and attacker["data"] is EnemyData:
			mod = attacker["data"].attack_bonus

	# Fase 5 (Mofa): el provocado pega con furia (+2 ataque).
	for b in attacker.get("buffs", []):
		if b.get("type", -1) == Enums.StatusEffectType.TAUNTED:
			mod += 2
			break

	return mod

## Tabla de Disfunción de la Disformidad de Warhammer Fantasy
static func resolve_warp_miscast(caster: Dictionary, all_units: Array, grid: TacticalGrid) -> String:
	var miscast_roll: int = (randi() % 4) + 1
	var c_name = caster.get("name", "El Hechicero")
	var c_pos: Vector2i = caster.get("pos", Vector2i.ZERO)
	var msg := ""

	match miscast_roll:
		1:
			# Llama Fatuo: Daño al hechicero
			var dmg: int = (randi() % 4) + 2
			caster["hp"] = maxi(0, caster.get("hp", 10) - dmg)
			if EventBus:
				EventBus.health_updated.emit(caster.get("id", ""), caster["hp"], caster.get("hp_max", 10), -dmg)
				EventBus.floating_text_requested.emit("-%d Disfunción" % dmg, Color.PURPLE, c_pos)
			msg = "¡DISFUNCIÓN DE LA DISFORMIDAD! Los Vientos de Aqshy se descontrolan e infligen %d de daño de fuego a %s." % [dmg, c_name]
		2:
			# Estallido Mágico: Daña a aliados y enemigos adyacentes
			for u in all_units:
				if u.get("is_alive", false) and grid.get_distance(c_pos, u.get("pos", Vector2i(-1, -1))) <= 1:
					u["hp"] = maxi(0, u.get("hp", 10) - 3)
					if EventBus:
						EventBus.health_updated.emit(u.get("id", ""), u["hp"], u.get("hp_max", 10), -3)
						EventBus.floating_text_requested.emit("-3 Estallido", Color.ORANGE, u.get("pos", Vector2i.ZERO))
			msg = "¡ESTALLIDO DE DISFORMIDAD! Una onda expansiva de fuego sacude a todas las unidades adyacentes (-3 HP)."
		3:
			# Pánico Mágico: Aturde al lanzador 1 turno
			msg = "¡ECOS DEL INMATERIAL! %s queda aturdido por los susurros de los Demonios del Caos." % c_name
		4:
			# Vórtice de Ceniza: Drena 2 puntos de recurso mágico
			caster["res"] = maxi(0, caster.get("res", 0) - 2)
			msg = "¡DISIPACIÓN SÚBITA! Los Vientos de la Magia se desvanecen (-2 Puntos de Aqshy)."

	return msg

static func resolve_attack(
	attacker: Dictionary,
	target: Dictionary,
	grid: TacticalGrid,
	damage_dice_count: int = 1,
	damage_dice_sides: int = 8,
	damage_flat_bonus: int = 0
) -> Dictionary:
	var ac_data := calculate_effective_ac(target, attacker.get("pos", Vector2i.ZERO), grid)
	var target_ac: int = ac_data["total_ac"]

	var d20_res := DiceRoller.roll_d20(false, false)
	var roll: int = d20_res["roll"]
	var attr_mod: int = get_attack_modifier(attacker)
	var total_attack: int = roll + attr_mod

	var is_crit: bool = d20_res["is_crit"]
	var is_fumble: bool = d20_res["is_fumble"]
	var is_hit: bool = is_crit or (not is_fumble and total_attack >= target_ac)

	var damage_dealt: int = 0
	if is_hit:
		var raw_damage: int = DiceRoller.roll_dice(damage_dice_count, damage_dice_sides) + damage_flat_bonus + attr_mod
		
		# Mecánica de Voto del Matador (Slayer Deathseeker): A menor HP, mayor daño
		if attacker.get("is_hero", false) and "gotrek" in attacker.get("name", "").to_lower():
			var hp_ratio = float(attacker.get("hp", 10)) / float(maxi(1, attacker.get("hp_max", 18)))
			if hp_ratio < 0.5:
				raw_damage += 3 # Furia Berserker activa
			if hp_ratio < 0.25:
				raw_damage += 6 # Furia Máxima por juramento
		
		if is_crit:
			raw_damage *= 2

		damage_dealt = maxi(1, raw_damage)

	return {
		"can_act": true,
		"is_hit": is_hit,
		"is_crit": is_crit,
		"is_fumble": is_fumble,
		"is_invulnerable": false,
		"d20_roll": roll,
		"attr_mod": attr_mod,
		"total_attack": total_attack,
		"target_ac": target_ac,
		"has_cover": ac_data["has_cover"],
		"has_advantage": false,
		"damage": damage_dealt
	}
