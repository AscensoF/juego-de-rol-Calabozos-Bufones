class_name DJModeController
extends Control

## Controlador del Modo Director del Caos (Modo DJ).
## Permite pintar celdas, alternar niebla e invocar entidades en tiempo real para depuración y testing táctico.

var panel: PanelContainer
var cell_type_option: OptionButton
var enemy_type_option: OptionButton
var check_fog: CheckBox
var btn_close: Button

var selected_cell_type: Enums.CellType = Enums.CellType.WALL
var selected_spawn_path: String = "res://data/enemies/goblin_burocrata.tres"
var is_active: bool = false

# Fase 5b: catálogo de invocación por datos (antes 6 kinds sin spawn real).
const SPAWNABLE: Array = [
	{"label": "Goblin Burócrata", "path": "res://data/enemies/goblin_burocrata.tres"},
	{"label": "Esqueleto Desmotivado", "path": "res://data/enemies/esqueleto_desmotivado.tres"},
	{"label": "Limo de Café Rancio", "path": "res://data/enemies/limo_toxico.tres"},
	{"label": "Mímico de Archivo", "path": "res://data/enemies/mimeto_archivo.tres"},
	{"label": "Lancero Goblin Nocturno", "path": "res://data/enemies/goblin_nocturno.tres"},
	{"label": "Troll de Piedra", "path": "res://data/enemies/troll_piedra.tres"},
	{"label": "Guerrero del Caos", "path": "res://data/enemies/guerrero_caos.tres"},
	{"label": "Rey Orco del Karaoke (jefe)", "path": "res://data/enemies/rey_orco_karaoke.tres"},
	{"label": "Balthazar Auditor (jefe)", "path": "res://data/enemies/demonio_auditoria.tres"},
	{"label": "Grimgar Kaudillo (jefe)", "path": "res://data/enemies/caudillo_orco_negro.tres"},
	{"label": "Malakor Profanador (jefe)", "path": "res://data/enemies/paladin_elegido_caos.tres"},
]

func _ready() -> void:
	visible = false
	_build_ui()
	if EventBus:
		EventBus.dj_mode_toggled.connect(_on_dj_mode_toggled)

func _build_ui() -> void:
	anchors_preset = PRESET_FULL_RECT
	mouse_filter = MOUSE_FILTER_IGNORE

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 360)
	panel.position = Vector2(20, 70)
	add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "🎛️ DIRECTOR DEL CAOS (DJ)"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(title)

	var lbl_cells := Label.new()
	lbl_cells.text = "Pintar Celda:"
	vbox.add_child(lbl_cells)

	cell_type_option = OptionButton.new()
	cell_type_option.add_item("Suelo", Enums.CellType.FLOOR)
	cell_type_option.add_item("Muro", Enums.CellType.WALL)
	cell_type_option.add_item("Puerta", Enums.CellType.DOOR)
	cell_type_option.add_item("Trampa (1d6)", Enums.CellType.TRAP)
	cell_type_option.add_item("Cofre", Enums.CellType.CHEST)
	cell_type_option.add_item("Altar", Enums.CellType.ALTAR)
	cell_type_option.add_item("Librería", Enums.CellType.BOOKSHELF)
	cell_type_option.item_selected.connect(func(idx): selected_cell_type = cell_type_option.get_item_id(idx) as Enums.CellType)
	vbox.add_child(cell_type_option)

	var lbl_enemies := Label.new()
	lbl_enemies.text = "Invocar Monstruo:"
	vbox.add_child(lbl_enemies)

	enemy_type_option = OptionButton.new()
	for entry in SPAWNABLE:
		enemy_type_option.add_item(entry["label"])
	enemy_type_option.item_selected.connect(func(idx): selected_spawn_path = SPAWNABLE[idx]["path"])
	vbox.add_child(enemy_type_option)

	var btn_spawn := Button.new()
	btn_spawn.text = "👹 Invocar en Celda Libre"
	btn_spawn.tooltip_text = "Genera al monstruo en una casilla de suelo libre al azar (verdad de exploración)."
	btn_spawn.pressed.connect(_on_spawn_pressed)
	vbox.add_child(btn_spawn)

	check_fog = CheckBox.new()
	check_fog.text = "Desactivar Niebla de Guerra"
	check_fog.toggled.connect(_on_fog_toggled)
	vbox.add_child(check_fog)

	var btn_heal_all := Button.new()
	btn_heal_all.text = "💚 Curar a Todo el Grupo"
	btn_heal_all.pressed.connect(_on_heal_party_pressed)
	vbox.add_child(btn_heal_all)

	var btn_kill_enemies := Button.new()
	btn_kill_enemies.text = "💀 Eliminar Enemigos"
	btn_kill_enemies.pressed.connect(_on_kill_enemies_pressed)
	vbox.add_child(btn_kill_enemies)

	btn_close = Button.new()
	btn_close.text = "Cerrar Modo DJ"
	btn_close.pressed.connect(_on_close_pressed)
	vbox.add_child(btn_close)

