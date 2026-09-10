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

func _ready():
	tactical_grid = TacticalGrid.new()
	combat_invoker = CombatInvoker.new()

	if grid_renderer:
		grid_renderer.tactical_grid = tactical_grid
	if hud:
		hud.combat_invoker = combat_invoker

	_load_campaign_data()
	_setup_initial_board()

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
	
	if hud:
		hud.register_heroes_list(party_heroes)

func _setup_initial_board():
	var start_positions := [
		Vector2i(4, 8), Vector2i(4, 9),
		Vector2i(3, 8), Vector2i(3, 9)
	]
	
	for i in party_heroes.size():
		var h = party_heroes[i]
		var pos = start_positions[i]
		var h_name = h.get("hero_name") if h.get("hero_name") != null else "Hero " + str(i)
		var h_hp = h.get("base_hp") if h.get("base_hp") != null else 10
		var h_res = h.get("base_resource") if h.get("base_resource") != null else 10
		var h_ac = h.get("base_ac") if h.get("base_ac") != null else 10
		var h_speed = h.get("speed") if h.get("speed") != null else 4
		
		var hero_token := {
			"id": h.resource_path.get_file().get_basename() if h.resource_path else "h" + str(i),
			"name": h_name,
			"is_hero": true,
			"data": h,
			"hp": h_hp, "hp_max": h_hp,
			"res": h_res, "res_max": h_res,
			"ac": h_ac,
			"speed": h_speed,
			"buffs": [], "is_alive": true
		}
		tactical_grid.register_unit(hero_token, pos)

	tactical_grid.set_cell_type(Vector2i(8, 8), Enums.CellType.TRAP)
	tactical_grid.set_cell_type(Vector2i(10, 5), Enums.CellType.CHEST)
	tactical_grid.set_cell_type(Vector2i(6, 12), Enums.CellType.ALTAR)
	tactical_grid.set_cell_type(Vector2i(14, 4), Enums.CellType.BOOKSHELF)

	var goblin_data = load("res://data/enemies/goblin_burocrata.tres")
	var esqueleto_data = load("res://data/enemies/esqueleto_desmotivado.tres")

	if goblin_data:
		tactical_grid.register_unit({
			"id": "enemy_goblin_1",
			"name": goblin_data.get("enemy_name") if goblin_data.get("enemy_name") != null else "Goblin",
			"is_hero": false, "data": goblin_data,
			"hp": goblin_data.get("base_hp") if goblin_data.get("base_hp") != null else 5,
			"hp_max": goblin_data.get("base_hp") if goblin_data.get("base_hp") != null else 5,
			"ac": goblin_data.get("armor_class") if goblin_data.get("armor_class") != null else 8,
			"speed": goblin_data.get("speed") if goblin_data.get("speed") != null else 4,
			"init_bonus": goblin_data.get("initiative_bonus") if goblin_data.get("initiative_bonus") != null else 1,
			"buffs": [], "is_alive": true
		}, Vector2i(12, 8))

	if esqueleto_data:
		tactical_grid.register_unit({
			"id": "enemy_esq_1",
			"name": esqueleto_data.get("enemy_name") if esqueleto_data.get("enemy_name") != null else "Esqueleto",
			"is_hero": false, "data": esqueleto_data,
			"hp": esqueleto_data.get("base_hp") if esqueleto_data.get("base_hp") != null else 6,
			"hp_max": esqueleto_data.get("base_hp") if esqueleto_data.get("base_hp") != null else 6,
			"ac": esqueleto_data.get("armor_class") if esqueleto_data.get("armor_class") != null else 10,
			"speed": esqueleto_data.get("speed") if esqueleto_data.get("speed") != null else 3,
			"init_bonus": esqueleto_data.get("initiative_bonus") if esqueleto_data.get("initiative_bonus") != null else 0,
			"buffs": [], "is_alive": true
		}, Vector2i(15, 10))

	if EventBus:
		EventBus.tile_revealed.emit(Vector2i(4, 8), 5)

