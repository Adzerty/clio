extends CharacterBody2D

const CATCH_EFFECT = preload("res://catch_effect.tscn") 
const SPLASH_EFFECT = preload("res://splash_effect.tscn") 
const CAST_DISTANCE = 40.0

enum Item { NONE, NET, FISHING_ROD }

@export var speed: int = 50
var equipped_item = Item.NONE

# --- NOUVELLES VARIABLES POUR L'ACTION ---
var is_busy = false # Bloque les mouvements pendant un coup de filet
var is_fishing = false
var current_butterfly = null # Mémorise l'insecte à portée
var last_dir_row = 0

@onready var sprite = $Sprite2D 
@onready var hand_anchor = $Sprite2D/HandAnchor
@onready var item_sprite = $Sprite2D/HandAnchor/EquippedItemSprite

@onready var water_detector = $WaterDetector
@onready var hook = $Hook
@onready var fishing_line = $Hook/FishingLine
@onready var rod_tip = $Sprite2D/HandAnchor/EquippedItemSprite/RodTip

const NET_TEXTURE = preload("res://assets/sprites/tools/net_sprite.png")
const FISHING_ROD_TEXTURE = preload("res://assets/sprites/tools/fishing_rod_sprite.png")

@onready var anim_player = $AnimationPlayer

func _ready():
	# On cache l'hameçon et le fil au démarrage
	hook.hide()
	fishing_line.hide()
	# Le fil ne doit pas bouger avec le joueur une fois lancé (très important !)
	#fishing_line.top_level = true 
	#hook.top_level = true
	
func _input(event):
	# On empêche de changer d'item en plein coup de filet
	if event.is_action_pressed("ui_focus_next") and !is_busy:
		cycle_items()
		
	if event.is_action_pressed("ui_accept") and (!is_busy || is_fishing):
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
	if is_busy or is_fishing:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var last_direction = direction
	
	if direction != Vector2.ZERO:
		velocity = direction * speed
		
		# --- NOUVEAU : On oriente le "laser" vers là où on regarde ---
		# Multiplie par la portée de ta canne (ex: 24 pixels)
		water_detector.target_position = last_direction * 20
		
		update_sprite_direction(direction)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
		# On arrête l'animation de marche si on s'arrête (sans couper les anims d'action)
		if !anim_player.is_playing() or anim_player.current_animation.begins_with("walk"):
			anim_player.stop()

	move_and_slide()

# --- DESSINER LE FIL DE PÊCHE EN TEMPS RÉEL ---
func _process(_delta):
	if is_fishing:
		# On met à jour avec to_local()
		fishing_line.set_point_position(0, fishing_line.to_local(rod_tip.global_position))
		fishing_line.set_point_position(1, fishing_line.to_local(hook.global_position))
		# On ajoute un petit décalage sinusoïdal à l'hameçon pour simuler le courant
		var wobble = sin(Time.get_ticks_msec() * 0.005) * 2.0
		hook.position.y += wobble * _delta # Ça va le faire osciller doucement
		
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
	item_sprite.hide()
	var tool_name = ""
	var dir_row = sprite.frame_coords.y % 3
	
	match equipped_item:
		Item.NET:
			tool_name = "net"
		Item.FISHING_ROD:
			tool_name = "fishing"
	
	if tool_name != "":
		match equipped_item:
			Item.NET:
				check_net_capture()
			Item.FISHING_ROD:
				if is_fishing:
					stop_fishing()
				else:
					start_fishing()

	
func start_anim_tool(tool_name):
	var anim_name = ""
	var shouldFlipAgain = false

	if last_dir_row == 0:
		anim_name = "use_"+tool_name+"_down"
	elif last_dir_row == 2:
		anim_name = "use_"+tool_name+"_up"
	elif last_dir_row % 3 == 1:
		if last_dir_row == 4:
			sprite.flip_h = false
			anim_name = "use_"+tool_name+"_left"
		else:
			anim_name = "use_"+tool_name+"_right"
	anim_player.play(anim_name)

	
func stop_anim_tool():
	var anim_name = ""
	#var shouldFlipAgain = false

	# On dit à l'AnimationPlayer de lâcher le contrôle
	if last_dir_row == 0:
		anim_name = "idle_down"
	elif last_dir_row == 2:
		anim_name = "idle_up"
	elif last_dir_row % 3 == 1:
		anim_name = "idle_side"
		if(last_dir_row == 4):
			sprite.flip_h = true
		
	anim_player.play(anim_name)
	
	# On raffiche le sprite du tool
	item_sprite.show()
	
func set_last_dir_row():
	last_dir_row = sprite.frame_coords.y + (3 if sprite.flip_h else 0)
	
func check_net_capture():
	is_busy = true

	set_last_dir_row()
	start_anim_tool("net")
	# On attend 0.2s pour que la capture corresponde au "schlack" visuel du filet sur le sol
	await get_tree().create_timer(0.4).timeout
	
	if current_butterfly:
		
		print("Insecte capturé !")
		
		var effect = CATCH_EFFECT.instantiate()
		
		effect.global_position = current_butterfly.global_position
		
		get_tree().current_scene.add_child(effect)
		
		# 4. Détruire le papillon
		current_butterfly.queue_free()
		current_butterfly = null
		
	stop_anim_tool()
	is_busy = false

		
func start_fishing():
	is_busy = true
	set_last_dir_row()
	
	# 1. On oriente le laser un peu plus loin que la portée pour être sûr de détecter l'eau
	water_detector.target_position = water_direction() * (CAST_DISTANCE)
	water_detector.force_raycast_update() # On force l'update pour le check immédiat
	
	start_anim_tool("fishing")
	await get_tree().create_timer(0.4).timeout
	
	# 2. On vérifie s'il y a de l'eau n'importe où sur la trajectoire
	if water_detector.is_colliding():
		is_fishing = true
		# CALCUL MAGIQUE : Position du joueur + (Direction * Distance Fixe)
		# On utilise global_position du joueur comme point de départ
		hook.global_position = global_position + (water_direction() * CAST_DISTANCE)
		hook.show()
		
		var effect = SPLASH_EFFECT.instantiate()
		effect.global_position = hook.global_position
		get_tree().current_scene.add_child(effect)
		
		# On initialise la ligne
		fishing_line.clear_points()
		fishing_line.add_point(fishing_line.to_local(rod_tip.global_position))
		fishing_line.add_point(fishing_line.to_local(hook.global_position))
		fishing_line.show()
	else:
		print("Trop loin de l'eau ou pas d'eau du tout !")
		stop_fishing()

# Petite fonction utilitaire pour récupérer le vecteur de direction propre
func water_direction() -> Vector2:
	# On se base sur ton last_dir_row pour recréer un vecteur propre
	if last_dir_row == 0: return Vector2.DOWN
	if last_dir_row == 2: return Vector2.UP
	if last_dir_row % 3 == 1:
		return Vector2.LEFT if last_dir_row == 4 else Vector2.RIGHT
	return Vector2.ZERO
	
func stop_fishing():
	print("Pêche terminée.")
	hook.hide()
	fishing_line.hide()
	is_fishing = false
	is_busy = false
	stop_anim_tool()

# --- SIGNAUX DE LA ZONE NetArea ---
# (Assure-toi de bien connecter ces signaux depuis l'éditeur Godot vers ce script)
func _on_net_area_area_entered(area):
	if area.is_in_group("insects"):
		current_butterfly = area

func _on_net_area_area_exited(area):
	if area == current_butterfly:
		current_butterfly = null
