extends ObjectRoom

@onready var closed_sprite: Sprite2D = $ClosedSprite
@onready var opened_sprite: Sprite2D = $OpenedSprite

var is_opened: bool = false
var degree: int = 0

func _ready() -> void:
	super._ready()
	add_to_group('doors')
	add_to_group('barrier')
	
func use() -> void:
	is_opened = !is_opened
	toggle_door(is_opened)

func toggle_door(is_door_opened: bool):
	if (is_door_opened and !is_opened) or (!is_door_opened and is_opened):
		is_opened = is_door_opened
	opened_sprite.visible = is_door_opened
	closed_sprite.visible = !is_door_opened
	
	if is_door_opened:
		remove_from_group('barrier')
	else:
		add_to_group('barrier')
	
# Упрощенный метод установки поворота
func set_rotation_degree(rot_degree: int) -> void:
	degree = rot_degree
	rotation_degrees = rot_degree
	
