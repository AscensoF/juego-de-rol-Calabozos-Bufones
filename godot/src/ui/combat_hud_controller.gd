class_name CombatHUDController
extends Control

## HUD de combate y exploración estilo Baldur's Gate 3 / Final Fantasy X:
## - Barra superior de orden de iniciativa (Turn Track con iconos en fila).
## - Banner cinemático de cambio de turno ("⚔️ Turno de Gotreksson").
## - Party Bar lateral izquierda con retratos y barras de HP en tiempo real.
## - Action Bar inferior ergonómica con botón de Pasar Turno.

var combat_invoker: CombatInvoker
var game_manager: GameManager
var status_label: Label
var log_richtext: RichTextLabel
var heroes_bar: VBoxContainer
var action_bar: PanelContainer
var abilities_container: HBoxContainer
var inventory_panel: PanelContainer
var inventory_container: HBoxContainer

# Barra de Iniciativa / Turn Track
var turn_track_container: HBoxContainer
var turn_banner_panel: PanelContainer
var turn_banner_title: Label
var turn_banner_sub: Label

var hero_cards: Dictionary = {}
var selected_ability: AbilityData = null
var current_active_unit: Dictionary = {}
var initiative_list: Array = []


static func create_grimdark_panel_style(bg_color: Color = Color(0.08, 0.09, 0.12, 0.88), border_color: Color = Color(0.65, 0.52, 0.28, 0.9), corner_radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(corner_radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 4
	return sb

static func create_grimdark_button_style(bg_color: Color = Color(0.14, 0.16, 0.22, 0.92), border_color: Color = Color(0.75, 0.62, 0.35, 0.8), corner_radius: int = 5) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(corner_radius)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 2
	return sb

const LOG_COLORS := {
	"game": Color(0.95, 0.9, 0.75),
	"info": Color(0.65, 0.85, 1.0),
	"damage": Color(1.0, 0.4, 0.4),
	"crit": Color(1.0, 0.85, 0.2),
	"heal": Color(0.4, 0.95, 0.5),
}

func _ready() -> void:
	print("CombatHUDController: Construyendo UI limpia y auditada...")
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_top_status_banner()
	_build_turn_track()
	_build_turn_banner_modal()
	_build_party_sidebar()
	_build_bottom_action_bar()
	_build_inventory_dock()
	_build_compact_combat_log()
	_connect_events()
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)

# Fase 2: respeta notch / Dynamic Island / home indicator (iOS safe area,
# Android display cutout). En escritorio los insets son 0 y no cambia nada.
func _apply_safe_area() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var safe := DisplayServer.get_display_safe_area()
	var top_inset := maxf(0.0, safe.position.y)
	var bottom_inset := maxf(0.0, vp_size.y - (safe.position.y + safe.size.y))
	var left_inset := maxf(0.0, safe.position.x)
	var right_inset := maxf(0.0, vp_size.x - (safe.position.x + safe.size.x))
	var banner = find_child("StatusBanner", false, false)
	if banner:
		banner.offset_top = 8.0 + top_inset
		banner.offset_bottom = 44.0 + top_inset
	var track = find_child("TurnTrackPanel", false, false)
	if track:
		track.offset_top = 50.0 + top_inset
		track.offset_bottom = 90.0 + top_inset
	var sidebar = find_child("PartySideBar", false, false)
	if sidebar:
		sidebar.position = Vector2(12.0 + left_inset, 12.0 + top_inset)
	var log_panel = find_child("CompactLog", false, false)
	if log_panel:
		log_panel.position = Vector2(-360.0 - right_inset, 12.0 + top_inset)
	if action_bar:
		action_bar.offset_top = -80.0 - bottom_inset
		action_bar.offset_bottom = -12.0 - bottom_inset
	if inventory_panel:
		inventory_panel.offset_top = -140.0 - bottom_inset
		inventory_panel.offset_bottom = -88.0 - bottom_inset

func _build_top_status_banner() -> void:
	var panel := PanelContainer.new()
	panel.name = "StatusBanner"
	panel.add_theme_stylebox_override("panel", create_grimdark_panel_style(Color(0.06, 0.07, 0.10, 0.92), Color(0.8, 0.65, 0.35, 1.0)))
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 220
	panel.offset_top = 8
	panel.offset_right = -220
	panel.offset_bottom = 44
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(panel)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(status_label)
	status_label.text = "Warhammer: The Old World Tactics"

func _build_turn_track() -> void:
	var track_panel := PanelContainer.new()
	track_panel.name = "TurnTrackPanel"
	track_panel.add_theme_stylebox_override("panel", create_grimdark_panel_style(Color(0.08, 0.09, 0.12, 0.85), Color(0.6, 0.5, 0.3, 0.7)))
	track_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	track_panel.offset_left = 220
	track_panel.offset_top = 50
	track_panel.offset_right = -380
	track_panel.offset_bottom = 90
	track_panel.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(track_panel)

	turn_track_container = HBoxContainer.new()
	turn_track_container.name = "TurnTrack"
	turn_track_container.alignment = BoxContainer.ALIGNMENT_CENTER
	turn_track_container.add_theme_constant_override("separation", 6)
	track_panel.add_child(turn_track_container)

func _build_turn_banner_modal() -> void:
	turn_banner_panel = PanelContainer.new()
	turn_banner_panel.name = "TurnBanner"
	turn_banner_panel.add_theme_stylebox_override("panel", create_grimdark_panel_style(Color(0.05, 0.05, 0.08, 0.95), Color(0.9, 0.75, 0.3, 1.0), 10))
	turn_banner_panel.set_anchors_preset(Control.PRESET_CENTER)
	turn_banner_panel.custom_minimum_size = Vector2(380, 100)
	turn_banner_panel.position = Vector2(-190, -150)
	turn_banner_panel.mouse_filter = MOUSE_FILTER_IGNORE
	turn_banner_panel.visible = false
	add_child(turn_banner_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	turn_banner_panel.add_child(vbox)

	turn_banner_title = Label.new()
	turn_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_banner_title.add_theme_font_size_override("font_size", 22)
	turn_banner_title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(turn_banner_title)

	turn_banner_sub = Label.new()
	turn_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_banner_sub.add_theme_font_size_override("font_size", 14)
	vbox.add_child(turn_banner_sub)

func _build_party_sidebar() -> void:
	heroes_bar = VBoxContainer.new()
	heroes_bar.name = "PartySideBar"
	heroes_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	heroes_bar.position = Vector2(12, 12)
	heroes_bar.custom_minimum_size = Vector2(200, 0)
	heroes_bar.add_theme_constant_override("separation", 8)
	add_child(heroes_bar)

func _build_bottom_action_bar() -> void:
	action_bar = PanelContainer.new()
	action_bar.name = "ActionBar"
	action_bar.add_theme_stylebox_override("panel", create_grimdark_panel_style(Color(0.07, 0.08, 0.11, 0.95), Color(0.75, 0.6, 0.3, 0.9), 8))
	action_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	action_bar.offset_left = 220
	action_bar.offset_top = -80
	action_bar.offset_right = -12
	action_bar.offset_bottom = -12
	add_child(action_bar)

	abilities_container = HBoxContainer.new()
	abilities_container.name = "AbilitiesContainer"
	abilities_container.alignment = BoxContainer.ALIGNMENT_CENTER
	abilities_container.add_theme_constant_override("separation", 10)
	action_bar.add_child(abilities_container)

func _build_inventory_dock() -> void:
	inventory_panel = PanelContainer.new()
	inventory_panel.name = "InventoryDock"
	inventory_panel.add_theme_stylebox_override("panel", create_grimdark_panel_style(Color(0.06, 0.07, 0.10, 0.95), Color(0.7, 0.55, 0.25, 0.9), 8))
	inventory_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	inventory_panel.offset_left = 220
	inventory_panel.offset_top = -140
	inventory_panel.offset_right = -12
	inventory_panel.offset_bottom = -88
	inventory_panel.visible = false
	add_child(inventory_panel)

	inventory_container = HBoxContainer.new()
	inventory_container.name = "InventoryContainer"
	inventory_container.alignment = BoxContainer.ALIGNMENT_CENTER
	inventory_container.add_theme_constant_override("separation", 8)
	inventory_panel.add_child(inventory_container)

func _build_compact_combat_log() -> void:
	var panel := PanelContainer.new()
	panel.name = "CompactLog"
	panel.add_theme_stylebox_override("panel", create_grimdark_panel_style(Color(0.05, 0.06, 0.09, 0.9), Color(0.55, 0.45, 0.25, 0.7), 6))
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-360, 12)
	panel.custom_minimum_size = Vector2(348, 120)
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(panel)

	log_richtext = RichTextLabel.new()
	log_richtext.name = "LogText"
	log_richtext.bbcode_enabled = true
	log_richtext.scroll_following = true
	log_richtext.add_theme_font_size_override("normal_font_size", 13)
	log_richtext.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(log_richtext)

func _connect_events() -> void:
	if not EventBus: return
	EventBus.status_panel_updated.connect(_on_status_updated)
	EventBus.combat_log_appended.connect(_on_log_appended)
	EventBus.health_updated.connect(_on_health_updated)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.initiative_rolled.connect(_on_initiative_rolled)
	EventBus.inventory_updated.connect(_on_inventory_updated)
	EventBus.turn_banner_announced.connect(_on_turn_banner_announced)
	EventBus.combat_ended.connect(func(_v):
		_build_exploration_action_bar()
		turn_track_container.get_parent().visible = false
	)

func show_ui() -> void:
	visible = true

func _on_initiative_rolled(order: Array) -> void:
	initiative_list = order
	turn_track_container.get_parent().visible = true
	_render_turn_track(current_active_unit.get("id", ""))

func _render_turn_track(active_id: String) -> void:
	for child in turn_track_container.get_children():
		child.queue_free()

	for entry in initiative_list:
		var uid: String = entry.get("id", "")
		var is_hero: bool = entry.get("is_hero", false)
		var u_name: String = entry.get("name", "Unidad")
		var is_active = (uid == active_id)

		var icon_btn := Button.new()
		icon_btn.custom_minimum_size = Vector2(34, 34)
		icon_btn.text = u_name.substr(0, 2).to_upper()
		icon_btn.add_theme_font_size_override("font_size", 11)
		icon_btn.mouse_filter = MOUSE_FILTER_IGNORE

		if is_active:
			icon_btn.add_theme_color_override("font_color", Color.GOLD)
			icon_btn.modulate = Color(1.3, 1.3, 1.0, 1.0)
		else:
			icon_btn.modulate = Color(0.6, 0.9, 0.6) if is_hero else Color(0.9, 0.4, 0.4)

		turn_track_container.add_child(icon_btn)

func _on_turn_banner_announced(title: String, subtitle: String, is_hero: bool) -> void:
	turn_banner_title.text = title
	turn_banner_title.add_theme_color_override("font_color", Color.GOLD if is_hero else Color.CORAL)
	turn_banner_sub.text = subtitle
	turn_banner_panel.visible = true
	
	var tw := create_tween()
	tw.tween_property(turn_banner_panel, "modulate:a", 1.0, 0.15).from(0.0)
	tw.tween_interval(0.6)
	tw.tween_property(turn_banner_panel, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func(): turn_banner_panel.visible = false)

func register_heroes_list(heroes: Array) -> void:
	for child in heroes_bar.get_children():
		child.queue_free()
	hero_cards.clear()

	for i in heroes.size():
		var h = heroes[i]
		if h == null: continue
		var hero_id := "hero_" + str(i)
		var h_name = h.get("hero_name") if h.get("hero_name") != null else "Héroe"
		var h_hp = h.get("base_hp") if h.get("base_hp") != null else 12
		
		var card := Button.new()
		card.custom_minimum_size = Vector2(195, 48)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.add_theme_stylebox_override("normal", create_grimdark_button_style(Color(0.1, 0.12, 0.16, 0.9), Color(0.5, 0.4, 0.25, 0.8), 6))
		card.add_theme_stylebox_override("hover", create_grimdark_button_style(Color(0.16, 0.19, 0.26, 0.95), Color(0.85, 0.7, 0.35, 1.0), 6))
		card.add_theme_stylebox_override("pressed", create_grimdark_button_style(Color(0.08, 0.09, 0.12, 1.0), Color(1.0, 0.85, 0.3, 1.0), 6))
		
		var hbox := HBoxContainer.new()
		hbox.mouse_filter = MOUSE_FILTER_IGNORE
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 8)
		card.add_child(hbox)
		
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(34, 34)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		var p_path := _get_hero_portrait(h_name)
		if ResourceLoader.exists(p_path):
			icon.texture = load(p_path)
		hbox.add_child(icon)
		
		var vbox := VBoxContainer.new()
		vbox.mouse_filter = MOUSE_FILTER_IGNORE
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var name_lbl := Label.new()
		name_lbl.text = h_name
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color.GOLD)
		vbox.add_child(name_lbl)
		
		var hp_lbl := Label.new()
		hp_lbl.name = "HPLabel"
		hp_lbl.text = "❤ %d/%d" % [h_hp, h_hp]
		hp_lbl.add_theme_font_size_override("font_size", 11)
		hp_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		vbox.add_child(hp_lbl)
		hbox.add_child(vbox)
		
		card.pressed.connect(func():
			var state_m = get_tree().get_root().get_node_or_null("MainGame/StateMachine")
			if state_m and state_m.has_node("ExplorationState"):
				state_m.get_node("ExplorationState").select_hero(hero_id)
		)
		
		heroes_bar.add_child(card)
		hero_cards[hero_id] = card

	_build_exploration_action_bar()

