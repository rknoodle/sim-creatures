# sim-creatures

Prototipo en **Godot 4.7** de una simulación de vida artificial: criaturas autónomas con un "cerebro" asociativo simple, necesidades fisiológicas que suben con el tiempo, y un sistema social que va desde conocerse hasta cortejar, emparejarse y reproducirse.

> Primer prototipo en Godot. El código está en español (comentarios, nombres de eventos, mensajes de log) y todavía tiene partes experimentales o en construcción (ver [Estado actual](#estado-actual)).

## Idea central

Cada criatura (`BaseAgent`) tiene un conjunto de **químicos** internos (hambre, cansancio, soledad, dolor, líbido) que suben solos con el tiempo. La criatura decide qué hacer según cuál de esos químicos está más crítico:

1. **Supervivencia** (prioridad máxima): si el hambre o el cansancio superan un umbral, va a buscar el objeto más cercano que lo alivie (comida, cama).
2. **Apareamiento**: si tiene pareja vinculada y la líbido es alta, va a buscarla para apareamiento.
3. **Cortejo**: si la líbido es media y hay un amigo candidato del sexo opuesto, intenta cortejarlo.
4. **Socializar**: si la soledad es alta, busca al agente más cercano para reducirla.
5. **Cerebro asociativo**: para el resto de los casos, un sistema de pesos (`BrainWeights`) que se refuerza con la experiencia decide la acción (comer, dormir, deambular).

No hay un "guion" fijo: el comportamiento emerge de estos químicos, del aprendizaje por refuerzo simple y de las relaciones sociales que cada criatura va acumulando con las demás.

## Sistemas principales

- **Químicos y refuerzo** (`resources/`): `ChemicalProfile` guarda los niveles; `BrainWeights` es una tabla de pesos acción↔químico que se ajusta con `ReinforcementSystem` comparando el estado antes/después de cada acción (si el químico bajó, refuerza; si no, penaliza).
- **Selección de acciones** (`agents/decision_maker.gd`, `resources/action_selector.gd`): dos versiones del "selector de acciones" (`action_selector.gd` parece ser la más nueva e híbrida, ver nota abajo).
- **Objetos interactivos** (`objects/smart_object.gd`, `food_bowl.gd`): objetos del mundo con una `InteractionDefinition` que define cuánto alivian cada químico. Se registran solos en el singleton `ObjectRegistry`, que los agentes consultan para encontrar el más cercano disponible.
- **Vida social** (`agents/social_memory.gd`, `social_sensor.gd`, `romance_controller.gd`, `companion_controller.gd`): cada agente recuerda a quién conoció, su afinidad y su relación (Desconocido → Conocido → Amigo → Pareja). El cortejo, el vínculo de pareja, el apareamiento y hasta el "acompañamiento" entre parejas (ir juntos a resolver una necesidad) están modelados como componentes separados.
- **Ciclo de vida**: las criaturas nacen con una `IdentityData` (nombre generado al azar, género, especie, edad) y pasan de juvenil a adulta, momento en el que se activa la líbido.
- **Autoloads / singletons** (`autoloads/`): `EventBus` (señales globales de selección), `EventLog` (registro de eventos del mundo, se ve en la UI), `ObjectRegistry` (búsqueda de objetos por químico), `SaveManager` (guardado/carga en JSON con reconciliación de relaciones sociales), `AgentDragger` (agarrar y mover agentes con clic derecho, para depuración).
- **UI/Debug** (`ui/`, `debug/`): inspector de criatura (barras de químicos, relación con otros), panel de debug (F1) para editar químicos en vivo, y overlays de depuración (algunos ya marcados como deprecados).

## Estructura de carpetas

```
agents/       Componentes que forman a un agente: BaseAgent, memoria social, cortejo,
              sensor social, acompañamiento de pareja, selección por clic, arrastre.
autoloads/    Singletons globales (bus de eventos, log, registro de objetos, guardado).
components/   Componentes reutilizables más genéricos (deambular, monitor de químicos).
debug/        Overlays de depuración (algunos deprecados).
objects/      Objetos interactivos del mundo (SmartObject y ejemplos como FoodBowl).
resources/    Resources de datos/lógica: perfil químico, pesos del cerebro, identidad,
              definición de interacción, selector de acciones, refuerzo, partículas.
scripts/      Utilidades sueltas (cámara).
ui/           Paneles de interfaz (inspector, debug, log de eventos, menú de pausa).
world/        Cámara libre para explorar el mundo.
```

Archivos sueltos en la raíz: `main_world.tscn`/`.gd` (escena principal, con dos agentes de ejemplo) y `base_agent_template.tscn` (plantilla de agente con todos sus componentes).

## Cómo se relacionan las piezas (resumen técnico)

- `BaseAgent` es un `CharacterBody2D` que delega casi toda su lógica en nodos hijos (`WanderController`, `ChemicalMonitor`, `ActionSelector`, `ReinforcementSystem`, `SocialMemory`, `RomanceController`, `SocialSensor`, `CompanionController`, `SelectionComponent`), y usa `NavigationAgent2D` para moverse hacia objetivos.
- El agente reacciona a señales de sus componentes (`action_chosen`, `social_target_chosen`, `courtship_target_chosen`, `mating_triggered`, etc.) y cambia de estado (`AgentState`: WANDERING, NAVIGATING_TO_OBJECT, INTERACTING, COURTING, COURTING_ACTIVE, MATING, SOCIALIZING).
- La relación social pasa por afinidad numérica (-100 a 100) con cooldown de ganancia, que determina el nivel de relación; solo se puede cortejar a un "Amigo" y solo hay un vínculo de "Pareja" por agente (monogamia).
- El guardado (`SaveManager`) serializa posición, químicos, identidad y memoria social de cada agente a JSON, y al cargar reconstruye los vínculos de pareja buscando agentes por nombre.

## Estado actual

- Prototipo temprano, pensado como ejercicio de aprendizaje de Godot/GDScript.
- El movimiento y la física son en **2D** (`CharacterBody2D`, `Area2D`, `NavigationAgent2D`), aunque `project.godot` tiene configurado el backend de físicas Jolt (normalmente usado en 3D) — probablemente configuración por defecto sin limpiar.
- Hay overlays y un `decision_maker.gd` que parecen versiones anteriores de lógica que después se reemplazó por `action_selector.gd` (selector híbrido con niveles de prioridad); falta confirmar/limpiar cuál está realmente en uso desde la escena.
- La reproducción llega hasta "concepción" (`mating_ready`); la genética/herencia de las crías está marcada como módulo futuro (ver comentario en `main_world.gd`).

## Requisitos

- [Godot Engine 4.7](https://godotengine.org/) (o superior compatible con el mismo `config/features`).
