extends Camera2D

# Velocidad a la que se mueve la cámara
var camera_speed: float = 400.0

func _process(delta):
	# Creamos un vector vacío para calcular la dirección
	var direction = Vector2.ZERO
	
	# Godot ya tiene estas acciones (ui_right, ui_left, etc.) mapeadas por defecto
	# a las flechas del teclado y al pad direccional.
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1
		
	# Normalizamos para que no se mueva más rápido en diagonal
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		
	# Movemos la cámara sumando la dirección por la velocidad
	position += direction * camera_speed * delta
