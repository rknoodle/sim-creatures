# boundary.gd
# Gestiona las paredes físicas y el sprite de fondo del área de juego.
class_name Boundary
extends Node2D

@export var width: float  = 1280.0
@export var height: float = 720.0
@export var wall_thickness: float = 20.0
@export var floor_texture: Texture2D = null

@onready var _floor_sprite: Sprite2D = $FloorSprite
@onready var _body: StaticBody2D     = $StaticBody2D


func _ready() -> void:
	_setup_floor()
	_setup_walls()


func _setup_floor() -> void:
	if _floor_sprite == null:
		return
	_floor_sprite.position = Vector2(width * 0.5, height * 0.5)

	if floor_texture != null:
		_floor_sprite.texture = floor_texture
		# Escalar el sprite para cubrir toda el área
		var tex_size: Vector2 = floor_texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			_floor_sprite.scale = Vector2(width / tex_size.x, height / tex_size.y)
	else:
		# Fondo de color sólido si no hay textura
		_floor_sprite.texture = _create_solid_texture()


func _setup_walls() -> void:
	if _body == null:
		return
	# Eliminar colisionadores previos y recrearlos
	for child: Node in _body.get_children():
		child.queue_free()

	var walls: Array[Dictionary] = [
		{"pos": Vector2(width * 0.5, -wall_thickness * 0.5),
		 "size": Vector2(width + wall_thickness * 2.0, wall_thickness)},
		{"pos": Vector2(width * 0.5, height + wall_thickness * 0.5),
		 "size": Vector2(width + wall_thickness * 2.0, wall_thickness)},
		{"pos": Vector2(-wall_thickness * 0.5, height * 0.5),
		 "size": Vector2(wall_thickness, height)},
		{"pos": Vector2(width + wall_thickness * 0.5, height * 0.5),
		 "size": Vector2(wall_thickness, height)},
	]

	for wall: Dictionary in walls:
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size     = wall["size"]
		col.shape      = shape
		col.position   = wall["pos"]
		_body.add_child(col)


func _create_solid_texture() -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color(0.30, 0.45, 0.25))
	return ImageTexture.create_from_image(img)
