class_name DefendCommand
extends CombatCommand

## Comando Defender: Otorga postura defensiva (+4 a la CA) hasta el próximo turno.

func _init(p_actor: Dictionary) -> void:
	command_name = "Defender"
	actor = p_actor

func execute() -> bool:
	actor["buffs"].append({
		"type": Enums.StatusEffectType.DEFENDING,
		"duration": 2,
		"ac": 4
	})

	if EventBus:
		EventBus.status_applied.emit(actor["id"], Enums.StatusEffectType.DEFENDING, 2)
		EventBus.combat_log_appended.emit("%s adopta postura defensiva (+4 CA)." % actor["name"], "info")

	actor["has_acted"] = true
	return true

func undo() -> bool:
	return false

func can_undo() -> bool:
	return false
