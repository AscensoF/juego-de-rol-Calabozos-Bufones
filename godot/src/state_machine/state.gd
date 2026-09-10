class_name State
extends Node

## Clase base abstracta para todos los estados de la FSM de Calabozos & Bufones.

@export var state_enum: Enums.GameFlowState = Enums.GameFlowState.MAIN_MENU

# Referencia al gestor de estados
var state_machine: StateMachine = null

func enter(_params: Dictionary = {}) -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass
