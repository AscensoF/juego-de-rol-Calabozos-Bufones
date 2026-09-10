class_name AttackCommand
extends CombatCommand

## Comando de Ataque Básico: Resolución d20 + mod vs CA, coberturas, ventajas e impacto de daño.

var target: Dictionary
var grid: TacticalGrid

func _init(p_actor: Dictionary, p_target: Dictionary, p_grid: TacticalGrid) -> void:
	command_name = "Atacar"
	actor = p_actor
	target = p_target
	grid = p_grid

func execute() -> bool:
	if not target.get("is_alive", false):
		return false

	var res := CombatRules.resolve_attack(actor, target, grid)
	if not res.get("can_act", true):
		if EventBus:
			EventBus.combat_log_appended.emit(res["reason"], "damage")
		return false

	var roll: int = res["d20_roll"]
	var mod: int = res["attr_mod"]
	var total: int = res["total_attack"]
	var ac: int = res["target_ac"]
	var is_hit: bool = res["is_hit"]
	var is_crit: bool = res["is_crit"]
	var is_fumble: bool = res["is_fumble"]
	var dmg: int = res["damage"]

	# Aplicar daño al objetivo si impacta
	if is_hit and dmg > 0:
		var old_hp: int = target["hp"]
		target["hp"] = maxi(0, target["hp"] - dmg)
		var delta: int = target["hp"] - old_hp

		if EventBus:
			EventBus.health_updated.emit(target["id"], target["hp"], target["hp_max"], delta)
			EventBus.floating_text_requested.emit(
				"-%d%s" % [dmg, " CRÍTICO!" if is_crit else ""],
				Color.YELLOW if is_crit else Color.CORAL,
				target.get("pos", Vector2i.ZERO)
			)

		# Ganancia de recurso para Guerrero (Throg genera Furia al golpear)
		if actor.get("is_hero", false) and actor.has("data"):
			var h_data: HeroData = actor["data"]
			if h_data.hero_class == Enums.HeroClass.GUERRERO:
				actor["res"] = mini(actor["res_max"], actor["res"] + 1)
				if EventBus:
					EventBus.resource_updated.emit(actor["id"], actor["res"], actor["res_max"], "Furia")

		# Comprobación de baja del objetivo
		if target["hp"] <= 0:
			target["is_alive"] = false
			var xp_reward: int = 0
			if not target.get("is_hero", false) and target.has("data"):
				xp_reward = target["data"].xp_reward

			if EventBus:
				EventBus.unit_defeated.emit(target["id"], target.get("is_hero", false), xp_reward)
				EventBus.combat_log_appended.emit("<b>¡%s ha sido derrotado!</b>" % target["name"], "damage")

	if EventBus:
		EventBus.attack_resolved.emit(
			actor["name"], target["name"], roll, mod, total, ac, is_hit, is_crit, is_fumble, dmg
		)
		var msg := "%s ataca a %s: Tirada d20(%d) + %d = %d vs CA %d. %s" % [
			actor["name"], target["name"], roll, mod, total, ac,
			("¡IMPACTO CRÍTICO!" if is_crit else "¡IMPACTO!") if is_hit else ("¡PIFIA!" if is_fumble else "Fallo.")
		]
		EventBus.combat_log_appended.emit(msg, "crit" if is_crit else ("damage" if is_hit else "info"))

	actor["has_acted"] = true
	return true

func undo() -> bool:
	return false

func can_undo() -> bool:
	return false
