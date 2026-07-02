# object_registry.gd
# Singleton (Autoload) que mantiene el registro de todos los SmartObjects activos.
# Los agentes consultan aquí para encontrar objetos por tipo de químico.
# Añadir en Project > Project Settings > Autoload como "ObjectRegistry".
# class_name ObjectRegistry
extends Node

# Mapa: chemical_name -> Array de SmartObject
var _registry: Dictionary = {
	&"hunger":     [],
	&"fatigue":    [],
	&"loneliness": [],
	&"pain":       [],
}


func register(object: SmartObject) -> void:
	var targets: Array[StringName] = object.get_target_chemicals()
	for chemical: StringName in targets:
		if _registry.has(chemical):
			if not _registry[chemical].has(object):
				_registry[chemical].append(object)
	object.tree_exiting.connect(_on_object_exiting.bind(object))


func unregister(object: SmartObject) -> void:
	for chemical: StringName in _registry.keys():
		_registry[chemical].erase(object)


## Devuelve el SmartObject más cercano que alivie el químico indicado.
## Retorna null si no hay ninguno disponible.
func find_nearest(chemical_name: StringName, from_position: Vector2) -> SmartObject:
	if not _registry.has(chemical_name):
		return null

	var candidates: Array = _registry[chemical_name]
	var best_object: SmartObject = null
	var best_distance: float = INF

	for obj: SmartObject in candidates:
		if not is_instance_valid(obj) or not obj.is_available():
			continue
		var dist: float = from_position.distance_to(obj.global_position)
		if dist < best_distance:
			best_distance = dist
			best_object = obj

	return best_object


func _on_object_exiting(object: SmartObject) -> void:
	unregister(object)
