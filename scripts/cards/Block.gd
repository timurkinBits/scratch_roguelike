extends Card
class_name Block

@export var text: String = ""

const MAX_TEXT_LENGTH = 14
const MENU_BLOCK_WIDTH = 180
const MENU_BLOCK_HEIGHT = 20

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
var block_id: String = ""
var slot_offset_start = Vector2(28, 32)

func _ready() -> void:
	super._ready()
	add_to_group("blocks")
	
	_setup_menu_card()
	_setup_config()
	_setup_slot_manager()
	update_appearance()

# Настройка блока для меню
func _setup_menu_card() -> void:
	if not is_menu_card:
		return
		
	texture_up.size = Vector2(MENU_BLOCK_WIDTH, MENU_BLOCK_HEIGHT)
	texture_down.visible = false
	texture_left.visible = false
	area.get_node('CollisionDown').queue_free()
	area.get_node('CollisionLeft').queue_free()

# Получение конфигурации блока
func _setup_config() -> void:
	config = _get_block_config()

func _get_block_config() -> Dictionary:
	# Блок начала хода
	if text == "начало хода":
		return {
			"prefix": "",
			"color": Color.YELLOW,
			"icon": "res://sprites/start_turn.png"
		}
	
	# Блоки из ItemData
	if text in ItemData.TEXT_TO_BLOCK_TYPE:
		var item_type = ItemData.TEXT_TO_BLOCK_TYPE[text]
		var color = ItemData.get_item_color(item_type)
		var icon_path = ItemData.get_item_icon(item_type)
		
		var prefix = "Повторить " if _is_loop_block() else "Улучшить "
		return {
			"prefix": prefix,
			"color": color,
			"icon": icon_path
		}
	
	# Конфигурация по умолчанию
	var prefix = "Повторить " if _is_loop_block() else "Улучшить "
	var default_color = Color.CHOCOLATE if _is_loop_block() else Color.TURQUOISE
	var default_icon = "res://sprites/loop.png" if _is_loop_block() else "res://sprites/ability.png"
	
	return {
		"prefix": prefix,
		"color": default_color,
		"icon": default_icon
	}

# Проверка типов блоков
func _is_loop_block() -> bool:
	return text.contains("раз") or text in ["Повторить 2 раз", "Повторить 3 раз"]

func _is_start_turn_block() -> bool:
	return text == "начало хода"

# Настройка менеджера слотов
func _setup_slot_manager() -> void:
	slot_manager = SlotManager.new(self, slot_offset_start)
	add_child(slot_manager)
	slot_manager.connect("slots_updated", _on_slots_updated)
	slot_manager.initialize_slots(_get_slot_count())

func _get_slot_count() -> int:
	match text:
		"начало хода": return 10
		"Повторить 2 раз", "Повторить 3 раз": return 2
		_: return 1

# Обновление внешнего вида
func update_appearance() -> void:
	texture.modulate = config.get("color", Color.WHITE)
	
	if config.has("icon") and config["icon"]:
		var icon_texture = load(config["icon"])
		if icon_texture:
			icon.texture = icon_texture
	
	label.text = _get_display_text()

func _get_display_text() -> String:
	var prefix = config.get("prefix", "")
	
	if _is_loop_block():
		if text == "Повторить 2 раз":
			return prefix + "2 раз"
		elif text == "Повторить 3 раз":
			return prefix + "3 раз"
		else:
			return prefix + "2 раз" # По умолчанию
	elif text == "начало хода":
		return text
	else:
		var display_text = text
		if text.length() > MAX_TEXT_LENGTH:
			display_text = text.substr(0, MAX_TEXT_LENGTH)
		return prefix + display_text

# Размеры блока
func get_total_height() -> float:
	return slot_manager.get_total_height()

func get_size() -> Vector2:
	if is_menu_card:
		return Vector2(MENU_BLOCK_WIDTH, MENU_BLOCK_HEIGHT)
	
	var base_size = Vector2(
		max(texture_up.size.x, texture_down.size.x),
		texture_down.position.y + texture_down.size.y
	)
	
	# Учитываем размеры дочерних команд
	for slot in slot_manager.slots:
		if slot and slot.command:
			var command_size = _get_command_size(slot.command)
			var slot_pos = slot.position
			base_size.x = max(base_size.x, slot_pos.x + command_size.x)
			base_size.y = max(base_size.y, slot_pos.y + command_size.y)
	
	return base_size

func _get_command_size(command) -> Vector2:
	if command is Block:
		return command.get_size() * command.scale
	
	var texture_node = command.get_node("Texture")
	return texture_node.size * command.scale if texture_node else Vector2.ZERO

# Обновление слотов
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
	# Очищаем старые коллизии
	for child in area.get_children():
		if child.name != "CollisionUpProperty":
			child.queue_free()
	
	# Создаем новые коллизии
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

# Делегирование методов менеджеру слотов
func prepare_for_insertion(target_slot: CommandSlot) -> void:
	slot_manager.prepare_for_insertion(target_slot)
	
func cancel_insertion() -> void:
	slot_manager.cancel_insertion()
	
func update_command_positions(base_z_index: int) -> void:
	slot_manager.update_command_positions(base_z_index)

# Обработка событий
func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if is_menu_card:
		return
	
	if event is InputEventMouseButton:
		# Перетаскивание
		_on_area_input_event(viewport, event, shape_idx)
		
		# Удаление правой кнопкой (кроме блока начала хода)
		if (event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and 
			not _is_start_turn_block() and not table.is_turn_in_progress):
			queue_free()

# Очистка ресурсов
func _exit_tree() -> void:
	# Освобождаем блок в Global
	if block_id != "" and not is_menu_card:
		Global.release_block(block_id)
	
	cleanup_parent_slot_reference()
		
func cleanup_parent_slot_reference() -> void:
	if parent_slot and is_instance_valid(parent_slot):
		var parent_block = parent_slot.block
		parent_slot.command = null
		parent_slot = null
		
		if parent_block and is_instance_valid(parent_block):
			parent_block.call_deferred("force_update_slots")

func force_update_slots() -> void:
	if slot_manager and is_instance_valid(slot_manager):
		slot_manager.force_rebuild_slots()
		
func on_extracted_from_slot() -> void:
	if parent_slot and is_instance_valid(parent_slot):
		var parent_block = parent_slot.block
		parent_slot.command = null
		parent_slot = null
		
		if parent_block and is_instance_valid(parent_block):
			parent_block.force_update_slots()
			parent_block.call_deferred("update_command_positions", parent_block.z_index)
