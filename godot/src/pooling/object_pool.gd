class_name ObjectPool
extends RefCounted

## Gestor de Object Pooling genérico y de alto rendimiento para plataformas móviles.
## Elimina la presión sobre el recolector de basura reutilizando instancias en memoria.

var pool: Array[Node] = []
var active_objects: Array[Node] = []
var template_script: GDScript
var parent_node: Node
var max_size: int = 50

func _init(script_type: GDScript, initial_capacity: int = 20, p_parent: Node = null, p_max_size: int = 50) -> void:
	template_script = script_type
	parent_node = p_parent
	max_size = p_max_size
	_prewarm(initial_capacity)

func _prewarm(amount: int) -> void:
	for i in amount:
		var instance: Node = template_script.new()
		instance.set("pool_owner", self)
		if instance is CanvasItem:
			instance.visible = false
		if parent_node and not instance.is_inside_tree():
			parent_node.add_child(instance)
		pool.append(instance)

func acquire() -> Node:
	var instance: Node = null
	if not pool.is_empty():
		instance = pool.pop_back()
	elif active_objects.size() < max_size:
		instance = template_script.new()
		instance.set("pool_owner", self)
		if parent_node and not instance.is_inside_tree():
			parent_node.add_child(instance)
	else:
		# Si se alcanza el límite estricto de memoria móvil, reciclamos la instancia activa más antigua
		instance = active_objects.pop_front()
		if instance.has_method("reset_state"):
			instance.reset_state()

	if instance:
		active_objects.append(instance)
		if instance is CanvasItem:
			instance.visible = true

	return instance

func release(instance: Node) -> void:
	if not instance:
		return

	var idx: int = active_objects.find(instance)
	if idx != -1:
		active_objects.remove_at(idx)

	if instance is CanvasItem:
		instance.visible = false

	if instance.has_method("reset_state"):
		instance.reset_state()

	pool.append(instance)

func clear() -> void:
	for obj in pool:
		if is_instance_valid(obj):
			obj.queue_free()
	for obj in active_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	pool.clear()
	active_objects.clear()
