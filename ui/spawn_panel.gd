# spawn_panel.gd
# Panel flotante y arrastrable para crear nuevas criaturas.
# Se abre desde un botón en el HUD.
class_name SpawnPanel
extends PanelContainer

@export var agent_scene: PackedScene
@export var spawn_area_min: Vector2 = Vector2(100.0, 100.0)
@export var spawn_area_max: Vector2 = Vector2(1180.0, 620.0)

var _name_input: LineEdit
var _gender_option: OptionButton
var _species_input: LineEdit
var _scale_slider: HSlider
var _scale_label: Label
var _start_adult_check: CheckBox
var _status_label: Label

# Perfil químico preview
var _hunger_slider: HSlider
var _fatigue_slider: HSlider
var _pain_slider: HSlider
var _loneliness_slider: HSlider

# Sprite
var _texture_path_label: Label
var _preview_sprite: TextureRect
var _selected_texture: Texture2D = null

# Drag
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_build_ui()
	_randomize_fields()
	hide()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed:
				_drag_offset = global_position - get_global_mouse_position()
	elif event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() + _drag_offset
		var vp: Vector2 = get_viewport_rect().size
		global_position.x = clampf(global_position.x, 0.0, vp.x - size.x)
		global_position.y = clampf(global_position.y, 0.0, vp.y - size.y)


# ─── Construcción de UI ───────────────────────────────────────────────────────

func _build_ui() -> void:
	custom_minimum_size = Vector2(240.0, 0.0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.08, 0.08, 0.11, 0.95)
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.32, 0.32, 0.40, 0.85)
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   12)
	margin.add_theme_constant_override("margin_right",  12)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 7)
	margin.add_child(root)

	root.add_child(_build_title_row())
	root.add_child(_build_separator())
	root.add_child(_build_sprite_section())
	root.add_child(_build_separator())
	root.add_child(_build_identity_section())
	root.add_child(_build_separator())
	root.add_child(_build_chemicals_section())
	root.add_child(_build_separator())
	root.add_child(_build_spawn_button())
	
	var portrait_section := _build_portrait_section()
	root.add_child(portrait_section)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)


func _build_title_row() -> HBoxContainer:
	var hbox := HBoxContainer.new()

	var title := Label.new()
	title.text = "NUEVA CRIATURA"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.92))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", Color(0.60, 0.60, 0.65))
	close_btn.pressed.connect(func() -> void: hide())
	hbox.add_child(close_btn)

	return hbox


