# event_log_anchor.gd
# Posiciona el panel de historial en la esquina inferior izquierda.
class_name EventLogAnchor
extends MarginContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	anchor_left   = 0.0
	anchor_top    = 1.0
	anchor_right  = 0.0
	anchor_bottom = 1.0
	offset_left   = 16.0
	offset_top    = -240.0
	offset_right  = 340.0
	offset_bottom = -16.0
	mouse_filter  = Control.MOUSE_FILTER_IGNORE
