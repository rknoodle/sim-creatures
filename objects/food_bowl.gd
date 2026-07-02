# food_bowl.gd
# Ejemplo de SmartObject específico. Toda la lógica vive en el Resource;
# este script sólo añade comportamiento visual opcional.
class_name FoodBowl
extends SmartObject


func _ready() -> void:
	super()
	interaction_started.connect(_on_started)
	interaction_completed.connect(_on_completed)


func _on_started(_agent: BaseAgent) -> void:
	modulate = Color(1.0, 0.8, 0.2)  # Tinte amarillo mientras se usa


func _on_completed(_agent: BaseAgent) -> void:
	modulate = Color.WHITE
