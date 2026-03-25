extends CharacterBody2D

const CATCH_EFFECT = preload("res://catch_effect.tscn") 

enum Item { NONE, NET, FISHING_ROD }

@export var speed: int = 50
var equipped_item = Item.NONE

# --- NOUVELLES VARIABLES POUR L'ACTION ---
var is_busy = false # Bloque les mouvements pendant un coup de filet
var current_butterfly = null # Mémorise l'insecte à portée

@onready var sprite = $Sprite2D 
@onready var hand_anchor = $Sprite2D/HandAnchor
@onready var item_sprite = $Sprite2D/HandAnchor/EquippedItemSprite

const NET_TEXTURE = preload("res://assets/sprites/tools/net_sprite.png")
const FISHING_ROD_TEXTURE = preload("res://assets/sprites/tools/fishing_rod_sprite.png")

@onready var anim_player = $AnimationPlayer

func _input(event):
	# On empêche de changer d'item en plein coup de filet
	if event.is_action_pressed("ui_focus_next") and !is_busy:
		cycle_items()
		
	if event.is_action_pressed("ui_accept") and !is_busy:
		handle_action()

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
	match equipped_item:
		Item.NONE:
			item_sprite.texture = null
		Item.NET:
			item_sprite.texture = NET_TEXTURE
		Item.FISHING_ROD:
			item_sprite.texture = FISHING_ROD_TEXTURE

	var dir_row = sprite.frame_coords.y

	match dir_row:
		0: # FACE
			item_sprite.flip_h = false 
			item_sprite.flip_v = false 
			item_sprite.z_index = 0 
		1: # PROFIL
			item_sprite.flip_h = sprite.flip_h 
			item_sprite.flip_v = false 
			item_sprite.z_index = -1 if sprite.flip_h else 0 
		2: # DOS
			item_sprite.flip_h = true 
			item_sprite.z_index = -1 
	
func _physics_process(_delta: float):
	# --- NOUVEAU : Si on est occupé (animation), on s'arrête net ---
	if is_busy:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if direction != Vector2.ZERO:
		velocity = direction * speed
		update_sprite_direction(direction)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
		# On arrête l'animation de marche si on s'arrête (sans couper les anims d'action)
		if !anim_player.is_playing() or anim_player.current_animation.begins_with("walk"):
			anim_player.stop()

	move_and_slide()

func update_sprite_direction(dir: Vector2):
	update_visuals()
	if dir != Vector2.ZERO:
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
		anim_player.stop()

func handle_action():
	if equipped_item == Item.NONE:
		return

	is_busy = true
	item_sprite.hide()
	var anim_name = ""
	var dir_row = sprite.frame_coords.y
	var shouldFlipAgain = false
	
	match equipped_item:
		Item.NET:
			# On choisit l'anim selon ta disposition
			if dir_row == 0:
				anim_name = "use_net_down"
			elif dir_row == 2:
				anim_name = "use_net_up"
			elif dir_row == 1:
				if sprite.flip_h:
					sprite.flip_h = false
					shouldFlipAgain = true
					anim_name = "use_net_left"
				else:
					anim_name = "use_net_right"
			
			anim_player.play(anim_name)
			
			check_net_capture()

		Item.FISHING_ROD:
			print("Animation de pêche à faire plus tard !")
			is_busy = false # On libère le joueur de suite pour éviter de bloquer
			item_sprite.show()
			return # On sort de la fonction car il n'y a pas d'anim à await

	# 1. On attend que le clip se termine (ATTENTION : l'anim ne doit pas boucler !)
	await anim_player.animation_finished
	
	if shouldFlipAgain:
		sprite.flip_h = true
	# 2. On dit à l'AnimationPlayer de lâcher le contrôle
	if dir_row == 0:
		anim_name = "idle_down"
	elif dir_row == 2:
		anim_name = "idle_up"
	elif dir_row == 1:
		anim_name = "idle_side"
		
	anim_player.play(anim_name)
		
	# 4. On remet tout en place
	item_sprite.show()
	is_busy = false
	
func check_net_capture():
	# On attend 0.2s pour que la capture corresponde au "schlack" visuel du filet sur le sol
	await get_tree().create_timer(0.2).timeout
	
	if current_butterfly:
		print("Insecte capturé !")
		
		var effect = CATCH_EFFECT.instantiate()
		
		effect.global_position = current_butterfly.global_position
		
		get_tree().current_scene.add_child(effect)
		
		# 4. Détruire le papillon
		current_butterfly.queue_free()
		current_butterfly = null

# --- SIGNAUX DE LA ZONE NetArea ---
# (Assure-toi de bien connecter ces signaux depuis l'éditeur Godot vers ce script)
func _on_net_area_area_entered(area):
	if area.is_in_group("insects"):
		current_butterfly = area

func _on_net_area_area_exited(area):
	if area == current_butterfly:
		current_butterfly = null
