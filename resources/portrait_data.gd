# portrait_data.gd
# Resource que almacena todas las capas del retrato de un agente.
# Se guarda dentro de IdentityData.
class_name PortraitData
extends Resource

# Orden de renderizado: de atrás hacia adelante
const LAYER_NAMES: Array[StringName] = [
	&"hair_back",
	&"head",
	&"ear",
	&"horn",
	&"face_detail",
	&"eye",
	&"nose",
	&"mouth",
	&"eyebrow",
	&"hair_front",
]

const LAYER_LABELS: Dictionary = {
	&"hair_back":   "Cabello (fondo)",
	&"head":        "Cabeza",
	&"ear":         "Orejas",
	&"horn":        "Cuernos",
	&"face_detail": "Detalle facial",
	&"eye":         "Ojos",
	&"nose":        "Nariz",
	&"mouth":       "Boca",
	&"eyebrow":     "Cejas",
	&"hair_front":  "Cabello (frente)",
}

const BASE_PATH: String = "res://assets/portrait/"

# Ahora es una variable estática. Se genera una sola vez en memoria para todos los PortraitData.
static var layer_paths: Dictionary = {}

# Una entrada por capa, indexada por StringName
@export var layers: Dictionary = {}


func _init() -> void:
	# Si es la primera vez que se usa esta clase, mapeamos los archivos del disco
	if layer_paths.is_empty():
		_initialize_layer_paths()
		
	for layer_name: StringName in LAYER_NAMES:
		if not layers.has(layer_name):
			layers[layer_name] = PortraitLayerData.new()


# Escanea el directorio una única vez y llena el diccionario estático
static func _initialize_layer_paths() -> void:
	for layer_name in LAYER_NAMES:
		# Traducimos el ID de la capa al nombre real de su carpeta
		var folder_name: String = str(layer_name)
		match folder_name:
			"hair_back": folder_name = "hair (background)"
			"hair_front": folder_name = "hair (front)"
			"face_detail": folder_name = "face detail"
		
		var folder_path: String = BASE_PATH + folder_name + "/"
		layer_paths[layer_name] = _scan_folder_for_pngs(folder_path)


# Función auxiliar estática para leer los archivos .png
static func _scan_folder_for_pngs(path: String) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and file_name.ends_with(".png"):
				files.append(path + file_name)
			# Soporte para cuando el juego esté exportado (.png.remap)
			elif !dir.current_is_dir() and file_name.ends_with(".png.remap"):
				files.append(path + file_name.trim_suffix(".remap"))
				
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		push_warning("PortraitData: No se pudo acceder a la ruta de assets: " + path)
		
	files.sort() # Mantiene el orden alfabético/numérico (00, 01, 02...)
	return files


func get_layer(layer_name: StringName) -> PortraitLayerData:
	if not layers.has(layer_name):
		layers[layer_name] = PortraitLayerData.new()
	return layers[layer_name] as PortraitLayerData


# Ahora busca en la variable estática autogenerada
static func get_paths_for(layer_name: StringName) -> Array:
	return layer_paths.get(layer_name, [])


func duplicate_portrait() -> PortraitData:
	var copy := PortraitData.new()
	for layer_name: StringName in LAYER_NAMES:
		var src: PortraitLayerData = get_layer(layer_name)
		copy.layers[layer_name] = src.duplicate_layer()
	return copy
