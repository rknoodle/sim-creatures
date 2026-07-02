# creature_inspector.gd
# Módulo 3.8: añade sección de pareja actual y panel desplegable de relaciones.
class_name CreatureInspector
extends PanelContainer

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

var _header_name: Label
var _species_label: Label
var _header_gender: Label
var _state_label: Label
var _age_label: Label
var _courtship_label: Label
var _partner_label: Label

var _bar_hunger: ProgressBar
var _bar_fatigue: ProgressBar
var _bar_libido: ProgressBar
var _bar_pain: ProgressBar
var _bar_loneliness: ProgressBar

var _label_hunger: Label
var _label_energy: Label
var _label_libido: Label
var _label_pain: Label
var _label_loneliness: Label

var _relations_toggle: Button
var _relations_container: VBoxContainer
var _relations_list: VBoxContainer
var _relations_expanded: bool = false

var _close_button: Button
var _selected_agent: BaseAgent = null

const COLOR_OK:       Color = Color(0.25, 0.80, 0.35)
const COLOR_WARNING:  Color = Color(0.90, 0.75, 0.10)
const COLOR_CRITICAL: Color = Color(0.85, 0.20, 0.20)
const COLOR_PAIN:     Color = Color(0.80, 0.25, 0.60)
const CRITICAL_THRESHOLD: float = 70.0
const WARNING_THRESHOLD:  float = 40.0

const RELATIONSHIP_LABELS: Dictionary = {
	SocialMemory.Relationship.STRANGER:     "Desconocido",
	SocialMemory.Relationship.ACQUAINTANCE: "Conocido",
	SocialMemory.Relationship.FRIEND:       "Amigo",
	SocialMemory.Relationship.PARTNER:      "Pareja",
}

const RELATIONSHIP_COLORS: Dictionary = {
	SocialMemory.Relationship.STRANGER:     Color(0.55, 0.55, 0.60),
	SocialMemory.Relationship.ACQUAINTANCE: Color(0.60, 0.75, 0.90),
	SocialMemory.Relationship.FRIEND:       Color(0.45, 0.80, 0.55),
	SocialMemory.Relationship.PARTNER:      Color(1.00, 0.55, 0.75),
}


func _ready() -> void:
	_build_ui()
	hide()
	# Posición inicial: esquina superior derecha, sin anchors
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	anchor_right  = 0.0
	anchor_bottom = 0.0
	# Se posiciona después de que el viewport tenga tamaño real
	await get_tree().process_frame
	global_position = Vector2(
		get_viewport_rect().size.x - custom_minimum_size.x - 16.0,
		16.0
	)
	EventBus.creature_selected.connect(_on_creature_selected)
	EventBus.creature_deselected.connect(_on_creature_deselected)


func _process(_delta: float) -> void:
	if _selected_agent == null:
		return
	if not is_instance_valid(_selected_agent):
		_clear_and_hide()
		return
	_refresh()


# ─── Construcción de UI ───────────────────────────────────────────────────────

func _build_ui() -> void:
	custom_minimum_size = Vector2(280.0, 0.0)

	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.08, 0.08, 0.10, 0.93)
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.30, 0.30, 0.35, 0.80)
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

	root.add_child(_build_header())
	root.add_child(_build_separator())
	root.add_child(_build_identity_section())
	root.add_child(_build_separator())
	root.add_child(_build_state_section())
	root.add_child(_build_separator())
	root.add_child(_build_needs_section())
	root.add_child(_build_separator())
	root.add_child(_build_relations_section())
	_header_name.mouse_filter = Control.MOUSE_FILTER_STOP


