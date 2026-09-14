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

# Inventario compartido del grupo
var party_inventory: Array[Dictionary] = []

func _ready():
	RenderingServer.set_default_clear_color(Color(0.04, 0.06, 0.10, 1.0))
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
	_setup_initial_board()
	_subscribe_inventory_events()
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
				"speaker": "El DJ de la Mazmorra",
				"text": "¡Bienvenidos a la Taberna del Caos, bufones! La junta directiva exige que limpiéis este calabozo antes de que expire vuestro contrato laboral.",
				"portrait": "res://assets/sprites/ui/logo.png"
			},
			{
				"speaker": "Throg",
				"text": "¿Contrato? ¡Throg solo entender que aplastar cráneos resuelve cualquier trámite burocrático!",
				"portrait": "res://assets/sprites/characters/heroes/throg.png"
			},
			{
				"speaker": "Elowen",
				"text": "Cálmate, bárbaro. Revisa tu mochila antes de avanzar hacia las sombras... y cuidado con las trampas en el suelo.",
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
		"name": "Poción de Vida",
		"type": "heal",
		"value": 8,
		"icon": "🧪",
		"desc": "Cura 8 puntos de vida al héroe seleccionado."
	})
	add_item_to_inventory({
		"id": "pocion_furia_1",
		"name": "Elixir de Furia",
		"type": "resource",
		"value": 2,
		"icon": "⚡",
		"desc": "Restaura 2 puntos de recurso/furia/maná."
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
			EventBus.combat_log_appended.emit("🧪 %s usa %s y recupera %d HP." % [u_name, item_dict["name"], delta], "heal")
	elif it_type == "resource":
		var new_res = mini(unit.get("res_max", 10), unit.get("res", 0) + it_val)
		unit["res"] = new_res
		if EventBus:
			EventBus.floating_text_requested.emit("+%d %s" % [it_val, unit.get("res_name", "Rec")], Color.CYAN, unit_pos)
			EventBus.combat_log_appended.emit("⚡ %s usa %s y recarga su recurso de combate." % [u_name, item_dict["name"]], "crit")

	remove_item_from_inventory(item_id)

func _load_campaign_data():
	act_data = load("res://data/acts/act_01_taberna.tres") as ActData
	var throg = load("res://data/heroes/throg.tres")
	var elowen = load("res://data/heroes/elowen.tres")
	var grimble = load("res://data/heroes/grimble.tres")
	var beryl = load("res://data/heroes/beryl.tres")
	
	if throg: party_heroes.append(throg)
	if elowen: party_heroes.append(elowen)
	if grimble: party_heroes.append(grimble)
	if beryl: party_heroes.append(beryl)
	
	if hud: hud.register_heroes_list(party_heroes)

func _setup_initial_board():
	var start_positions := [
		Vector2i(4, 8), Vector2i(4, 9),
		Vector2i(3, 8), Vector2i(3, 9)
	]
	
	for i in party_heroes.size():
		var h = party_heroes[i]
		var pos = start_positions[i]
		var hero_token := {
			"id": "hero_" + str(i),
			"name": h.get("hero_name") if h.get("hero_name") != null else "Hero",
			"is_hero": true, "data": h,
			"hp": h.get("base_hp") if h.get("base_hp") != null else 10,
			"hp_max": h.get("base_hp") if h.get("base_hp") != null else 10,
			"res": h.get("base_resource") if h.get("base_resource") != null else 10,
			"res_max": h.get("base_resource") if h.get("base_resource") != null else 10,
			"res_name": h.get("resource_name") if h.get("resource_name") != null else "Furia",
			"speed": h.get("speed") if h.get("speed") != null else 4,
			"is_alive": true
		}
		tactical_grid.register_unit(hero_token, pos)

	tactical_grid.set_cell_type(Vector2i(8, 8), Enums.CellType.TRAP)
	tactical_grid.set_cell_type(Vector2i(10, 5), Enums.CellType.CHEST)
	tactical_grid.set_cell_type(Vector2i(6, 12), Enums.CellType.ALTAR)
	tactical_grid.set_cell_type(Vector2i(14, 4), Enums.CellType.BOOKSHELF)

	var goblin_data = load("res://data/enemies/goblin_burocrata.tres")
	if goblin_data:
		tactical_grid.register_unit({
			"id": "enemy_goblin_1",
			"name": goblin_data.get("enemy_name") if goblin_data.get("enemy_name") != null else "Goblin",
			"is_hero": false, "data": goblin_data,
			"hp": goblin_data.get("base_hp") if goblin_data.get("base_hp") != null else 5,
			"hp_max": goblin_data.get("base_hp") if goblin_data.get("base_hp") != null else 5,
			"is_alive": true
		}, Vector2i(12, 8))

	var esq_data = load("res://data/enemies/esqueleto_desmotivado.tres")
	if esq_data:
		tactical_grid.register_unit({
			"id": "enemy_esq_1",
			"name": esq_data.get("enemy_name") if esq_data.get("enemy_name") != null else "Esqueleto",
			"is_hero": false, "data": esq_data,
			"hp": esq_data.get("base_hp") if esq_data.get("base_hp") != null else 6,
			"hp_max": esq_data.get("base_hp") if esq_data.get("base_hp") != null else 6,
			"is_alive": true
		}, Vector2i(15, 10))

	if EventBus:
		EventBus.tile_revealed.emit(Vector2i(4, 8), 5)

