class_name CombatVFX
extends Node2D

## Gestor de efectos visuales de combate: Chispas de pólvora, sangre visceral y fuego de Aqshy.

static func spawn_blood_splatter(parent: Node, world_pos: Vector2, is_crit: bool = false) -> void:
	var particles := CPUParticles2D.new()
	particles.position = world_pos
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.lifetime = 0.6 if not is_crit else 0.9
	particles.amount = 24 if not is_crit else 50
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.initial_velocity_min = 40.0 if not is_crit else 80.0
	particles.initial_velocity_max = 90.0 if not is_crit else 160.0
	particles.gravity = Vector2(0, 300)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.5 if not is_crit else 6.0
	particles.color = Color(0.75, 0.05, 0.05, 0.95) if not is_crit else Color(0.95, 0.1, 0.0, 1.0)
	parent.add_child(particles)
	
	# Auto-destrucción al terminar
	particles.finished.connect(func(): particles.queue_free())

static func spawn_fire_burst(parent: Node, world_pos: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.position = world_pos
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.lifetime = 0.7
	particles.amount = 40
	particles.direction = Vector2(0, -1)
	particles.spread = 120.0
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 130.0
	particles.gravity = Vector2(0, -80)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 7.0
	particles.color = Color(1.0, 0.55, 0.1, 0.9)
	parent.add_child(particles)
	particles.finished.connect(func(): particles.queue_free())

static func spawn_gunpowder_smoke(parent: Node, world_pos: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.position = world_pos
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 0.8
	particles.amount = 20
	particles.direction = Vector2(1, -0.5)
	particles.spread = 45.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 100.0
	particles.gravity = Vector2(0, -40)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = Color(0.7, 0.7, 0.7, 0.7)
	parent.add_child(particles)
	particles.finished.connect(func(): particles.queue_free())

