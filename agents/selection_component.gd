# selection_component.gd
# Componente Area2D hijo del agente. Detecta clics y gestiona
# el indicador visual de selección. Se crea con su propio CollisionShape2D.
class_name SelectionComponent
extends Area2D

@export var indicator_radius: float = 18.0
@export var indicator_color: Color = Color(1.0, 1.0, 1.0, 0.35)

var _is_selected: bool = false
var _indicator: Node2D


func _ready() -> void:
	# Colisión para detectar clic
	var shape := CircleShape2D.new()
	shape.radius = indicator_radius
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	collision_layer = 2
	collision_mask  = 0
	input_pickable  = true

	input_event.connect(_on_input_event)

	# Indicador visual (dibujado en Node2D hijo)
	_indicator = _build_indicator()
	add_child(_indicator)
	_indicator.visible = false


func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			EventBus.creature_selected.emit(get_parent() as BaseAgent)


func set_selected(selected: bool) -> void:
	_is_selected = selected
	_indicator.visible = selected


func _build_indicator() -> Node2D:
	var n := Node2D.new()
	n.name = "SelectionIndicator"
	# Script inline anónimo para dibujar el círculo
	var script := GDScript.new()
	script.source_code = """
extends Node2D
var radius: float = 18.0
var color: Color = Color(1, 1, 1, 0.35)
func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color, 2.0)
"""
	script.reload()
	n.set_script(script)
	# Pasar parámetros después de asignar script
	n.set("radius", indicator_radius)
	n.set("color", indicator_color)
	return n

## Actualiza el radio del colisionador de selección.
func update_radius(new_radius: float) -> void:
	indicator_radius = new_radius
	var col := get_child(0) as CollisionShape2D
	if col != null and col.shape is CircleShape2D:
		(col.shape as CircleShape2D).radius = new_radius
	if _indicator != null:
		_indicator.set("radius", new_radius)