func _get_hero_portrait(hero_name: String) -> String:
	var s = hero_name.to_lower()
	if "gotrek" in s or "throg" in s: return "res://assets/sprites/characters/heroes/throg.png"
	elif "kallina" in s or "elowen" in s: return "res://assets/sprites/characters/heroes/elowen.png"
	elif "valtieri" in s or "grimble" in s: return "res://assets/sprites/characters/heroes/grimble.png"
	elif "beryl" in s: return "res://assets/sprites/characters/heroes/beryl.png"
	return "res://assets/sprites/ui/logo.png"

func _build_exploration_action_bar() -> void:
	for child in abilities_container.get_children():
		child.queue_free()

	var exp_lbl := Label.new()
	exp_lbl.text = "🗺️ Exploración: Toca un héroe o casilla para avanzar"
	exp_lbl.add_theme_font_size_override("font_size", 14)
	abilities_container.add_child(exp_lbl)

	var bag_btn := Button.new()
	bag_btn.text = "🎒 Mochila del Grupo"
	bag_btn.custom_minimum_size = Vector2(170, 42)
	bag_btn.pressed.connect(func():
		inventory_panel.visible = not inventory_panel.visible
		if inventory_panel.visible: _render_inventory_items()
	)
	abilities_container.add_child(bag_btn)

