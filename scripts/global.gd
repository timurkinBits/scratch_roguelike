# In global.gd - Add tracking for available conditions and loops
extends Node

signal points_changed
signal coins_changed

var points: Dictionary = {
	Command.TypeCommand.MOVE: 10,
	Command.TypeCommand.ATTACK: 20,
	Command.TypeCommand.HEAL: 3,
	Command.TypeCommand.DEFENSE: 3
}

var coins: int = 0

var remaining_move_points: int
var remaining_attack_points: int
var remaining_heal_points: int
var remaining_defense_points: int

var block_limits: Dictionary = {
	ItemData.BlockType.CONDITION: 0,  # Start with 0 until conditions are available
	ItemData.BlockType.LOOP: 0,       # Start with 0 until loops are available
	ItemData.BlockType.ABILITY: 0     # Start with 0 until abilities are available
}

var remaining_blocks: Dictionary = {
	ItemData.BlockType.CONDITION: 0,
	ItemData.BlockType.LOOP: 0,
	ItemData.BlockType.ABILITY: 0
}

# Track purchased abilities, conditions and loops
var purchased_abilities: Dictionary = {}
var purchased_conditions: Dictionary = {}
var purchased_loops: Dictionary = {}

func _ready() -> void:
	# Initialize purchased items dictionaries
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
	
	reset_remaining_points()
	reset_remaining_blocks()
	update_available_block_types()

func reset_remaining_points() -> void:
	remaining_move_points = points[Command.TypeCommand.MOVE]
	remaining_attack_points = points[Command.TypeCommand.ATTACK]
	remaining_heal_points = points[Command.TypeCommand.HEAL]
	remaining_defense_points = points[Command.TypeCommand.DEFENSE]
	
	points_changed.emit()

func reset_remaining_blocks():
	for block_type in block_limits:
		remaining_blocks[block_type] = block_limits[block_type]
		
# Get remaining points for specific command type
func get_remaining_points(command_type) -> int:
	match command_type:
		Command.TypeCommand.MOVE: return remaining_move_points
		Command.TypeCommand.ATTACK: return remaining_attack_points
		Command.TypeCommand.HEAL: return remaining_heal_points
		Command.TypeCommand.DEFENSE: return remaining_defense_points
		_: return 100

# Change remaining points for specific command type
func use_points(command_type, value) -> void:
	match command_type:
		Command.TypeCommand.MOVE: remaining_move_points -= value
		Command.TypeCommand.ATTACK: remaining_attack_points -= value
		Command.TypeCommand.HEAL: remaining_heal_points -= value
		Command.TypeCommand.DEFENSE: remaining_defense_points -= value
	
	# Ensure we never go below zero
	remaining_move_points = max(0, remaining_move_points)
	remaining_attack_points = max(0, remaining_attack_points)
	remaining_heal_points = max(0, remaining_heal_points)
	remaining_defense_points = max(0, remaining_defense_points)
	
	points_changed.emit()

# Return points to the general pool
func release_points(command_type, value) -> void:
	match command_type:
		Command.TypeCommand.MOVE: 
			remaining_move_points = min(points[Command.TypeCommand.MOVE], remaining_move_points + value)
		Command.TypeCommand.ATTACK: 
			remaining_attack_points = min(points[Command.TypeCommand.ATTACK], remaining_attack_points + value)
		Command.TypeCommand.HEAL: 
			remaining_heal_points = min(points[Command.TypeCommand.HEAL], remaining_heal_points + value)
		Command.TypeCommand.DEFENSE: 
			remaining_defense_points = min(points[Command.TypeCommand.DEFENSE], remaining_defense_points + value)
	
	points_changed.emit()
	
func get_remaining_blocks(block_type) -> int:
	if block_type in remaining_blocks:
		return remaining_blocks[block_type]
	return 0

func use_block(block_type) -> void:
	if block_type in remaining_blocks:
		remaining_blocks[block_type] = max(0, remaining_blocks[block_type] - 1)
		points_changed.emit()

func release_block(block_type) -> void:
	if block_type in remaining_blocks:
		remaining_blocks[block_type] = min(block_limits[block_type], remaining_blocks[block_type] + 1)
		points_changed.emit()

# Functions for coin system
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

func increase_block_limit(block_type, amount: int = 1) -> void:
	if block_type in block_limits:
		block_limits[block_type] += amount
		remaining_blocks[block_type] += amount
		points_changed.emit()
		
# Mark ability as purchased and update available abilities for blocks
func purchase_ability(ability_name: String) -> void:
	if ability_name in purchased_abilities:
		purchased_abilities[ability_name] = true
		
		# Update all blocks with the new ability
		update_available_block_types()

# Purchase a specific condition and update available conditions
func purchase_condition(condition_name: String) -> void:
	if condition_name in purchased_conditions:
		purchased_conditions[condition_name] = true
		
		# Update available conditions
		update_available_block_types()
		
# Purchase a specific loop and update available loops
func purchase_loop(loop_name: String) -> void:
	if loop_name in purchased_loops:
		purchased_loops[loop_name] = true
		
		# Update available loops
		update_available_block_types()
		
# Check if an ability has been purchased
func is_ability_purchased(ability_name: String) -> bool:
	return ability_name in purchased_abilities and purchased_abilities[ability_name]

# Check if a condition has been purchased
func is_condition_purchased(condition_name: String) -> bool:
	return condition_name in purchased_conditions and purchased_conditions[condition_name]

# Check if a loop has been purchased
func is_loop_purchased(loop_name: String) -> bool:
	return loop_name in purchased_loops and purchased_loops[loop_name]

# Process item purchase based on its type
func purchase_item(item_type: int) -> void:
	var ability_name = ItemData.get_ability_name(item_type)
	var condition_name = ItemData.get_condition_name(item_type)
	var loop_name = ItemData.get_loop_name(item_type)
	var block_type = ItemData.get_block_type(item_type)
	
	if ability_name != "":
		purchase_ability(ability_name)
	elif condition_name != "":
		purchase_condition(condition_name)
	elif loop_name != "":
		purchase_loop(loop_name)
	elif block_type != -1:
		increase_block_limit(block_type)

# Update the available block types for all blocks
func update_available_block_types() -> void:
	# Update abilities
	var updated_abilities = []
	for ability in purchased_abilities:
		if purchased_abilities[ability]:
			updated_abilities.append(ability)
	
	# Update conditions
	var updated_conditions = []
	for condition in purchased_conditions:
		if purchased_conditions[condition]:
			updated_conditions.append(condition)
	
	# Update loops
	var updated_loops = []
	for loop in purchased_loops:
		if purchased_loops[loop]:
			updated_loops.append(loop)
	
	# Update the static variables in Block class
	Block.available_abilities = updated_abilities
	Block.available_conditions = updated_conditions
	Block.available_loops = updated_loops
	
	# Update block limits based on availability
	if Block.available_abilities.size() > 0 and block_limits[ItemData.BlockType.ABILITY] == 0:
		increase_block_limit(ItemData.BlockType.ABILITY)
	
	if Block.available_conditions.size() > 0 and block_limits[ItemData.BlockType.CONDITION] == 0:
		increase_block_limit(ItemData.BlockType.CONDITION)
	
	if Block.available_loops.size() > 0 and block_limits[ItemData.BlockType.LOOP] == 0:
		increase_block_limit(ItemData.BlockType.LOOP)
