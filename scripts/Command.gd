extends Node2D
class_name Command

enum TypeCommand { NONE, TURN, ATTACK, MOVE, USE, HEAL, DEFENSE }

@export var type: TypeCommand
var value: int = 0
var chances: Array[int] = [0, 6, 6, 7, 1, 1]
var is_menu_command: bool = false
var is_settings: bool = false
var slot: CommandSlot
var block: Block
var additional_properties: String
var config: Dictionary  # Кэшированная конфигурация для типа команды

signal menu_card_clicked(type: int)

@onready var sprite: ColorRect = $'Texture/Sprite'
@onready var icon: TextureRect = $Icon
@onready var text_label: Label = $Texture/TextLabel
@onready var num_label: Label = $Texture/NumLabel
@onready var up_button: Button = $Texture/Up
@onready var down_button: Button = $Texture/Down
@onready var ui_node: UI = $'../../../UI'
@onready var table: Table = get_parent().get_parent()

var command_configs = {
	TypeCommand.ATTACK: {
		"prefix": "Атака ",
		"color": Color.RED,
		"icon": "res://sprites/fb663.png"
	},
	TypeCommand.MOVE: {
		"prefix": "Перейти ",
		"color": Color.BLUE,
		"icon": "res://sprites/fb658.png"
	},
	TypeCommand.TURN: {
		"prefix": "Поворот ",
		"color": Color.LIGHT_BLUE,
		"icon": "res://sprites/fb647.png",
		"values": [90, -90, 180]  # Значения углов: вправо, влево, разворот
	},
	TypeCommand.USE: {
		"prefix": "Использовать ",
		"color": Color.BLUE_VIOLET,
		"icon": "res://sprites/fb658.png"
	},
	TypeCommand.HEAL: {
		"prefix": "Лечение ",
		"color": Color.GREEN,
		"icon": "res://sprites/fb615.png"
	},
	TypeCommand.DEFENSE: {
		"prefix": "Защита ",
		"color": Color.SILVER,
		"icon": "res://sprites/fb613.png"
	},
	TypeCommand.NONE: {
		"prefix": "none ",
		"color": Color.WHITE,
		"icon": ""
	}
}

func _ready() -> void:
	# Убедимся, что тип команды существует в конфигурации
	if type in command_configs:
		config = command_configs[type]
	else:
		# Если тип не найден, используем конфигурацию для NONE
		config = command_configs[TypeCommand.NONE]
	
	# Инициализация значений углов для команды поворота
	if type == TypeCommand.TURN:
		if value == 0:  # Если значение не установлено, используем первый угол по умолчанию
			value = config["values"][0]
			
	num_label.visible = false
	
	add_to_group("commands")
	
	if get_parent().name == "CommandMenu":
		is_menu_command = true  # Устанавливаем для команд в меню
	if chances.size() < TypeCommand.size():
		chances.resize(TypeCommand.size())
		for i in range(1, TypeCommand.size()):
			chances[i] = 1 if i < chances.size() else 1
	update_appearance()
	
func update_appearance() -> void:
	sprite.color = config["color"]
	
	if !is_menu_command:
		if type == TypeCommand.TURN:
			num_label.text = str(value)
			num_label.visible = true
		elif type in [TypeCommand.ATTACK, TypeCommand.MOVE, TypeCommand.HEAL, TypeCommand.DEFENSE]:
			set_number(value)
			num_label.visible = true

	text_label.text = config["prefix"]
	icon.texture = load(config["icon"])
	
	# Обновляем доступность кнопок в зависимости от оставшихся очков
	if is_settings:
		update_all_buttons()

func update_all_buttons():
	for command in get_tree().get_nodes_in_group("commands"):
		command.update_buttons_state()
			
func set_number(new_value):
	if type == TypeCommand.TURN:
		# Для поворота обрабатываем значения углов
		var values = config["values"]
		var current_index = values.find(value)
		var new_index
		
		if new_value > value:  # Кнопка вверх
			new_index = (current_index + 1) % values.size()
		else:  # Кнопка вниз
			new_index = (current_index - 1 + values.size()) % values.size()
			
		value = values[new_index]
		num_label.text = str(value)
		return
		
	# Для остальных типов команд - стандартная логика
	# Освобождаем очки текущего значения
	
	if !is_menu_command and value > 0:
		Global.release_points(type, value)
	
	# Получаем максимальное количество доступных очков
	
	var max_available = Global.get_remaining_points(type)
	
	# Для не-меню команд добавляем обратно текущее значение, так как мы его только что освободили
	if !is_menu_command:
		max_available += value
		
	# Ограничиваем значение
	var clamped_value = min(new_value, max_available)
	clamped_value = max(1, clamped_value)
	
	# Устанавливаем новое значение и используем очки
	value = clamped_value
	if !is_menu_command:
		Global.use_points(type, value)
		# Обновляем UI с актуальными оставшимися очками
		if ui_node and is_instance_valid(ui_node):
			ui_node.change_scores(type)
	
	# Обновляем текст
	num_label.text = str(value)
	
	# Обновляем состояние кнопок
	if is_settings:
		update_all_buttons()

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

func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_menu_command:
				menu_card_clicked.emit(type)
			else:
				is_settings = false
				change_settings(is_settings)
		elif event.button_index == MOUSE_BUTTON_RIGHT and !is_menu_command and event.pressed:
			Global.release_points(type, value)
			queue_free()

func _on_up_pressed() -> void:
	if type == TypeCommand.TURN:
		set_number(value + 1)  # Передаем любое значение, больше текущего
		return
		
	var new_value = min(value + 1, Global.get_remaining_points(type) + value, get_max_points())
	if new_value > value:
		set_number(new_value)
	update_all_buttons()

func _on_down_pressed() -> void:
	if type == TypeCommand.TURN:
		set_number(value - 1)  # Передаем любое значение, меньше текущего
		return
		
	if value > 1:
		set_number(value - 1)
	update_all_buttons()

func _exit_tree() -> void:
	# Сохраняем ссылку на слот и блок перед удалением
	var parent_block = null
	if slot and is_instance_valid(slot):
		parent_block = slot.block
		slot.command = null  # Очищаем ссылку на эту команду в слоте
	
	# Возвращаем очки в общий пул и обновляем UI
	if !is_menu_command and value > 0 and type != TypeCommand.TURN and type != TypeCommand.USE:
		
		if ui_node and is_instance_valid(ui_node):
			ui_node.change_scores(type)
		
	# Обновляем блок после всех изменений
	if parent_block and is_instance_valid(parent_block):
		parent_block.update_slots()

func _on_num_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_menu_command and not table.is_turn_in_progress:
			is_settings = !is_settings
			change_settings(is_settings)
			update_all_buttons()
			
func change_settings(settings):
	up_button.visible = settings
	down_button.visible = settings
