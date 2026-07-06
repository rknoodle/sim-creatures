# debug_panel.gd
# Panel de depuración completo con secciones desplegables.
# Cubre: Identity, Move Speed, Chemical Profile (valores + tasas), Brain weights.
class_name DebugPanel
extends PanelContainer

const CHEMICALS: Array[StringName] = [
	&"hunger", &"fatigue", &"loneliness", &"pain", &"libido"
]
const CHEMICAL_LABELS: Dictionary = {
	&"hunger":     "Hambre",
	&"fatigue":    "Cansancio",
	&"loneliness": "Soledad",
	&"pain":       "Dolor",
	&"libido":     "Líbido",
}
const ACTIONS: Array[StringName] = [&"eat", &"sleep", &"wander"]
const ACTION_LABELS: Dictionary = {
	&"eat":    "Comer",
	&"sleep":  "Dormir",
	&"wander": "Vagar",
}
const BRAIN_CHEMICALS: Array[StringName] = [
	&"hunger", &"fatigue", &"loneliness", &"pain"
]

var _selected_agent: BaseAgent = null

# Secciones desplegables
var _sections: Dictionary = {}  # { section_name: { "btn": Button, "container": VBoxContainer } }

# Referencias a controles por sección
var _identity_controls: Dictionary = {}
var _chem_value_sliders: Dictionary = {}
var _chem_rate_sliders: Dictionary = {}
var _brain_sliders: Dictionary = {}  # { "eat_hunger": HSlider, ... }
var _move_speed_slider: HSlider
var _age_timer_label: Label
var _agent_header_label: Label

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _portrait_editor: PortraitEditor = null


func _ready() -> void:
	_build_ui()
	hide()
	EventBus.creature_selected.connect(_on_creature_selected)
	EventBus.creature_deselected.connect(_on_creature_deselected)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_F1:
			visible = not visible


func _process(_delta: float) -> void:
	if _selected_agent == null or not visible:
		return
	if not is_instance_valid(_selected_agent):
		hide()
		return
	_refresh_read_only_fields()


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


# ─── Construcción ─────────────────────────────────────────────────────────────

func _build_ui() -> void:
	custom_minimum_size = Vector2(300.0, 0.0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.07, 0.10, 0.07, 0.96)
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.20, 0.45, 0.20, 0.80)
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   12)
	margin.add_theme_constant_override("margin_right",  12)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 520.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	# Header
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "🛠 DEBUG"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.45, 0.90, 0.45))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", Color(0.60, 0.60, 0.65))
	close_btn.pressed.connect(func() -> void: hide())
	header.add_child(close_btn)
	root.add_child(header)

	_agent_header_label = Label.new()
	_agent_header_label.text = "Sin agente seleccionado"
	_agent_header_label.add_theme_font_size_override("font_size", 11)
	_agent_header_label.add_theme_color_override("font_color", Color(0.65, 0.80, 0.65))
	root.add_child(_agent_header_label)

	root.add_child(_build_separator())

	# Secciones desplegables
	root.add_child(_build_section("identity",   "👤 Identidad",         _build_identity_content()))
	root.add_child(_build_section("movement",   "🏃 Movimiento",        _build_movement_content()))
	root.add_child(_build_section("chem_vals",  "🧪 Niveles químicos",  _build_chem_values_content()))
	root.add_child(_build_section("chem_rates", "⏱ Tasas químicas",    _build_chem_rates_content()))
	root.add_child(_build_section("brain",      "🧠 Cerebro (pesos)",   _build_brain_content()))
	root.add_child(_build_section("portrait", "🎨 Retrato", _build_portrait_editor_content()))

	root.add_child(_build_separator())
	root.add_child(_build_quick_actions())


func _build_section(id: StringName, label: String, content: VBoxContainer) -> VBoxContainer:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 4)

	var toggle_btn := Button.new()
	toggle_btn.text = "▸ " + label
	toggle_btn.flat = true
	toggle_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle_btn.add_theme_font_size_override("font_size", 11)
	toggle_btn.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55))
	wrapper.add_child(toggle_btn)

	content.visible = false
	wrapper.add_child(content)

	toggle_btn.pressed.connect(func() -> void:
		content.visible = not content.visible
		toggle_btn.text = ("▾ " if content.visible else "▸ ") + label
	)

	_sections[id] = {"btn": toggle_btn, "container": content}
	return wrapper