func _build_header() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	_header_name = Label.new()
	_header_name.text = "—"
	_header_name.add_theme_font_size_override("font_size", 17)
	_header_name.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	_header_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_header_name)

	_header_gender = Label.new()
	_header_gender.text = ""
	_header_gender.add_theme_font_size_override("font_size", 18)
	hbox.add_child(_header_gender)

	_close_button = Button.new()
	_close_button.text = "✕"
	_close_button.flat = true
	_close_button.add_theme_color_override("font_color", Color(0.60, 0.60, 0.65))
	_close_button.pressed.connect(_on_close_pressed)
	hbox.add_child(_close_button)

	return hbox


func _build_identity_section() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.add_child(_make_section_label("IDENTIDAD"))
	
	_species_label = Label.new()
	_species_label.text = "—"
	_species_label.add_theme_font_size_override("font_size", 10)
	_species_label.add_theme_color_override("font_color", Color(0.60, 0.65, 0.75))
	vbox.add_child(_species_label)

	_age_label = Label.new()
	_age_label.text = "Edad: —"
	_age_label.add_theme_font_size_override("font_size", 12)
	_age_label.add_theme_color_override("font_color", Color(0.80, 0.85, 0.95))
	vbox.add_child(_age_label)

	_partner_label = Label.new()
	_partner_label.text = "Pareja: ninguna"
	_partner_label.add_theme_font_size_override("font_size", 12)
	_partner_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.78))
	vbox.add_child(_partner_label)

	return vbox


func _build_state_section() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.add_child(_make_section_label("ESTADO"))

	_state_label = Label.new()
	_state_label.text = "—"
	_state_label.add_theme_font_size_override("font_size", 12)
	_state_label.add_theme_color_override("font_color", Color(0.80, 0.88, 1.00))
	_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_state_label)

	_courtship_label = Label.new()
	_courtship_label.text = ""
	_courtship_label.add_theme_font_size_override("font_size", 11)
	_courtship_label.add_theme_color_override("font_color", Color(1.0, 0.60, 0.75))
	_courtship_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_courtship_label)

	return vbox


func _build_needs_section() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	vbox.add_child(_make_section_label("NECESIDADES"))

	var hunger_row  := _build_bar_row("Hambre",  "🍖")
	var fatigue_row := _build_bar_row("Energía", "⚡")
	var lonely_row  := _build_bar_row("Soledad", "👤")
	var pain_row    := _build_bar_row("Dolor",   "💢")
	var libido_row  := _build_bar_row("Líbido",  "❤")

	_bar_hunger     = hunger_row[0];  _label_hunger     = hunger_row[1]
	_bar_fatigue    = fatigue_row[0]; _label_energy     = fatigue_row[1]
	_bar_loneliness = lonely_row[0];  _label_loneliness = lonely_row[1]
	_bar_pain       = pain_row[0];    _label_pain       = pain_row[1]
	_bar_libido     = libido_row[0];  _label_libido     = libido_row[1]

	vbox.add_child(hunger_row[2])
	vbox.add_child(fatigue_row[2])
	vbox.add_child(lonely_row[2])
	vbox.add_child(pain_row[2])
	vbox.add_child(libido_row[2])

	return vbox


func _build_relations_section() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	_relations_toggle = Button.new()
	_relations_toggle.text = "▸ RELACIONES (0)"
	_relations_toggle.flat = true
	_relations_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_relations_toggle.add_theme_font_size_override("font_size", 10)
	_relations_toggle.add_theme_color_override("font_color", Color(0.50, 0.50, 0.58))
	_relations_toggle.pressed.connect(_on_relations_toggle_pressed)
	vbox.add_child(_relations_toggle)

	_relations_container = VBoxContainer.new()
	_relations_container.add_theme_constant_override("separation", 4)
	_relations_container.visible = false

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 140.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_relations_container.add_child(scroll)

	_relations_list = VBoxContainer.new()
	_relations_list.add_theme_constant_override("separation", 4)
	_relations_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_relations_list)

	vbox.add_child(_relations_container)
	return vbox


