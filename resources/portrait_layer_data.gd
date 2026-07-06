# portrait_layer_data.gd
# Datos de una sola capa del retrato: qué textura, qué color y offset.
class_name PortraitLayerData
extends Resource

@export var texture: Texture2D = null
@export var color: Color = Color.WHITE
@export var offset: Vector2 = Vector2.ZERO
@export var visible: bool = true


func duplicate_layer() -> PortraitLayerData:
	var copy := PortraitLayerData.new()
	copy.texture = texture
	copy.color   = color
	copy.offset  = offset
	copy.visible = visible
	return copy
