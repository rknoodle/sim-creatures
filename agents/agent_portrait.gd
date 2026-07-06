# agent_portrait.gd
class_name AgentPortrait
extends Node

## Tamaño en píxeles al que queremos que se vea el retrato en el mundo.
## Equivale al tamaño de tus sprites originales (114x114 * 0.5 scale = 57px efectivos).
@export var target_display_size: float = 57.0

@onready var _viewport: PortraitViewport = $PortraitViewport

var _sprite: Sprite2D = null
var _portrait_data: PortraitData = null


func _ready() -> void:
	_sprite = get_parent().get_node_or_null("Sprite2D") as Sprite2D
	await get_tree().process_frame
	var agent := get_parent() as BaseAgent
	if agent != null and agent.identity != null and agent.identity.portrait != null:
		apply(agent.identity.portrait)


func apply(data: PortraitData) -> void:
	if data == null:
		return
	_portrait_data = data
	_viewport.apply_portrait(data)
	# Esperar dos frames para que el SubViewport renderice
	await get_tree().process_frame
	await get_tree().process_frame
	_apply_to_sprite()


func _apply_to_sprite() -> void:
	if _sprite == null:
		return
	_sprite.texture = _viewport.get_texture()

	# Calcular escala para que el retrato ocupe target_display_size píxeles,
	# independientemente del body_scale del agente (que ya aplica scale al nodo raíz).
	var agent := get_parent() as BaseAgent
	var body_scale: float = 1.0
	if agent != null and agent.identity != null:
		body_scale = agent.identity.body_scale

	# El viewport es 512px. Queremos target_display_size px en pantalla.
	# Como el nodo raíz ya tiene scale = body_scale, compensamos dividiéndolo.
	var final_scale: float = target_display_size / (512.0 * body_scale)
	_sprite.scale = Vector2(final_scale, final_scale)
	_sprite.centered = true
	
	# Actualizar radio de selección para que coincida con el tamaño visual real
	var selection: SelectionComponent = \
		get_parent().get_node_or_null("SelectionComponent") as SelectionComponent
	if selection != null:
		selection.update_radius(target_display_size * 0.5)


func refresh_layer(layer_name: StringName) -> void:
	_viewport.refresh_layer(layer_name)
	await get_tree().process_frame
	_apply_to_sprite()
