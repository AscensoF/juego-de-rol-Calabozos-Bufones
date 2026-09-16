class_name GameOverState
extends State

## Estado de Fin de Partida / Victoria de Acto: Maneja pantallas modales con opción de reintentar o avanzar al siguiente acto.

var is_victory: bool = false
var modal_panel: PanelContainer
# Fase 4: Campamento de la Corte (servicios una vez por visita).
var camp_gold_label: Label
var camp_used_chapel: bool = false
var camp_used_minstrel: bool = false

const CAMP_BALSAM_COST := 10
const CAMP_POWDER_COST := 15
const CAMP_CHAPEL_COST := 40
const CAMP_MINSTREL_COST := 25

func _init() -> void:
	state_enum = Enums.GameFlowState.GAME_OVER

func enter(params: Dictionary = {}) -> void:
	is_victory = params.get("victory", false)
	camp_used_chapel = false
	camp_used_minstrel = false

	if is_victory:
		_grant_victory_rewards(int(params.get("total_xp", 0)))

	if EventBus:
		if is_victory:
			EventBus.status_panel_updated.emit("¡VICTORIA ÉPICA! Habéis limpiado la zona.")
			EventBus.combat_log_appended.emit("<b>¡ZONA COMPLETADA! La burocracia retrocede.</b>", "heal")
		else:
			EventBus.status_panel_updated.emit("GAME OVER: La pifia fue demasiado grande.")
			EventBus.combat_log_appended.emit("<b>Todos vuestros héroes yacen derrotados.</b>", "damage")

	_build_modal_ui()

func _build_modal_ui() -> void:
	var gm = state_machine.get_parent()
	if not gm: return
	var canvas = gm.get_node_or_null("CanvasLayer")
	if not canvas: return

	modal_panel = PanelContainer.new()
	modal_panel.name = "GameOverModal"
	modal_panel.set_anchors_preset(Control.PRESET_CENTER)
	modal_panel.custom_minimum_size = Vector2(440, 260)
	modal_panel.position = Vector2(-220, -130)
	canvas.add_child(modal_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	modal_panel.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "¡VICTORIA DEL ACTO!" if is_victory else "GAME OVER"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 30)
	title_lbl.add_theme_color_override("font_color", Color.GOLD if is_victory else Color.CORAL)
	vbox.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = "¡Habéis derrotado a las amenazas del calabozo!" if is_victory else "Vuestro grupo ha sucumbido en la oscuridad..."
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(desc_lbl)

	if is_victory:
		_build_camp_section(vbox)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 14)
	vbox.add_child(hbox)

	if is_victory:
		var next_act_btn := Button.new()
		next_act_btn.text = "⏩ Siguiente Acto"
		next_act_btn.custom_minimum_size = Vector2(160, 44)
		next_act_btn.pressed.connect(func():
			_cleanup_modal()
			advance_to_next_act()
		)
		hbox.add_child(next_act_btn)
	else:
		var retry_btn := Button.new()
		retry_btn.text = "🔄 Reintentar"
		retry_btn.custom_minimum_size = Vector2(140, 44)
		retry_btn.pressed.connect(func():
			_cleanup_modal()
			retry_from_checkpoint()
		)
		hbox.add_child(retry_btn)

	var menu_btn := Button.new()
	menu_btn.text = "🏠 Menú Principal"
	menu_btn.custom_minimum_size = Vector2(140, 44)
	menu_btn.pressed.connect(func():
		_cleanup_modal()
		return_to_main_menu()
	)
	hbox.add_child(menu_btn)

# Fase 4: XP + oro de victoria sobre el roster persistente (GameManager.party_heroes).
func _grant_victory_rewards(total_xp: int) -> void:
	var gm = state_machine.get_parent()
	if gm == null:
		return
	var act_num: int = gm.get("current_act_number") if gm.get("current_act_number") != null else 1
	var gold: int = Progression.victory_gold(act_num)
	if gm.has_method("add_party_gold"):
		gm.add_party_gold(gold)
	for line in Progression.grant_xp(gm.get("party_heroes") if gm.get("party_heroes") != null else [], total_xp):
		if EventBus:
			EventBus.combat_log_appended.emit(line, "heal")
	if EventBus:
		EventBus.combat_log_appended.emit("Botín de guerra: +%d monedas de oro." % gold, "crit")

