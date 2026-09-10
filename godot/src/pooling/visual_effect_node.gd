class_name VisualEffectNode
extends Node2D

## Efecto visual procedural ligero para partículas y animaciones de impacto táctico.

var pool_owner: ObjectPool = null
var active_tween: Tween
var visual_rect: ColorRect

func _init() -> void:
	z_index = 90
	visual_rect = ColorRect.new()
	visual_rect.custom_minimum_size = Vector2(24, 24)
	visual_rect.position = -Vector2(12, 12)
	add_child(visual_rect)

func play_effect(effect_name: String, world_pos: Vector2) -> void:
	reset_state()
	global_position = world_pos
	visible = true

	match effect_name:
		"slash_heavy":
			visual_rect.color = Color(1.0, 0.2, 0.2, 0.9)
			visual_rect.size = Vector2(32, 6)
			visual_rect.position = -Vector2(16, 3)
		"magic_missile", "arcane-hit":
			visual_rect.color = Color(0.65, 0.35, 0.95, 0.9)
			visual_rect.size = Vector2(20, 20)
			visual_rect.position = -Vector2(10, 10)
		"divine", "holy_burst":
			visual_rect.color = Color(1.0, 0.9, 0.3, 0.9)
			visual_rect.size = Vector2(28, 28)
			visual_rect.position = -Vector2(14, 14)
		_:
			visual_rect.color = Color(1.0, 1.0, 1.0, 0.8)

	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "modulate:a", 0.0, 0.35)
	active_tween.chain().tween_callback(_on_effect_finished)

func _on_effect_finished() -> void:
	if pool_owner:
		pool_owner.release(self)

func reset_state() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	scale = Vector2.ONE
	modulate = Color.WHITE
	visible = false
