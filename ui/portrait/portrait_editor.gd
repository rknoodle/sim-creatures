# portrait_editor.gd
# Panel editor del retrato. Se puede usar tanto en SpawnPanel como en DebugPanel.
# Recibe un PortraitData y emite portrait_changed cuando se modifica.
class_name PortraitEditor
extends PanelContainer

signal portrait_changed(data: PortraitData)

var _portrait_data: PortraitData = null
var _preview_renderer: PortraitRenderer = null
var _preview_viewport: SubViewport = null
var _layer_controls: Dictionary = {}  # { layer_name: Dictionary de controles }
var _active_layer: StringName = &""
var _dragging_layer: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_build_ui()


func load_portrait(data: PortraitData) -> void:
	if data == null:
		data = PortraitData.new()
	_portrait_data = data
	_refresh_all_controls()
	_refresh_preview()


func get_portrait_data() -> PortraitData:
	return _portrait_data


# ─── Construcción de UI ───────────────────────────────────────────────────────

func _build_ui() -> void:
	custom_minimum_size = Vector2(520.0, 0.0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.12, 0.97)
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.30, 0.30, 0.38, 0.80)
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    12)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	# Columna izquierda: preview + controles de offset
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 8)
	hbox.add_child(left_col)

	left_col.add_child(_build_preview())
	left_col.add_child(_build_offset_controls())
	left_col.add_child(_build_quick_actions())

	# Columna derecha: lista de capas con scroll
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 6)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(right_col)

	var layers_title := Label.new()
	layers_title.text = "CAPAS"
	layers_title.add_theme_font_size_override("font_size", 10)
	layers_title.add_theme_color_override("font_color", Color(0.50, 0.50, 0.58))
	right_col.add_child(layers_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0.0, 400.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_col.add_child(scroll)

	var layers_list := VBoxContainer.new()
	layers_list.add_theme_constant_override("separation", 6)
	layers_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(layers_list)

	# Construir cada capa en orden inverso (las últimas en el array son las de encima)
	var reversed_layers: Array[StringName] = []
	for l: StringName in PortraitData.LAYER_NAMES:
		reversed_layers.push_front(l)

	for layer_name: StringName in reversed_layers:
		layers_list.add_child(_build_layer_row(layer_name))


func _build_preview() -> Control:
	var container := PanelContainer.new()
	container.custom_minimum_size = Vector2(180.0, 180.0)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.18)
	bg_style.corner_radius_top_left     = 6
	bg_style.corner_radius_top_right    = 6
	bg_style.corner_radius_bottom_left  = 6
	bg_style.corner_radius_bottom_right = 6
	container.add_theme_stylebox_override("panel", bg_style)

	_preview_viewport = SubViewport.new()
	_preview_viewport.size = Vector2i(512, 512)
	_preview_viewport.transparent_bg = true
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	_preview_renderer = PortraitRenderer.new()
	_preview_viewport.add_child(_preview_renderer)

	var preview_texture := TextureRect.new()
	preview_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_texture.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview_texture.texture = _preview_viewport.get_texture()
	preview_texture.mouse_filter = Control.MOUSE_FILTER_STOP

	# Drag de offset con click en la preview
	preview_texture.gui_input.connect(_on_preview_gui_input)

	container.add_child(_preview_viewport)
	container.add_child(preview_texture)

	return container


func _build_offset_controls() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var hint := Label.new()
	hint.text = "Arrastra la preview para mover\nla capa seleccionada"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.50, 0.50, 0.58))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)

	var reset_offset_btn := Button.new()
	reset_offset_btn.text = "↺ Centrar capa activa"
	reset_offset_btn.pressed.connect(_on_reset_offset_pressed)
	vbox.add_child(reset_offset_btn)

	return vbox


func _build_quick_actions() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var randomize_btn := Button.new()
	randomize_btn.text = "🎲 Aleatorio"
	randomize_btn.pressed.connect(_on_randomize_pressed)
	vbox.add_child(randomize_btn)

	var clear_btn := Button.new()
	clear_btn.text = "🗑 Limpiar todo"
	clear_btn.pressed.connect(_on_clear_pressed)
	vbox.add_child(clear_btn)

	return vbox


