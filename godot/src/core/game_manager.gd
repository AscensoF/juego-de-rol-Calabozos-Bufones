class_name GameManager
extends Node2D

@onready var state_machine: StateMachine = $StateMachine
@onready var grid_renderer: GridRenderer = $GridRenderer
@onready var hud: CombatHUDController = $CanvasLayer/CombatHUD
@onready var dice_visualizer: DiceVisualizer = $CanvasLayer/DiceVisualizer
@onready var dj_controller: DJModeController = $CanvasLayer/DJModeController
@onready var pool_manager: PoolManager = $PoolManager

var tactical_grid: TacticalGrid
var combat_invoker: CombatInvoker
var party_heroes: Array = []
var act_data: ActData
var camera: TacticalCamera
var dialogue_box: DialogueBox

var current_act_number: int = 1
var party_inventory: Array[Dictionary] = []

func _ready():
	RenderingServer.set_default_clear_color(Color(0.03, 0.04, 0.07, 1.0))
	tactical_grid = TacticalGrid.new()
	combat_invoker = CombatInvoker.new()

	if grid_renderer:
		grid_renderer.tactical_grid = tactical_grid
	if hud:
		hud.combat_invoker = combat_invoker
		hud.game_manager = self

	_setup_camera()
	_setup_dialogue_box()
	_load_campaign_data()
	_setup_initial_inventory()
	_load_act(1)
	_subscribe_inventory_events()
	_subscribe_turn_events()
	_trigger_intro_dialogue()

func _setup_camera():
	camera = TacticalCamera.new()
	add_child(camera)
	camera.position = Vector2(400, 300)

func _setup_dialogue_box():
	dialogue_box = DialogueBox.new()
	dialogue_box.name = "DialogueBox"
	$CanvasLayer.add_child(dialogue_box)

func _trigger_intro_dialogue():
	await get_tree().create_timer(0.5).timeout
	if not is_inside_tree(): return
	if EventBus:
		EventBus.dialogue_requested.emit([
			{
				"speaker": "Inquisidor von Kessel",
				"text": "¡Por Sigmar! Los informes de las alcantarillas de Altdorf no mentían. La herejía y los hombres rata se extienden bajo la ciudad imperial. Purgadlos sin piedad.",
				"portrait": "res://assets/sprites/ui/logo.png"
			},
			{
				"speaker": "Gotreksson el Matador",
				"text": "¡Menos discursos y más acero! Mi hacha tiene sed de sangre Skaven. ¡Por Grimnir y por el honor de Karak Kadrin!",
				"portrait": "res://assets/sprites/characters/heroes/throg.png"
			},
			{
				"speaker": "Kallina von Halstadt",
				"text": "Pólvora seca y virotes de plata listos. Mantened la formación y vigilad las esquinas oscuras.",
				"portrait": "res://assets/sprites/characters/heroes/elowen.png"
			}
		])

func focus_camera_on(grid_pos: Vector2i, zoom_level: float = 2.0) -> void:
	if not camera or not grid_renderer: return
	var world := grid_renderer.grid_to_world(grid_pos) + Vector2(grid_renderer.tile_size * 0.5, grid_renderer.tile_size * 0.5)
	camera.position = world
	if zoom_level > 0.0:
		camera.zoom_target = Vector2(zoom_level, zoom_level)

func _setup_initial_inventory():
	party_inventory.clear()
	add_item_to_inventory({
		"id": "pocion_vida_1",
		"name": "Bálsamo de Shallya",
		"type": "heal",
		"value": 10,
		"icon": "🧪",
		"desc": "Elixir medicinal bendito que cura 10 heridas graves."
	})
	add_item_to_inventory({
		"id": "pocion_furia_1",
		"name": "Pólvora Negra Refinada",
		"type": "resource",
		"value": 3,
		"icon": "⚡",
		"desc": "Recarga 3 puntos de recursos de combate (Furia/Pólvora/Magia)."
	})

func add_item_to_inventory(item: Dictionary) -> void:
	party_inventory.append(item)
	if EventBus:
		EventBus.inventory_updated.emit(party_inventory)

func remove_item_from_inventory(item_id: String) -> void:
	for i in party_inventory.size():
		if party_inventory[i]["id"] == item_id:
			party_inventory.remove_at(i)
			break
	if EventBus:
		EventBus.inventory_updated.emit(party_inventory)

func _subscribe_inventory_events() -> void:
	if not EventBus: return
	EventBus.item_used.connect(_on_item_used)

# Fase 3: autosave por turno. Snapshot v1: acto + inventario + PV de héroes
# del grid táctico (verdad en exploración; en combate refleja pre-combate —
# snapshot completo de combate queda para backlog).
func _subscribe_turn_events() -> void:
	if not EventBus: return
	EventBus.turn_ended.connect(_on_turn_ended)

func _on_turn_ended(_unit: Dictionary) -> void:
	var heroes_hp := {}
	if tactical_grid:
		for pos in tactical_grid.units_by_pos:
			var u = tactical_grid.units_by_pos[pos]
			if u.get("is_hero", false):
				heroes_hp[u.get("id", "")] = u.get("hp", 0)
	SaveSystem.auto_save_campaign_progress(current_act_number, party_inventory, heroes_hp, [])

