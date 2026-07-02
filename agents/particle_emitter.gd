# particle_emitter.gd
# Nodo visual ligero que representa una sola partícula animada.
# Creado y destruido dinámicamente por AgentParticles.
class_name ParticleEmitter
extends Node2D

var _velocity: Vector2 = Vector2.ZERO
var _lifetime: float = 1.0
var _elapsed: float = 0.0
var _fade: bool = true
var _config: ParticleConfig = null

# Nodos visuales internos (solo uno estará activo según el modo)
var _label: Label = null
var _sprite: Sprite2D = null
var _dot_radius: float = 4.0
var _dot_color: Color = Color.WHITE


func setup(config: ParticleConfig, direction: Vector2, speed: float) -> void:
	_config   = config
	_lifetime = config.lifetime
	_fade     = config.fade_out
	_velocity = direction * speed
	scale     = Vector2.ONE * config.particle_scale

	match config.mode:
		ParticleConfig.ParticleMode.EMOJI:
			_label = Label.new()
			_label.text = config.emoji_text
			_label.add_theme_font_size_override("font_size", config.emoji_font_size)
			_label.position = Vector2(
				-config.emoji_font_size * 0.3,
				-config.emoji_font_size * 0.5
			)
			add_child(_label)

		ParticleConfig.ParticleMode.TEXTURE:
			if config.texture != null:
				_sprite = Sprite2D.new()
				_sprite.texture = config.texture
				add_child(_sprite)

		ParticleConfig.ParticleMode.COLOR_DOT:
			_dot_radius = config.dot_radius
			_dot_color  = config.dot_color


func _draw() -> void:
	if _config != null and _config.mode == ParticleConfig.ParticleMode.COLOR_DOT:
		var alpha: float = 1.0
		if _fade and _lifetime > 0.0:
			alpha = 1.0 - (_elapsed / _lifetime)
		draw_circle(Vector2.ZERO, _dot_radius, Color(_dot_color, alpha))


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _lifetime:
		queue_free()
		return

	_velocity.y += _config.gravity * delta
	position += _velocity * delta

	var progress: float = _elapsed / _lifetime
	if _fade:
		modulate.a = 1.0 - progress

	if _config.mode == ParticleConfig.ParticleMode.COLOR_DOT:
		queue_redraw()
