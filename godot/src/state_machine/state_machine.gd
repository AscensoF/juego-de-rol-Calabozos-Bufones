class_name StateMachine
extends Node

## Máquina de Estados Finitos (FSM) jerárquica para el ciclo de vida del juego.
## Controla el flujo global: Menú Principal, Exploración, Combate Táctico, Modo DJ y Game Over.

@export var initial_state: State

var current_state: State = null
var previous_state: State = null
var states: Dictionary = {} # Enums.GameFlowState -> State

func _ready() -> void:
	_register_child_states()
	if initial_state:
		change_state(initial_state.state_enum)
	elif states.has(Enums.GameFlowState.EXPLORATION):
		change_state(Enums.GameFlowState.EXPLORATION)
	elif states.has(Enums.GameFlowState.MAIN_MENU):
		change_state(Enums.GameFlowState.MAIN_MENU)

func _register_child_states() -> void:
	for child in get_children():
		if child is State:
			states[child.state_enum] = child
			child.state_machine = self

func register_state(state_type: Enums.GameFlowState, state_node: State) -> void:
	states[state_type] = state_node
	state_node.state_machine = self
	if not state_node.is_inside_tree():
		add_child(state_node)

func change_state(target_state_enum: Enums.GameFlowState, params: Dictionary = {}) -> bool:
	if not states.has(target_state_enum):
		push_error("[StateMachine] Error: No existe un estado registrado para el enum: %d" % target_state_enum)
		return false

	var next_state: State = states[target_state_enum]
	if current_state == next_state:
		return false

	var old_enum: int = current_state.state_enum if current_state else -1

	# Salida del estado previo
	if current_state:
		current_state.exit()
		previous_state = current_state

	# Transición y Entrada
	current_state = next_state
	current_state.enter(params)

	# Notificación desacoplada vía EventBus
	if EventBus:
		EventBus.state_changed.emit(old_enum, target_state_enum)

	return true

func revert_to_previous_state(params: Dictionary = {}) -> bool:
	if previous_state:
		return change_state(previous_state.state_enum, params)
	return false

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)
