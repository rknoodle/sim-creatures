# particle_config.gd
# Resource exportable que define el aspecto de un efecto de partículas.
class_name ParticleConfig
extends Resource

enum ParticleMode { EMOJI, TEXTURE, COLOR_DOT }

@export var mode: ParticleMode = ParticleMode.EMOJI

## Usado si mode = EMOJI
@export var emoji_text: String = "✨"
@export var emoji_font_size: int = 18

## Usado si mode = TEXTURE
@export var texture: Texture2D = null

## Usado si mode = COLOR_DOT
@export var dot_color: Color = Color.WHITE
@export var dot_radius: float = 4.0

## Comportamiento general
@export var amount: int = 8
@export var particle_scale: float = 1.0
@export var lifetime: float = 0.9
@export var speed_min: float = 20.0
@export var speed_max: float = 50.0
@export var spread_angle: float = 360.0   # grados de dispersión
@export var gravity: float = 60.0
@export var fade_out: bool = true
@export var spawn_offset: Vector2 = Vector2(0.0, -20.0)
