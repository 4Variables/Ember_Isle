extends Node3D
class_name InteractableItem

@export var ItemHighlightMesh : MeshInstance3D

@export var interact_prompt: String = "Pick up"

func GainFocus():
	ItemHighlightMesh.visible = true

func LoseFocus():
	ItemHighlightMesh.visible = false
