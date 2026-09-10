class_name CombatLogView
extends PanelContainer

## Visor de Registro de Combate y Eventos con filtrado por color y autoscroll.

var rich_label: RichTextLabel
var scroll_container: ScrollContainer

func _init() -> void:
	custom_minimum_size = Vector2(280, 160)
	_build_ui()

func _ready() -> void:
	if EventBus:
		EventBus.combat_log_appended.connect(append_log)

func _build_ui() -> void:
	rich_label = RichTextLabel.new()
	rich_label.bbcode_enabled = true
	rich_label.scroll_following = true
	rich_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rich_label.add_theme_font_size_override("normal_font_size", 12)
	add_child(rich_label)

func append_log(message: String, category: String = "info") -> void:
	var color_tag: String = "white"
	match category:
		"damage": color_tag = "#ef4444" # Rojo
		"heal": color_tag = "#22c55e"   # Verde
		"crit": color_tag = "#eab308"   # Amarillo oro
		"game": color_tag = "#a855f7"   # Púrpura épico
		_: color_tag = "#94a3b8"        # Slate info

	rich_label.append_text("[color=%s]%s[/color]\n" % [color_tag, message])
