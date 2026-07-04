# zoom_indicator.gd
# Label pequeño que muestra el zoom actual como porcentaje.
class_name ZoomIndicator
extends Label


func _ready() -> void:
	add_theme_font_size_override("font_size", 11)
	add_theme_color_override("font_color", Color(0.75, 0.75, 0.80))
	text = "100%"
	await get_tree().process_frame
	var cameras: Array[Node] = get_tree().get_nodes_in_group("main_camera")
	if not cameras.is_empty():
		var cam := cameras[0] as FreeCamera
		if cam != null:
			cam.zoom_changed.connect(_on_zoom_changed)


func _on_zoom_changed(percent: int) -> void:
	text = "%d%%" % percent
