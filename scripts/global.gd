# In global.gd - Add tracking for available conditions and loops
extends Node

signal points_changed
signal coins_changed

var points: Dictionary = {
	Command.TypeCommand.MOVE: 10,
	Command.TypeCommand.ATTACK: 10,
	Command.TypeCommand.HEAL: 3,
	Command.TypeCommand.DEFENSE: 3
}

var coins: int = 100

var remaining_move_points: int
var remaining_attack_points: int
var remaining_heal_points: int
var remaining_defense_points: int

var block_limits: Dictionary = {
	Block.BlockType.CONDITION: 0,  # Start with 0 until conditions are available
	Block.BlockType.LOOP: 0,       # Start with 0 until loops are available
	Block.BlockType.ABILITY: 0     # Start with 0 until abilities are available
}

var remaining_blocks: Dictionary = {
	Block.BlockType.CONDITION: 0,
	Block.BlockType.LOOP: 0,
	Block.BlockType.ABILITY: 0
}

# Track purchased abilities, conditions and loops
var purchased_abilities: Dictionary = {
	"+1 движ.": false,
	"+1 атака": false,
	"+1 защита": false,
	"+1 леч.": false
}

var purchased_conditions: Dictionary = {
	"здоровье < 50%": false
}

var purchased_loops: Dictionary = {
	"Повторить 2 раз": false,
	"Повторить 3 раз": false
}

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
		
# Get mapping of item types to ability/condition/loop names
func get_ability_name_for_item_type(item_type) -> String:
	match item_type:
		Item.ItemType.ABILITY_PLUS_MOVE:
			return "+1 движ."
		Item.ItemType.ABILITY_PLUS_ATTACK:
			return "+1 атака"
		Item.ItemType.ABILITY_PLUS_DEFENSE:
			return "+1 защита"
		Item.ItemType.ABILITY_PLUS_HEAL:
			return "+1 леч."
		Item.ItemType.CONDITION_BELOW_HALF_HP:
			return "здоровье < 50%"
		Item.ItemType.LOOP_2_TIMES:
			return "Повторить 2 раз"
		Item.ItemType.LOOP_3_TIMES:
			return "Повторить 3 раз"
		_:
			return ""

# Check if an ability has been purchased
func is_ability_purchased(ability_name: String) -> bool:
	return ability_name in purchased_abilities and purchased_abilities[ability_name]

# Check if a condition has been purchased
func is_condition_purchased(condition_name: String) -> bool:
	return condition_name in purchased_conditions and purchased_conditions[condition_name]

# Check if a loop has been purchased
func is_loop_purchased(loop_name: String) -> bool:
	return loop_name in purchased_loops and purchased_loops[loop_name]

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
	if Block.available_abilities.size() > 0 and block_limits[Block.BlockType.ABILITY] == 0:
		increase_block_limit(Block.BlockType.ABILITY)
	
	if Block.available_conditions.size() > 0 and block_limits[Block.BlockType.CONDITION] == 0:
		increase_block_limit(Block.BlockType.CONDITION)
	
	if Block.available_loops.size() > 0 and block_limits[Block.BlockType.LOOP] == 0:
		increase_block_limit(Block.BlockType.LOOP)

# Call this at startup to initialize the available lists
func _ready() -> void:
	update_available_block_types()