## Devuelve [ProgressBar, Label_valor, contenedor_raiz]
func _build_bar_row(label_text: String, icon: String) -> Array:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 4)

	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.add_theme_font_size_override("font_size", 12)
	top.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_lbl)

	var value_lbl := Label.new()
	value_lbl.text = "0"
	value_lbl.add_theme_font_size_override("font_size", 11)
	value_lbl.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90))
	value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(value_lbl)

	vbox.add_child(top)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value     = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, 10.0)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.14, 0.14, 0.17)
	bar_bg.corner_radius_top_left     = 4
	bar_bg.corner_radius_top_right    = 4
	bar_bg.corner_radius_bottom_left  = 4
	bar_bg.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = COLOR_OK
	bar_fill.corner_radius_top_left     = 4
	bar_fill.corner_radius_top_right    = 4
	bar_fill.corner_radius_bottom_left  = 4
	bar_fill.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("fill", bar_fill)

	vbox.add_child(bar)
	return [bar, value_lbl, vbox]


func _make_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.48, 0.48, 0.56))
	return lbl


func _build_separator() -> HSeparator:
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color             = Color(0.26, 0.26, 0.30, 0.55)
	sep_style.content_margin_top   = 0
	sep_style.content_margin_bottom = 0
	sep.add_theme_stylebox_override("separator", sep_style)
	return sep


# ─── Actualización de datos ───────────────────────────────────────────────────

func _refresh() -> void:
	var p: ChemicalProfile  = _selected_agent.chemical_profile
	var id: IdentityData    = _selected_agent.identity

	_header_name.text = id.creature_name
	if not _species_label == null:
		_species_label.text = _selected_agent.identity.species
	_header_gender.text = "♂" if id.gender == IdentityData.Gender.MALE else "♀"
	_header_gender.add_theme_color_override("font_color",
		Color(0.45, 0.65, 1.0) if id.gender == IdentityData.Gender.MALE
		else Color(1.0, 0.55, 0.75)
	)

	var age_stage: String = "Adulto" \
		if _selected_agent._age_stage == BaseAgent.AgeStage.ADULT \
		else "Juvenil"
	_age_label.text = "Edad: %s  (%.0fs)" % [age_stage, _selected_agent._age_timer]

	_refresh_partner_label()
	_state_label.text = _build_state_text()

	if _selected_agent.romance.is_courting:
		var partner: BaseAgent = _selected_agent.romance.current_partner
		if partner != null and is_instance_valid(partner):
			_courtship_label.text = "💕 Cortejando a %s" % partner.identity.creature_name
		else:
			_courtship_label.text = "💕 Buscando pareja..."
	else:
		_courtship_label.text = ""

	_update_bar(_bar_hunger,     _label_hunger,     p.hunger,     false)
	_update_bar(_bar_loneliness, _label_loneliness, p.loneliness, false)
	_update_bar(_bar_pain,       _label_pain,       p.pain,       false, true)
	_update_bar(_bar_fatigue,    _label_energy,     100.0 - p.fatigue, true)
	_update_bar(_bar_libido,     _label_libido,     p.libido,     false)

	if _relations_expanded:
		_refresh_relations_list()
	_relations_toggle.text = "%s RELACIONES (%d)" % [
		"▾" if _relations_expanded else "▸",
		_selected_agent.memory.social_memory.size()
	]
	if _relations_expanded:
		_refresh_relations_list()


func _refresh_partner_label() -> void:
	var bonded: BaseAgent = _selected_agent.romance.bonded_partner
	if bonded != null and is_instance_valid(bonded):
		_partner_label.text = "Pareja: %s" % bonded.identity.creature_name
	else:
		_partner_label.text = "Pareja: ninguna"


