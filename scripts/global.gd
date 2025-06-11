extends Node

signal points_changed
signal coins_changed

var points: Dictionary = {
	Command.TypeCommand.MOVE: 10,
	Command.TypeCommand.ATTACK: 30,
	Command.TypeCommand.HEAL: 3,
	Command.TypeCommand.DEFENSE: 3
}

var coins: int = 0
var remaining_points: Dictionary = {}

# Block system
var purchased_blocks: Array[Dictionary] = []
var next_block_id: int = 0

# Legacy compatibility
var purchased_abilities: Dictionary = {}
var purchased_conditions: Dictionary = {}
var purchased_loops: Dictionary = {}

func _ready() -> void:
	_initialize_legacy_items()
	reset_remaining_points()
	reset_all_blocks()

func _initialize_legacy_items() -> void:
	for item_type in ItemData.ItemType.values():
		var ability_name = ItemData.get_ability_name(item_type)
		if ability_name != "":
			purchased_abilities[ability_name] = false
		
		var condition_name = ItemData.get_condition_name(item_type)
		if condition_name != "":
			purchased_conditions[condition_name] = false
		
		var loop_name = ItemData.get_loop_name(item_type)
		if loop_name != "":
			purchased_loops[loop_name] = false

# Points management
func reset_remaining_points() -> void:
	remaining_points = points.duplicate()
	points_changed.emit()

func get_remaining_points(command_type) -> int:
	if command_type in [Command.TypeCommand.USE, Command.TypeCommand.TURN]:
		return 999
	return remaining_points.get(command_type, 0)

func use_points(command_type, value) -> void:
	if command_type in [Command.TypeCommand.USE, Command.TypeCommand.TURN]:
		return
	
	if command_type in remaining_points:
		remaining_points[command_type] = max(0, remaining_points[command_type] - value)
		points_changed.emit()

func release_points(command_type, value) -> void:
	if command_type in [Command.TypeCommand.USE, Command.TypeCommand.TURN]:
		return
	
	if command_type in remaining_points:
		remaining_points[command_type] = min(points[command_type], remaining_points[command_type] + value)
		points_changed.emit()

# Coins management
func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit()

func get_coins() -> int:
	return coins

func spend_coins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		coins_changed.emit()
		return true
	return false

# Block management
func generate_block_id() -> String:
	var id = "block_" + str(next_block_id)
	next_block_id += 1
	return id

func purchase_block(block_type: int, block_text: String, count: int = 1) -> void:
	for i in range(count):
		var new_block = {
			"id": generate_block_id(),
			"type": block_type,
			"text": block_text,
			"used": false
		}
		purchased_blocks.append(new_block)
	
	_update_legacy_compatibility(block_type, block_text)
	points_changed.emit()

func _update_legacy_compatibility(block_type: int, block_text: String) -> void:
	match block_type:
		ItemData.BlockType.ABILITY:
			purchased_abilities[block_text] = true
		ItemData.BlockType.CONDITION:
			purchased_conditions[block_text] = true
		ItemData.BlockType.LOOP:
			purchased_loops[block_text] = true

func can_use_block_by_id(block_id: String) -> bool:
	for block in purchased_blocks:
		if block.id == block_id:
			return not block.used
	return false

func use_block(block_id: String) -> bool:
	for block in purchased_blocks:
		if block.id == block_id and not block.used:
			block.used = true
			points_changed.emit()
			return true
	return false

func release_block(block_id: String) -> void:
	for block in purchased_blocks:
		if block.id == block_id and block.used:
			block.used = false
			points_changed.emit()
			return

func reset_all_blocks() -> void:
	for block in purchased_blocks:
		block.used = false
	points_changed.emit()

func get_all_purchased_blocks() -> Array:
	return purchased_blocks.duplicate()

# Legacy compatibility functions
func purchase_ability(ability_name: String, count: int = 1) -> void:
	purchase_block(ItemData.BlockType.ABILITY, ability_name, count)

func purchase_condition(condition_name: String, count: int = 1) -> void:
	purchase_block(ItemData.BlockType.CONDITION, condition_name, count)

func purchase_loop(loop_name: String, count: int = 1) -> void:
	purchase_block(ItemData.BlockType.LOOP, loop_name, count)

func purchase_item(item_type: int, count: int = 1) -> void:
	var ability_name = ItemData.get_ability_name(item_type)
	var condition_name = ItemData.get_condition_name(item_type)
	var loop_name = ItemData.get_loop_name(item_type)
	
	if ability_name != "":
		purchase_ability(ability_name, count)
	elif condition_name != "":
		purchase_condition(condition_name, count)
	elif loop_name != "":
		purchase_loop(loop_name, count)

func is_ability_purchased(ability_name: String) -> bool:
	return purchased_abilities.get(ability_name, false)

func is_condition_purchased(condition_name: String) -> bool:
	return purchased_conditions.get(condition_name, false)

func is_loop_purchased(loop_name: String) -> bool:
	return purchased_loops.get(loop_name, false)

# Legacy aliases
func reset_remaining_blocks() -> void:
	reset_all_blocks()

func can_use_block(block_type: int, block_text: String = "") -> bool:
	if block_text == "":
		for block in purchased_blocks:
			if block.type == block_type and not block.used:
				return true
		return false
	
	for block in purchased_blocks:
		if block.type == block_type and block.text == block_text and not block.used:
			return true
	return false

func find_available_block(block_type: int, block_text: String) -> Dictionary:
	for block in purchased_blocks:
		if block.type == block_type and block.text == block_text and not block.used:
			return block
	return {}
