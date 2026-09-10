class_name PoolManager
extends Node2D

## Sistema de Object Pooling para optimizar recursos repetitivos como daños flotantes y proyectiles.
## Evita los costosos instanciados (instantiate) y liberaciones (queue_free) durante el combate.

@export var floating_text_scene: PackedScene
@export var pool_size: int = 20

var text_pool: Array[Node2D] = []

func _ready() -> void:
	print("PoolManager: Preparando Object Pool.")
	if floating_text_scene:
		for i in pool_size:
			var inst = floating_text_scene.instantiate()
			inst.visible = false
			add_child(inst)
			text_pool.append(inst)

	if EventBus:
		EventBus.floating_text_requested.connect(_spawn_floating_text)

func _spawn_floating_text(text: String, color: Color, grid_pos: Vector2i) -> void:
	var game_manager = get_parent()
	if not game_manager or not game_manager.has_node("GridRenderer"):
		return
		
	var grid_renderer = game_manager.get_node("GridRenderer")
	var screen_pos = grid_renderer.grid_to_world(grid_pos) + Vector2(grid_renderer.tile_size * 0.5, 0)

	for inst in text_pool:
		if not inst.visible:
			inst.position = screen_pos
			# Asumimos que el script del texto flotante tiene un método `start()`
			if inst.has_method("start"):
				inst.start(text, color)
			else:
				print("Error: El texto flotante no tiene un método start(text, color)")
			break

