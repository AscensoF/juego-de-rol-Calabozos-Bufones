class_name HeroData
extends Resource

@export var id: String = ""
@export var hero_name: String = ""
@export var base_hp: int = 10
@export var base_resource: int = 10
@export var base_ac: int = 10
@export var speed: int = 4
@export var attributes: Resource # Modificado para no causar error de export

