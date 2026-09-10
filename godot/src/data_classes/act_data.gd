class_name ActData
extends Resource

## Definición declarativa de un Acto de la Campaña de Calabozos & Bufones.

@export_group("Narrativa y Misión")
@export var act_number: int = 1
@export var title: String = ""
@export_multiline var synopsis: String = ""
@export var faction: String = ""
@export_multiline var mission_description: String = ""
@export var mission_objective: String = ""

@export_group("Enemigos y Jefe")
@export var available_enemies: Array[EnemyData] = []
@export var boss: EnemyData

@export_group("Audio y Estilo")
@export var map_style: String = "act1"
@export var background_music: AudioStream
