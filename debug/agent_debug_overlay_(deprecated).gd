# agent_debug_overlay.gd
# Overlay de depuración opcional. Conectar a un Label o RichTextLabel.
# Muestra los niveles químicos del agente en pantalla durante desarrollo.
class_name AgentDebugOverlay
extends RichTextLabel

@export var agent: BaseAgent


func _process(_delta: float) -> void:
	if agent == null or agent.chemical_profile == null:
		return

	var p: ChemicalProfile = agent.chemical_profile
	text = (
		"[b]Químicos[/b]\n"
		+ "Hambre:    %.1f\n" % p.hunger
		+ "Cansancio: %.1f\n" % p.fatigue
		+ "Soledad:   %.1f\n" % p.loneliness
		+ "Dolor:     %.1f\n" % p.pain
	)