# ─── Contenido: Identidad ─────────────────────────────────────────────────────

func _build_identity_content() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	# Nombre
	var name_input := LineEdit.new()
	name_input.placeholder_text = "Nombre..."
	name_input.text_submitted.connect(
		func(text: String) -> void:
			if _selected_agent != null:
				_selected_agent.identity.creature_name = text
	)
	_identity_controls[&"name"] = name_input
	vbox.add_child(_labeled_control("Nombre", name_input))

	# Especie
	var species_input := LineEdit.new()
	species_input.placeholder_text = "Human, Monster..."
	species_input.text_submitted.connect(
		func(text: String) -> void:
			if _selected_agent != null:
				_selected_agent.identity.species = text
	)
	_identity_controls[&"species"] = species_input
	vbox.add_child(_labeled_control("Especie", species_input))

	# Género
	var gender_option := OptionButton.new()
	gender_option.add_item("Macho",  IdentityData.Gender.MALE)
	gender_option.add_item("Hembra", IdentityData.Gender.FEMALE)
	gender_option.item_selected.connect(
		func(idx: int) -> void:
			if _selected_agent != null:
				_selected_agent.identity.gender = gender_option.get_item_id(idx) \
					as IdentityData.Gender
	)
	_identity_controls[&"gender"] = gender_option
	vbox.add_child(_labeled_control("Género", gender_option))

	# Escala corporal
	var scale_row := _slider_with_label(0.5, 2.0, 0.05, 1.0,
		func(v: float) -> void:
			if _selected_agent == null:
				return
			_selected_agent.identity.body_scale = v
			_selected_agent.scale = Vector2(v, v)
	)
	_identity_controls[&"body_scale"] = scale_row[0]
	vbox.add_child(_labeled_control("Escala corporal", scale_row[1]))

	# Age to Adult
	var age_adult_row := _slider_with_label(10.0, 300.0, 5.0, 60.0,
		func(v: float) -> void:
			if _selected_agent != null:
				_selected_agent.identity.age_to_adult = v
	)
	_identity_controls[&"age_to_adult"] = age_adult_row[0]
	vbox.add_child(_labeled_control("Edad adulta (s)", age_adult_row[1]))

	# Courtship pursue speed
	var courtship_row := _slider_with_label(1.0, 3.0, 0.1, 1.6,
		func(v: float) -> void:
			if _selected_agent != null:
				_selected_agent.identity.courtship_pursue_speed_multiplier = v
	)
	_identity_controls[&"courtship_speed"] = courtship_row[0]
	vbox.add_child(_labeled_control("Velocidad cortejo", courtship_row[1]))

	# Start Age (solo lectura)
	_age_timer_label = Label.new()
	_age_timer_label.text = "— s"
	_age_timer_label.add_theme_font_size_override("font_size", 11)
	_age_timer_label.add_theme_color_override("font_color", Color(0.80, 0.80, 0.85))
	vbox.add_child(_labeled_control("Edad actual (s) [lectura]", _age_timer_label))

	return vbox


# ─── Contenido: Movimiento ────────────────────────────────────────────────────

func _build_movement_content() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var speed_row := _slider_with_label(10.0, 300.0, 5.0, 80.0,
		func(v: float) -> void:
			if _selected_agent != null:
				_selected_agent.move_speed = v
	)
	_move_speed_slider = speed_row[0]
	vbox.add_child(_labeled_control("Velocidad (px/s)", speed_row[1]))

	return vbox


# ─── Contenido: Niveles químicos ──────────────────────────────────────────────

func _build_chem_values_content() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	for chemical: StringName in CHEMICALS:
		var row := _slider_with_label(0.0, 100.0, 0.5, 0.0,
			func(v: float) -> void:
				if _selected_agent != null:
					_selected_agent.chemical_profile.set_level(chemical, v)
		)
		_chem_value_sliders[chemical] = row[0]
		vbox.add_child(_labeled_control(
			CHEMICAL_LABELS.get(chemical, str(chemical)), row[1]
		))

	return vbox


# ─── Contenido: Tasas químicas ────────────────────────────────────────────────

