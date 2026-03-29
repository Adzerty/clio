extends CPUParticles2D

# Le composant gère ses propres ressources (encapsulation)
const ICON_QUESTION = preload("res://assets/emotes/interrogation_emote.png")
const ICON_EXCLAMATION = preload("res://assets/emotes/exclamation_emote.png")
const ICON_BORED = preload("res://assets/emotes/bored_emote.png")

func interrogate():
	texture = ICON_QUESTION
	restart() # Relance l'émission de la particule depuis le début

func exclam():
	texture = ICON_EXCLAMATION
	restart()
	
func bored():
	texture = ICON_BORED
	restart()