func _on_dj_mode_toggled(active: bool) -> void:
	is_active = active
	visible = active

func _on_fog_toggled(toggled_on: bool) -> void:
	if EventBus: EventBus.dj_fog_cleared.emit(toggled_on)

func _on_heal_party_pressed() -> void:
	# Fase 5: efecto real sobre el grid (antes solo log). Héroes vivos al máximo.
	var grid := _find_grid()
	if grid == null:
		return
	var healed := 0
	for pos in grid.units_by_pos:
		var u = grid.units_by_pos[pos]
		if u.get("is_hero", false) and u.get("is_alive", false):
			var delta: int = int(u.get("hp_max", u.get("hp", 0))) - int(u.get("hp", 0))
			u["hp"] = u.get("hp_max", u.get("hp", 0))
			healed += 1
			if EventBus:
				EventBus.health_updated.emit(u.get("id", ""), u["hp"], u.get("hp_max", 0), delta)
				EventBus.floating_text_requested.emit("+%d HP" % delta, Color.GREEN, pos)
	if EventBus:
		EventBus.combat_log_appended.emit("[DJ] %d héroes sanados por completo." % healed, "heal")
		EventBus.redraw_requested.emit()

func _on_kill_enemies_pressed() -> void:
	# Fase 5: efecto real sobre el grid (antes solo log). NOTA: en combate las
	# listas de CombatState son copias — el DJ actúa sobre la verdad de
	# exploración; usar fuera de combate o re-iniciar el encuentro.
	var grid := _find_grid()
	if grid == null:
		return
	var slain := 0
	for pos in grid.units_by_pos:
		var u = grid.units_by_pos[pos]
		if not u.get("is_hero", false) and u.get("is_alive", false):
			u["is_alive"] = false
			u["hp"] = 0
			slain += 1
			if EventBus:
				EventBus.unit_defeated.emit(u.get("id", ""), false, 0)
	if EventBus:
		EventBus.combat_log_appended.emit("[DJ] %d aberraciones eliminadas por el Director del Caos." % slain, "crit")
		EventBus.redraw_requested.emit()

func _on_spawn_pressed() -> void:
	var grid := _find_grid()
	if grid == null:
		return
	var data: EnemyData = load(selected_spawn_path) as EnemyData
	if data == null:
		push_error("[DJ] No se pudo cargar: %s" % selected_spawn_path)
		return
	var cell := _find_free_cell(grid)
	if cell == Vector2i(-1, -1):
		if EventBus: EventBus.combat_log_appended.emit("[DJ] Sin celdas libres para invocar.", "info")
		return
	var token := ActLoader.build_enemy_token(data, "dj_enemy_%d" % Time.get_ticks_msec(), data.enemy_name)
	grid.register_unit(token, cell)
	if EventBus:
		EventBus.combat_log_appended.emit("[DJ] Invocado %s en [%d, %d]." % [data.enemy_name, cell.x, cell.y], "crit")
		EventBus.redraw_requested.emit()

func _find_free_cell(grid: TacticalGrid) -> Vector2i:
	for i in 40:
		var p := Vector2i(randi() % TacticalGrid.WIDTH, randi() % TacticalGrid.HEIGHT)
		if grid.get_cell_type(p) == Enums.CellType.FLOOR and not grid.units_by_pos.has(p):
			return p
	return Vector2i(-1, -1)

func _find_grid() -> TacticalGrid:
	var gm = get_tree().get_root().get_node_or_null("MainGame")
	if gm == null:
		return null
	return gm.get("tactical_grid") as TacticalGrid

func _on_close_pressed() -> void:
	if EventBus: EventBus.dj_mode_toggled.emit(false)

