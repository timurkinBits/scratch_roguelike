extends Card
class_name Block

@export var text: String = ""

const MAX_TEXT_LENGTH = 14

@onready var label: Label = $Label
@onready var texture: Control = $Texture
@onready var area: Area2D = $Area2D
@onready var icon: Sprite2D = $Icon
@onready var texture_up = $Texture/TextureUp
@onready var texture_down = $Texture/TextureDown
@onready var texture_left = $Texture/TextureLeft

var slot_manager: SlotManager
var parent_slot: CommandSlot
var config: Dictionary
var loop_count: int = 2
var block_id: String = ""

# Slot positioning
var slot_offset_start = Vector2(28, 32)

func _ready() -> void:
	super._ready()
	add_to_group("blocks")
	
	_setup_menu_card()
	_setup_config()
	_setup_slot_manager()
	update_appearance()

func _setup_menu_card() -> void:
	if not is_menu_card:
		return
		
	texture_down.visible = false
	texture_left.visible = false
	area.get_node('CollisionDown').queue_free()
	area.get_node('CollisionLeft').queue_free()

func _setup_config() -> void:
	config = _get_block_config()

func _get_block_config() -> Dictionary:
	# Специальная конфигурация для блока "начало хода"
	if text == "начало хода":
		return {
			"prefix": "",
			"color": Color.YELLOW,
			"icon": "res://sprites/start_turn.png"
		}
	
	# Получаем цвет и иконку из ItemData для блоков из item_data
	if text in ItemData.TEXT_TO_ITEM_TYPE:
		var item_type = ItemData.TEXT_TO_ITEM_TYPE[text]
		var color = ItemData.get_item_color(item_type)
		var icon_path = ItemData.get_item_icon(item_type)
		
		# Конфигурация для циклов
		if _is_loop_block():
			return {
				"prefix": "Повторить ",
				"color": color,
				"icon": icon_path
			}
		
		# Конфигурация для навыков (все остальные блоки)
		return {
			"prefix": "Улучшить ",
			"color": color,
			"icon": icon_path
		}
	
	# Конфигурация по умолчанию для блоков, не найденных в item_data
	if _is_loop_block():
		return {
			"prefix": "Повторить ",
			"color": Color.CHOCOLATE,
			"icon": "res://sprites/loop.png"
		}
	else:
		return {
			"prefix": "Улучшить ",
			"color": Color.TURQUOISE,
			"icon": "res://sprites/ability.png"
		}

func _get_icon_for_block_text(block_text: String) -> String:
	# Получаем тип предмета по тексту блока
	if block_text in ItemData.TEXT_TO_ITEM_TYPE:
		var item_type = ItemData.TEXT_TO_ITEM_TYPE[block_text]
		return ItemData.get_item_icon(item_type)
	
	# Для блоков, которых нет в item_data, возвращаем пустую строку
	return ""

func _is_loop_block() -> bool:
	return text.contains("раз") or text == "Повторить 2 раз" or text == "Повторить 3 раз"

func _is_start_turn_block() -> bool:
	return text == "начало хода"

func _setup_slot_manager() -> void:
	slot_manager = SlotManager.new(self, slot_offset_start)
	add_child(slot_manager)
	slot_manager.connect("slots_updated", _on_slots_updated)
	slot_manager.initialize_slots(_get_slot_count())

func _get_slot_count() -> int:
	if text == "начало хода":
		return 10
	elif text == "Повторить 2 раз":
		return 2
	elif text == "Повторить 3 раз":
		return 2
	else:
		return 1  # Навыки имеют 1 слот

func update_appearance() -> void:
	texture.modulate = config.get("color", Color.WHITE)
	if config.has("icon") and config["icon"]:
		var icon_texture = load(config["icon"])
		if icon_texture:
			icon.texture = icon_texture
		else:
			print("Предупреждение: Не удалось загрузить иконку: " + config["icon"])
	label.text = _get_display_text()

