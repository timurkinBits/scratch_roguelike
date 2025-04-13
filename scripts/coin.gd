extends ObjectRoom
class_name Coin

func _ready() -> void:
	super._ready()
	add_to_group('coins')  # Add to coins group for easy finding
	
func use():
	Global.add_coins(1)  # Add one coin to global counter
	queue_free()  # Remove the coin from the scene
