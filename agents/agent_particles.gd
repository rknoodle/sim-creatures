# agent_particles.gd
# Componente Node2D. Lanza ParticleEmitter individuales según ParticleConfig.
# Todos los configs son exportables y editables desde el Inspector por instancia.
class_name AgentParticles
extends Node2D

@export_group("Comer")
@export var config_eat: ParticleConfig

@export_group("Dormir")
@export var config_sleep: ParticleConfig

@export_group("Apareamiento")
@export var config_mating: ParticleConfig

@export_group("Cortejo")
@export var config_courtship: ParticleConfig

@export_group("Socializar")
@export var config_socialize: ParticleConfig

var _agent: BaseAgent


func _ready() -> void:
	_agent = get_parent() as BaseAgent
	assert(_agent != null, "AgentParticles: debe ser hijo de BaseAgent.")
	_create_default_configs()
	call_deferred("_connect_agent_signals")


func emit(config: ParticleConfig) -> void:
	if config == null:
		return
	for i: int in range(config.amount):
		var angle_rad: float = deg_to_rad(
			randf_range(
				-config.spread_angle * 0.5,
				 config.spread_angle * 0.5
			)
		)
		var base_dir: Vector2 = Vector2(0.0, -1.0).rotated(angle_rad)
		var speed: float = randf_range(config.speed_min, config.speed_max)

		var p := ParticleEmitter.new()
		p.position = config.spawn_offset
		add_child(p)
		p.setup(config, base_dir, speed)


func emit_eat()      -> void: emit(config_eat)
func emit_sleep()    -> void: emit(config_sleep)
func emit_mating()   -> void: emit(config_mating)
func emit_courtship()-> void: emit(config_courtship)
func emit_socialize()-> void: emit(config_socialize)


func _connect_agent_signals() -> void:
	_agent.arrived_at_object.connect(_on_arrived_at_object)

	_agent.romance.mating_pleasure.connect(
		func(_a: BaseAgent, _b: BaseAgent) -> void: emit_mating()
	)
	_agent.romance.mating_ready.connect(
		func(_a: BaseAgent, _b: BaseAgent) -> void: emit_mating()
	)
	_agent.romance.courtship_succeeded.connect(
		func(_target: BaseAgent) -> void: emit_courtship()
	)
	_agent.romance.courtship_failed.connect(
		func(_target: BaseAgent) -> void: emit_courtship()
	)


func _on_arrived_at_object(object: SmartObject) -> void:
	if object == null:
		return
	var targets: Array[StringName] = object.get_target_chemicals()
	if &"hunger" in targets:
		emit_eat()
	elif &"fatigue" in targets:
		emit_sleep()


## Crea configuraciones por defecto si no se asignaron desde el Inspector.
func _create_default_configs() -> void:
	if config_eat == null:
		config_eat = ParticleConfig.new()
		config_eat.emoji_text    = "🍖"
		config_eat.emoji_font_size = 16
		config_eat.amount        = 10
		config_eat.speed_min     = 25.0
		config_eat.speed_max     = 50.0
		config_eat.lifetime      = 0.8
		config_eat.spawn_offset  = Vector2(0.0, -20.0)

	if config_sleep == null:
		config_sleep = ParticleConfig.new()
		config_sleep.emoji_text    = "💤"
		config_sleep.emoji_font_size = 18
		config_sleep.amount        = 6
		config_sleep.speed_min     = 10.0
		config_sleep.speed_max     = 25.0
		config_sleep.lifetime      = 1.2
		config_sleep.gravity       = 20.0
		config_sleep.spawn_offset  = Vector2(0.0, -24.0)

	if config_mating == null:
		config_mating = ParticleConfig.new()
		config_mating.emoji_text    = "✨"
		config_mating.emoji_font_size = 16
		config_mating.amount        = 16
		config_mating.speed_min     = 35.0
		config_mating.speed_max     = 65.0
		config_mating.lifetime      = 1.0
		config_mating.spawn_offset  = Vector2(0.0, -20.0)

	if config_courtship == null:
		config_courtship = ParticleConfig.new()
		config_courtship.emoji_text    = "💕"
		config_courtship.emoji_font_size = 14
		config_courtship.amount        = 8
		config_courtship.speed_min     = 20.0
		config_courtship.speed_max     = 40.0
		config_courtship.lifetime      = 0.9
		config_courtship.spawn_offset  = Vector2(0.0, -20.0)

	if config_socialize == null:
		config_socialize = ParticleConfig.new()
		config_socialize.emoji_text    = "💬"
		config_socialize.emoji_font_size = 14
		config_socialize.amount        = 6
		config_socialize.speed_min     = 15.0
		config_socialize.speed_max     = 30.0
		config_socialize.lifetime      = 0.7
		config_socialize.spawn_offset  = Vector2(0.0, -20.0)
