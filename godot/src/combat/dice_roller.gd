class_name DiceRoller
extends RefCounted

## Gestor de tiradas de dados D&D/D20 puras para resolución táctica.

static func roll_d20(advantage: bool = false, disadvantage: bool = false) -> Dictionary:
	var roll1: int = (randi() % 20) + 1
	var roll2: int = (randi() % 20) + 1
	var chosen_roll: int = roll1

	if advantage and not disadvantage:
		chosen_roll = maxi(roll1, roll2)
	elif disadvantage and not advantage:
		chosen_roll = mini(roll1, roll2)

	var is_crit: bool = (chosen_roll == 20)
	var is_fumble: bool = (chosen_roll == 1)

	return {
		"roll": chosen_roll,
		"roll1": roll1,
		"roll2": roll2,
		"has_advantage": advantage and not disadvantage,
		"has_disadvantage": disadvantage and not advantage,
		"is_crit": is_crit,
		"is_fumble": is_fumble
	}

static func roll_dice(count: int, sides: int) -> int:
	if count <= 0 or sides <= 0:
		return 0
	var total: int = 0
	for i in count:
		total += (randi() % sides) + 1
	return total

static func roll_dice_detailed(count: int, sides: int) -> Dictionary:
	var rolls: Array[int] = []
	var total: int = 0
	for i in count:
		var r: int = (randi() % sides) + 1
		rolls.append(r)
		total += r
	return {
		"rolls": rolls,
		"total": total,
		"count": count,
		"sides": sides
	}
