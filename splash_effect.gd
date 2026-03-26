extends CPUParticles2D

func _ready():
	# Dès que la scène apparaît, on lance l'explosion
	emitting = true
	# On attend la fin de l'animation
	await finished
	# On supprime le nœud
	queue_free()
