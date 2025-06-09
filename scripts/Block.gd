extends Card
class_name Block

@export var type: ItemData.BlockType
@export var text: String

const MAX_TEXT_LENGTH := 14

@onready var label: Label = $Label
@onready var texture: Control = $Texture
@onready var area: Area2D = $Area2D
@onready var icon: Sprite2D = $Icon
@onready var texture_up = $Texture/TextureUp
@onready var texture_down = $Texture/TextureDown
@onready var texture_left = $Texture/TextureLeft

var slot_manager: SlotManager
var parent_slot: CommandSlot = null
var config: Dictionary
var loop_count: int
var slot_offset_start := Vector2(28, 32)

static var available_conditions := []
static var available_loops := []
static var available_abilities := []

func _ready() -> void:
	super._ready()
	add_to_group("blocks")
	
	if text.is_empty() and !is_menu_command:
		initialize_block_properties()
	
	config = ItemData.get_block_config(type)
	slot_manager = SlotManager.new(self, slot_offset_start)
	add_child(slot_manager)
	slot_manager.connect("slots_updated", _on_slots_updated)
	
	update_appearance()
	
	slot_manager.initialize_slots(ItemData.get_slot_count(type, text))

func get_size() -> Vector2:
	return get_full_size()

func initialize_block_properties() -> void:
	match type:
		ItemData.BlockType.CONDITION:
			if not available_conditions.is_empty():
				text = available_conditions[0]
			else:
				text = "здоровье < 50%"
		ItemData.BlockType.LOOP:
			if not available_loops.is_empty():
				text = available_loops[0]
			else:
				text = "Повторить 2 раз"
			var parts = text.split(" ")
			if parts.size() > 1:
				loop_count = int(parts[1])
		ItemData.BlockType.ABILITY:
			if not available_abilities.is_empty():
				text = available_abilities[0]
			else:
				text = "+1 атака"
	
	if type == ItemData.BlockType.LOOP and not "Повторить" in text:
		text = "Повторить 2 раз"
		loop_count = 2
	elif type == ItemData.BlockType.CONDITION and not text in ItemData.TEXT_TO_ITEM_TYPE:
		text = "здоровье < 50%"
	elif type == ItemData.BlockType.ABILITY and not text in ItemData.TEXT_TO_ITEM_TYPE:
		text = "+1 атака"

func update_appearance() -> void:
	texture.modulate = config["color"]
	icon.texture = load(config["icon"]) if config["icon"] else null
	label.text = get_display_text()

func get_display_text() -> String:
	if type == ItemData.BlockType.LOOP:
		if !is_menu_command:
			return config["prefix"] + str(loop_count) + " раз"
		else:
			return config["prefix"]
	return config["prefix"] + truncate_text(text)

func truncate_text(input_text: String) -> String:
	return input_text.substr(0, MAX_TEXT_LENGTH) if input_text.length() > MAX_TEXT_LENGTH else input_text

func get_total_height() -> float:
	return slot_manager.get_total_height()

func update_slots() -> void:
	slot_manager.update_slots()

func _on_slots_updated() -> void:
	update_texture_sizes()
	
	if parent_slot and is_instance_valid(parent_slot) and parent_slot.block:
		parent_slot.block.update_slots()

func update_texture_sizes() -> void:
	var total_height = get_total_height()
	texture_down.position.y = total_height
	texture_left.size.y = total_height
	
	recreate_collision_shapes(total_height)

func recreate_collision_shapes(total_height: float) -> void:
	for child in area.get_children():
		if child.name != "CollisionUpProperty":
			child.queue_free()
	
	create_collision_rectangle("CollisionUp", texture_up.size, 
		Vector2(texture_up.size.x / 2, texture_up.size.y / 2))
	
	create_collision_rectangle("CollisionDown", texture_down.size,
		Vector2(texture_down.size.x / 2, total_height + texture_down.size.y / 2))
	
	create_collision_rectangle("CollisionLeft", 
		Vector2(texture_left.size.x, total_height - texture_up.size.y),
		Vector2(texture_left.size.x / 2, texture_up.size.y + (total_height - texture_up.size.y) / 2))

func create_collision_rectangle(name_collision: String, size: Vector2, position_collision: Vector2) -> void:
	var collision = CollisionShape2D.new()
	collision.name = name_collision
	var shape = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = position_collision
	area.add_child(collision)

func get_full_size() -> Vector2:
	var base_size = Vector2(
		max(texture_up.size.x, texture_down.size.x),
		texture_down.position.y + texture_down.size.y
	)
	
	for slot in slot_manager.slots:
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
		
		base_size.x = max(base_size.x, slot_pos.x + command_size.x)
		base_size.y = max(base_size.y, slot_pos.y + command_size.y)
	
	return base_size

func prepare_for_insertion(target_slot: CommandSlot) -> void:
	slot_manager.prepare_for_insertion(target_slot)
	
func cancel_insertion() -> void:
	slot_manager.cancel_insertion()
	
func update_command_positions(base_z_index: int) -> void:
	slot_manager.update_command_positions(base_z_index)

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if is_menu_command:
		return
	
	if event is InputEventMouseButton:
		super._on_area_input_event(viewport, event, shape_idx)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and \
		   !is_menu_command and text != 'начало хода' and not table.is_turn_in_progress:
			queue_free()

func _exit_tree() -> void:
	var parent = null
	if parent_slot and is_instance_valid(parent_slot):
		parent = parent_slot.block
		parent_slot.command = null
	
	if parent and is_instance_valid(parent):
		parent.call_deferred("update_slots")
	
	if not is_menu_command:
		Global.release_block(type, text)
		
		var block_menu = get_tree().get_first_node_in_group("block_menu")
		if block_menu and is_instance_valid(block_menu):
			block_menu.return_block_to_slot(type, text)
