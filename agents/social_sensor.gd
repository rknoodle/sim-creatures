# social_sensor.gd — Módulo 3.8 fix: solo alivia soledad la compañía de
# gente con relación establecida (ACQUAINTANCE o superior), no extraños.
class_name SocialSensor
extends Area2D

@export var detection_radius: float = 120.0
@export var isolation_grace_period: float = 4.0

var _agent: BaseAgent
var _memory: SocialMemory
var _romance: RomanceController
var _known_companions_in_range: int = 0
var _isolation_timer: float = 0.0

## Agentes actualmente dentro del radio, para recalcular tras cambios de relación.
var _agents_in_range: Array[BaseAgent] = []


func _ready() -> void:
	_agent = get_parent() as BaseAgent
	assert(_agent != null, "SocialSensor: debe ser hijo de BaseAgent.")

	var shape := CircleShape2D.new()
	shape.radius = detection_radius
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	collision_layer = 2
	collision_mask  = 2
	monitoring  = true
	monitorable = true

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _physics_process(delta: float) -> void:
	_recalculate_known_companions()

	if _known_companions_in_range > 0:
		_isolation_timer = 0.0
		_agent.chemical_profile.set_isolated(false)
	else:
		_isolation_timer += delta
		if _isolation_timer >= isolation_grace_period:
			_agent.chemical_profile.set_isolated(true)


func initialize(memory: SocialMemory, romance: RomanceController) -> void:
	_memory  = memory
	_romance = romance


func _on_area_entered(area: Area2D) -> void:
	var other := area.get_parent() as BaseAgent
	if other == null or other == _agent:
		return

	_agents_in_range.append(other)

	var is_new: bool = _memory.meet(other)
	if is_new:
		EventLog.push("%s conoció a %s" % [
			_agent.identity.creature_name, other.identity.creature_name
		])

	if _romance.is_courting and _romance.current_partner == null:
		if other.romance.is_courting and other.identity.gender != _agent.identity.gender:
			_romance.begin_courtship()


func _on_area_exited(area: Area2D) -> void:
	var other := area.get_parent() as BaseAgent
	if other == null:
		return
	_agents_in_range.erase(other)


## Solo cuenta como "compañía real" (que detiene la subida de soledad)
## a quienes ya son PARTNER. Desconocidos, conocidos y amigos no alivian
## la soledad pasivamente con solo estar cerca — eso fuerza al agente
## a seguir socializando activamente hasta formar una pareja estable.
func _recalculate_known_companions() -> void:
	var count: int = 0
	for other: BaseAgent in _agents_in_range:
		if not is_instance_valid(other):
			continue
		var relationship: SocialMemory.Relationship = _memory.get_relationship(
			other.get_instance_id()
		)
		if relationship == SocialMemory.Relationship.PARTNER:
			count += 1
	_known_companions_in_range = count
