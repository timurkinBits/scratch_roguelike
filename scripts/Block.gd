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
		if slot.command and slot.command is Block:
			increment = slot.command.get_total_height() + SLOT_HEIGHT_INCREMENT
		current_y += increment

# Обновляет размеры и позиции текстур и коллизий
func update_texture_sizes() -> void:
	var total_height = get_total_height()
	texture_down.position.y = total_height
	texture_left.size.y = total_height
	recreate_collision_shapes(total_height)
	if parent_slot and is_instance_valid(parent_slot) and parent_slot.block:
		parent_slot.block.call_deferred("update_slots")

# Пересоздает коллизии на основе текущего размера
func recreate_collision_shapes(total_height: float) -> void:
	for child in area.get_children():
		child.queue_free()
	_create_top_collision()
	_create_bottom_collision(total_height)
	_create_left_collision(total_height)

# Создает верхнюю коллизию
func _create_top_collision() -> void:
	var collision = CollisionShape2D.new()
	collision.name = "CollisionUp"
	var shape = RectangleShape2D.new()
	shape.size = texture_up.size
	collision.shape = shape
	collision.position = Vector2(texture_up.size.x / 2, texture_up.size.y / 2)
	area.add_child(collision)

# Создает нижнюю коллизию
func _create_bottom_collision(total_height: float) -> void:
	var collision = CollisionShape2D.new()
	collision.name = "CollisionDown"
	var shape = RectangleShape2D.new()
	shape.size = texture_down.size
	collision.shape = shape
	collision.position = Vector2(texture_down.size.x / 2, total_height + texture_down.size.y / 2)
	area.add_child(collision)

# Создает левую коллизию
func _create_left_collision(total_height: float) -> void:
	var collision = CollisionShape2D.new()
	collision.name = "CollisionLeft"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(texture_left.size.x, total_height - texture_up.size.y)
	collision.shape = shape
	collision.position = Vector2(texture_left.size.x / 2, texture_up.size.y + shape.size.y / 2)
	area.add_child(collision)

# Обновляет все слоты: сдвигает команды вверх, регулирует количество и обновляет позиции
func update_slots() -> void:
	shift_commands_up()
	adjust_slot_count()
	update_all_slot_positions()
	update_texture_sizes()

# Сдвигает команды вверх, убирая промежутки
func shift_commands_up() -> void:
	var commands = slots.filter(func(s): return s.command != null).map(func(s): return s.command)
	for i in slots.size():
		slots[i].command = commands[i] if i < commands.size() else null
		if slots[i].command and is_instance_valid(slots[i].command):
			slots[i].command.global_position = slots[i].global_position

# Регулирует количество слотов в зависимости от команд
func adjust_slot_count() -> void:
	if slots.is_empty():
		return
	var command_count = slots.filter(func(s): return s.command != null).size()
	var target_count = command_count + 1
	if type == BlockType.LOOP:
		target_count = min(command_count + 1, MAX_LOOP_SLOTS)
	while slots.size() > target_count and not slots.back().command:
		slots.pop_back().queue_free()
	if slots.size() < target_count:
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
