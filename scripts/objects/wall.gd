extends ObjectRoom
class_name Wall

func _ready() -> void:
	super._ready()
	add_to_group("barrier")
	add_to_group('walls')
