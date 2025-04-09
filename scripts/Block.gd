extends Node2D
class_name Block

enum BlockType { NONE, CONDITION, LOOP, ABILITY }

@export_category("Block Settings")
@export var type: BlockType
@export var text: String
@export var loop_count: int = 2
@export var slot_offset_start := Vector2(28, 32)

const MAX_TEXT_LENGTH := 14

@onready var label: Label = $Label
@onready var texture: Control = $Texture
@onready var area: Area2D = $Area2D
@onready var icon: Sprite2D = $Icon
@onready var texture_up = $Texture/TextureUp
@onready var texture_down = $Texture/TextureDown
@onready var texture_left = $Texture/TextureLeft
@onready var buttons = [$'Buttons/Up', $'Buttons/Down']
@onready var table = $'../..'
@onready var button_color: ColorRect = $'Buttons/ColorRect'

var slot_manager: SlotManager
var parent_slot: CommandSlot = null
var config: Dictionary
var is_menu_command: bool = false
var is_settings: bool = false

const AVAILABLE_CONDITIONS = ["здоровье < 50%"]
const AVAILABLE_ABILITIES = ['+1 движ.', '+1 атака', '+1 защита', '+1 леч.']

# Slot count for different block types
const CONDITION_SLOTS = {
	"начало хода": 999,
	"здоровье < 50%": 3,
}

const ABILITY_SLOTS = {
	"+1 движ.": 1,
	"+1 атака": 1,
	"+1 защита": 1,
	"+1 леч.": 1,
}

# Block configurations
const BLOCK_CONFIGS = {
	BlockType.CONDITION: {
		"prefix": "Если ",
		"color": Color.YELLOW,
		"icon": "res://sprites/fb13.png"
	},
	BlockType.LOOP: {
		"prefix": "Повторить ",
		"color": Color.CHOCOLATE,
		"icon": "res://sprites/fb666.png"
	},
	BlockType.ABILITY: {
		"prefix": "Улучшить ",
		"color": Color.TURQUOISE,
		"icon": "res://sprites/fb12.png"
	},
	BlockType.NONE: {
		"prefix": "none ",
		"color": Color.WHITE,
		"icon": ""
	}
}

func _ready() -> void:
	add_to_group("blocks")
	config = BLOCK_CONFIGS[type]
	slot_manager = SlotManager.new(self, slot_offset_start)
	add_child(slot_manager)
	slot_manager.connect("slots_updated", _on_slots_updated)
	
	update_appearance()
	initialize_slots_for_current_type()
	
	# Hide buttons initially
	buttons[0].visible = false
	buttons[1].visible = false
	button_color.visible = false

# Initialize slots based on block type
func initialize_slots_for_current_type() -> void:
	slot_manager.initialize_slots(get_slot_count_for_current_type())

# Get slot count based on block type and text
func get_slot_count_for_current_type() -> int:
	match type:
		BlockType.CONDITION:
			return CONDITION_SLOTS.get(text, 3)
		BlockType.LOOP:
			return loop_count
		BlockType.ABILITY:
			return ABILITY_SLOTS.get(text, 1)
		_:
			return 1

func update_appearance() -> void:
	texture.modulate = config["color"]
	icon.texture = load(config["icon"]) if config["icon"] else null
	label.text = get_display_text()

func get_display_text() -> String:
	if type == BlockType.LOOP:
		return config["prefix"] + str(loop_count) + " раз"
	return config["prefix"] + truncate_text(text)

func truncate_text(input_text: String) -> String:
	return input_text.substr(0, MAX_TEXT_LENGTH) if input_text.length() > MAX_TEXT_LENGTH else input_text

func get_total_height() -> float:
	return slot_manager.get_total_height()

func update_slots() -> void:
	slot_manager.update_slots()

func _on_slots_updated() -> void:
	update_texture_sizes()
	
	# Update parent block if exists
	if parent_slot and is_instance_valid(parent_slot) and parent_slot.block:
		parent_slot.block.update_slots()

func update_texture_sizes() -> void:
	var total_height = get_total_height()
	texture_down.position.y = total_height
	texture_left.size.y = total_height
	
	recreate_collision_shapes(total_height)

func recreate_collision_shapes(total_height: float) -> void:
	# Clear existing shapes except CollisionUpProperty
	for child in area.get_children():
		if child.name != "CollisionUpProperty":
			child.queue_free()
	
	# Create new collision shapes
	var size_up = texture_up.size.x / 1.78
	create_collision_rectangle("CollisionUp", Vector2(size_up, texture_up.size.y), 
		Vector2(size_up / 2, texture_up.size.y / 2))
	
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
	
	# Check size of all command slots
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

# Set block condition with command preservation
func set_condition(new_condition: String) -> void:
	if type != BlockType.CONDITION or not new_condition in AVAILABLE_CONDITIONS:
		return
		
	# Calculate slot changes
	var old_slot_count = get_slot_count_for_current_type()
	var old_text = text
	
	text = new_condition
	var new_slot_count = get_slot_count_for_current_type()
	text = old_text  # Restore temporarily
	
	# Gather commands that might be displaced
	var commands_to_release = gather_commands_in_excess_slots(old_slot_count, new_slot_count)
	
	# Apply new condition
	text = new_condition
	update_appearance()
	
	# Update slots and release excess commands
	update_slots_count_and_release_commands(commands_to_release, new_slot_count)