func _build_sprite_section() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(_make_section_label("APARIENCIA"))

	# Preview de textura
	_preview_sprite = TextureRect.new()
	_preview_sprite.custom_minimum_size = Vector2(48.0, 48.0)
	_preview_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_sprite.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL

	var preview_bg := PanelContainer.new()
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.12, 0.12, 0.15)
	preview_style.corner_radius_top_left     = 4
	preview_style.corner_radius_top_right    = 4
	preview_style.corner_radius_bottom_left  = 4
	preview_style.corner_radius_bottom_right = 4
	preview_bg.add_theme_stylebox_override("panel", preview_style)
	preview_bg.add_child(_preview_sprite)

	var sprite_row := HBoxContainer.new()
	sprite_row.add_theme_constant_override("separation", 8)
	sprite_row.add_child(preview_bg)

	var sprite_controls := VBoxContainer.new()
	sprite_controls.add_theme_constant_override("separation", 4)
	sprite_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_texture_path_label = Label.new()
	_texture_path_label.text = "Sin textura"
	_texture_path_label.add_theme_font_size_override("font_size", 10)
	_texture_path_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60))
	_texture_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sprite_controls.add_child(_texture_path_label)

	var load_btn := Button.new()
	load_btn.text = "Cargar imagen..."
	load_btn.custom_minimum_size = Vector2(0.0, 26.0)
	load_btn.pressed.connect(_on_load_texture_pressed)
	sprite_controls.add_child(load_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Quitar textura"
	clear_btn.custom_minimum_size = Vector2(0.0, 26.0)
	clear_btn.pressed.connect(_on_clear_texture_pressed)
	sprite_controls.add_child(clear_btn)

	sprite_row.add_child(sprite_controls)
	vbox.add_child(sprite_row)

	return vbox


func _build_identity_section() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.add_child(_make_section_label("IDENTIDAD"))

	# Nombre
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Nombre..."
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_input)
	var rnd_btn := Button.new()
	rnd_btn.text = "🎲"
	rnd_btn.custom_minimum_size = Vector2(28.0, 0.0)
	rnd_btn.tooltip_text = "Nombre aleatorio"
	rnd_btn.pressed.connect(_randomize_name)
	name_row.add_child(rnd_btn)
	vbox.add_child(_labeled_row("Nombre", name_row))

	# Género
	_gender_option = OptionButton.new()
	_gender_option.add_item("Macho",  IdentityData.Gender.MALE)
	_gender_option.add_item("Hembra", IdentityData.Gender.FEMALE)
	vbox.add_child(_labeled_row("Género", _gender_option))

	# Especie
	_species_input = LineEdit.new()
	_species_input.text = "Human"
	vbox.add_child(_labeled_row("Especie", _species_input))

	# Escala
	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 6)
	_scale_slider = HSlider.new()
	_scale_slider.min_value = 0.5
	_scale_slider.max_value = 2.0
	_scale_slider.step      = 0.05
	_scale_slider.value     = 1.0
	_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale_label = Label.new()
	_scale_label.text = "1.00"
	_scale_label.custom_minimum_size = Vector2(34.0, 0.0)
	_scale_label.add_theme_font_size_override("font_size", 11)
	_scale_slider.value_changed.connect(
		func(v: float) -> void: _scale_label.text = "%.2f" % v
	)
	scale_row.add_child(_scale_slider)
	scale_row.add_child(_scale_label)
	vbox.add_child(_labeled_row("Tamaño", scale_row))

	# Adulto
	_start_adult_check = CheckBox.new()
	_start_adult_check.text = "Iniciar como adulto"
	_start_adult_check.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_start_adult_check)

	return vbox


func _build_chemicals_section() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.add_child(_make_section_label("QUÍMICOS INICIALES"))

	var chemicals: Array[Dictionary] = [
		{"label": "Hambre",    "ref": "_hunger_slider"},
		{"label": "Cansancio", "ref": "_fatigue_slider"},
		{"label": "Dolor",     "ref": "_pain_slider"},
		{"label": "Soledad",   "ref": "_loneliness_slider"},
	]

	for entry: Dictionary in chemicals:
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step      = 1.0
		slider.value     = 0.0

		var val_lbl := Label.new()
		val_lbl.text = "0"
		val_lbl.custom_minimum_size = Vector2(28.0, 0.0)
		val_lbl.add_theme_font_size_override("font_size", 11)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slider.value_changed.connect(
			func(v: float) -> void: val_lbl.text = "%d" % int(v)
		)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		row.add_child(val_lbl)

		vbox.add_child(_labeled_row(entry["label"], row))

		match entry["ref"]:
			"_hunger_slider":    _hunger_slider    = slider
			"_fatigue_slider":   _fatigue_slider   = slider
			"_pain_slider":      _pain_slider       = slider
			"_loneliness_slider": _loneliness_slider = slider

	return vbox


func _build_spawn_button() -> Button:
	var btn := Button.new()
	btn.text = "＋ Crear criatura"
	btn.custom_minimum_size = Vector2(0.0, 36.0)
	btn.pressed.connect(_on_spawn_pressed)
	return btn


# ─── Helpers de layout ────────────────────────────────────────────────────────

func _labeled_row(label_text: String, control: Control) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.add_child(_make_section_label(label_text))
	vbox.add_child(control)
	return vbox


func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.48, 0.48, 0.56))
	return lbl


func _build_separator() -> HSeparator:
	var sep := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.26, 0.26, 0.30, 0.55)
	sep.add_theme_stylebox_override("separator", style)
	return sep


# ─── Lógica ───────────────────────────────────────────────────────────────────

