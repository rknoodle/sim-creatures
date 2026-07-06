# identity_data.gd
# Resource de identidad completo. Centraliza todos los datos estáticos del agente.
class_name IdentityData
extends Resource

enum Gender { MALE, FEMALE }

# ─── Apariencia ───────────────────────────────────────────────────────────────
@export_group("Apariencia")
@export var sprite_texture: Texture2D = null
@export var body_scale: float = 1.0
@export_range(0.5, 3.0, 0.05) var body_scale_range: float = 1.0
@export var portrait: PortraitData = null

# ─── Identidad ────────────────────────────────────────────────────────────────
@export_group("Identidad")
@export var creature_name: String = ""
@export var gender: Gender = Gender.MALE
@export var species: String = "Human"

# ─── Edad ─────────────────────────────────────────────────────────────────────
@export_group("Edad")
## Edad inicial en segundos al instanciar el agente.
@export var start_age: float = 0.0
## Segundos hasta alcanzar la madurez (AgeStage.ADULT).
@export var age_to_adult: float = 60.0

# ─── Comportamiento ───────────────────────────────────────────────────────────
@export_group("Comportamiento")
## Multiplicador de velocidad durante el cortejo (solo el perseguidor).
@export var courtship_pursue_speed_multiplier: float = 1.6

# ─── Generación de nombre aleatorio ──────────────────────────────────────────

const NAME_PREFIXES: PackedStringArray = [
	"Bora", "Glim", "Nox", "Vel", "Thar", "Omi", "Zek", "Aer",
	"Dun", "Fal", "Kira", "Sol", "Wen", "Yva", "Crel", "Mora"
]
const NAME_SUFFIXES: PackedStringArray = [
	"la", "bo", "rus", "ix", "en", "tis", "va", "mor",
	"kel", "un", "shi", "das", "orn", "fel", "ara", "nu"
]


func generate_random() -> void:
	var prefix: String = NAME_PREFIXES[randi() % NAME_PREFIXES.size()]
	var suffix: String = NAME_SUFFIXES[randi() % NAME_SUFFIXES.size()]
	creature_name = prefix + suffix
	gender = Gender.MALE if randi() % 2 == 0 else Gender.FEMALE


func gender_label() -> String:
	return "M" if gender == Gender.MALE else "F"


func display() -> String:
	return "%s [%s] (%s)" % [creature_name, gender_label(), species]
