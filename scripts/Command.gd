extends Node2D
class_name Command

enum TypeCommand { NONE, TURN_LEFT, TURN_RIGHT, TURN_AROUND, ATTACK, MOVE, HEAL, DEFENSE }

@export var type: TypeCommand
var value: int = 0
var target_required: bool = false
var direction: Vector2 = Vector2(0, 0)
var chances: Array[int] = [0, 2, 2, 2, 6, 7, 1, 1]
var is_menu_command: bool = false
var is_settings: bool = false
var slot: CommandSlot
var block: Block
var previous_value: int = 0  # Для отслеживания предыдущего значения при изменении

signal menu_command_clicked(type: int)

@onready var text_label: Label = $Texture/TextLabel
@onready var num_label: Label = $Texture/NumLabel
@onready var up_button: Button = $Texture/Up
@onready var down_button: Button = $Texture/Down
@onready var ui_node: UI = $'../../../UI'
const MAX_LENGTH := 5

func _ready() -> void:
	num_label.visible = false
	change_settings(false)
	
	add_to_group("commands")
	
	if get_parent().name == "CommandMenu":
		is_menu_command = true  # Устанавливаем для команд в меню
	if chances.size() < TypeCommand.size():
		chances.resize(TypeCommand.size())
		for i in range(1, TypeCommand.size()):
			chances[i] = 1 if i < chances.size() else 1
	update_appearance()
	
func update_appearance() -> void:
	modulate = get_color()
	if type not in [TypeCommand.TURN_LEFT, TypeCommand.TURN_RIGHT, TypeCommand.TURN_AROUND] and not is_menu_command:
		text_label.text = get_prefix()
		num_label.visible = true
		set_number(value)
	else:
		text_label.text = get_prefix()
	
	# Обновляем доступность кнопок в зависимости от оставшихся очков
	if is_settings and !is_menu_command:
		for command in get_tree().get_nodes_in_group("commands"):
			command.update_buttons_state()

func set_number(new_value):
	# First release points from current value
	if !is_menu_command and value > 0:
		Global.release_points(type, value)
	
	# Get maximum available points
	var max_available = Global.get_remaining_points(type)
	
	# For non-menu commands, add back the current value since we just released it
	if !is_menu_command:
		max_available += value
		
	# Strictly clamp the value
	var clamped_value = min(new_value, max_available)
	clamped_value = max(1, clamped_value)
	
	# Set the new value and use points
	value = clamped_value
	if !is_menu_command:
		Global.use_points(type, value)
	
	# Update text
	num_label.text = str(value).substr(0, MAX_LENGTH)
	
	# Update button states
	if is_settings:
		for command in get_tree().get_nodes_in_group("commands"):
			command.update_buttons_state()

func update_buttons_state() -> void:
	if type in [TypeCommand.ATTACK, TypeCommand.MOVE, TypeCommand.HEAL, TypeCommand.DEFENSE]:
		var remaining = Global.get_remaining_points(type)
		up_button.disabled = (value >= remaining + value) or (value >= get_max_points())
		down_button.disabled = (value <= 1)

func get_max_points() -> int:
	match type:
		TypeCommand.ATTACK: return Global.points[Command.TypeCommand.ATTACK]
		TypeCommand.MOVE: return Global.points[Command.TypeCommand.MOVE]
		TypeCommand.HEAL: return Global.points[Command.TypeCommand.HEAL]
		TypeCommand.DEFENSE: return Global.points[Command.TypeCommand.DEFENSE]
		_: return 0
	
func get_prefix() -> String:
	match type:
		TypeCommand.ATTACK: return "Атака "
		TypeCommand.MOVE: return "Перейти "
		TypeCommand.TURN_LEFT: return "Налево "
		TypeCommand.TURN_RIGHT: return "Направо "
		TypeCommand.TURN_AROUND: return "Разворот "
		TypeCommand.HEAL: return "Лечение "
		TypeCommand.DEFENSE: return "Защита "
		_: return "none "

func get_color() -> Color:
	match type:
		TypeCommand.ATTACK: return Color.RED
		TypeCommand.MOVE: return Color.BLUE
		TypeCommand.TURN_LEFT: return Color.LIGHT_BLUE
		TypeCommand.TURN_RIGHT: return Color.LIGHT_BLUE
		TypeCommand.TURN_AROUND: return Color.LIGHT_BLUE
		TypeCommand.HEAL: return Color.GREEN
		TypeCommand.DEFENSE: return Color.SILVER
		_: return Color.WHITE
		
func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_menu_command:
				menu_command_clicked.emit(type)
				
			else:
				is_settings = false
				change_settings(is_settings)
		elif event.button_index == MOUSE_BUTTON_RIGHT and !is_menu_command and event.pressed:
			queue_free()

func _on_up_pressed() -> void:
	var remaining = Global.get_remaining_points(type) + value
	var max_points = get_max_points()
	var new_value = min(value + 1, remaining, max_points)
	if new_value > value:
		set_number(new_value)
	for command in get_tree().get_nodes_in_group("commands"):
		command.update_buttons_state()

func _on_down_pressed() -> void:
	if value > 1:
		set_number(value - 1)
	for command in get_tree().get_nodes_in_group("commands"):
		command.update_buttons_state()

func _exit_tree() -> void:
	# Сохраняем ссылку на слот и блок перед удалением
	var parent_block = null
	if slot and is_instance_valid(slot):
		parent_block = slot.block
		slot.command = null  # Очищаем ссылку на эту команду в слоте
	
	# Возвращаем очки в общий пул
	if !is_menu_command and value > 0:
		Global.release_points(type, value)
	
	# Обновляем блок после всех изменений
	if parent_block and is_instance_valid(parent_block):
		parent_block.call_deferred("update_slots")

func _on_num_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_menu_command:
			# Открываем настройки при клике на область числа
			is_settings = !is_settings
			change_settings(is_settings)
			for command in get_tree().get_nodes_in_group("commands"):
				command.update_buttons_state()
			
func change_settings(is_settings: bool):
	up_button.visible = is_settings
	down_button.visible = is_settings
