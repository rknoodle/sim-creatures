# main_world.gd
extends Node2D

@onready var agent_m: BaseAgent = $BaseAgentM
@onready var agent_f: BaseAgent = $BaseAgentF


func _ready() -> void:
	_connect_agent_signals(agent_m)
	_connect_agent_signals(agent_f)
	await get_tree().process_frame
	var cameras: Array[Node] = get_tree().get_nodes_in_group("main_camera")
	if not cameras.is_empty():
		AgentDragger.register_camera(cameras[0] as Camera2D)


func _connect_agent_signals(agent: BaseAgent) -> void:
	agent.hunger_critical.connect(_on_agent_hunger_critical.bind(agent))
	agent.chemical_normalized.connect(_on_chemical_normalized.bind(agent))


func _on_agent_hunger_critical(level: float, agent: BaseAgent) -> void:
	print("¡HAMBRE CRÍTICA! %s — Nivel: %.1f" % [agent.identity.creature_name, level])


func _on_chemical_normalized(chem_name: StringName, agent: BaseAgent) -> void:
	print("Químico normalizado en %s: %s" % [agent.identity.creature_name, chem_name])
	
func _enter_tree() -> void:
	add_to_group("world")


func on_mating_ready(parent_a: BaseAgent, parent_b: BaseAgent) -> void:
	print("[Apareamiento confirmado] %s + %s — listo para genética (módulo futuro)" % [
		parent_a.identity.creature_name,
		parent_b.identity.creature_name
	])
