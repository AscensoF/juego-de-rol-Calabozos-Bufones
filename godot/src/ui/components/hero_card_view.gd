class_name HeroCardView
extends PanelContainer

## Tarjeta de Interfaz de Héroe: Muestra retrato, barras de vida/recurso y estado de turno.

var hero_id: String = ""
var portrait_rect: TextureRect
var name_label: Label
var hp_bar: ProgressBar
var hp_label: Label
var res_bar: ProgressBar
var res_label: Label

func _init() -> void:
	custom_minimum_size = Vector2(240, 70)
	_build_ui()

func _build_ui() -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(hbox)

	portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(48, 48)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(portrait_rect)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(name_label)

	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 10)
	hp_bar.show_percentage = false
	vbox.add_child(hp_bar)

	hp_label = Label.new()
	hp_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(hp_label)

	res_bar = ProgressBar.new()
	res_bar.custom_minimum_size = Vector2(0, 8)
	res_bar.show_percentage = false
	vbox.add_child(res_bar)

	res_label = Label.new()
	res_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(res_label)

func bind_hero(h_data: HeroData, current_hp: int, current_res: int) -> void:
	hero_id = h_data.id
	name_label.text = h_data.hero_name
	if h_data.portrait:
		portrait_rect.texture = h_data.portrait

	update_hp(current_hp, h_data.base_hp)
	update_resource(current_res, h_data.base_resource, h_data.resource_name)

func update_hp(current: int, max_val: int) -> void:
	hp_bar.max_value = max_val
	hp_bar.value = current
	hp_label.text = "PV: %d / %d" % [current, max_val]
	if current <= 0:
		modulate = Color(0.5, 0.5, 0.5, 0.7)
	else:
		modulate = Color.WHITE

func update_resource(current: int, max_val: int, res_name: String) -> void:
	res_bar.max_value = max_val
	res_bar.value = current
	res_label.text = "%s: %d / %d" % [res_name, current, max_val]

func set_active_turn(is_active: bool) -> void:
	if is_active:
		self_modulate = Color(1.2, 1.2, 0.8) # Resaltado dorado
	else:
		self_modulate = Color.WHITE
