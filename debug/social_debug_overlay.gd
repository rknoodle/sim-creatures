# social_debug_overlay.gd
# Muestra identidad, edad, libido y memoria social del agente.
class_name SocialDebugOverlay
extends RichTextLabel

@export var agent: BaseAgent


func _process(_delta: float) -> void:
	if agent == null:
		return

	var p: ChemicalProfile = agent.chemical_profile
	var id: IdentityData   = agent.identity
	var mem: Dictionary    = agent.memory.social_memory

	var lines: PackedStringArray = PackedStringArray()
	lines.append("[b]%s[/b]" % id.display())
	lines.append("Libido:  %.1f" % p.libido)
	lines.append("Estado:  %s" % _state_label())
	lines.append("\n[b]Memoria social[/b]")

	if mem.is_empty():
		lines.append("  (ningún conocido)")
	else:
		for agent_id: int in mem:
			var entry: Dictionary = mem[agent_id]
			lines.append("  %s → afinidad %.1f" % [
				entry.get("name", "?"),
				entry.get("affinity", 0.0)
			])

	text = "\n".join(lines)


func _state_label() -> String:
	match agent.romance.is_courting:
		true:  return "CORTEJANDO"
		false: return "NORMAL"
	return "NORMAL"
