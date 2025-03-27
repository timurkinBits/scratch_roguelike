extends Node2D
class_name Block

enum BlockType { NONE, CONDITION, LOOP, ABILITY }

@export_category("Block Settings")
@export var type: BlockType
@export var text: String
@export var loop_count: int = 2
@export var slot_offset_start := Vector2(28, 32)

const MAX_TEXT_LENGTH := 14
const SLOT_OFFSET := 37
const SLOT_HEIGHT_INCREMENT := 30  # Прирост высоты слота для вложенных блоков
const MAX_LOOP_SLOTS := 3

@onready var label: Label = $Label
@onready var texture: Control = $Texture
@onready var area: Area2D = $Area2D
@onready var icon: Sprite2D = $Texture/Icon
@onready var texture_up = $Texture/TextureUp
@onready var texture_down = $Texture/TextureDown
@onready var texture_left = $Texture/TextureLeft

var slots: Array[CommandSlot] = []
var parent_slot: CommandSlot = null
var config: Dictionary  # Кэшированная конфигурация для типа блока
var original_slot_commands: Array = []

# Конфигурация типов блоков
var block_configs = {
	BlockType.CONDITION: {
		"prefix": "Если ",
		"color": Color.YELLOW,
		"icon": "res://sprites/ConditionIcon.svg"
	},
	BlockType.LOOP: {
		"prefix": "Повторить ",
		"color": Color.PURPLE,
		"icon": "res://sprites/LoopIcon.svg"
	},
	BlockType.ABILITY: {
		"prefix": "Улучшить ",
		"color": Color.TURQUOISE,
		"icon": "res://sprites/AbilityIcon.svg"
	},
	BlockType.NONE: {
		"prefix": "none ",
		"color": Color.WHITE,
		"icon": ""
	}
}

func _ready() -> void:
	add_to_group("blocks")
	config = block_configs[type]  # Кэшируем конфигурацию
	update_appearance()
	initialize_slots()

# Инициализирует слоты в зависимости от типа блока
func initialize_slots() -> void:
	if slots.is_empty():
		var slot_count = min(loop_count, MAX_LOOP_SLOTS) if type == BlockType.LOOP else 1
		for _i in range(slot_count):
			create_slot()
	update_slots()

# Обновляет внешний вид блока
func update_appearance() -> void:
	texture.modulate = config["color"]
	icon.texture = load(config["icon"]) if config["icon"] else null
	label.text = get_display_text()

# Генерирует отображаемый текст для блока
func get_display_text() -> String:
	if type == BlockType.LOOP:
		return config["prefix"] + str(loop_count) + " раз"
	return config["prefix"] + truncate_text(text)

# Обрезает текст, если он превышает максимальную длину
func truncate_text(input_text: String) -> String:
	return input_text.substr(0, MAX_TEXT_LENGTH) if input_text.length() > MAX_TEXT_LENGTH else input_text

# Создает новый слот и добавляет его в блок
func create_slot() -> CommandSlot:
	if type == BlockType.LOOP and slots.size() >= MAX_LOOP_SLOTS:
		return slots.back()  # Возвращает последний слот, если достигнут лимит для циклов
	var slot = preload("res://scenes/command_slot.tscn").instantiate() as CommandSlot
	add_child(slot)
	slot.block = self
	slots.append(slot)
	return slot

# Вычисляет общую высоту блока, включая вложенные блоки
func get_total_height() -> float:
	var height = slot_offset_start.y
	for slot in slots:
		var slot_height = SLOT_OFFSET
		if slot.command and slot.command is Block:
			slot_height = slot.command.get_total_height() + SLOT_HEIGHT_INCREMENT
		height += slot_height
	return height

# Обновляет позиции всех слотов в блоке
func update_all_slot_positions() -> void:
	var current_y = slot_offset_start.y
	for slot in slots:
		if not is_instance_valid(slot):
			continue
		slot.position = Vector2(slot_offset_start.x, current_y)
		var increment = SLOT_OFFSET
		if slot.command and is_instance_valid(slot.command):
			slot.command.global_position = to_global(slot.position)  # Синхронизируем позицию команды
			if slot.command is Block:
				increment = slot.command.get_total_height() + SLOT_HEIGHT_INCREMENT
		current_y += increment

func update_texture_sizes() -> void:
	var total_height = get_total_height()
	texture_down.position.y = total_height
	texture_left.size.y = total_height
	recreate_collision_shapes(total_height)
	if parent_slot and is_instance_valid(parent_slot) and parent_slot.block:
		parent_slot.block.call_deferred("update_slots")

func recreate_collision_shapes(total_height: float) -> void:
	for child in area.get_children():
		child.queue_free()
	_create_top_collision()
	_create_bottom_collision(total_height)
	_create_left_collision(total_height)

func _create_top_collision() -> void:
	var collision = CollisionShape2D.new()
	collision.name = "CollisionUp"
	var shape = RectangleShape2D.new()
	shape.size = texture_up.size
	collision.shape = shape
	collision.position = Vector2(texture_up.size.x / 2, texture_up.size.y / 2)
	area.add_child(collision)