func _build_chem_rates_content() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var rates: Array[Dictionary] = [
		{"key": &"hunger_rate",    "label": "Tasa Hambre",    "default": 1.0},
		{"key": &"fatigue_rate",   "label": "Tasa Cansancio", "default": 0.8},
		{"key": &"pain_rate",      "label": "Tasa Dolor",     "default": -0.3},
		{"key": &"libido_rate",    "label": "Tasa Líbido",    "default": 0.4},
		{"key": &"loneliness_isolated_rate",   "label": "Soledad (aislado)",   "default": 0.9},
		{"key": &"loneliness_accompanied_rate","label": "Soledad (acompañado)","default": -1.2},
	]

	for entry: Dictionary in rates:
		var key: StringName = entry["key"]
		var default_val: float = entry["default"]
		var row := _slider_with_label(-3.0, 5.0, 0.05, default_val,
			func(v: float) -> void:
				if _selected_agent != null:
					_selected_agent.chemical_profile.set(key, v)
		)
		_chem_rate_sliders[key] = row[0]
		vbox.add_child(_labeled_control(entry["label"], row[1]))

	return vbox


# ─── Contenido: Brain weights ─────────────────────────────────────────────────

func _build_brain_content() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	for action: StringName in ACTIONS:
		var action_vbox := VBoxContainer.new()
		action_vbox.add_theme_constant_override("separation", 4)

		var action_lbl := Label.new()
		action_lbl.text = ACTION_LABELS.get(action, str(action)).to_upper()
		action_lbl.add_theme_font_size_override("font_size", 10)
		action_lbl.add_theme_color_override("font_color", Color(0.50, 0.85, 0.50))
		action_vbox.add_child(action_lbl)

		for chemical: StringName in BRAIN_CHEMICALS:
			var slider_key: String = "%s_%s" % [action, chemical]
			var default_weight: float = BrainWeights.new().get_weight(action, chemical)
			var row := _slider_with_label(-1.0, 1.0, 0.01, default_weight,
				func(v: float) -> void:
					if _selected_agent != null:
						_selected_agent.brain.weights[action][chemical] = v
			)
			_brain_sliders[slider_key] = row[0]
			action_vbox.add_child(_labeled_control(
				CHEMICAL_LABELS.get(chemical, str(chemical)), row[1]
			))

		vbox.add_child(action_vbox)
		if action != ACTIONS[-1]:
			vbox.add_child(_build_separator())

	# Botón reset
	var reset_btn := Button.new()
	reset_btn.text = "↺ Resetear pesos a valores por defecto"
	reset_btn.custom_minimum_size = Vector2(0.0, 28.0)
	reset_btn.pressed.connect(_on_brain_reset_pressed)
	vbox.add_child(reset_btn)

	return vbox


# ─── Acciones rápidas ─────────────────────────────────────────────────────────

func _build_quick_actions() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)

	var lbl := Label.new()
	lbl.text = "ACCIONES RÁPIDAS"
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.48, 0.48, 0.56))
	vbox.add_child(lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 5)

	var btn_fill := _make_btn("Llenar todo")
	btn_fill.pressed.connect(func() -> void:
		if _selected_agent == null: return
		for c: StringName in CHEMICALS:
			_selected_agent.chemical_profile.set_level(c, 100.0)
	)
	btn_row.add_child(btn_fill)

	var btn_empty := _make_btn("Vaciar todo")
	btn_empty.pressed.connect(func() -> void:
		if _selected_agent == null: return
		for c: StringName in CHEMICALS:
			_selected_agent.chemical_profile.set_level(c, 0.0)
	)
	btn_row.add_child(btn_empty)

	var btn_adult := _make_btn("→ Adulto")
	btn_adult.pressed.connect(_on_force_adult_pressed)
	btn_row.add_child(btn_adult)

	vbox.add_child(btn_row)
	return vbox


# ─── Helpers ──────────────────────────────────────────────────────────────────

## Devuelve [HSlider, HBoxContainer_con_slider_y_label]
func _slider_with_label(
	min_v: float, max_v: float, step: float, default_v: float,
	on_change: Callable
) -> Array:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step      = step
	slider.value     = default_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % default_v
	val_lbl.custom_minimum_size = Vector2(42.0, 0.0)
	val_lbl.add_theme_font_size_override("font_size", 10)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(val_lbl)

	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = "%.2f" % v
		on_change.call(v)
	)

	return [slider, hbox]


func _labeled_control(label_text: String, control: Control) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.50, 0.50, 0.58))
	vbox.add_child(lbl)
	vbox.add_child(control)
	return vbox


func _make_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0.0, 26.0)
	return btn


func _build_separator() -> HSeparator:
	var sep := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.20, 0.38, 0.20, 0.55)
	sep.add_theme_stylebox_override("separator", style)
	return sep