# Fase 4: Campamento de la Corte — gasta el oro en servicios de grupo.
# Todo persiste en sesión (HeroData/inventario); persistencia entre sesiones: backlog.
func _build_camp_section(vbox: VBoxContainer) -> void:
	var gm = state_machine.get_parent()
	camp_gold_label = Label.new()
	camp_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	camp_gold_label.add_theme_font_size_override("font_size", 16)
	camp_gold_label.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(camp_gold_label)
	_refresh_camp_gold()

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)

	var balsam_btn := _camp_button(grid, "⚒️ Bálsamo (%dg)" % CAMP_BALSAM_COST)
	balsam_btn.pressed.connect(func():
		if gm and gm.spend_party_gold(CAMP_BALSAM_COST):
			gm.add_item_to_inventory({
				"id": "camp_balamo_%d" % Time.get_ticks_msec(),
				"name": "Bálsamo de Shallya",
				"type": "heal", "value": 10, "icon": "🧪",
				"desc": "Comprado en el campamento: cura 10 heridas."
			})
			_refresh_camp_section()
	)
	var powder_btn := _camp_button(grid, "🧨 Pólvora (%dg)" % CAMP_POWDER_COST)
	powder_btn.pressed.connect(func():
		if gm and gm.spend_party_gold(CAMP_POWDER_COST):
			gm.add_item_to_inventory({
				"id": "camp_polvora_%d" % Time.get_ticks_msec(),
				"name": "Pólvora Negra Refinada",
				"type": "resource", "value": 3, "icon": "⚡",
				"desc": "Comprada en el campamento: recarga 3 de recurso."
			})
			_refresh_camp_section()
	)
	var chapel_btn := _camp_button(grid, "⛪ Capilla: +2 PV grupo (%dg)" % CAMP_CHAPEL_COST)
	chapel_btn.pressed.connect(func():
		if camp_used_chapel:
			return
		if gm and gm.spend_party_gold(CAMP_CHAPEL_COST):
			camp_used_chapel = true
			for h in gm.party_heroes:
				if h is HeroData:
					h.base_hp += 2
			if EventBus: EventBus.combat_log_appended.emit("La Corte os bendice: +2 PV máximos a todo el grupo.", "heal")
			_refresh_camp_section()
	)
	var minstrel_btn := _camp_button(grid, "🎻 Juglaría: +1 recurso (%dg)" % CAMP_MINSTREL_COST)
	minstrel_btn.pressed.connect(func():
		if camp_used_minstrel:
			return
		if gm and gm.spend_party_gold(CAMP_MINSTREL_COST):
			camp_used_minstrel = true
			for h in gm.party_heroes:
				if h is HeroData:
					h.base_resource += 1
			if EventBus: EventBus.combat_log_appended.emit("¡Canción de valor! +1 recurso máximo a todo el grupo.", "heal")
			_refresh_camp_section()
	)

func _camp_button(parent: Control, text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(220, 48)
	btn.add_theme_font_size_override("font_size", 13)
	parent.add_child(btn)
	return btn

func _camp_gold() -> int:
	var gm = state_machine.get_parent()
	if gm and "party_gold" in gm:
		return int(gm.party_gold)
	return 0

func _refresh_camp_gold() -> void:
	if camp_gold_label:
		camp_gold_label.text = "🏕️ Campamento de la Corte — Oro del grupo: %dg" % _camp_gold()

func _refresh_camp_section() -> void:
	_refresh_camp_gold()
	if EventBus:
		EventBus.combat_log_appended.emit("Oro restante: %dg." % _camp_gold(), "info")

func _cleanup_modal() -> void:
	if modal_panel and is_instance_valid(modal_panel):
		modal_panel.queue_free()
		modal_panel = null

func advance_to_next_act() -> void:
	var gm = state_machine.get_parent()
	if gm and gm.has_method("load_next_act"):
		gm.load_next_act()
	state_machine.change_state(Enums.GameFlowState.EXPLORATION, {"new_act": true})

func retry_from_checkpoint() -> void:
	var gm = state_machine.get_parent()
	if gm and gm.has_method("_setup_board_for_current_act"):
		gm._setup_board_for_current_act()
	state_machine.change_state(Enums.GameFlowState.EXPLORATION, {"retry": true})

func return_to_main_menu() -> void:
	state_machine.change_state(Enums.GameFlowState.MAIN_MENU)

func exit() -> void:
	_cleanup_modal()

