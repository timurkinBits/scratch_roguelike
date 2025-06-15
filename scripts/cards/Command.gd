extends Card
class_name Command

enum TypeCommand { NONE, TURN, ATTACK, MOVE, USE, HEAL, DEFENSE }

@export var type: TypeCommand = TypeCommand.NONE
var value: int = 0
var is_settings: bool = false
var block: Block
var additional_properties: String = ""

signal menu_card_clicked(type: int)

@onready var sprite: ColorRect = $'Texture/Sprite'
@onready var icon: TextureRect = $Icon
@onready var text_label: Label = $Texture/TextLabel
@onready var num_label: Label = $Texture/NumLabel
@onready var up_button: Button = $Texture/Up
@onready var down_button: Button = $Texture/Down
@onready var ui_node: UI = $'../../../UI'

# Command configurations
var configs = {
	TypeCommand.ATTACK: {
		"prefix": "Атака ",
		"color": Color.RED,
		"icon": "res://sprites/attack.png"
	},
	TypeCommand.MOVE: {
		"prefix": "Перейти ",
		"color": Color.BLUE,
		"icon": "res://sprites/move.png"
	},
	TypeCommand.TURN: {
		"prefix": "Поворот ",
		"color": Color.LIGHT_BLUE,
		"icon": "res://sprites/turn.png",
		"values": [90, -90, 180]
	},
	TypeCommand.USE: {
		"prefix": "Использовать ",
		"color": Color.BLUE_VIOLET,
		"icon": "res://sprites/use.png"
	},
	TypeCommand.HEAL: {
		"prefix": "Лечение ",
		"color": Color.GREEN,
		"icon": "res://sprites/heal.png"
	},
	TypeCommand.DEFENSE: {
		"prefix": "Защита ",
		"color": Color.SILVER,
		"icon": "res://sprites/defense.png"
	},
	TypeCommand.NONE: {
		"prefix": "none ",
		"color": Color.WHITE,
		"icon": ""
	}
}

func _ready() -> void:
	super._ready()
	add_to_group("commands")
	
	_setup_menu_card()
	_initialize_turn_value()
	update_appearance()

func _setup_menu_card() -> void:
	if get_parent().name == "CommandMenu":
		is_menu_card = true

func _initialize_turn_value() -> void:
	if type == TypeCommand.TURN and value == 0:
		value = configs[type]["values"][0]

func update_appearance() -> void:
	var config = _get_config()
	
	sprite.color = config["color"]
	text_label.text = config["prefix"]
	icon.texture = load(config["icon"]) if config["icon"] else null
	
	_update_number_display()
	
	if is_settings:
		_update_all_buttons()

func _get_config() -> Dictionary:
	return configs.get(type, configs[TypeCommand.NONE])

func _update_number_display() -> void:
	if is_menu_card:
		num_label.visible = false
		return
	
	var should_show_number = type in [TypeCommand.TURN, TypeCommand.ATTACK, 
									  TypeCommand.MOVE, TypeCommand.HEAL, TypeCommand.DEFENSE]
	
	if should_show_number:
		num_label.text = str(value)
		num_label.visible = true
	else:
		num_label.visible = false

func get_size() -> Vector2:
	return $Texture.size

func set_number(new_value: int) -> void:
	if type == TypeCommand.TURN:
		_handle_turn_value_change(new_value)
		return
	
	_handle_standard_value_change(new_value)

func _handle_turn_value_change(new_value: int) -> void:
	var values = configs[type]["values"]
	var current_index = values.find(value)
	var new_index: int
	
	if new_value > value:
		new_index = (current_index + 1) % values.size()
	else:
		new_index = (current_index - 1 + values.size()) % values.size()
	
	value = values[new_index]
	num_label.text = str(value)

func _handle_standard_value_change(new_value: int) -> void:
	# Release current points
	if not is_menu_card and value > 0:
		Global.release_points(type, value)
	
	# Calculate available points
	var max_available = Global.get_remaining_points(type)
	if not is_menu_card:
		max_available += value
	
	# Set new value within limits
	value = clamp(new_value, 1, min(max_available, _get_max_points()))
	
	# Use new points
	if not is_menu_card:
		Global.use_points(type, value)
		if ui_node and is_instance_valid(ui_node):
			ui_node.change_scores(type)
	
	num_label.text = str(value)
	
	if is_settings:
		_update_all_buttons()

func _get_max_points() -> int:
	match type:
		TypeCommand.ATTACK: return Global.points[TypeCommand.ATTACK]
		TypeCommand.MOVE: return Global.points[TypeCommand.MOVE]
		TypeCommand.HEAL: return Global.points[TypeCommand.HEAL]
		TypeCommand.DEFENSE: return Global.points[TypeCommand.DEFENSE]
		_: return 0

func _update_all_buttons() -> void:
	for command in get_tree().get_nodes_in_group("commands"):
		command.update_buttons_state()

func update_buttons_state() -> void:
	if type not in [TypeCommand.ATTACK, TypeCommand.MOVE, TypeCommand.HEAL, TypeCommand.DEFENSE]:
		return
	
	var remaining = Global.get_remaining_points(type)
	up_button.disabled = (value >= remaining + value) or (value >= _get_max_points())
	down_button.disabled = (value <= 1)

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	super._on_area_input_event(viewport, event, shape_idx)
	
	if not event is InputEventMouseButton or not event.pressed:
		return
	
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			_handle_left_click()
		MOUSE_BUTTON_RIGHT:
			_handle_right_click()

func _handle_left_click() -> void:
	if is_menu_card:
		menu_card_clicked.emit(type)
	else:
		is_settings = false
		change_settings(is_settings)

func _handle_right_click() -> void:
	if not is_menu_card and not table.is_turn_in_progress:
		Global.release_points(type, value)
		queue_free()

func _on_up_pressed() -> void:
	if type == TypeCommand.TURN:
		set_number(value + 1)
		return
	
	var new_value = min(value + 1, Global.get_remaining_points(type) + value, _get_max_points())
	if new_value > value:
		set_number(new_value)
	_update_all_buttons()

func _on_down_pressed() -> void:
	if type == TypeCommand.TURN:
		set_number(value - 1)
		return
	
	if value > 1:
		set_number(value - 1)
	_update_all_buttons()

func _on_num_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and 
		event.pressed and not is_menu_card and not table.is_turn_in_progress):
		is_settings = not is_settings
		change_settings(is_settings)
		_update_all_buttons()

func change_settings(settings: bool) -> void:
	up_button.visible = settings
	down_button.visible = settings

func _exit_tree() -> void:
	# Clean up slot reference
	if slot and is_instance_valid(slot):
		var parent_block = slot.block
		slot.command = null
		
		if parent_block and is_instance_valid(parent_block):
			parent_block.update_slots()
