extends ObjectRoom

@onready var info: Label = $Label

var key: int

func _ready() -> void:
	super._ready()
	add_to_group('info')

func _on_area_2d_mouse_entered() -> void:
	info.text = '12345678'

func _on_area_2d_mouse_exited() -> void:
	info.text = ''
