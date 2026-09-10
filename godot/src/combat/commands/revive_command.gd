class_name ReviveCommand
extends CombatCommand

## Comando Reanimar: Levanta a un aliado adyacente caído con 1d6 PV.

var target: Dictionary
var grid: TacticalGrid

func _init(p_actor: Dictionary, p_target: Dictionary, p_grid: TacticalGrid) -> void:
	command_name = "Reanimar"
	actor = p_actor
	target = p_target
	grid = p_grid

func execute() -> bool:
	if target.get("is_alive", true):
		return false

	var dist: int = grid.get_distance(actor.get("pos", Vector2i.ZERO), target.get("pos", Vector2i.ZERO))
	if dist > 1:
		if EventBus:
			EventBus.combat_log_appended.emit("El aliado caído está demasiado lejos para ser reanimado.", "info")
		return false

	var restored_hp: int = DiceRoller.roll_dice(1, 6)
	target["is_alive"] = true
	target["hp"] = restored_hp

	if EventBus:
		EventBus.unit_revived.emit(target["id"], restored_hp)
		EventBus.health_updated.emit(target["id"], target["hp"], target["hp_max"], restored_hp)
		EventBus.combat_log_appended.emit("¡%s reanima a %s con %d PV!" % [actor["name"], target["name"], restored_hp], "heal")

	actor["has_acted"] = true
	return true

func undo() -> bool:
	return false

func can_undo() -> bool:
	return false