func _get_display_text() -> String:
	var prefix = config.get("prefix", "")
	
	if _is_loop_block():
		if text == "Повторить 2 раз":
			return prefix + "2 раз"
		elif text == "Повторить 3 раз":
			return prefix + "3 раз"
		else:
			return prefix + str(loop_count) + " раз"
	
	if text == "начало хода":
		return text
	
	var display_text = text
	if text.length() > MAX_TEXT_LENGTH:
		display_text = text.substr(0, MAX_TEXT_LENGTH)
	
	return prefix + display_text

func get_total_height() -> float:
	return slot_manager.get_total_height()

func get_size() -> Vector2:
	var base_size = Vector2(
		max(texture_up.size.x, texture_down.size.x),
		texture_down.position.y + texture_down.size.y
	)
	
	# Account for child commands
	for slot in slot_manager.slots:
		if not slot or not slot.command:
			continue
			
		var command_size = _get_command_size(slot.command)
		var slot_pos = slot.position
		
		base_size.x = max(base_size.x, slot_pos.x + command_size.x)
		base_size.y = max(base_size.y, slot_pos.y + command_size.y)
	
	return base_size

func _get_command_size(command) -> Vector2:
	if command is Block:
		return command.get_size() * command.scale
	
	var texture_node = command.get_node("Texture")
	if texture_node:
		return texture_node.size * command.scale
	
	return Vector2.ZERO

func update_slots() -> void:
	slot_manager.update_slots()

func _on_slots_updated() -> void:
	if is_menu_card:
		return
		
	_update_texture_sizes()
	
	if parent_slot and is_instance_valid(parent_slot) and parent_slot.block:
		parent_slot.block.update_slots()

func _update_texture_sizes() -> void:
	var total_height = get_total_height()
	texture_down.position.y = total_height
	texture_left.size.y = total_height
	_recreate_collision_shapes(total_height)

func _recreate_collision_shapes(total_height: float) -> void:
	# Clear existing collision shapes (except special ones)
	for child in area.get_children():
		if child.name != "CollisionUpProperty":
			child.queue_free()
	
	# Create new collision shapes
	_create_collision_rectangle("CollisionUp", texture_up.size, 
		Vector2(texture_up.size.x / 2, texture_up.size.y / 2))
	
	_create_collision_rectangle("CollisionDown", texture_down.size,
		Vector2(texture_down.size.x / 2, total_height + texture_down.size.y / 2))
	
	_create_collision_rectangle("CollisionLeft", 
		Vector2(texture_left.size.x, total_height - texture_up.size.y),
		Vector2(texture_left.size.x / 2, texture_up.size.y + (total_height - texture_up.size.y) / 2))

func _create_collision_rectangle(name: String, size: Vector2, pos: Vector2) -> void:
	var collision = CollisionShape2D.new()
	collision.name = name
	
	var shape = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = pos
	
	area.add_child(collision)

# Delegation methods
func prepare_for_insertion(target_slot: CommandSlot) -> void:
	slot_manager.prepare_for_insertion(target_slot)
	
func cancel_insertion() -> void:
	slot_manager.cancel_insertion()
	
func update_command_positions(base_z_index: int) -> void:
	slot_manager.update_command_positions(base_z_index)

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if is_menu_card:
		return
	
	if event is InputEventMouseButton:
		# Вызываем родительский метод для обработки перетаскивания
		_on_area_input_event(viewport, event, shape_idx)
		
		# Right click to delete (блок "начало хода" нельзя удалить)
		if (event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and 
			not _is_start_turn_block() and not table.is_turn_in_progress):
			queue_free()

func _exit_tree() -> void:
	# Clean up parent slot reference
	if parent_slot and is_instance_valid(parent_slot):
		var parent = parent_slot.block
		parent_slot.command = null
		
		if parent and is_instance_valid(parent):
			parent.call_deferred("update_slots")
	
	# Release block resources
	if block_id != "":
		Global.release_block(block_id)
