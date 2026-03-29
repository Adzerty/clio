extends Area2D

func on_fish_bite(fish_node):
	# On passe le message au parent (le Joueur)
	if get_parent().has_method("on_fish_bite"):
		get_parent().on_fish_bite(fish_node)
