extends Area2D

@export var speed: float = 40.0
var direction: Vector2 = Vector2.ZERO
var target_direction: Vector2 = Vector2.ZERO
@export var butterfly_texture: Texture2D


func _ready():
	# On prend une texture
	if butterfly_texture:
		$Sprite2D.texture = butterfly_texture
	# On initialise une direction au hasard
	_pick_new_direction()

func _process(delta):
	# Interpolation douce vers la nouvelle direction (Lerp)
	# C'est l'équivalent d'un transition: all 0.5s en CSS
	direction = direction.lerp(target_direction, 2.0 * delta)
	
	# Déplacement
	position += direction * speed * delta
	
	# Si le papillon sort trop loin, on le force à changer de direction
	# (On pourra affiner ça avec les limites de ta map plus tard)

func _pick_new_direction():
	# Angle aléatoire
	var angle = randf_range(0, TAU) # TAU = 2*PI
	target_direction = Vector2.from_angle(angle)
	
	# On rappelle cette fonction dans 0.5 à 1.5 secondes (aléatoire)
	await get_tree().create_timer(randf_range(0.5, 1.5)).timeout
	_pick_new_direction()
