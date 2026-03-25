extends Area2D

@export var speed: float = 40.0
@export var butterfly_texture: Texture2D

var direction: Vector2 = Vector2.ZERO
var target_direction: Vector2 = Vector2.ZERO

@onready var sprite = $Sprite2D
@onready var shadow = $Shadow # Idéalement, mets l'ombre en enfant direct de l'Area2D, pas du Sprite

# Variables pour le vol
var vertical_offset: float = 0.0
var target_vertical_offset: float = 0.0

func _ready():
	if butterfly_texture:
		sprite.texture = butterfly_texture
	_pick_new_direction()
	_pick_new_altitude()

func _process(delta):
	# 1. Déplacement horizontal (X, Y global)
	direction = direction.lerp(target_direction, 2.0 * delta)
	position += direction * speed * delta

	# 2. Simulation de l'altitude (Mouvement du Sprite uniquement)
	# On interpole la position Y du sprite pour un effet fluide
	vertical_offset = lerp(vertical_offset, target_vertical_offset, 1.0 * delta)
	sprite.position.y = vertical_offset

	# 3. Effet visuel sur l'ombre (Optionnel mais top)
	# Plus l'insecte est haut (vertical_offset négatif), plus l'ombre est petite
	var shadow_scale = clamp(1.0 - (abs(vertical_offset) / 40.0), 0.2, 6.0)
	shadow.scale = Vector2(shadow_scale, shadow_scale)
	# On s'assure que l'ombre reste au "sol" (y=0) même si le sprite monte
	shadow.position.y = -vertical_offset 

func _pick_new_direction():
	var angle = randf_range(0, TAU)
	target_direction = Vector2.from_angle(angle)
	
	await get_tree().create_timer(randf_range(0.5, 1.5)).timeout
	_pick_new_direction()

func _pick_new_altitude():
	# On choisit une "hauteur" aléatoire (valeur négative car Y haut = négatif)
	target_vertical_offset = randf_range(-5.0, -20.0)
	
	# On change d'altitude toutes les 2 à 4 secondes
	await get_tree().create_timer(randf_range(2.0, 4.0)).timeout
	_pick_new_altitude()
