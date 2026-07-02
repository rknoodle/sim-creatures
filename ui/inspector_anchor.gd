# inspector_anchor.gd
# Posiciona el panel en la esquina superior derecha y lo mantiene ahí.
# Asignar a un MarginContainer raíz dentro del CanvasLayer.
class_name InspectorAnchor
extends MarginContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	anchor_left   = 1.0
	anchor_top    = 0.0
	anchor_right  = 1.0
	anchor_bottom = 0.0
	offset_left   = -280.0
	offset_top    = 16.0
	offset_right  = -16.0
	offset_bottom = 600.0
	mouse_filter  = Control.MOUSE_FILTER_IGNORE
