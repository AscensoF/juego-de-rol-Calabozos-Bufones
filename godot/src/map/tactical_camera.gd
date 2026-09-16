class_name TacticalCamera
extends Camera2D

## Cámara táctica con soporte para arrastrar (Touch/Ratón), Zoom y Vibración de Impactos (Camera Shake).

var zoom_target := Vector2(2.0, 2.0) # Zoom inicial más cercano (x2)
var is_dragging := false
# Fase 2: pinch-to-zoom táctil (dos dedos). Single-finger drag intacto.
var _touches: Dictionary = {}
var _pinch_base_dist: float = 0.0

var shake_intensity: float = 0.0
var shake_decay: float = 12.0

func _ready() -> void:
	make_current()
	zoom = zoom_target
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	if EventBus:
		EventBus.attack_resolved.connect(_on_attack_resolved)

func add_shake(intensity: float) -> void:
	shake_intensity = maxf(shake_intensity, intensity)

func _on_attack_resolved(_attacker: String, _target: String, _roll: int, _mod: int, _total: int, _ac: int, is_hit: bool, is_crit: bool, _is_fumble: bool, damage: int) -> void:
	if is_crit:
		add_shake(12.0) # Vibración fuerte en impactos críticos
	elif is_hit and damage > 0:
		add_shake(5.0) # Vibración ligera en golpes normales

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			is_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_target += Vector2(0.2, 0.2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_target -= Vector2(0.2, 0.2)
	
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch_base_dist = _current_touch_dist()

	if event is InputEventMouseMotion and is_dragging:
		position -= event.relative / zoom
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 2:
			var d := _current_touch_dist()
			if _pinch_base_dist > 0.0 and d > 0.0:
				zoom_target *= d / _pinch_base_dist
			_pinch_base_dist = d
		else:
			position -= event.relative / zoom

func _current_touch_dist() -> float:
	if _touches.size() < 2:
		return 0.0
	var pts: Array = _touches.values()
	return (pts[0] as Vector2 - pts[1] as Vector2).length()

func _process(delta: float) -> void:
	zoom_target = zoom_target.clamp(Vector2(0.8, 0.8), Vector2(4.0, 4.0))
	zoom = zoom.lerp(zoom_target, 12.0 * delta)

	# Cálculo de vibración de la cámara (Impact Shake)
	if shake_intensity > 0.0:
		shake_intensity = lerpf(shake_intensity, 0.0, shake_decay * delta)
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_intensity
		if shake_intensity < 0.1:
			shake_intensity = 0.0
			offset = Vector2.ZERO

