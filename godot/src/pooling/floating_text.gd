class_name FloatingText
extends Node2D

## Elemento visual reciclable para daño, curación y textos flotantes tácticos.

var pool_owner: ObjectPool = null
var label: Label
var active_tween: Tween

func _init() -> void:
	z_index = 100
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(label)

func spawn(text: String, color: Color, world_pos: Vector2, is_crit: bool = false) -> void:
	reset_state()
	global_position = world_pos
	label.text = text
	label.modulate = color
	visible = true

	if active_tween and active_tween.is_valid():
		active_tween.kill()

	active_tween = create_tween()
	active_tween.set_parallel(true)

	var target_y: float = world_pos.y - 45.0
	active_tween.tween_property(self, "global_position:y", target_y, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "modulate:a", 0.0, 0.75).set_delay(0.2)

	if is_crit:
		scale = Vector2(1.5, 1.5)
		label.add_theme_font_size_override("font_size", 24)
		active_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BOUNCE)
	else:
		scale = Vector2(1.0, 1.0)
		label.add_theme_font_size_override("font_size", 18)

	active_tween.chain().tween_callback(_on_animation_finished)

func _on_animation_finished() -> void:
	if pool_owner:
		pool_owner.release(self)

func reset_state() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	modulate = Color.WHITE
	scale = Vector2.ONE
	visible = false
