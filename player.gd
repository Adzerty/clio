extends CharacterBody2D

enum Item { NONE, NET, FISHING_ROD }

@export var speed: int = 150
var equipped_item = Item.NONE

# @onready permet de récupérer le nœud Sprite2D au lancement du jeu
# C'est l'équivalent d'un querySelector() ou d'un useRef()
@onready var sprite = $Sprite2D 
@onready var hand_anchor = $Sprite2D/HandAnchor
@onready var item_sprite = $Sprite2D/HandAnchor/EquippedItemSprite

const NET_TEXTURE = preload("res://assets/sprites/tools/net_sprite.png")
const FISHING_ROD_TEXTURE = preload("res://assets/sprites/tools/fishing_rod_sprite.png")

@onready var anim_player = $AnimationPlayer

func _input(event):
	# On simule l'équipement avec les touches 1, 2, 3 du clavier
	if event.is_action_pressed("ui_focus_next"): # Touche Tab par défaut
		cycle_items()
		
func cycle_items():
	if equipped_item == Item.NONE:
		equipped_item = Item.NET
		print("Filet équipé !")
	elif equipped_item == Item.NET:
		equipped_item = Item.FISHING_ROD
		print("Canne à pêche équipée.")
	elif equipped_item == Item.FISHING_ROD:
		equipped_item = Item.NONE
		print("Mains nues.")
	
	update_visuals()

func update_visuals():
	# On applique la texture selon l'item
	match equipped_item:
		Item.NONE:
			item_sprite.texture = null # On cache l'objet
		Item.NET:
			item_sprite.texture = NET_TEXTURE
		Item.FISHING_ROD:
			item_sprite.texture = FISHING_ROD_TEXTURE

	# 1. On récupère la frame de direction actuelle (0=Face, 1=Dos, 2=Profil)
	var dir_row = sprite.frame_coords.y

	# 2. On gère la perspective du filet selon la direction du corps
	match dir_row:
		0: # FACE
			# Le filet est devant le corps, pointant vers le bas-droite
			item_sprite.flip_h = false # Pose standard
			item_sprite.flip_v = false # On le pointe vers le haut
			item_sprite.z_index = 0 # Devant le sprite du corps
		1: # PROFIL
			# Le filet suit le profil
			# Si le corps est flippé (vers la gauche), le filet l'est aussi
			item_sprite.flip_h = sprite.flip_h 
			item_sprite.flip_v = false # On le remet à plat
			item_sprite.z_index = -1 if sprite.flip_h else 0 # Toujours devant
		2: # DOS
			# Le filet est derrière le corps, pointant vers le haut-gauche
			# Astuce : On flip verticalement pour qu'il pointe vers le haut
			item_sprite.flip_h = true # On reste dans l'axe
			item_sprite.z_index = -1 # Derrière le sprite du corps
	
func _physics_process(_delta: float):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if direction != Vector2.ZERO:
		velocity = direction * speed
		update_sprite_direction(direction)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)

	move_and_slide()


func update_sprite_direction(dir: Vector2):
	update_visuals()
	if dir != Vector2.ZERO:
		# On choisit l'animation selon la direction dominante
		if abs(dir.x) > abs(dir.y):
			anim_player.play("walk_side")
			sprite.flip_h = (dir.x < 0)
		else:
			sprite.flip_h = false
			if dir.y > 0:
				anim_player.play("walk_down")
			else:
				anim_player.play("walk_up")
	else:
		# Si on ne bouge plus, on arrête l'anim et on revient sur la frame IDLE
		anim_player.stop()
		# Optionnel : forcer la frame neutre selon la dernière direction
		# Pour l'instant, un simple stop() suffira.
