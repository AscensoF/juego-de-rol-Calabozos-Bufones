class_name MainMenuState
extends State

## Estado de Menú Principal: Controla pantalla de inicio, selección de héroes y carga de partida.

func _init() -> void:
	state_enum = Enums.GameFlowState.MAIN_MENU

func enter(params: Dictionary = {}) -> void:
	if EventBus:
		EventBus.status_panel_updated.emit("Menú Principal: Selecciona una opción para comenzar.")
		EventBus.combat_log_appended.emit("Bienvenido a Calabozos & Bufones.", "game")

func start_new_game(act_resource_path: String = "res://data/acts/act_01_taberna.tres") -> void:
	var act_data: ActData = load(act_resource_path) as ActData
	# Fase 1: roster canon único vía ActLoader (antes roster satírico distinto
	# al de game_manager.gd).
	var heroes: Array = ActLoader.load_party()

	var transition_data := {
		"act": act_data,
		"party": heroes,
		"is_new_game": true
	}

	state_machine.change_state(Enums.GameFlowState.EXPLORATION, transition_data)

func continue_game(save_data: Dictionary) -> void:
	state_machine.change_state(Enums.GameFlowState.EXPLORATION, {
		"save_data": save_data,
		"is_new_game": false
	})

# Fase 5c: continuar desde el autosave de campaña (botón Continuar del menú).
func continue_from_campaign() -> bool:
	var gm = state_machine.get_parent()
	if gm and gm.has_method("load_campaign_applied") and gm.load_campaign_applied():
		state_machine.change_state(Enums.GameFlowState.EXPLORATION, {
			"is_new_game": false,
			"continued": true
		})
		return true
	return false

func exit() -> void:
	pass