func _build_layer_row(layer_name: StringName) -> PanelContainer:
	var row := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.12, 0.12, 0.15, 0.85)
	row_style.corner_radius_top_left     = 5
	row_style.corner_radius_top_right    = 5
	row_style.corner_radius_bottom_left  = 5
	row_style.corner_radius_bottom_right = 5
	row_style.content_margin_left   = 8
	row_style.content_margin_right  = 8
	row_style.content_margin_top    = 6
	row_style.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", row_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	row.add_child(vbox)

	# Header de la capa
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)

	var vis_check := CheckBox.new()
	vis_check.button_pressed = true
	vis_check.toggled.connect(func(on: bool) -> void:
		_on_layer_visible_toggled(layer_name, on)
	)
	header.add_child(vis_check)

	var layer_label := Button.new()
	layer_label.text = PortraitData.LAYER_LABELS.get(layer_name, str(layer_name))
	layer_label.flat = true
	layer_label.alignment = HORIZONTAL_ALIGNMENT_LEFT
	layer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer_label.add_theme_font_size_override("font_size", 11)
	layer_label.pressed.connect(func() -> void:
		_active_layer = layer_name
		_highlight_active_row()
	)
	header.add_child(layer_label)

	vbox.add_child(header)

	# Selector de variante (thumbnails en fila)
	var variants_scroll := ScrollContainer.new()
	variants_scroll.custom_minimum_size = Vector2(0.0, 52.0)
	variants_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var variants_hbox := HBoxContainer.new()
	variants_hbox.add_theme_constant_override("separation", 4)
	variants_scroll.add_child(variants_hbox)

	# Opción "ninguno"
	var none_btn := _build_variant_button(null, layer_name)
	variants_hbox.add_child(none_btn)

	var paths: Array = PortraitData.get_paths_for(layer_name) \
		if _portrait_data == null \
		else _portrait_data.get_paths_for(layer_name)

	for path: String in paths:
		var tex: Texture2D = load(path) as Texture2D
		if tex != null:
			var btn := _build_variant_button(tex, layer_name)
			variants_hbox.add_child(btn)

	vbox.add_child(variants_scroll)

	
	
	# Selector de color
	var color_row := HBoxContainer.new()
	# Opción de color vinculado (solo para capas que lo necesitan)
	var link_check: CheckBox = null
	if layer_name == &"ear":
		link_check = _build_link_color_check(layer_name, &"head",
			"Mismo color que la Cabeza")
	elif layer_name == &"hair_front":
		link_check = _build_link_color_check(layer_name, &"hair_back",
			"Mismo color que Cabello fondo")
	elif layer_name == &"hair_back":
		link_check = _build_link_color_check(layer_name, &"hair_front",
			"Mismo color que Cabello frente")
	if link_check != null:
		vbox.add_child(link_check)

	vbox.add_child(color_row)
	color_row.add_theme_constant_override("separation", 6)

	var color_label := Label.new()
	color_label.text = "Color:"
	color_label.add_theme_font_size_override("font_size", 10)
	color_label.add_theme_color_override("font_color", Color(0.60, 0.60, 0.65))
	color_row.add_child(color_label)

	var color_picker_btn := ColorPickerButton.new()
	color_picker_btn.color = Color.WHITE
	color_picker_btn.custom_minimum_size = Vector2(80.0, 24.0)
	color_picker_btn.color_changed.connect(func(c: Color) -> void:
		_on_layer_color_changed(layer_name, c)
	)
	# Configurar el picker interno como HSV
	color_picker_btn.get_picker().color_mode = ColorPicker.MODE_HSV
	color_row.add_child(color_picker_btn)

	var reset_color_btn := Button.new()
	reset_color_btn.text = "↺"
	reset_color_btn.custom_minimum_size = Vector2(24.0, 24.0)
	reset_color_btn.tooltip_text = "Resetear color a blanco"
	reset_color_btn.pressed.connect(func() -> void:
		color_picker_btn.color = Color.WHITE
		_on_layer_color_changed(layer_name, Color.WHITE)
	)
	color_row.add_child(reset_color_btn)

	vbox.add_child(color_row)

	_layer_controls[layer_name] = {
		"vis_check":        vis_check,
		"label_btn":        layer_label,
		"color_picker_btn": color_picker_btn,
		"row":              row,
	}

	return row


func _build_variant_button(tex: Texture2D, layer_name: StringName) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(44.0, 44.0)
	btn.tooltip_text = "Ninguno" if tex == null else "Variante"

	if tex != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture      = tex
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon_rect)
	else:
		btn.text = "✕"

	btn.pressed.connect(func() -> void:
		_on_layer_texture_selected(layer_name, tex)
		_active_layer = layer_name
		_highlight_active_row()
	)
	return btn


# ─── Lógica de edición ────────────────────────────────────────────────────────

func _on_layer_texture_selected(layer_name: StringName, tex: Texture2D) -> void:
	if _portrait_data == null:
		return
	_portrait_data.get_layer(layer_name).texture = tex
	_preview_renderer.refresh_layer(layer_name)
	portrait_changed.emit(_portrait_data)


func _on_layer_color_changed(layer_name: StringName, color: Color) -> void:
	if _portrait_data == null:
		return
	_portrait_data.get_layer(layer_name).color = color
	_preview_renderer.refresh_layer(layer_name)
	portrait_changed.emit(_portrait_data)