# Set block ability with command preservation
func set_ability(new_ability: String) -> void:
	if type != BlockType.ABILITY or not new_ability in AVAILABLE_ABILITIES:
		return
		
	# Calculate slot changes
	var old_slot_count = get_slot_count_for_current_type()
	var old_text = text
	
	text = new_ability
	var new_slot_count = get_slot_count_for_current_type()
	text = old_text  # Restore temporarily
	
	# Gather commands that might be displaced
	var commands_to_release = gather_commands_in_excess_slots(old_slot_count, new_slot_count)
	
	# Apply new ability
	text = new_ability
	update_appearance()
	
	# Update slots and release excess commands
	update_slots_count_and_release_commands(commands_to_release, new_slot_count)

# Gather commands from slots that will be removed
func gather_commands_in_excess_slots(old_slot_count: int, new_slot_count: int) -> Array:
	var commands_to_release = []
	
	# If new slot count is less than old, collect excess commands
	if new_slot_count < old_slot_count:
		for i in range(new_slot_count, min(old_slot_count, slot_manager.slots.size())):
			if i < slot_manager.slots.size():
				var slot = slot_manager.slots[i]
				if is_instance_valid(slot) and slot.command:
					commands_to_release.append(slot.command)
	
	return commands_to_release

# Update slot count and release excess commands
func update_slots_count_and_release_commands(commands_to_release: Array, new_slot_count: int = -1) -> void:
	# Use current type's slot count if not specified
	if new_slot_count == -1:
		new_slot_count = get_slot_count_for_current_type()
	
	# Clear connections between commands and slots
	for command in commands_to_release:
		if is_instance_valid(command):
			if command.slot:
				command.slot.command = null
			command.slot = null
	
	# Remove excess slots if needed
	while slot_manager.slots.size() > new_slot_count:
		var last_slot = slot_manager.slots.pop_back()
		if is_instance_valid(last_slot):
			last_slot.queue_free()
	
	# Update remaining slots and positions
	slot_manager.update_slots()
	
	# Place released commands on table
	for i in range(commands_to_release.size()):
		var command = commands_to_release[i]
		if is_instance_valid(command):
			command.global_position = global_position + Vector2(100, 50 + i * 30)

# Change loop count with command preservation
func change_loop_count(amount: int) -> void:
	if type != BlockType.LOOP:
		return
		
	var old_count = loop_count
	var new_count = clamp(loop_count + amount, 2, 2)  # Limit from 2 to 5
	
	if old_count != new_count:
		var commands_to_release = gather_commands_in_excess_slots(old_count, new_count)
		
		loop_count = new_count
		update_appearance()
		
		update_slots_count_and_release_commands(commands_to_release, new_count)

# Navigate through available options based on block type
func navigate_options(direction: int) -> void:
	match type:
		BlockType.CONDITION:
			_navigate_conditions(direction)
		BlockType.LOOP:
			change_loop_count(direction)
		BlockType.ABILITY:
			_navigate_abilities(direction)

# Navigate through available conditions
func _navigate_conditions(direction: int) -> void:
	if AVAILABLE_CONDITIONS.is_empty():
		return
		
	var current_index = AVAILABLE_CONDITIONS.find(text)
	if current_index == -1:
		current_index = 0
	else:
		current_index = (current_index + direction) % AVAILABLE_CONDITIONS.size()
		if current_index < 0:
			current_index = AVAILABLE_CONDITIONS.size() - 1
			
	set_condition(AVAILABLE_CONDITIONS[current_index])

# Navigate through available abilities
func _navigate_abilities(direction: int) -> void:
	if AVAILABLE_ABILITIES.is_empty():
		return
		
	var current_index = AVAILABLE_ABILITIES.find(text)
	if current_index == -1:
		current_index = 0
	else:
		current_index = (current_index + direction) % AVAILABLE_ABILITIES.size()
		if current_index < 0:
			current_index = AVAILABLE_ABILITIES.size() - 1
			
	set_ability(AVAILABLE_ABILITIES[current_index])

# Handle block interaction
func _on_area_2d_input_event(_viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
		
	if shape_idx != 0:  # Not the top part
		if event.button_index == MOUSE_BUTTON_RIGHT and !is_menu_command \
			and text != 'начало хода' and not table.is_turn_in_progress:
				queue_free()
		else:
			is_settings = false
			change_settings(is_settings)
	else:  # Top part
		if event.button_index == MOUSE_BUTTON_LEFT and !is_menu_command \
			and text != 'начало хода' and not table.is_turn_in_progress:
				is_settings = !is_settings
				change_settings(is_settings)

func change_settings(settings: bool) -> void:
	buttons[0].visible = settings
	buttons[1].visible = settings

func _exit_tree() -> void:
	var parent = null
	if parent_slot and is_instance_valid(parent_slot):
		parent = parent_slot.block
		parent_slot.command = null
	
	# Update parent after this node is removed
	if parent and is_instance_valid(parent):
		# Use call_deferred to ensure this happens after current operations complete
		parent.call_deferred("update_slots")
	
	Global.release_block(type)

func _on_up_pressed() -> void:
	navigate_options(1)  # 1 означает переход к следующему элементу

func _on_down_pressed() -> void:
	navigate_options(-1)  # -1 означает переход к предыдущему элементу