func _refresh_relations_list() -> void:
	var memory: Dictionary = _selected_agent.memory.social_memory

	# Reconstruir solo si el número de entradas cambió
	var current_count: int = _relations_list.get_child_count()
	var memory_count: int = memory.size()

	if current_count != memory_count:
		for child: Node in _relations_list.get_children():
			child.queue_free()
		if memory.is_empty():
			var empty_lbl := Label.new()
			empty_lbl.text = "Sin contactos conocidos."
			empty_lbl.add_theme_font_size_override("font_size", 10)
			empty_lbl.add_theme_color_override("font_color", Color(0.50, 0.50, 0.55))
			_relations_list.add_child(empty_lbl)
			return
		var sorted_ids: Array = memory.keys()
		sorted_ids.sort_custom(func(a: int, b: int) -> bool:
			return memory[a]["affinity"] > memory[b]["affinity"]
		)
		for agent_id: int in sorted_ids:
			_relations_list.add_child(_build_relation_row(memory[agent_id]))
		return

	# Si el conteo es igual, solo actualizar valores existentes
	var sorted_ids: Array = memory.keys()
	sorted_ids.sort_custom(func(a: int, b: int) -> bool:
		return memory[a]["affinity"] > memory[b]["affinity"]
	)
	var children: Array = _relations_list.get_children()
	for i: int in range(mini(sorted_ids.size(), children.size())):
		var entry: Dictionary = memory[sorted_ids[i]]
		var row: PanelContainer = children[i] as PanelContainer
		if row == null:
			continue
		_update_relation_row(row, entry)

func _update_relation_row(row: PanelContainer, entry: Dictionary) -> void:
	var vbox := row.get_child(0) as VBoxContainer
	if vbox == null:
		return
	var top := vbox.get_child(0) as HBoxContainer
	if top == null:
		return

	var name_lbl := top.get_child(0) as Label
	if name_lbl != null:
		name_lbl.text = entry["name"]

	var rel_lbl := top.get_child(1) as Label
	var relationship: SocialMemory.Relationship = entry["relationship"]
	if rel_lbl != null:
		rel_lbl.text = RELATIONSHIP_LABELS.get(relationship, "—")
		rel_lbl.add_theme_color_override("font_color",
			RELATIONSHIP_COLORS.get(relationship, Color.WHITE)
		)

	var affinity_bar := vbox.get_child(1) as ProgressBar
	if affinity_bar != null:
		affinity_bar.value = entry["affinity"]
		var fill_style := affinity_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_style != null:
			fill_style.bg_color = RELATIONSHIP_COLORS.get(relationship, Color(0.25, 0.80, 0.35))

	var affinity_lbl := vbox.get_child(2) as Label
	if affinity_lbl != null:
		affinity_lbl.text = "Afinidad: %.0f" % entry["affinity"]


func _build_relation_row(entry: Dictionary) -> PanelContainer:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.13, 0.16, 0.80)
	style.corner_radius_top_left     = 5
	style.corner_radius_top_right    = 5
	style.corner_radius_bottom_left  = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left   = 8
	style.content_margin_right  = 8
	style.content_margin_top    = 4
	style.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	row.add_child(vbox)

	var top := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = entry["name"]
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.85))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_lbl)

	var relationship: SocialMemory.Relationship = entry["relationship"]
	var rel_lbl := Label.new()
	rel_lbl.text = RELATIONSHIP_LABELS.get(relationship, "—")
	rel_lbl.add_theme_font_size_override("font_size", 10)
	rel_lbl.add_theme_color_override("font_color",
		RELATIONSHIP_COLORS.get(relationship, Color.WHITE)
	)
	top.add_child(rel_lbl)
	vbox.add_child(top)

	var affinity_bar := ProgressBar.new()
	affinity_bar.min_value = -100.0
	affinity_bar.max_value = 100.0
	affinity_bar.value     = entry["affinity"]
	affinity_bar.show_percentage = false
	affinity_bar.custom_minimum_size = Vector2(0.0, 6.0)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.10, 0.10, 0.12)
	bar_bg.corner_radius_top_left = 3
	bar_bg.corner_radius_top_right = 3
	bar_bg.corner_radius_bottom_left = 3
	bar_bg.corner_radius_bottom_right = 3
	affinity_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = RELATIONSHIP_COLORS.get(relationship, COLOR_OK)
	bar_fill.corner_radius_top_left = 3
	bar_fill.corner_radius_top_right = 3
	bar_fill.corner_radius_bottom_left = 3
	bar_fill.corner_radius_bottom_right = 3
	affinity_bar.add_theme_stylebox_override("fill", bar_fill)

	vbox.add_child(affinity_bar)

	var affinity_lbl := Label.new()
	affinity_lbl.text = "Afinidad: %.0f" % entry["affinity"]
	affinity_lbl.add_theme_font_size_override("font_size", 9)
	affinity_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60))
	vbox.add_child(affinity_lbl)

	return row


