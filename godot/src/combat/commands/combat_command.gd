class_name CombatCommand
extends RefCounted

## Clase base abstracta del Patrón Comando para acciones tácticas en combate.

var command_name: String = "Acción"
var actor: Dictionary = {}

func execute() -> bool:
	return false

func undo() -> bool:
	return false

func can_undo() -> bool:
	return false