# ─── Actualización ────────────────────────────────────────────────────────────

func _refresh_read_only_fields() -> void:
	if _age_timer_label != null:
		_age_timer_label.text = "%.1f s" % _selected_agent._age_timer


func _populate_sliders_from_agent() -> void:
	if _selected_agent == null:
		return

	var p: ChemicalProfile  = _selected_agent.chemical_profile
	var id: IdentityData    = _selected_agent.identity
	var b: BrainWeights     = _selected_agent.brain

	# Identity
	if _identity_controls.has(&"name"):
		(_identity_controls[&"name"] as LineEdit).text = id.creature_name
	if _identity_controls.has(&"species"):
		(_identity_controls[&"species"] as LineEdit).text = id.species
	if _identity_controls.has(&"gender"):
		(_identity_controls[&"gender"] as OptionButton).selected = int(id.gender)
	if _identity_controls.has(&"body_scale"):
		(_identity_controls[&"body_scale"] as HSlider).value = id.body_scale
	if _identity_controls.has(&"age_to_adult"):
		(_identity_controls[&"age_to_adult"] as HSlider).value = id.age_to_adult
	if _identity_controls.has(&"courtship_speed"):
		(_identity_controls[&"courtship_speed"] as HSlider).value = \
			id.courtship_pursue_speed_multiplier

	# Move speed
	if _move_speed_slider != null:
		_move_speed_slider.value = _selected_agent.move_speed

	# Chem values
	for chemical: StringName in CHEMICALS:
		if _chem_value_sliders.has(chemical):
			(_chem_value_sliders[chemical] as HSlider).value = p.get_level(chemical)

	# Chem rates
	var rate_keys: Array[StringName] = [
		&"hunger_rate", &"fatigue_rate", &"pain_rate", &"libido_rate",
		&"loneliness_isolated_rate", &"loneliness_accompanied_rate"
	]
	for key: StringName in rate_keys:
		if _chem_rate_sliders.has(key):
			(_chem_rate_sliders[key] as HSlider).value = p.get(key)

	# Brain
	for action: StringName in ACTIONS:
		for chemical: StringName in BRAIN_CHEMICALS:
			var slider_key: String = "%s_%s" % [action, chemical]
			if _brain_sliders.has(slider_key):
				(_brain_sliders[slider_key] as HSlider).value = \
					b.get_weight(action, chemical)


# ─── Callbacks ────────────────────────────────────────────────────────────────

func _on_creature_selected(creature: BaseAgent) -> void:
	_selected_agent = creature
	_agent_header_label.text = "Editando: %s" % creature.identity.creature_name
	_populate_sliders_from_agent()

	if _portrait_editor != null:
		# Crear PortraitData si el agente no tiene uno todavía
		if creature.identity.portrait == null:
			creature.identity.portrait = PortraitData.new()
		_portrait_editor.load_portrait(creature.identity.portrait)
	

func _on_creature_deselected() -> void:
	_selected_agent = null
	_agent_header_label.text = "Sin agente seleccionado"


func _on_force_adult_pressed() -> void:
	if _selected_agent == null:
		return
	_selected_agent._age_stage = BaseAgent.AgeStage.ADULT
	_selected_agent._age_timer = _selected_agent.identity.age_to_adult
	_selected_agent.chemical_profile.set_libido_active(true)
	EventLog.push("[Debug] %s forzado a adulto" % _selected_agent.identity.creature_name)


func _on_brain_reset_pressed() -> void:
	if _selected_agent == null:
		return
	var fresh := BrainWeights.new()
	_selected_agent.brain.weights = fresh.weights.duplicate(true)
	_populate_sliders_from_agent()
	EventLog.push("[Debug] Cerebro de %s reseteado" % _selected_agent.identity.creature_name)

func _build_portrait_editor_content() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	_portrait_editor = PortraitEditor.new()
	_portrait_editor.portrait_changed.connect(_on_portrait_changed)
	vbox.add_child(_portrait_editor)
	return vbox


func _on_portrait_changed(data: PortraitData) -> void:
	if _selected_agent == null:
		return
	_selected_agent.identity.portrait = data
	# Actualizar el AgentPortrait del agente en el mundo
	var portrait_component: AgentPortrait = \
		_selected_agent.get_node_or_null("AgentPortrait")
	if portrait_component != null:
		portrait_component.apply(data)
