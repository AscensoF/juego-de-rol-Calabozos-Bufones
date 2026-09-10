class_name EnemyData
extends Resource

## Definición declarativa de una criatura o jefe del Bestiario de los Absurdos.

@export_group("Identificación")
@export var id: String = ""
@export var enemy_name: String = ""
@export var enemy_kind: Enums.EnemyKind = Enums.EnemyKind.GOBLIN_BUROCRATA
@export var portrait: Texture2D
@export var is_boss: bool = false

@export_group("Combate y Movilidad")
@export var base_hp: int = 10
@export var armor_class: int = 12
@export var attack_bonus: int = 2
@export var damage_dice_count: int = 1
@export var damage_dice_sides: int = 4
@export var damage_flat_bonus: int = 0
@export var speed: int = 4
@export var initiative_bonus: int = 0

@export_group("Recompensas")
@export var xp_reward: int = 15

@export_group("Habilidad Especial Absurda")
@export var special_ability_id: String = ""
@export var special_ability_name: String = ""
@export_multiline var special_ability_desc: String = ""
