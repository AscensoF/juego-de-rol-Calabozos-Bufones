class_name ItemData
extends Resource

## Definición declarativa de un Objeto del Inventario.

@export_group("Identificación")
@export var id: String = ""
@export var item_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Efectos")
@export var item_type: int = 0
@export var target_type: int = 0
@export var range_distance: int = 0
@export var area_radius: int = 0
@export var heal_amount: int = 0
@export var damage_dice_count: int = 0
@export var damage_dice_sides: int = 0
@export var applied_status: int = 0
@export var status_duration_turns: int = 0

