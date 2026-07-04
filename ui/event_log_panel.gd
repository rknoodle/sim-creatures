# event_log_panel.gd
# Panel visual del historial de eventos. Construye su UI por código.
class_name EventLogPanel
extends PanelContainer

var _scroll: ScrollContainer
var _list: VBoxContainer

const MAX_VISIBLE_LABELS: int = 200


func _ready() -> void:
	_build_ui()
	EventLog.entry_added.connect(_on_entry_added)
	for entry: Dictionary in EventLog.entries:
		_add_label(entry["text"], entry["timestamp"])


func _build_ui() -> void:
	custom_minimum_size = Vector2(320.0, 220.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09, 0.90)
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.28, 0.28, 0.32, 0.75)
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	margin.add_child(root)
	
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "HISTORIAL"
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_color_override("font_color", Color(0.50, 0.50, 0.58))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)
	
	var debug_btn := Button.new()
	debug_btn.text = "🛠 Debug"
	debug_btn.flat = true
	debug_btn.add_theme_font_size_override("font_size", 10)
	debug_btn.add_theme_color_override("font_color", Color(0.45, 0.90, 0.45))
	debug_btn.pressed.connect(_on_debug_button_pressed)
	header_row.add_child(debug_btn)
	
	var spawn_btn := Button.new()
	spawn_btn.text = "＋ Criatura"
	spawn_btn.flat = true
	spawn_btn.add_theme_font_size_override("font_size", 10)
	spawn_btn.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	spawn_btn.pressed.connect(_on_spawn_button_pressed)
	header_row.add_child(spawn_btn)

	root.add_child(header_row)   # ← en vez de root.add_child(title)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)


func _on_entry_added(text: String, timestamp: String) -> void:
	_add_label(text, timestamp)
	_scroll_to_bottom()


func _add_label(text: String, timestamp: String) -> void:
	var lbl := Label.new()
	lbl.text = "[%s] %s" % [timestamp, text]
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.85))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(lbl)

	if _list.get_child_count() > MAX_VISIBLE_LABELS:
		_list.get_child(0).queue_free()


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

var _debug_panel: DebugPanel = null


func _on_debug_button_pressed() -> void:
	if _debug_panel == null:
		_debug_panel = DebugPanel.new()
		# Posicionar encima del historial
		_debug_panel.position = Vector2(0.0, -320.0)
		get_parent().add_child(_debug_panel)
	else:
		_debug_panel.visible = not _debug_panel.visible

# — Añadir variable y método:

var _spawn_panel: SpawnPanel = null


func _on_spawn_button_pressed() -> void:
	if _spawn_panel == null:
		_spawn_panel = SpawnPanel.new()
		_spawn_panel.agent_scene = load("res://base_agent_template.tscn") # Hardcodeado
		_spawn_panel.position = Vector2(350.0, 50.0)
		get_parent().add_child(_spawn_panel)
	_spawn_panel.visible = not _spawn_panel.visible
