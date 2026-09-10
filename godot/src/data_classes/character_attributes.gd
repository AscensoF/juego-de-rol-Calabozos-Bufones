class_name CharacterAttributes
extends Resource

## Almacena y calcula los modificadores de atributos estilo D20 para entidades tácticas.

@export var strength: int = 10
@export var dexterity: int = 10
@export var constitution: int = 10
@export var intelligence: int = 10
@export var wisdom: int = 10
@export var charisma: int = 10

static func calculate_modifier(stat_value: int) -> int:
	return int(floor((float(stat_value) - 10.0) / 2.0))

func get_str_mod() -> int:
	return calculate_modifier(strength)

func get_dex_mod() -> int:
	return calculate_modifier(dexterity)

func get_con_mod() -> int:
	return calculate_modifier(constitution)

func get_int_mod() -> int:
	return calculate_modifier(intelligence)

func get_wis_mod() -> int:
	return calculate_modifier(wisdom)

func get_cha_mod() -> int:
	return calculate_modifier(charisma)

func get_modifier_by_name(attr_name: String) -> int:
	match attr_name.to_upper():
		"STR", "FUERZA": return get_str_mod()
		"DEX", "DESTREZA": return get_dex_mod()
		"CON", "CONSTITUCION": return get_con_mod()
		"INT", "INTELIGENCIA": return get_int_mod()
		"WIS", "SABIDURIA": return get_wis_mod()
		"CHA", "CARISMA": return get_cha_mod()
		_: return 0

func clone() -> CharacterAttributes:
	var c := CharacterAttributes.new()
	c.strength = strength
	c.dexterity = dexterity
	c.constitution = constitution
	c.intelligence = intelligence
	c.wisdom = wisdom
	c.charisma = charisma
	return c

func to_dict() -> Dictionary:
	return {
		"STR": strength,
		"DEX": dexterity,
		"CON": constitution,
		"INT": intelligence,
		"WIS": wisdom,
		"CHA": charisma
	}

func from_dict(data: Dictionary) -> void:
	strength = int(data.get("STR", strength))
	dexterity = int(data.get("DEX", dexterity))
	constitution = int(data.get("CON", constitution))
	intelligence = int(data.get("INT", intelligence))
	wisdom = int(data.get("WIS", wisdom))
	charisma = int(data.get("CHA", charisma))
