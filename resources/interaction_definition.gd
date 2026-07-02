# interaction_definition.gd
# Resource que describe qué hace una interacción: qué químico altera y cuánto.
# Permite definir objetos con múltiples efectos combinados.
class_name InteractionDefinition
extends Resource

@export var interaction_name: StringName = &"interact"
@export var duration_seconds: float = 2.0

# Cambios aplicados al ChemicalProfile al completar la interacción.
# Valores negativos reducen el químico (alivio), positivos lo aumentan.
@export var hunger_change: float = 0.0
@export var fatigue_change: float = 0.0
@export var loneliness_change: float = 0.0
@export var pain_change: float = 0.0


func apply_to(profile: ChemicalProfile) -> void:
	profile.set_level(&"hunger",
		profile.hunger + hunger_change)
	profile.set_level(&"fatigue",
		profile.fatigue + fatigue_change)
	profile.set_level(&"loneliness",
		profile.loneliness + loneliness_change)
	profile.set_level(&"pain",
		profile.pain + pain_change)


## Devuelve qué tanto alivia el químico indicado (valor positivo = alivio real).
func get_relief_for(chemical_name: StringName) -> float:
	match chemical_name:
		&"hunger":     return -hunger_change
		&"fatigue":    return -fatigue_change
		&"loneliness": return -loneliness_change
		&"pain":       return -pain_change
		_:             return 0.0
