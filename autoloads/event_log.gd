# event_log.gd
# Singleton que centraliza el registro de eventos del mundo.
# Añadir en Project > Autoload como "EventLog".
#class_name EventLog
extends Node

signal entry_added(text: String, timestamp: String)

const MAX_ENTRIES: int = 200

var entries: Array[Dictionary] = []


func push(message: String) -> void:
	var timestamp: String = Time.get_time_string_from_system()
	entries.append({"text": message, "timestamp": timestamp})
	if entries.size() > MAX_ENTRIES:
		entries.pop_front()
	entry_added.emit(message, timestamp)
	print("[%s] %s" % [timestamp, message])


func clear() -> void:
	entries.clear()
