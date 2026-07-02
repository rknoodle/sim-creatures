# action_snapshot.gd
# Instantánea del estado químico antes de ejecutar una acción.
# El sistema de refuerzo la usa para calcular cuánto cambió cada químico.
class_name ActionSnapshot
extends RefCounted

var action_name: StringName = &""
var chemical_before: Dictionary = {}
var timestamp: float = 0.0


func capture(action: StringName, profile: ChemicalProfile) -> void:
	action_name = action
	timestamp = Time.get_ticks_msec() / 1000.0
	chemical_before = {
		&"hunger":     profile.hunger,
		&"fatigue":    profile.fatigue,
		&"loneliness": profile.loneliness,
		&"pain":       profile.pain,
	}


## Devuelve cuánto cambió cada químico respecto al snapshot.
## Valor negativo = bajó (alivio), positivo = subió (empeoramiento).
func compute_deltas(profile: ChemicalProfile) -> Dictionary:
	return {
		&"hunger":     profile.hunger     - chemical_before.get(&"hunger",     0.0),
		&"fatigue":    profile.fatigue    - chemical_before.get(&"fatigue",    0.0),
		&"loneliness": profile.loneliness - chemical_before.get(&"loneliness", 0.0),
		&"pain":       profile.pain       - chemical_before.get(&"pain",       0.0),
	}
