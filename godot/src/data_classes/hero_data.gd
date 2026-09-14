class_name HeroData
extends Resource

## Definición declarativa de un héroe jugable.
## NOTA: 'resource_name' ya existe en la clase nativa Resource, así que lo usamos directamente.

@export_group("Identificación")
@export var id: String = ""
@export var hero_name: String = ""
@export var hero_class: Enums.HeroClass = Enums.HeroClass.GUERRERO
@export_multiline var lore_history: String = ""
@export_multiline var lore_attributes: String = ""
@export var portrait: Texture2D

@export_group("Combate y Movilidad")
@export var base_hp: int = 10
@export var base_ac: int = 10
@export var speed: int = 4
@export var base_resource: int = 10
@export var starting_attribute_points: int = 0

@export_group("Atributos y Equipo")
@export var attributes: CharacterAttributes
@export var abilities: Array[AbilityData] = []
@export var starting_inventory: Array[ItemData] = []
