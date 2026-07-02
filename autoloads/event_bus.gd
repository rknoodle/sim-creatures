# event_bus.gd
# Singleton global de señales desacopladas.
# Añadir en Project > Autoload como "EventBus".
# class_name EventBus
extends Node

signal creature_selected(creature: BaseAgent)
signal creature_deselected
