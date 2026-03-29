extends CharacterBody2D

enum State { IDLE, SWIM, NOTICED, CHASE, BITING }
var current_state = State.IDLE

@export var swim_speed: float = 12.0
@export var chase_speed: float = 30.0
@export var notice_duration: float = 1.0

var swim_direction: Vector2 = Vector2.ZERO
var target_hook = null

@onready var sprite = $Sprite2D
@onready var vision_anchor = $VisionAnchor
@onready var emote_particles = $EmoteParticles

func _ready():
	add_to_group("fishes")
	vision_anchor.rotation = 0.0
	choose_next_action()

func choose_next_action():
	# Si le poisson est occupé (chasse, morsure, etc.), on stoppe la boucle de flânerie
	if current_state != State.IDLE and current_state != State.SWIM:
		return

	if randf() < 0.55:
		current_state = State.IDLE
		await get_tree().create_timer(randf_range(1.0, 3.0)).timeout
	else:
		current_state = State.SWIM
		swim_direction = Vector2.from_angle(randf_range(0, TAU))
		await get_tree().create_timer(randf_range(3.0, 6.0)).timeout
		
	# On rappelle la fonction UNIQUEMENT si on est toujours en train de flâner
	# (Si l'hameçon l'a distrait pendant le timer, on ne relance pas le wandering)
	if current_state == State.IDLE or current_state == State.SWIM:
		choose_next_action()
		
func _physics_process(delta):
	match current_state:
		State.IDLE, State.NOTICED, State.BITING:
			# Pas de mouvement dans ces états
			velocity = Vector2.ZERO
		State.SWIM:
			velocity = swim_direction * swim_speed
			var collision = move_and_collide(velocity * delta)
			if collision:
				swim_direction = swim_direction.bounce(collision.get_normal())
		State.CHASE:
			if target_hook and target_hook.visible: # On vérifie si l'hameçon est toujours là
				var dist = global_position.distance_to(target_hook.global_position)
				
				# 1. SI ON EST ASSEZ PRÈS : On arrête de bouger et on "mord"
				if dist < 5.0:
					_start_biting_sequence()
				else:
					# 2. SINON : On continue la poursuite (même si c'est hors du cône !)
					var dir_to_hook = (target_hook.global_position - global_position).normalized()
					velocity = dir_to_hook * chase_speed
					move_and_slide()
					swim_direction = velocity
			else:
				# L'hameçon a disparu (le joueur a remonté la ligne)
				_return_to_wandering()

	handle_sprite_orientation(delta)
	
# Petite fonction dédiée pour gérer le visuel
func handle_sprite_orientation(delta):
	# On s'assure qu'il y a un mouvement horizontal
	if abs(swim_direction.x) > 0.01:
		# SOLUTION 2 (MIEUX) : La Rotation Douce
		# Pour du pixel art, on préfère souvent une rotation subtile
		# que de flipper le sprite brutalement.
		var target_rotation = 0.0
		if swim_direction.x < 0:
			# Il regarde vers la droite
			sprite.flip_h = true # Ajuste selon ton dessin de base
			# Petite inclinaison vers le haut ou le bas pour le "style"
			target_rotation = deg_to_rad(10.0 if swim_direction.y > 0 else -10.0)
			vision_anchor.scale.x = -1.0 # Flip horizontal
		else:
			# Il regarde vers la gauche
			sprite.flip_h = false
			target_rotation = deg_to_rad(-10.0 if swim_direction.y > 0 else 10.0)
			vision_anchor.scale.x = 1.0 # Standard

			
		# On "lerp" la rotation pour un effet de demi-tour fluide
		sprite.rotation = lerp_angle(sprite.rotation, target_rotation, 5.0 * delta)
		vision_anchor.rotation = sprite.rotation # La vision suit l'inclinaison


func _on_vision_cone_area_entered(area):
	# On ne déclenche la chasse QUE si on est en train de flâner
	if area.is_in_group("hooks") and (current_state == State.SWIM or current_state == State.IDLE):
		target_hook = area
		current_state = State.NOTICED
		
		emote_particles.interrogate()
		
		await get_tree().create_timer(notice_duration).timeout
		
		if target_hook and target_hook.visible:
			current_state = State.CHASE 
		else:
			_return_to_wandering()

func _on_vision_cone_area_exited(area):
	pass

func _return_to_wandering():
	target_hook = null
	current_state = State.IDLE
	emote_particles.bored()
	choose_next_action()

func _start_biting_sequence():
	if current_state == State.BITING: return
	
	current_state = State.BITING
	
	# Appel de la méthode du composant
	emote_particles.exclam()
	
	# On prévient l'hameçon qu'il a été mordu
	if target_hook.has_method("on_fish_bite"):
		target_hook.on_fish_bite(self)

func escape():
	if current_state == State.BITING:
		# On le fait repartir à ses occupations (ou tu pourrais le faire nager très vite !)
		_return_to_wandering()
