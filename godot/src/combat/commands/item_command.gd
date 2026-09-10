class_name ItemCommand
extends CombatCommand

## Comando de Uso de Objeto de Inventario.

var item: ItemData
var target: Dictionary
var target_pos: Vector2i
var grid: TacticalGrid
var all_units: Array[Dictionary] = []

func _init(
	p_actor: Dictionary,
	p_item: ItemData,
	p_target: Dictionary,
	p_target_pos: Vector2i,
	p_grid: TacticalGrid,
	p_all_units: Array[Dictionary] = []
) -> void:
	command_name = p_item.item_name
	actor = p_actor
	item = p_item
	target = p_target
	target_pos = p_target_pos
	grid = p_grid
	all_units = p_all_units

func execute() -> bool:
	match item.item_type:
		Enums.ItemType.HEALING_POTION:
			var heal: int = item.heal_amount
			actor["hp"] = mini(actor["hp_max"], actor["hp"] + heal)
			if EventBus:
				EventBus.health_updated.emit(actor["id"], actor["hp"], actor["hp_max"], heal)
				EventBus.floating_text_requested.emit("+%d" % heal, Color.GREEN, actor.get("pos", Vector2i.ZERO))
				EventBus.combat_log_appended.emit("%s usa %s y recupera %d PV." % [actor["name"], item.item_name, heal], "heal")

		Enums.ItemType.SHARPENING_STONE:
			actor["buffs"].append({"type": Enums.StatusEffectType.SHARPENED, "duration": item.status_duration_turns})
			if EventBus:
				EventBus.status_applied.emit(actor["id"], Enums.StatusEffectType.SHARPENED, item.status_duration_turns)
				EventBus.combat_log_appended.emit("%s usa %s: +2 de daño en el siguiente ataque." % [actor["name"], item.item_name], "info")

		Enums.ItemType.SMOKE_BOMB:
			if grid.is_walkable(target_pos):
				grid.move_unit_on_grid(actor["pos"], target_pos)
				if EventBus:
					EventBus.unit_moved.emit(actor["id"], actor["pos"], target_pos)
					EventBus.combat_log_appended.emit("%s lanza una bomba de humo y se reposiciona." % actor["name"], "info")

		Enums.ItemType.FIREBALL_SCROLL:
			for u in all_units:
				if u.get("is_alive", false) and grid.get_distance(target_pos, u["pos"]) <= item.area_radius:
					var dmg: int = DiceRoller.roll_dice(item.damage_dice_count, item.damage_dice_sides)
					u["hp"] = maxi(0, u["hp"] - dmg)
					if EventBus:
						EventBus.health_updated.emit(u["id"], u["hp"], u["hp_max"], -dmg)
						EventBus.floating_text_requested.emit("-%d" % dmg, Color.ORANGE, u["pos"])

		_:
			pass

	actor["has_acted"] = true
	return true

func undo() -> bool:
	return false

func can_undo() -> bool:
	return false