func _create_bottom_collision(total_height: float) -> void:
	var collision = CollisionShape2D.new()
	collision.name = "CollisionDown"
	var shape = RectangleShape2D.new()
	shape.size = texture_down.size
	collision.shape = shape
	collision.position = Vector2(texture_down.size.x / 2, total_height + texture_down.size.y / 2)
	area.add_child(collision)

func _create_left_collision(total_height: float) -> void:
	var collision = CollisionShape2D.new()
	collision.name = "CollisionLeft"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(texture_left.size.x, total_height - texture_up.size.y)
	collision.shape = shape
	collision.position = Vector2(texture_left.size.x / 2, texture_up.size.y + shape.size.y / 2)
	area.add_child(collision)

func update_slots() -> void:
	shift_commands_up()
	adjust_slot_count()
	update_all_slot_positions()
	update_texture_sizes()

# Сдвигает команды вверх, убирая промежутки
func shift_commands_up() -> void:
	var commands = slots.filter(func(s): return s.command != null and is_instance_valid(s.command)).map(func(s): return s.command)
	for i in slots.size():
		if i < commands.size():
			slots[i].command = commands[i]
			if is_instance_valid(slots[i].command):
				if slots[i].command is Command:
					slots[i].command.slot = slots[i]
				slots[i].command.global_position = slots[i].global_position
		else:
			slots[i].command = null

# Регулирует количество слотов в зависимости от команд
func adjust_slot_count() -> void:
	if slots.is_empty():
		create_slot()
		return
	
	# Подсчитываем количество занятых слотов
	var command_count = slots.filter(func(s): return s.command != null and is_instance_valid(s.command)).size()
	
	# Определяем целевое количество слотов
	var target_count = command_count + 1  # Всегда оставляем один пустой слот
	if type == BlockType.LOOP:
		target_count = min(command_count + 1, MAX_LOOP_SLOTS)  # Для циклов учитываем лимит
	
	# Удаляем все лишние пустые слоты с конца
	while slots.size() > target_count:
		var last_slot = slots.back()
		if not last_slot.command and is_instance_valid(last_slot):
			slots.pop_back()
			last_slot.queue_free()
		else:
			break  # Прерываем, если последний слот занят, чтобы не удалить нужное
	
	# Если слотов меньше, чем нужно, добавляем новый
	while slots.size() < target_count:
		create_slot()
	
	# Убеждаемся, что остался хотя бы один слот
	if slots.is_empty():
		create_slot()

# Вычисляет полный размер блока, включая текстуры и слоты
func get_full_size() -> Vector2:
	var base_size = Vector2.ZERO
	
	# Базовый размер блока с учетом текстур
	var texture_max_x = max(texture_up.size.x, texture_down.size.x)
	var texture_max_y = texture_down.position.y + texture_down.size.y
	base_size = Vector2(texture_max_x, texture_max_y)
	
	# Проверяем, не выходят ли команды за пределы базового размера
	for slot in slots:
		if not is_instance_valid(slot) or not slot.command:
			continue
		
		var command_size = Vector2.ZERO
		var slot_pos = slot.position
		
		if slot.command is Block:
			command_size = slot.command.get_full_size() * slot.command.scale
		else:
			var texture_node = slot.command.get_node("Texture")
			if texture_node:
				command_size = texture_node.size * slot.command.scale
		
		# Учитываем позицию слота и размер команды
		var command_right = slot_pos.x + command_size.x
		var command_bottom = slot_pos.y + command_size.y
		
		base_size.x = max(base_size.x, command_right)
		base_size.y = max(base_size.y, command_bottom)
	
	return base_size
	
func prepare_for_insertion(target_slot: CommandSlot) -> void:
	if slots.is_empty() or target_slot not in slots:
		return
	original_slot_commands = []
	for slot in slots:
		original_slot_commands.append(slot.command)
	var hover_index = slots.find(target_slot)
	if slots.back().command:
		create_slot()
	for i in range(slots.size() - 1, hover_index, -1):
		slots[i].command = slots[i - 1].command
	slots[hover_index].command = null
	update_all_slot_positions()
	for slot in slots:
		if slot.command and is_instance_valid(slot.command):
			slot.command.global_position = to_global(slot.position)
			
func cancel_insertion() -> void:
	if original_slot_commands.is_empty():
		return
	for i in range(min(slots.size(), original_slot_commands.size())):
		slots[i].command = original_slot_commands[i]
	for i in range(original_slot_commands.size(), slots.size()):
		slots[i].command = null
	original_slot_commands = []
	update_slots()
	
func update_command_positions(base_z_index: int) -> void:
	for slot in slots:
		if slot.command and is_instance_valid(slot.command):
			slot.command.global_position = to_global(slot.position)
			slot.command.visible = true
			slot.command.z_index = base_z_index - 1
			if slot.command is Block:
				slot.command.update_command_positions(base_z_index - 1)
