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
	var gotrek = load("res://data/heroes/gotreksson.tres")
	var kallina = load("res://data/heroes/kallina.tres")
	var valtieri = load("res://data/heroes/valtieri.tres")
	var beryl = load("res://data/heroes/beryl_sigmar.tres")
	
	if gotrek: party_heroes.append(gotrek)
	if kallina: party_heroes.append(kallina)
	if valtieri: party_heroes.append(valtieri)
	if beryl: party_heroes.append(beryl)
	
	if hud: hud.register_heroes_list(party_heroes)

func load_next_act() -> void:
	var next_act = current_act_number + 1
	if next_act > 4: next_act = 1 # Loop o Victoria de Campaña
	_load_act(next_act)

func _load_act(act_num: int) -> void:
	current_act_number = act_num
	match act_num:
		1: act_data = load("res://data/acts/act_01_taberna.tres") as ActData
		2: act_data = load("res://data/acts/act_02_catacumbas.tres") as ActData
		3: act_data = load("res://data/acts/act_03_minas_kadrin.tres") as ActData
		4: act_data = load("res://data/acts/act_04_fortaleza_caos.tres") as ActData
	
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_act_music"):
		audio_mgr.play_act_music(act_num)
	
	_setup_board_for_current_act()

func _setup_board_for_current_act():
	tactical_grid = TacticalGrid.new()
	if grid_renderer:
		grid_renderer.tactical_grid = tactical_grid
		grid_renderer._init_fog()

	var start_positions := [
		Vector2i(4, 8), Vector2i(4, 9),
		Vector2i(3, 8), Vector2i(3, 9)
	]
	
	for i in party_heroes.size():
		var h = party_heroes[i]
		var pos = start_positions[i]
		var hero_token := {
			"id": "hero_" + str(i),
			"name": h.get("hero_name") if h.get("hero_name") != null else "Héroe",
			"is_hero": true, "data": h,
			"hp": h.get("base_hp") if h.get("base_hp") != null else 12,
			"hp_max": h.get("base_hp") if h.get("base_hp") != null else 12,
			"res": h.get("base_resource") if h.get("base_resource") != null else 4,
			"res_max": h.get("base_resource") if h.get("base_resource") != null else 4,
			"res_name": h.get("resource_name") if h.get("resource_name") != null else "Recurso",
			"speed": h.get("speed") if h.get("speed") != null else 4,
			"is_alive": true
		}
		tactical_grid.register_unit(hero_token, pos)

	match current_act_number:
		1:
			# Acto 1: Alcantarillas de Altdorf (Skavens)
			tactical_grid.set_cell_type(Vector2i(8, 8), Enums.CellType.TRAP)
			tactical_grid.set_cell_type(Vector2i(10, 5), Enums.CellType.CHEST)
			tactical_grid.set_cell_type(Vector2i(6, 12), Enums.CellType.ALTAR)
			tactical_grid.set_cell_type(Vector2i(14, 4), Enums.CellType.BOOKSHELF)
			
			var goblin_data = load("res://data/enemies/goblin_burocrata.tres")
			if goblin_data:
				tactical_grid.register_unit({
					"id": "enemy_skaven_1",
					"name": "Guerrero de Clan Skaven",
					"is_hero": false, "data": goblin_data,
					"hp": 8, "hp_max": 8,
					"is_alive": true
				}, Vector2i(12, 8))

			var esq_data = load("res://data/enemies/esqueleto_desmotivado.tres")
			if esq_data:
				tactical_grid.register_unit({
					"id": "enemy_rata_1",
					"name": "Rata Gigante de Alcantarilla",
					"is_hero": false, "data": esq_data,
					"hp": 6, "hp_max": 6,
					"is_alive": true
				}, Vector2i(15, 10))

		2:
			# Acto 2: El Bosque de las Sombras (Hombres Bestia y Nurgle)
			tactical_grid.set_cell_type(Vector2i(7, 6), Enums.CellType.TRAP)
			tactical_grid.set_cell_type(Vector2i(11, 10), Enums.CellType.TRAP)
			tactical_grid.set_cell_type(Vector2i(14, 5), Enums.CellType.CHEST)
			tactical_grid.set_cell_type(Vector2i(8, 14), Enums.CellType.ALTAR)
			
			var limo_data = load("res://data/enemies/limo_toxico.tres")
			if limo_data:
				tactical_grid.register_unit({
					"id": "enemy_limo_1",
					"name": "Engendro de Nurgle",
					"is_hero": false, "data": limo_data,
					"hp": 14, "hp_max": 14,
					"is_alive": true
				}, Vector2i(11, 7))
			
			var mimi_data = load("res://data/enemies/mimeto_archivo.tres")
			if mimi_data:
				tactical_grid.register_unit({
					"id": "enemy_mimi_1",
					"name": "Cazador Furtivo Hombre Bestia",
					"is_hero": false, "data": mimi_data,
					"hp": 16, "hp_max": 16,
					"is_alive": true
				}, Vector2i(15, 8))
			
			var boss_data = load("res://data/enemies/demonio_auditoria.tres")
			if boss_data:
				tactical_grid.register_unit({
					"id": "enemy_boss_2",
					"name": "Caudillo Gor de Nurgle",
					"is_hero": false, "data": boss_data,
					"hp": 30, "hp_max": 30,
					"is_alive": true
				}, Vector2i(18, 11))

		3:
			# Acto 3: Las Minas Olvidadas de Karak Kadrin (Pielesverdes y Trolls)
			tactical_grid.set_cell_type(Vector2i(6, 6), Enums.CellType.TRAP)
			tactical_grid.set_cell_type(Vector2i(12, 12), Enums.CellType.CHEST)
			tactical_grid.set_cell_type(Vector2i(16, 6), Enums.CellType.ALTAR)
			
			var gob_data = load("res://data/enemies/goblin_nocturno.tres")
			if gob_data:
				tactical_grid.register_unit({
					"id": "enemy_gob_kadrin",
					"name": "Lancero Goblin Nocturno",
					"is_hero": false, "data": gob_data,
					"hp": 10, "hp_max": 10,
					"is_alive": true
				}, Vector2i(11, 8))
			
			var troll_data = load("res://data/enemies/troll_piedra.tres")
			if troll_data:
				tactical_grid.register_unit({
					"id": "enemy_troll_kadrin",
					"name": "Troll de Piedra Come-Enanos",
					"is_hero": false, "data": troll_data,
					"hp": 24, "hp_max": 24,
					"is_alive": true
				}, Vector2i(15, 9))
			
			var orco_boss = load("res://data/enemies/caudillo_orco_negro.tres")
			if orco_boss:
				tactical_grid.register_unit({
					"id": "enemy_orco_boss_3",
					"name": "Grimgar Machakarock",
					"is_hero": false, "data": orco_boss,
					"hp": 38, "hp_max": 38,
					"is_alive": true
				}, Vector2i(18, 12))

		4:
			# Acto 4: La Fortaleza de la Disformidad (Guerreros del Caos)
			tactical_grid.set_cell_type(Vector2i(8, 6), Enums.CellType.TRAP)
			tactical_grid.set_cell_type(Vector2i(10, 12), Enums.CellType.TRAP)
			tactical_grid.set_cell_type(Vector2i(15, 5), Enums.CellType.CHEST)
			tactical_grid.set_cell_type(Vector2i(6, 14), Enums.CellType.ALTAR)
			
			var caos_data = load("res://data/enemies/guerrero_caos.tres")
			if caos_data:
				tactical_grid.register_unit({
					"id": "enemy_caos_1",
					"name": "Guerrero del Caos de Khorne",
					"is_hero": false, "data": caos_data,
					"hp": 22, "hp_max": 22,
					"is_alive": true
				}, Vector2i(12, 8))
			
			var paladin_boss = load("res://data/enemies/paladin_elegido_caos.tres")
			if paladin_boss:
				tactical_grid.register_unit({
					"id": "enemy_paladin_boss_4",
					"name": "Malakor el Profanador",
					"is_hero": false, "data": paladin_boss,
					"hp": 50, "hp_max": 50,
					"is_alive": true
				}, Vector2i(18, 10))

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