func _on_layer_visible_toggled(layer_name: StringName, visible_state: bool) -> void:
	if _portrait_data == null:
		return
	_portrait_data.get_layer(layer_name).visible = visible_state
	_preview_renderer.refresh_layer(layer_name)
	portrait_changed.emit(_portrait_data)


func _on_preview_gui_input(event: InputEvent) -> void:
	if _active_layer == &"" or _portrait_data == null:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging_layer = mb.pressed
			if mb.pressed:
				_drag_start_mouse = mb.position
				_drag_start_offset = _portrait_data.get_layer(_active_layer).offset

	elif event is InputEventMouseMotion and _dragging_layer:
		# Escalar el movimiento del mouse al espacio 512x512 del viewport
		var preview_size: Vector2 = Vector2(180.0, 180.0)
		var scale_factor: float = 512.0 / preview_size.x
		var delta: Vector2 = (event.position - _drag_start_mouse) * scale_factor
		var new_offset: Vector2 = _drag_start_offset + delta
		_portrait_data.get_layer(_active_layer).offset = new_offset
		_preview_renderer.refresh_layer(_active_layer)
		portrait_changed.emit(_portrait_data)


func _on_reset_offset_pressed() -> void:
	if _active_layer == &"" or _portrait_data == null:
		return
	_portrait_data.get_layer(_active_layer).offset = Vector2.ZERO
	_preview_renderer.refresh_layer(_active_layer)
	portrait_changed.emit(_portrait_data)


func _on_randomize_pressed() -> void:
	if _portrait_data == null:
		_portrait_data = PortraitData.new()
	for layer_name: StringName in PortraitData.LAYER_NAMES:
		var paths: Array = _portrait_data.get_paths_for(layer_name)
		if paths.is_empty():
			continue
		var random_path: String = paths[randi() % paths.size()]
		var tex: Texture2D = load(random_path) as Texture2D
		var layer: PortraitLayerData = _portrait_data.get_layer(layer_name)
		layer.texture = tex
		layer.color   = Color(randf(), randf(), randf())
		layer.offset  = Vector2.ZERO
		layer.visible = true
	_refresh_all_controls()
	_refresh_preview()
	portrait_changed.emit(_portrait_data)


func _on_clear_pressed() -> void:
	if _portrait_data == null:
		return
	for layer_name: StringName in PortraitData.LAYER_NAMES:
		var layer: PortraitLayerData = _portrait_data.get_layer(layer_name)
		layer.texture = null
		layer.color   = Color.WHITE
		layer.offset  = Vector2.ZERO
		layer.visible = true
	_refresh_all_controls()
	_refresh_preview()
	portrait_changed.emit(_portrait_data)


func _highlight_active_row() -> void:
	for layer_name: StringName in _layer_controls:
		var controls: Dictionary = _layer_controls[layer_name]
		var row := controls["row"] as PanelContainer
		if row == null:
			continue
		var style := row.get_theme_stylebox("panel") as StyleBoxFlat
		if style == null:
			continue
		style.bg_color = Color(0.18, 0.22, 0.28, 0.95) \
			if layer_name == _active_layer \
			else Color(0.12, 0.12, 0.15, 0.85)


func _refresh_preview() -> void:
	if _preview_renderer != null and _portrait_data != null:
		_preview_renderer.apply_portrait(_portrait_data)


func _refresh_all_controls() -> void:
	if _portrait_data == null:
		return
	for layer_name: StringName in _layer_controls:
		var controls: Dictionary = _layer_controls[layer_name]
		var layer: PortraitLayerData = _portrait_data.get_layer(layer_name)
		(controls["vis_check"] as CheckBox).button_pressed = layer.visible
		(controls["color_picker_btn"] as ColorPickerButton).color = layer.color

func _build_link_color_check(
	layer_name: StringName,
	source_layer: StringName,
	label_text: String
) -> CheckBox:
	var check := CheckBox.new()
	check.text = label_text
	check.add_theme_font_size_override("font_size", 10)
	check.toggled.connect(func(on: bool) -> void:
		if not on or _portrait_data == null:
			return
		# Copiar color de la capa fuente a esta capa
		var source_color: Color = _portrait_data.get_layer(source_layer).color
		_portrait_data.get_layer(layer_name).color = source_color
		# Actualizar el ColorPickerButton de esta capa
		var controls: Dictionary = _layer_controls.get(layer_name, {})
		var picker := controls.get("color_picker_btn") as ColorPickerButton
		if picker != null:
			picker.color = source_color
		_preview_renderer.refresh_layer(layer_name)
		portrait_changed.emit(_portrait_data)
		# Desactivar el check tras aplicar (es una acción puntual, no un vínculo continuo)
		check.button_pressed = false
	)
	return check
