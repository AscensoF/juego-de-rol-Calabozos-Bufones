class_name Progression
extends RefCounted

## Fase 4: progresión XP/nivel data-driven (cierra la brecha del canon Godot,
## donde el XP se anunciaba y se evaporaba: unit_defeated sin suscriptores).
## Curva verificada contra la tabla legacy: XP(n) = 50·n·(n−1) + 100·(n−1).
## NOTA: HeroData son Objects (no Dictionaries): acceso directo, sin .get().

const MAX_LEVEL := 10
const XP_TABLE := [0, 100, 300, 600, 1000, 1500, 2200, 3000, 4000, 5200, 6500]

static func xp_for_next(level: int) -> int:
	if level < 1 or level >= MAX_LEVEL:
		return -1
	return XP_TABLE[level]

## Reparte XP a todo el grupo (generoso por diseño satírico: todos cobran
## entero, como en el prototipo). Devuelve líneas de log.
static func grant_xp(party: Array, total_xp: int) -> Array[String]:
	var lines: Array[String] = []
	if total_xp <= 0:
		return lines
	for h in party:
		if not (h is HeroData):
			continue
		h.current_xp += total_xp
		lines.append("%s gana %d XP." % [h.hero_name, total_xp])
		while h.level < MAX_LEVEL:
			var need := xp_for_next(h.level)
			if need < 0 or h.current_xp < need:
				break
			h.current_xp -= need
			h.level += 1
			h.base_hp += 3
			h.base_resource += 1
			h.xp_to_next_level = xp_for_next(h.level)
			lines.append("¡%s sube a nivel %d! (+3 PV, +1 recurso)" % [h.hero_name, h.level])
	return lines

## Oro de victoria: 15 + 10 por acto (F4: Acto 1 → 25g = 2 bálsamos o media capilla).
static func victory_gold(act_number: int) -> int:
	return 15 + 10 * maxi(1, act_number)
