class_name ActLoader
extends RefCounted

## Fase 1: única fuente de construcción de tablero por acto.
## game_manager.gd y main_menu_state.gd deben usar PARTY_ROSTER y setup_board.
## Stats desde EnemyData/HeroData (.tres); layout (tiles/spawns) en BOARD_PRESETS
## hasta que ActData exponga board_* (Fase 2).
##
## Cambio de balance Fase 1 (intencionado, data-driven):
## los PV de spawn ahora salen de EnemyData.base_hp en vez de valores
## hardcodeados en game_manager (ej. demonio 30->28, troll 24->22, paladín 50->45).

const PARTY_ROSTER: Array[String] = [
	"res://data/heroes/gotreksson.tres",
	"res://data/heroes/kallina.tres",
	"res://data/heroes/valtieri.tres",
	"res://data/heroes/beryl_sigmar.tres",
]

const ACT_PATHS := {
	1: "res://data/acts/act_01_taberna.tres",
	2: "res://data/acts/act_02_catacumbas.tres",
	3: "res://data/acts/act_03_minas_kadrin.tres",
	4: "res://data/acts/act_04_fortaleza_caos.tres",
}

const START_POSITIONS: Array[Vector2i] = [
	Vector2i(4, 8), Vector2i(4, 9),
	Vector2i(3, 8), Vector2i(3, 9),
]

# kind: "listed" (act_data.available_enemies[index]) o "boss" (act_data.boss).
const BOARD_PRESETS := {
	1: {
		"tiles": [
			[8, 8, Enums.CellType.TRAP], [10, 5, Enums.CellType.CHEST],
			[6, 12, Enums.CellType.ALTAR], [14, 4, Enums.CellType.BOOKSHELF],
		],
		"enemies": [
			{"kind": "listed", "index": 0, "id": "enemy_skaven_1", "name": "Guerrero de Clan Skaven", "pos": Vector2i(12, 8)},
			{"kind": "listed", "index": 1, "id": "enemy_rata_1", "name": "Rata Gigante de Alcantarilla", "pos": Vector2i(15, 10)},
		],
	},
	2: {
		"tiles": [
			[7, 6, Enums.CellType.TRAP], [11, 10, Enums.CellType.TRAP],
			[14, 5, Enums.CellType.CHEST], [8, 14, Enums.CellType.ALTAR],
		],
		"enemies": [
			{"kind": "listed", "index": 0, "id": "enemy_limo_1", "name": "Engendro de Nurgle", "pos": Vector2i(11, 7)},
			{"kind": "listed", "index": 1, "id": "enemy_mimi_1", "name": "Cazador Furtivo Hombre Bestia", "pos": Vector2i(15, 8)},
			{"kind": "boss", "id": "enemy_boss_2", "name": "Caudillo Gor de Nurgle", "pos": Vector2i(18, 11)},
		],
	},
	3: {
		"tiles": [
			[6, 6, Enums.CellType.TRAP], [12, 12, Enums.CellType.CHEST],
			[16, 6, Enums.CellType.ALTAR],
		],
		"enemies": [
			{"kind": "listed", "index": 0, "id": "enemy_gob_kadrin", "name": "Lancero Goblin Nocturno", "pos": Vector2i(11, 8)},
			{"kind": "listed", "index": 1, "id": "enemy_troll_kadrin", "name": "Troll de Piedra Come-Enanos", "pos": Vector2i(15, 9)},
			{"kind": "boss", "id": "enemy_orco_boss_3", "name": "Grimgar Machakarock", "pos": Vector2i(18, 12)},
		],
	},
	4: {
		"tiles": [
			[8, 6, Enums.CellType.TRAP], [10, 12, Enums.CellType.TRAP],
			[15, 5, Enums.CellType.CHEST], [6, 14, Enums.CellType.ALTAR],
		],
		"enemies": [
			{"kind": "listed", "index": 0, "id": "enemy_caos_1", "name": "Guerrero del Caos de Khorne", "pos": Vector2i(12, 8)},
			{"kind": "boss", "id": "enemy_paladin_boss_4", "name": "Malakor el Profanador", "pos": Vector2i(18, 10)},
		],
	},
}

static func load_party() -> Array:
	var party: Array = []
	for path in PARTY_ROSTER:
		var h: HeroData = load(path) as HeroData
		if h == null:
			push_error("[ActLoader] Héroe canon no cargable: %s" % path)
			continue
		party.append(h)
	return party

static func act_path(act_num: int) -> String:
	return ACT_PATHS.get(act_num, ACT_PATHS[1])

static func build_hero_token(h: HeroData, idx: int) -> Dictionary:
	return {
		"id": "hero_" + str(idx),
		"name": h.hero_name if h.hero_name != "" else "Héroe",
		"is_hero": true, "data": h,
		"hp": h.base_hp,
		"hpmax": h.base_hp,
		"res": h.base_resource,
		"res_max": h.base_resource,
		"res_name": h.resource_name if h.resource_name != "" else "Recurso",
		"speed": h.speed,
		"is_alive": true,
	}

static func build_enemy_token(data: EnemyData, unit_id: String, display_name: String) -> Dictionary:
	return {
		"id": unit_id,
		"name": display_name if display_name != "" else data.enemy_name,
		"is_hero": false, "data": data,
		"hp": data.base_hp, "hp_max": data.base_hp,
		"is_alive": true,
	}

# Fase 5c: invocación puntual por datos (Modo DJ). Devuelve el token o {}.
static func spawn_enemy_at(grid: TacticalGrid, data_path: String, pos: Vector2i, id_prefix: String = "dj_enemy") -> Dictionary:
	if grid == null:
		return {}
	var data: EnemyData = load(data_path) as EnemyData
	if data == null:
		push_error("[ActLoader] Enemigo no cargable: %s" % data_path)
		return {}
	if not grid.is_in_bounds(pos):
		return {}
	if grid.get_cell_type(pos) == Enums.CellType.WALL:
		return {}
	if grid.units_by_pos.has(pos):
		return {}
	var token := build_enemy_token(data, "%s_%d" % [id_prefix, Time.get_ticks_msec()], data.enemy_name)
	grid.register_unit(token, pos)
	return token

static func setup_board(grid: TacticalGrid, act_data: ActData) -> void:
	if grid == null or act_data == null:
		push_error("[ActLoader] setup_board con grid o act_data nulos.")
		return
	var preset: Dictionary = BOARD_PRESETS.get(act_data.act_number, BOARD_PRESETS[1])
	for t in preset["tiles"]:
		grid.set_cell_type(Vector2i(t[0], t[1]), t[2])
	for e in preset["enemies"]:
		var data: EnemyData = null
		if e["kind"] == "boss":
			data = act_data.boss
		else:
			var idx: int = e.get("index", 0)
			if idx >= 0 and idx < act_data.available_enemies.size():
				data = act_data.available_enemies[idx]
		if data == null:
			push_error("[ActLoader] Enemigo no resoluble en acto %d: %s" % [act_data.act_number, e["id"]])
			continue
		grid.register_unit(build_enemy_token(data, e["id"], e["name"]), e["pos"])
