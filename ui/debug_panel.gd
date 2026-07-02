# debug_panel.gd
# Panel de depuración para editar químicos del agente seleccionado en tiempo real.
# Se abre/cierra con F1. Solo visible en desarrollo.
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

var _selected_agent: BaseAgent = null
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _agent_label: Label
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO


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
	# Actualizar labels de valor sin mover los sliders mientras el usuario los mueve
	for chemical: StringName in CHEMICALS:
		var val: float = _selected_agent.chemical_profile.get_level(chemical)
		_value_labels[chemical].text = "%.1f" % val
		if not (_sliders[chemical] as HSlider).has_focus():
			(_sliders[chemical] as HSlider).value = val


func _build_ui() -> void:
	custom_minimum_size = Vector2(280.0, 0.0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.08, 0.95)
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

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	# Header
	var header := HBoxContainer.new()
	var debug_title := Label.new()
	debug_title.text = "🛠 DEBUG"
	debug_title.add_theme_font_size_override("font_size", 13)
	debug_title.add_theme_color_override("font_color", Color(0.45, 0.90, 0.45))
	debug_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(debug_title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_color_override("font_color", Color(0.60, 0.60, 0.65))
	close_btn.pressed.connect(func() -> void: hide())
	header.add_child(close_btn)
	root.add_child(header)

	_agent_label = Label.new()
	_agent_label.text = "Sin agente seleccionado"
	_agent_label.add_theme_font_size_override("font_size", 11)
	_agent_label.add_theme_color_override("font_color", Color(0.70, 0.70, 0.75))
	root.add_child(_agent_label)

	root.add_child(_build_separator())

	# Sliders por químico
	for chemical: StringName in CHEMICALS:
		root.add_child(_build_slider_row(chemical))

	root.add_child(_build_separator())

	# Botones de acceso rápido
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)

	var btn_fill := _make_debug_button("Llenar todo")
	btn_fill.pressed.connect(_on_fill_all_pressed)
	btn_row.add_child(btn_fill)

	var btn_empty := _make_debug_button("Vaciar todo")
	btn_empty.pressed.connect(_on_empty_all_pressed)
	btn_row.add_child(btn_empty)

	var btn_adult := _make_debug_button("Forzar adulto")
	btn_adult.pressed.connect(_on_force_adult_pressed)
	btn_row.add_child(btn_adult)

	root.add_child(btn_row)


func _build_slider_row(chemical: StringName) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var top := HBoxContainer.new()

	var name_lbl := Label.new()
	name_lbl.text = CHEMICAL_LABELS.get(chemical, str(chemical))
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.75, 0.90, 0.75))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_lbl)

	var value_lbl := Label.new()
	value_lbl.text = "0.0"
	value_lbl.add_theme_font_size_override("font_size", 11)
	value_lbl.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90))
	value_lbl.custom_minimum_size = Vector2(38.0, 0.0)
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(value_lbl)
	vbox.add_child(top)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step      = 0.5
	slider.value     = 0.0
	slider.value_changed.connect(_on_slider_changed.bind(chemical))
	vbox.add_child(slider)

	_sliders[chemical]      = slider
	_value_labels[chemical] = value_lbl
	return vbox


func _make_debug_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0.0, 28.0)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return btn


func _build_separator() -> HSeparator:
	var sep := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.20, 0.38, 0.20, 0.55)
	sep.add_theme_stylebox_override("separator", style)
	return sep


# ─── Callbacks ────────────────────────────────────────────────────────────────

func _on_slider_changed(value: float, chemical: StringName) -> void:
	if _selected_agent == null or not is_instance_valid(_selected_agent):
		return
	_selected_agent.chemical_profile.set_level(chemical, value)


func _on_fill_all_pressed() -> void:
	if _selected_agent == null:
		return
	for chemical: StringName in CHEMICALS:
		_selected_agent.chemical_profile.set_level(chemical, 100.0)


func _on_empty_all_pressed() -> void:
	if _selected_agent == null:
		return
	for chemical: StringName in CHEMICALS:
		_selected_agent.chemical_profile.set_level(chemical, 0.0)


func _on_force_adult_pressed() -> void:
	if _selected_agent == null:
		return
	_selected_agent._age_stage = BaseAgent.AgeStage.ADULT
	_selected_agent._age_timer = _selected_agent.age_to_adult
	_selected_agent.chemical_profile.set_libido_active(true)
	EventLog.push("[Debug] %s forzado a adulto" % _selected_agent.identity.creature_name)


func _on_creature_selected(creature: BaseAgent) -> void:
	_selected_agent = creature
	_agent_label.text = "Editando: %s" % creature.identity.creature_name


func _on_creature_deselected() -> void:
	_selected_agent = null
	_agent_label.text = "Sin agente seleccionado"


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
