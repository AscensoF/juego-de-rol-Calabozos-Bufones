class_name AbilityData
extends Resource

## Definición declarativa de una habilidad especial de Héroe o Criatura.

@export_group("Identificación")
@export var id: String = ""
@export var ability_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Requisitos y Costes")
@export var cost: int = 1 # Puntos de Recurso (Furia/Maná/Astucia/Fe)
@export var required_level: int = 1
@export var once_per_combat: bool = false

@export_group("Táctica y Alcance")
@export var target_type: int = 0
@export var ability_type: int = 0
@export var range_distance: int = 1
@export var area_radius: int = 0
@export var requires_adjacent_ally: bool = false
@export var auto_hit: bool = false

@export_group("Efectos de Daño y Curación")
@export var damage_dice_count: int = 1
@export var damage_dice_sides: int = 6
@export var damage_flat_bonus: int = 0
@export var heal_dice_count: int = 0
@export var heal_dice_sides: int = 0
@export var heal_flat_bonus: int = 0

@export_group("Estados Alterados y Riesgos")
@export var applied_status: int = 0
@export var status_duration_turns: int = 0
@export var backlash_threshold: int = 0 # Umbral de pifia para magias caóticas
@export var taunt_enemies_in_radius: int = 0

@export_group("Presentación Visual")
@export var animation_effect_name: String = ""