func _on_turn_started(unit: Dictionary) -> void:
	selected_ability = null
	current_active_unit = unit
	_render_turn_track(unit.get("id", ""))
	
	if unit.get("is_hero", false) and unit.get("is_alive", false):
		_populate_combat_action_bar(unit)
		inventory_panel.visible = false
		_highlight_hero_card(unit.get("id", ""))
	else:
		_populate_enemy_turn_bar(unit)

func _highlight_hero_card(active_id: String) -> void:
	for uid in hero_cards:
		var card: Button = hero_cards[uid]
		if uid == active_id:
			card.add_theme_color_override("font_color", Color.GOLD)
		else:
			card.remove_theme_color_override("font_color")

func _populate_enemy_turn_bar(unit: Dictionary) -> void:
	for child in abilities_container.get_children():
		child.queue_free()
	var lbl := Label.new()
	lbl.text = "⚔️ Turno de %s (Evaluando movimiento y ataque...)" % unit.get("name", "Enemigo")
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color.CORAL)
	abilities_container.add_child(lbl)

func _populate_combat_action_bar(unit: Dictionary) -> void:
	for child in abilities_container.get_children():
		child.queue_free()

	# 1. Ataque Básico
	var atk_btn := Button.new()
	atk_btn.custom_minimum_size = Vector2(140, 44)
	atk_btn.text = "⚔️ Ataque Básico"
	atk_btn.add_theme_stylebox_override("normal", create_grimdark_button_style(Color(0.18, 0.12, 0.12, 0.9), Color(0.8, 0.3, 0.3, 0.8), 6))
	atk_btn.add_theme_stylebox_override("hover", create_grimdark_button_style(Color(0.25, 0.15, 0.15, 0.95), Color(1.0, 0.45, 0.45, 1.0), 6))
	atk_btn.add_theme_font_size_override("font_size", 13)
	atk_btn.pressed.connect(func():
		selected_ability = null
		_highlight_ability_button(atk_btn)
		if EventBus: EventBus.status_panel_updated.emit("⚔️ Ataque Básico listo: Toca a un enemigo para golpear.")
	)
	abilities_container.add_child(atk_btn)
	_highlight_ability_button(atk_btn)

	# 2. Habilidades Especiales
	var h_data = unit.get("data")
	if h_data and h_data.get("abilities"):
		for ab in h_data.abilities:
			if ab == null or not (ab is AbilityData): continue
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(160, 44)
			var cost_text = " (%d %s)" % [ab.cost, unit.get("res_name", "Rec")] if ab.cost > 0 else ""
			btn.text = "✨ " + ab.ability_name + cost_text
			btn.add_theme_font_size_override("font_size", 12)
			
			if unit.get("res", 0) < ab.cost:
				btn.disabled = true
				btn.modulate = Color(0.6, 0.6, 0.6, 0.6)
			
			btn.pressed.connect(func():
				selected_ability = ab
				_highlight_ability_button(btn)
				if EventBus: EventBus.status_panel_updated.emit("✨ Habilidad: %s. Toca objetivo." % ab.ability_name)
			)
			abilities_container.add_child(btn)

	# 3. Bolsa / Mochila
	var bag_btn := Button.new()
	bag_btn.custom_minimum_size = Vector2(110, 44)
	bag_btn.text = "🎒 Mochila"

	# Botón Modo DJ
	var dj_btn := Button.new()
	dj_btn.custom_minimum_size = Vector2(100, 44)
	dj_btn.text = "🎲 Modo DJ"
	dj_btn.add_theme_font_size_override("font_size", 13)
	dj_btn.add_theme_stylebox_override("normal", create_grimdark_button_style(Color(0.2, 0.15, 0.08, 0.9), Color(0.9, 0.7, 0.2, 0.9), 6))
	dj_btn.pressed.connect(func():
		if game_manager and game_manager.dj_controller:
			game_manager.dj_controller.visible = not game_manager.dj_controller.visible
	)
	abilities_container.add_child(dj_btn)
	bag_btn.add_theme_font_size_override("font_size", 13)
	bag_btn.pressed.connect(func():
		inventory_panel.visible = not inventory_panel.visible
		if inventory_panel.visible: _render_inventory_items()
	)
	abilities_container.add_child(bag_btn)

	# 4. Botón de Pasar Turno
	var pass_btn := Button.new()
	pass_btn.custom_minimum_size = Vector2(110, 44)
	pass_btn.text = "⏩ Fin Turno"
	pass_btn.add_theme_stylebox_override("normal", create_grimdark_button_style(Color(0.12, 0.15, 0.18, 0.9), Color(0.4, 0.6, 0.8, 0.8), 6))
	pass_btn.add_theme_stylebox_override("hover", create_grimdark_button_style(Color(0.18, 0.22, 0.28, 0.95), Color(0.6, 0.8, 1.0, 1.0), 6))
	pass_btn.add_theme_font_size_override("font_size", 13)
	pass_btn.pressed.connect(func():
		var state_m = get_tree().get_root().get_node_or_null("MainGame/StateMachine")
		if state_m and state_m.has_node("CombatState"):
			state_m.get_node("CombatState").next_turn()
	)
	abilities_container.add_child(pass_btn)

