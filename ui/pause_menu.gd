# pause_menu.gd
# Menú de pausa con lista de slots de guardado múltiples.
class_name PauseMenu
extends CanvasLayer

var _panel: PanelContainer
var _slot_list: VBoxContainer
var _btn_new_save: Button
var _btn_resume: Button
var _btn_quit: Button
var _status_label: Label

var _is_open: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	SaveManager.slots_refreshed.connect(_refresh_slot_list)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			_toggle_menu()
			get_viewport().set_input_as_handled()


func _toggle_menu() -> void:
	_is_open = not _is_open
	visible = _is_open
	get_tree().paused = _is_open
	if _is_open:
		_refresh_slot_list()


# ─── Construcción de UI ───────────────────────────────────────────────────────

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(360.0, 0.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.12, 0.97)
	style.corner_radius_top_left     = 10
	style.corner_radius_top_right    = 10
	style.corner_radius_bottom_left  = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.32, 0.32, 0.38, 0.85)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   20)
	margin.add_theme_constant_override("margin_right",  20)
	margin.add_theme_constant_override("margin_top",    18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var title := Label.new()
	title.text = "PAUSA"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.92, 0.92, 0.88))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	_btn_resume = _make_button("Reanudar")
	_btn_resume.pressed.connect(_on_resume_pressed)
	root.add_child(_btn_resume)

	root.add_child(_build_separator())

	var slots_title := Label.new()
	slots_title.text = "PARTIDAS GUARDADAS"
	slots_title.add_theme_font_size_override("font_size", 10)
	slots_title.add_theme_color_override("font_color", Color(0.50, 0.50, 0.58))
	root.add_child(slots_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 180.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_slot_list = VBoxContainer.new()
	_slot_list.add_theme_constant_override("separation", 6)
	_slot_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_slot_list)

	_btn_new_save = _make_button("+ Guardar como nueva partida")
	_btn_new_save.pressed.connect(_on_new_save_pressed)
	root.add_child(_btn_new_save)

	root.add_child(_build_separator())

	_btn_quit = _make_button("Salir del juego")
	_btn_quit.pressed.connect(_on_quit_pressed)
	root.add_child(_btn_quit)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0.0, 34.0)
	return btn


func _build_separator() -> HSeparator:
	var sep := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.26, 0.26, 0.30, 0.6)
	sep.add_theme_stylebox_override("separator", style)
	return sep


# ─── Lista dinámica de slots ───────────────────────────────────────────────────

func _refresh_slot_list() -> void:
	for child: Node in _slot_list.get_children():
		child.queue_free()

	var slots: Array[Dictionary] = SaveManager.list_slots()

	if slots.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No hay partidas guardadas."
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60))
		_slot_list.add_child(empty_lbl)
		return

	for slot: Dictionary in slots:
		_slot_list.add_child(_build_slot_row(slot))


func _build_slot_row(slot: Dictionary) -> PanelContainer:
	var row_panel := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.13, 0.13, 0.16, 0.85)
	row_style.corner_radius_top_left     = 6
	row_style.corner_radius_top_right    = 6
	row_style.corner_radius_bottom_left  = 6
	row_style.corner_radius_bottom_right = 6
	row_style.content_margin_left   = 10
	row_style.content_margin_right  = 8
	row_style.content_margin_top    = 6
	row_style.content_margin_bottom = 6
	row_panel.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row_panel.add_child(hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 1)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	name_lbl.text = slot["display_name"]
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.90, 0.90, 0.88))
	info_vbox.add_child(name_lbl)

	var meta_lbl := Label.new()
	meta_lbl.text = "%s · %d criaturas" % [slot["saved_at_readable"], slot["agent_count"]]
	meta_lbl.add_theme_font_size_override("font_size", 10)
	meta_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62))
	info_vbox.add_child(meta_lbl)

	hbox.add_child(info_vbox)

	var btn_load := Button.new()
	btn_load.text = "Cargar"
	btn_load.custom_minimum_size = Vector2(64.0, 28.0)
	btn_load.pressed.connect(_on_load_pressed.bind(slot["slot_id"], slot["display_name"]))
	hbox.add_child(btn_load)

	var btn_overwrite := Button.new()
	btn_overwrite.text = "↺"
	btn_overwrite.tooltip_text = "Sobrescribir con la partida actual"
	btn_overwrite.custom_minimum_size = Vector2(28.0, 28.0)
	btn_overwrite.pressed.connect(_on_overwrite_pressed.bind(slot["slot_id"], slot["display_name"]))
	hbox.add_child(btn_overwrite)

	var btn_delete := Button.new()
	btn_delete.text = "✕"
	btn_delete.tooltip_text = "Eliminar esta partida"
	btn_delete.custom_minimum_size = Vector2(28.0, 28.0)
	btn_delete.add_theme_color_override("font_color", Color(0.85, 0.45, 0.45))
	btn_delete.pressed.connect(_on_delete_pressed.bind(slot["slot_id"]))
	hbox.add_child(btn_delete)

	return row_panel


# ─── Acciones ─────────────────────────────────────────────────────────────────

func _on_resume_pressed() -> void:
	_toggle_menu()


func _on_new_save_pressed() -> void:
	var slot_id: String = SaveManager.generate_new_slot_id()
	var display_name: String = "Partida %s" % Time.get_datetime_string_from_system().replace("T", " ")
	var ok: bool = SaveManager.save_game(slot_id, display_name)
	_show_status("Partida guardada." if ok else "Error al guardar.", ok)


func _on_overwrite_pressed(slot_id: String, display_name: String) -> void:
	var ok: bool = SaveManager.save_game(slot_id, display_name)
	_show_status("'%s' sobrescrita." % display_name if ok else "Error al guardar.", ok)


func _on_load_pressed(slot_id: String, display_name: String) -> void:
	var ok: bool = SaveManager.load_game(slot_id)
	_show_status("'%s' cargada." % display_name if ok else "Error al cargar.", ok)
	if ok:
		_toggle_menu()


func _on_delete_pressed(slot_id: String) -> void:
	var ok: bool = SaveManager.delete_save(slot_id)
	_show_status("Partida eliminada." if ok else "Error al eliminar.", ok)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _show_status(text: String, success: bool) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color",
		Color(0.55, 0.80, 0.55) if success else Color(0.85, 0.45, 0.45)
	)
