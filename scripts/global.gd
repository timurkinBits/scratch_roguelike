extends Node

signal points_changed

var points: Dictionary = {
	Command.TypeCommand.MOVE: 10,
	Command.TypeCommand.ATTACK: 10,
	Command.TypeCommand.HEAL: 3,
	Command.TypeCommand.DEFENSE: 3
}

var remaining_move_points: int
var remaining_attack_points: int
var remaining_heal_points: int
var remaining_defense_points: int

var block_limits: Dictionary = {
	Block.BlockType.CONDITION: 1,
	Block.BlockType.LOOP: 1,
	Block.BlockType.ABILITY: 1
}

var remaining_blocks: Dictionary = {}

func reset_remaining_points() -> void:
	remaining_move_points = points[Command.TypeCommand.MOVE]
	remaining_attack_points = points[Command.TypeCommand.ATTACK]
	remaining_heal_points = points[Command.TypeCommand.HEAL]
	remaining_defense_points = points[Command.TypeCommand.DEFENSE]
	
	points_changed.emit()

func reset_remaining_blocks():
	for block_type in block_limits:
		remaining_blocks[block_type] = block_limits[block_type]
		
# Получить оставшиеся очки для конкретного типа команды
func get_remaining_points(command_type) -> int:
	match command_type:
		Command.TypeCommand.MOVE: return remaining_move_points
		Command.TypeCommand.ATTACK: return remaining_attack_points
		Command.TypeCommand.HEAL: return remaining_heal_points
		Command.TypeCommand.DEFENSE: return remaining_defense_points
		_: return 100

# Изменить оставшиеся очки для конкретного типа команды
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

# Вернуть очки в общий пул
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
