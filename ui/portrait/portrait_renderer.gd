# portrait_renderer.gd
# Node2D que renderiza las capas del PortraitData apiladas.
# Usado dentro de SubViewport para composición final.
class_name PortraitRenderer
extends Node2D

const RENDER_SIZE: int = 512

var _sprites: Dictionary = {}  # { layer_name: Sprite2D }
var _portrait_data: PortraitData = null


func _ready() -> void:
	_build_sprite_stack()


func _build_sprite_stack() -> void:
	for child: Node in get_children():
		child.queue_free()
	_sprites.clear()

	for layer_name: StringName in PortraitData.LAYER_NAMES:
		var sprite := Sprite2D.new()
		sprite.name            = str(layer_name)
		sprite.centered        = false
		sprite.position        = Vector2.ZERO
		sprite.texture_filter  = CanvasItem.TEXTURE_FILTER_LINEAR
		_sprites[layer_name]   = sprite
		add_child(sprite)


func apply_portrait(data: PortraitData) -> void:
	_portrait_data = data
	refresh()


func refresh() -> void:
	if _portrait_data == null:
		return
	for layer_name: StringName in PortraitData.LAYER_NAMES:
		var sprite := _sprites.get(layer_name) as Sprite2D
		if sprite == null:
			continue
		var layer: PortraitLayerData = _portrait_data.get_layer(layer_name)
		sprite.texture  = layer.texture
		sprite.modulate = layer.color
		sprite.position = layer.offset
		sprite.visible  = layer.visible and layer.texture != null


func refresh_layer(layer_name: StringName) -> void:
	if _portrait_data == null:
		return
	var sprite := _sprites.get(layer_name) as Sprite2D
	if sprite == null:
		return
	var layer: PortraitLayerData = _portrait_data.get_layer(layer_name)
	sprite.texture  = layer.texture
	sprite.modulate = layer.color
	sprite.position = layer.offset
	sprite.visible  = layer.visible and layer.texture != null
