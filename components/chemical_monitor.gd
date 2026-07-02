# chemical_monitor.gd
# Componente (Node) que observa un ChemicalProfile y emite señales de umbral.
# Se añade como hijo del agente. Completamente desacoplado del movimiento.
class_name ChemicalMonitor
extends Node

signal hunger_critical(level: float)
signal fatigue_critical(level: float)
signal loneliness_critical(level: float)
signal pain_critical(level: float)
signal chemical_normalized(chemical_name: StringName)

@export var profile: ChemicalProfile
@export var critical_threshold: float = 80.0
@export var normal_threshold: float = 60.0  # Por debajo de esto se considera "normal"

# Seguimiento interno para evitar emitir señales repetidas en cada frame
var _is_critical: Dictionary = {
	&"hunger": false,
	&"fatigue": false,
	&"loneliness": false,
	&"pain": false,
}

const CHEMICALS: Array[StringName] = [&"hunger", &"fatigue", &"loneliness", &"pain"]


func _ready() -> void:
	pass  # El profile se asigna por BaseAgent justo después de _ready()


func evaluate() -> void:
	if profile == null:
		return

	for chemical: StringName in CHEMICALS:
		var level: float = profile.get_level(chemical)
		var was_critical: bool = _is_critical[chemical]

		if level >= critical_threshold and not was_critical:
			_is_critical[chemical] = true
			_emit_critical(chemical, level)

		elif level < normal_threshold and was_critical:
			_is_critical[chemical] = false
			chemical_normalized.emit(chemical)


func _emit_critical(chemical_name: StringName, level: float) -> void:
	match chemical_name:
		&"hunger":    hunger_critical.emit(level)
		&"fatigue":   fatigue_critical.emit(level)
		&"loneliness": loneliness_critical.emit(level)
		&"pain":      pain_critical.emit(level)
