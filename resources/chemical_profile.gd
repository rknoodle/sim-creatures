# chemical_profile.gd
class_name ChemicalProfile
extends Resource

@export var hunger: float = 0.0
@export var fatigue: float = 0.0
@export var loneliness: float = 0.0
@export var pain: float = 0.0
@export var libido: float = 0.0

const MIN_VALUE: float = 0.0
const MAX_VALUE: float = 100.0

@export var hunger_rate: float = 1.0
@export var fatigue_rate: float = 0.8
@export var pain_rate: float = -0.3
@export var libido_rate: float = 0.4

## Tasa de soledad cuando NO hay compañía cercana reciente.
@export var loneliness_isolated_rate: float = 0.9
## Tasa de soledad (negativa = alivio) cuando SÍ hay compañía cercana.
@export var loneliness_accompanied_rate: float = -1.2

var _libido_active: bool = false
var _is_isolated: bool = true


func set_libido_active(active: bool) -> void:
	_libido_active = active


## Llamado externamente por SocialMemory/SocialSensor cada vez que detecta compañía.
func set_isolated(isolated: bool) -> void:
	_is_isolated = isolated


func tick(delta: float) -> void:
	hunger  = clampf(hunger  + hunger_rate  * delta, MIN_VALUE, MAX_VALUE)
	fatigue = clampf(fatigue + fatigue_rate * delta, MIN_VALUE, MAX_VALUE)
	pain    = clampf(pain    + pain_rate    * delta, MIN_VALUE, MAX_VALUE)

	var loneliness_rate: float = loneliness_isolated_rate if _is_isolated \
		else loneliness_accompanied_rate
	loneliness = clampf(loneliness + loneliness_rate * delta, MIN_VALUE, MAX_VALUE)

	if _libido_active:
		libido = clampf(libido + libido_rate * delta, MIN_VALUE, MAX_VALUE)


func get_level(chemical_name: StringName) -> float:
	match chemical_name:
		&"hunger":     return hunger
		&"fatigue":    return fatigue
		&"loneliness": return loneliness
		&"pain":       return pain
		&"libido":     return libido
		_:
			push_error("ChemicalProfile: químico desconocido '%s'" % chemical_name)
			return 0.0


func set_level(chemical_name: StringName, value: float) -> void:
	var clamped: float = clampf(value, MIN_VALUE, MAX_VALUE)
	match chemical_name:
		&"hunger":     hunger     = clamped
		&"fatigue":    fatigue    = clamped
		&"loneliness": loneliness = clamped
		&"pain":       pain       = clamped
		&"libido":     libido     = clamped
		_:
			push_error("ChemicalProfile: químico desconocido '%s'" % chemical_name)


## Serializa el estado actual para guardado.
func to_dict() -> Dictionary:
	return {
		"hunger": hunger, "fatigue": fatigue,
		"loneliness": loneliness, "pain": pain, "libido": libido,
	}


func from_dict(data: Dictionary) -> void:
	hunger     = data.get("hunger", 0.0)
	fatigue    = data.get("fatigue", 0.0)
	loneliness = data.get("loneliness", 0.0)
	pain       = data.get("pain", 0.0)
	libido     = data.get("libido", 0.0)
