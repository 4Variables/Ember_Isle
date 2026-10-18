extends Resource
class_name ItemData

@export var ItemName : String
@export var Icon : Texture2D

@export var ItemModelPrefab : PackedScene

# Called when the item is used from the inventory. Return true if it leaves the inventory.
func use(_user : Node) -> bool:
	return false
