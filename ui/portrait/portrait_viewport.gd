# portrait_viewport.gd
# SubViewport que contiene un PortraitRenderer y expone la textura resultante.
# Úsalo como hijo del agente o de la UI para obtener el avatar compuesto.
class_name PortraitViewport
extends SubViewport

@onready var _renderer: PortraitRenderer = $PortraitRenderer

const SIZE: int = 512


func _ready() -> void:
	size               = Vector2i(SIZE, SIZE)
	transparent_bg     = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS


func apply_portrait(data: PortraitData) -> void:
	if _renderer != null:
		_renderer.apply_portrait(data)


func refresh_layer(layer_name: StringName) -> void:
	if _renderer != null:
		_renderer.refresh_layer(layer_name)

# --- Se eliminó la función get_texture() duplicada ---