func _update_bar(
	bar: ProgressBar,
	value_label: Label,
	value: float,
	inverted: bool,
	use_pain_color: bool = false
) -> void:
	bar.value        = value
	value_label.text = "%d" % int(value)

	var fill_style := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style == null:
		return

	if use_pain_color:
		fill_style.bg_color = COLOR_PAIN if value >= WARNING_THRESHOLD else COLOR_OK
		return

	var is_critical: bool = value >= CRITICAL_THRESHOLD if not inverted \
		else value <= (100.0 - CRITICAL_THRESHOLD)
	var is_warning: bool  = value >= WARNING_THRESHOLD  if not inverted \
		else value <= (100.0 - WARNING_THRESHOLD)

	if is_critical:
		fill_style.bg_color = COLOR_CRITICAL
	elif is_warning:
		fill_style.bg_color = COLOR_WARNING
	else:
		fill_style.bg_color = COLOR_OK


func _build_state_text() -> String:
	if not is_instance_valid(_selected_agent):
		return "—"
	match _selected_agent._state:
		BaseAgent.AgentState.WANDERING:            return "Vagando"
		BaseAgent.AgentState.NAVIGATING_TO_OBJECT: return "Desplazándose"
		BaseAgent.AgentState.INTERACTING:          return "Interactuando"
		BaseAgent.AgentState.COURTING:             return "Yendo a cortejar"
		BaseAgent.AgentState.COURTING_ACTIVE:      return "Cortejando..."
		BaseAgent.AgentState.MATING:               return "Apareándose"
		BaseAgent.AgentState.SOCIALIZING:          return "Socializando"
		_:                                         return "—"


# ─── Señales ─────────────────────────────────────────────────────────────────

func _on_creature_selected(creature: BaseAgent) -> void:
	_selected_agent = creature
	_relations_expanded = false
	_refresh()
	show()


func _on_creature_deselected() -> void:
	_clear_and_hide()


func _on_close_pressed() -> void:
	EventBus.creature_deselected.emit()
	_clear_and_hide()


func _on_relations_toggle_pressed() -> void:
	_relations_expanded = not _relations_expanded
	_relations_container.visible = _relations_expanded
	if _relations_expanded:
		_refresh_relations_list()


func _clear_and_hide() -> void:
	_selected_agent       = null
	_header_name.text     = "—"
	_header_gender.text   = ""
	_state_label.text     = "—"
	_courtship_label.text = ""
	_age_label.text       = "Edad: —"
	_partner_label.text   = "Pareja: ninguna"
	_bar_hunger.value      = 0.0
	_bar_fatigue.value     = 0.0
	_bar_libido.value      = 0.0
	_bar_pain.value        = 0.0
	_bar_loneliness.value  = 0.0
	_relations_expanded = false
	_relations_container.visible = false
	for child: Node in _relations_list.get_children():
		child.queue_free()
	hide()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_offset = global_position - get_global_mouse_position()
			else:
				_dragging = false

	elif event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() + _drag_offset
		# Mantener dentro de los límites de la ventana
		var vp: Vector2 = get_viewport_rect().size
		global_position.x = clampf(global_position.x, 0.0, vp.x - size.x)
		global_position.y = clampf(global_position.y, 0.0, vp.y - size.y)
