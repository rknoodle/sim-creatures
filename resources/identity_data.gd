# identity_data.gd
# Resource que almacena la identidad estática del agente: nombre y sexo.
class_name IdentityData
extends Resource

enum Gender { MALE, FEMALE }

@export var creature_name: String = ""
@export var gender: Gender = Gender.MALE

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
	return "%s [%s]" % [creature_name, gender_label()]