func _randomize_fields() -> void:
	_randomize_name()
	_gender_option.selected = randi() % 2
	_scale_slider.value = snappedf(randf_range(0.85, 1.15), 0.05)


func _randomize_name() -> void:
	var temp := IdentityData.new()
	temp.generate_random()
	_name_input.text = temp.creature_name


func _on_load_texture_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode    = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access       = FileDialog.ACCESS_RESOURCES
	dialog.filters      = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp,*.svg ; Imágenes"])
	dialog.file_selected.connect(_on_texture_file_selected)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered(Vector2(700, 500))


func _on_texture_file_selected(path: String) -> void:
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		_show_status("No se pudo cargar la imagen.", false)
		return
	_selected_texture = tex
	_preview_sprite.texture = tex
	_texture_path_label.text = path.get_file()


func _on_clear_texture_pressed() -> void:
	_selected_texture = null
	_preview_sprite.texture = null
	_texture_path_label.text = "Sin textura"


func _on_spawn_pressed() -> void:
	if agent_scene == null:
		_show_status("Asigna 'Agent Scene' (base_agent.tscn) en el Inspector.", false)
		return

	var new_agent: BaseAgent = agent_scene.instantiate() as BaseAgent
	if new_agent == null:
		_show_status("Error: la escena no es un BaseAgent válido.", false)
		return

	# Identidad
	var id := IdentityData.new()
	id.creature_name = _name_input.text.strip_edges()
	if id.creature_name == "":
		id.generate_random()
	id.gender      = _gender_option.get_selected_id() as IdentityData.Gender
	id.species     = _species_input.text.strip_edges()
	if id.species == "":
		id.species = "Human"
	id.body_scale      = _scale_slider.value
	id.sprite_texture  = _selected_texture
	id.start_age       = id.age_to_adult if _start_adult_check.button_pressed else 0.0
	new_agent.identity = id

	# Recursos únicos
	new_agent.chemical_profile = ChemicalProfile.new()
	new_agent.brain            = BrainWeights.new()

	# Posición aleatoria dentro del Boundary
	new_agent.global_position = Vector2(
		randf_range(spawn_area_min.x, spawn_area_max.x),
		randf_range(spawn_area_min.y, spawn_area_max.y)
	)

	id.portrait = _portrait_editor.get_portrait_data().duplicate_portrait()
	get_tree().current_scene.add_child(new_agent)

	# Aplicar valores químicos iniciales tras añadir al árbol
	await get_tree().process_frame
	new_agent.chemical_profile.set_level(&"hunger",    _hunger_slider.value)
	new_agent.chemical_profile.set_level(&"fatigue",   _fatigue_slider.value)
	new_agent.chemical_profile.set_level(&"pain",      _pain_slider.value)
	new_agent.chemical_profile.set_level(&"loneliness", _loneliness_slider.value)

	_show_status("✓ %s creado" % id.creature_name, true)
	EventLog.push("Nueva criatura: %s" % id.display())
	_randomize_fields()


func _show_status(text: String, success: bool) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color",
		Color(0.55, 0.80, 0.55) if success else Color(0.85, 0.45, 0.45)
	)

var _portrait_editor: PortraitEditor = null


func _build_portrait_section() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)

	var toggle_btn := Button.new()
	toggle_btn.text = "▸ 🎨 Retrato"
	toggle_btn.flat = true
	toggle_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle_btn.add_theme_font_size_override("font_size", 11)
	toggle_btn.add_theme_color_override("font_color", Color(0.75, 0.65, 0.90))
	vbox.add_child(toggle_btn)

	_portrait_editor = PortraitEditor.new()
	_portrait_editor.visible = false
	_portrait_editor.load_portrait(PortraitData.new())
	vbox.add_child(_portrait_editor)

	toggle_btn.pressed.connect(func() -> void:
		_portrait_editor.visible = not _portrait_editor.visible
		toggle_btn.text = ("▾ " if _portrait_editor.visible else "▸ ") + "🎨 Retrato"
	)

	return vbox
