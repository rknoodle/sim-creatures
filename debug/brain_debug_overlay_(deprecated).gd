# brain_debug_overlay.gd
# Overlay opcional que muestra la matriz de pesos en tiempo real.
class_name BrainDebugOverlay
extends RichTextLabel

@export var agent: BaseAgent

const ACTIONS: Array[StringName] = [&"eat", &"sleep", &"wander"]
const CHEMICALS: Array[StringName] = [&"hunger", &"fatigue", &"loneliness", &"pain"]


func _process(_delta: float) -> void:
	if agent == null or agent.brain == null:
		return

	var b: BrainWeights = agent.brain
	var p: ChemicalProfile = agent.chemical_profile
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[b]CEREBRO — Pesos asociativos[/b]")

	for action: StringName in ACTIONS:
		var score: float = b.score_action(action, p)
		lines.append("\n[b]%s[/b]  (score: %.3f)" % [action, score])
		for chemical: StringName in CHEMICALS:
			var w: float = b.get_weight(action, chemical)
			var bar: String = _weight_bar(w)
			lines.append("  %s %s %.3f" % [chemical, bar, w])

	text = "\n".join(lines)


func _weight_bar(w: float) -> String:
	var filled: int = int((w + 1.0) / 2.0 * 10.0)
	filled = clampi(filled, 0, 10)
	return "[" + "█".repeat(filled) + "░".repeat(10 - filled) + "]"