func _render_inventory_items() -> void:
	for child in inventory_container.get_children():
		child.queue_free()

	if not game_manager or game_manager.party_inventory.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Mochila vacía"
		empty_lbl.add_theme_font_size_override("font_size", 13)
		inventory_container.add_child(empty_lbl)
		return

	for it in game_manager.party_inventory:
		var item_btn := Button.new()
		item_btn.text = "%s %s" % [it.get("icon", "📦"), it.get("name", "Objeto")]
		# Fase 2: altura táctil mínima 48px (HIG/Human Interface + Material).
		item_btn.custom_minimum_size = Vector2(150, 48)
		var it_id: String = it.get("id", "")
		item_btn.pressed.connect(func():
			var uid = current_active_unit.get("id", "hero_0")
			if EventBus: EventBus.item_used.emit(it_id, uid)
			_render_inventory_items()
		)
		inventory_container.add_child(item_btn)

func _on_inventory_updated(_items: Array) -> void:
	if inventory_panel and inventory_panel.visible:
		_render_inventory_items()

func _highlight_ability_button(active_btn: Button) -> void:
	for btn in abilities_container.get_children():
		if btn is Button and btn.text != "🎒 Mochila" and btn.text != "⏩ Fin Turno":
			if btn == active_btn:
				btn.add_theme_color_override("font_color", Color.GOLD)
			else:
				btn.remove_theme_color_override("font_color")

func _on_status_updated(text: String) -> void:
	if status_label: status_label.text = text

func _on_log_appended(text: String, type: String) -> void:
	if not log_richtext: return
	var color: Color = LOG_COLORS.get(type, Color(0.85, 0.85, 0.85))
	var hex := "#%s%s%s" % [
		"%02x" % int(color.r * 255),
		"%02x" % int(color.g * 255),
		"%02x" % int(color.b * 255)
	]
	log_richtext.append_text("[color=%s]%s[/color]\n" % [hex, text])

func _on_health_updated(unit_id: String, hp: int, hp_max: int, _delta: int) -> void:
	if not hero_cards.has(unit_id): return
	var card: Button = hero_cards[unit_id]
	var hp_lbl: Label = card.find_child("HPLabel", true, false)
	if hp_lbl:
		hp_lbl.text = "❤ %d/%d" % [hp, hp_max]
		var ratio: float = float(hp) / float(max(hp_max, 1))
		if ratio > 0.5:
			hp_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
		elif ratio > 0.2:
			hp_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		else:
			hp_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
