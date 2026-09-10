class_name CombatRules
extends RefCounted

## Lógica pura de reglas de combate táctico D20 para Calabozos & Bufones.

static func calculate_effective_ac(target: Dictionary, attacker_pos: Vector2i, grid: TacticalGrid) -> Dictionary:
	var base_ac: int = target.get("ac", 10)
	var buff_bonus: int = 0
	var has_cover: bool = false

	# Comprobación de Cobertura diagonal (+2 CA)
	if grid and target.has("pos"):
		has_cover = grid.has_diagonal_cover(attacker_pos, target["pos"])
		if has_cover:
			buff_bonus += 2

	# Bonificadores de Buffs (ej. Defendiendo +4 CA)
	for b in target.get("buffs", []):
		if b.get("type", -1) == Enums.StatusEffectType.DEFENDING:
			buff_bonus += 4
		elif b.has("ac"):
			buff_bonus += b["ac"]

	var total_ac: int = base_ac + buff_bonus
	return {
		"total_ac": total_ac,
		"base_ac": base_ac,
		"has_cover": has_cover,
		"buff_bonus": buff_bonus
	}

static func check_tactical_advantage(attacker: Dictionary, target: Dictionary) -> bool:
	# Ventajas tácticas canónicas entre Clases de Héroes y Tipos de Enemigo
	var attacker_hero_class: int = -1
	if attacker.get("is_hero", false) and attacker.has("data"):
		var h_data: HeroData = attacker["data"]
		attacker_hero_class = h_data.hero_class

	var target_enemy_kind: int = -1
	if not target.get("is_hero", true) and target.has("data"):
		var e_data: EnemyData = target["data"]
		target_enemy_kind = e_data.enemy_kind

	# Matriz de afinidad táctica:
	if attacker_hero_class == Enums.HeroClass.GUERRERO and target_enemy_kind == Enums.EnemyKind.ESQUELETO_DESMOTIVADO:
		return true
	if attacker_hero_class == Enums.HeroClass.MAGO and target_enemy_kind == Enums.EnemyKind.LIMO_NOSTALGIA:
		return true
	if attacker_hero_class == Enums.HeroClass.PICARO and target_enemy_kind == Enums.EnemyKind.GOBLIN_BUROCRATA:
		return true
	if attacker_hero_class == Enums.HeroClass.CLERIGO and target_enemy_kind == Enums.EnemyKind.SOMBRA_NARRADOR:
		return true

	return false

static func get_attack_modifier(attacker: Dictionary) -> int:
	var mod: int = 0
	if attacker.get("is_hero", false) and attacker.has("data"):
		var h: HeroData = attacker["data"]
		match h.hero_class:
			Enums.HeroClass.GUERRERO: mod = h.attributes.get_str_mod() if h.attributes else 0
			Enums.HeroClass.MAGO: mod = h.attributes.get_int_mod() if h.attributes else 0
			Enums.HeroClass.PICARO: mod = h.attributes.get_dex_mod() if h.attributes else 0
			Enums.HeroClass.CLERIGO: mod = h.attributes.get_wis_mod() if h.attributes else 0
	else:
		if attacker.has("data") and attacker["data"] is EnemyData:
			mod = attacker["data"].attack_bonus

	# Modificadores de estado (Poder Divino +2, Melancolía -2)
	for b in attacker.get("buffs", []):
		if b.get("type", -1) == Enums.StatusEffectType.DIVINE_MIGHT:
			mod += 2
		elif b.get("type", -1) == Enums.StatusEffectType.MELANCHOLY:
			mod -= 2

	return mod

static func resolve_attack(
	attacker: Dictionary,
	target: Dictionary,
	grid: TacticalGrid,
	damage_dice_count: int = 1,
	damage_dice_sides: int = 8,
	damage_flat_bonus: int = 0
) -> Dictionary:
	# 1. Comprobar si el atacante está aturdido
	for b in attacker.get("buffs", []):
		if b.get("type", -1) == Enums.StatusEffectType.STUN:
			return {
				"can_act": false,
				"reason": "La unidad está Aturdida y no puede atacar.",
				"is_hit": false,
				"damage": 0
			}

	# 2. Comprobar si el objetivo es invulnerable
	var is_invulnerable: bool = false
	for b in target.get("buffs", []):
		if b.get("type", -1) == Enums.StatusEffectType.INVULNERABLE:
			is_invulnerable = true
			break

	# 3. Calcular CA efectiva con Cobertura y Buffs
	var ac_data := calculate_effective_ac(target, attacker.get("pos", Vector2i.ZERO), grid)
	var target_ac: int = ac_data["total_ac"]

	# 4. Ventaja táctica
	var has_advantage: bool = check_tactical_advantage(attacker, target)
	var has_disadvantage: bool = false

	# 5. Tirada D20
	var d20_res := DiceRoller.roll_d20(has_advantage, has_disadvantage)
	var roll: int = d20_res["roll"]
	var attr_mod: int = get_attack_modifier(attacker)
	var total_attack: int = roll + attr_mod

	# 6. Comprobar si tenía crítico garantizado (Grimble)
	var has_guaranteed_crit: bool = false
	var crit_buff_idx: int = -1
	var buffs: Array = attacker.get("buffs", [])
	for i in buffs.size():
		if buffs[i].get("type", -1) == Enums.StatusEffectType.GUARANTEED_CRIT:
			has_guaranteed_crit = true
			crit_buff_idx = i
			break

	var is_crit: bool = d20_res["is_crit"] or has_guaranteed_crit
	var is_fumble: bool = d20_res["is_fumble"] and not has_guaranteed_crit

	var is_hit: bool = is_crit or (not is_fumble and total_attack >= target_ac)

	# 7. Cálculo de daño
	var damage_dealt: int = 0
	if is_hit and not is_invulnerable:
		var raw_damage: int = DiceRoller.roll_dice(damage_dice_count, damage_dice_sides) + damage_flat_bonus
		# Bono de daño por atributo primario
		raw_damage += maxi(1, attr_mod)

		# Bono de Afilado (+2 daño)
		var sharpened_idx: int = -1
		for i in buffs.size():
			if buffs[i].get("type", -1) == Enums.StatusEffectType.SHARPENED:
				raw_damage += 2
				sharpened_idx = i
				break
		if sharpened_idx != -1:
			buffs.remove_at(sharpened_idx)

		if is_crit:
			raw_damage *= 2 # Daño crítico duplicado

		damage_dealt = maxi(1, raw_damage)

	# Consumir crítico garantizado tras el ataque
	if crit_buff_idx != -1 and crit_buff_idx < buffs.size():
		buffs.remove_at(crit_buff_idx)

	return {
		"can_act": true,
		"is_hit": is_hit,
		"is_crit": is_crit,
		"is_fumble": is_fumble,
		"is_invulnerable": is_invulnerable,
		"d20_roll": roll,
		"attr_mod": attr_mod,
		"total_attack": total_attack,
		"target_ac": target_ac,
		"has_cover": ac_data["has_cover"],
		"has_advantage": has_advantage,
		"damage": damage_dealt
	}