func _on_item_used(item_id: String, user_id: String) -> void:
	var item_dict: Dictionary = {}
	for it in party_inventory:
		if it["id"] == item_id:
			item_dict = it
			break
	if item_dict.is_empty(): return

	var unit_pos = tactical_grid.pos_by_unit_id.get(user_id, Vector2i(-1, -1))
	if unit_pos == Vector2i(-1, -1): return
	var unit = tactical_grid.get_unit_at(unit_pos)
	if unit.is_empty(): return

	var u_name = unit.get("name", "Héroe")
	var it_type = item_dict.get("type", "heal")
	var it_val = item_dict.get("value", 5)

	if it_type == "heal":
		var new_hp = mini(unit.get("hp_max", 10), unit.get("hp", 10) + it_val)
		var delta = new_hp - unit.get("hp", 10)
		unit["hp"] = new_hp
		if EventBus:
			EventBus.health_updated.emit(user_id, new_hp, unit.get("hp_max", 10), delta)
			EventBus.floating_text_requested.emit("+%d HP" % delta, Color.GREEN, unit_pos)
			EventBus.combat_log_appended.emit("🧪 %s usa %s y recupera %d heridas." % [u_name, item_dict["name"], delta], "heal")
	elif it_type == "resource":
		var new_res = mini(unit.get("res_max", 10), unit.get("res", 0) + it_val)
		unit["res"] = new_res
		if EventBus:
			EventBus.floating_text_requested.emit("+%d %s" % [it_val, unit.get("res_name", "Rec")], Color.CYAN, unit_pos)
			EventBus.combat_log_appended.emit("⚡ %s usa %s y recarga su recurso de combate." % [u_name, item_dict["name"]], "crit")

	remove_item_from_inventory(item_id)

func _load_campaign_data():
	party_heroes.clear()
	# Fase 1: roster canon único vía ActLoader (antes 4 loads hardcodeados aquí
	# y otro roster distinto en main_menu_state.gd).
	party_heroes = ActLoader.load_party()
	
	if hud: hud.register_heroes_list(party_heroes)

func load_next_act() -> void:
	var next_act = current_act_number + 1
	if next_act > 4: next_act = 1 # Loop o Victoria de Campaña
	_load_act(next_act)

func _load_act(act_num: int) -> void:
	current_act_number = act_num
	# Fase 1: ruta del acto vía ActLoader (antes match hardcodeado).
	act_data = load(ActLoader.act_path(act_num)) as ActData
	if act_data == null:
		push_error("[GameManager] ActData no cargable para acto %d." % act_num)
		return
	
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_act_music"):
		audio_mgr.play_act_music(act_num)
	
	_setup_board_for_current_act()

func _setup_board_for_current_act():
	tactical_grid = TacticalGrid.new()
	if grid_renderer:
		grid_renderer.tactical_grid = tactical_grid
		grid_renderer._init_fog()

	var start_positions := ActLoader.START_POSITIONS

	for i in party_heroes.size():
		var h = party_heroes[i]
		var pos = start_positions[i]
		var hero_token := ActLoader.build_hero_token(h, i)
		tactical_grid.register_unit(hero_token, pos)

	# Fase 1: layout + spawns vía ActLoader.setup_board (antes match de ~120
	# líneas con stats hardcodeados; ahora stats desde EnemyData.base_hp).
	ActLoader.setup_board(tactical_grid, act_data)

	if EventBus:
		EventBus.tile_revealed.emit(Vector2i(4, 8), 5)

func generate_act_loot(act_num: int) -> Array[Dictionary]:
	var loot: Array[Dictionary] = []
	match act_num:
		1:
			loot.append({
				"id": "item_vial_shallya",
				"name": "Bálsamo Bendito de Shallya",
				"type": "heal", "value": 12, "icon": "🧪",
				"desc": "Sana 12 heridas graves y limpia el estado de Veneno."
			})
		2:
			loot.append({
				"id": "item_amuleto_sigmar",
				"name": "Amuelto del Martillo de Sigmar",
				"type": "equip", "slot": "accessory", "value": 2, "icon": "✝️",
				"desc": "+2 a la Clase de Armadura (AC) y resistencia a la Disformidad."
			})
		3:
			loot.append({
				"id": "item_hacha_gromril",
				"name": "Hacha Forjada en Gromril",
				"type": "equip", "slot": "weapon", "value": 4, "icon": "🪓",
				"desc": "+4 al daño físico de combate e ignora armaduras ligeras."
			})
		4:
			loot.append({
				"id": "item_elixir_aqshy",
				"name": "Elixir de los Vientos de Aqshy",
				"type": "resource", "value": 6, "icon": "🔥",
				"desc": "Restaura 6 puntos de recursos mágicos/furia al instante."
			})
	return loot

func grant_chest_loot_for_current_act() -> void:
	var items = generate_act_loot(current_act_number)
	for it in items:
		add_item_to_inventory(it)
	if EventBus:
		EventBus.combat_log_appended.emit("<b>🎁 ¡Cofre abierto! Se obtienen objetos de calidad imperial.</b>", "crit")
