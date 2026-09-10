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
var selected_enemy_kind: Enums.EnemyKind = Enums.EnemyKind.GOBLIN_BUROCRATA
var is_active: bool = false

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

	# 1. PINTAR CELDAS
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

	# 2. INVOCAR ENEMIGOS
	var lbl_enemies := Label.new()
	lbl_enemies.text = "Invocar Monstruo:"
	vbox.add_child(lbl_enemies)

	enemy_type_option = OptionButton.new()
	enemy_type_option.add_item("Goblin Burócrata", Enums.EnemyKind.GOBLIN_BUROCRATA)
	enemy_type_option.add_item("Esqueleto Desmotivado", Enums.EnemyKind.ESQUELETO_DESMOTIVADO)
	enemy_type_option.add_item("Orco Chistoso", Enums.EnemyKind.ORCO_CHISTOSO)
	enemy_type_option.add_item("Mímico Existencial", Enums.EnemyKind.MIMICO_EXISTENCIAL)
	enemy_type_option.add_item("Limo de la Nostalgia", Enums.EnemyKind.LIMO_NOSTALGIA)
	enemy_type_option.add_item("Rey Orco del Karaoke (Jefe)", Enums.EnemyKind.REY_ORCO_KARAOKE)
	enemy_type_option.item_selected.connect(func(idx): selected_enemy_kind = enemy_type_option.get_item_id(idx) as Enums.EnemyKind)
	vbox.add_child(enemy_type_option)

	# 3. NIEBLA DE GUERRA
	check_fog = CheckBox.new()
	check_fog.text = "Desactivar Niebla de Guerra"
	check_fog.toggled.connect(_on_fog_toggled)
	vbox.add_child(check_fog)

	# 4. BOTONES DE ACCIÓN RÁPIDA / CHEATS
	var btn_heal_all := Button.new()
	btn_heal_all.text = "💚 Curar a Todo el Grupo"
	btn_heal_all.pressed.connect(_on_heal_party_pressed)
	vbox.add_child(btn_heal_all)

	var btn_kill_enemies := Button.new()
	btn_kill_enemies.text = "💀 Eliminar Enemigos"
	btn_kill_enemies.pressed.connect(_on_kill_enemies_pressed)
	vbox.add_child(btn_kill_enemies)

	# 5. SALIR
	btn_close = Button.new()
	btn_close.text = "Cerrar Modo DJ"
	btn_close.pressed.connect(_on_close_pressed)
	vbox.add_child(btn_close)

func _on_dj_mode_toggled(active: bool) -> void:
	is_active = active
	visible = active

func _on_fog_toggled(toggled_on: bool) -> void:
	if EventBus:
		EventBus.dj_fog_cleared.emit(toggled_on)

func _on_heal_party_pressed() -> void:
	if EventBus:
		EventBus.combat_log_appended.emit("[DJ Cheat] Todos los héroes han sido sanados por completo.", "heal")

func _on_kill_enemies_pressed() -> void:
	if EventBus:
		EventBus.combat_log_appended.emit("[DJ Cheat] Aberraciones eliminadas por el Director del Caos.", "crit")

func _on_close_pressed() -> void:
	if EventBus:
		EventBus.dj_mode_toggled.emit(false)
