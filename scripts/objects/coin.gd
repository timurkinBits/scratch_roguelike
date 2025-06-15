# Modified coin.gd
extends ObjectRoom
class_name Coin

enum CoinType{
	SMALL,
	MIDDLE,
	BIG
}

const COINS = {
	CoinType.SMALL: {
		"icon": "res://sprites/small_coin.png",
		"value": 1
	},
	CoinType.MIDDLE: {
		"icon": "res://sprites/middle_coin.png",
		"value": 3
	},
	CoinType.BIG: {
		"icon": "res://sprites/big_coin.png",
		"value": 5
	}
}

# Default drop chances for regular enemies
const DEFAULT_DROP_CHANCES = {
	CoinType.SMALL: 70,
	CoinType.MIDDLE: 25,
	CoinType.BIG: 5
}

# Higher drop chances for elite enemies
const ELITE_DROP_CHANCES = {
	CoinType.SMALL: 30,
	CoinType.MIDDLE: 45,
	CoinType.BIG: 25
}

@onready var icon: Sprite2D = $Sprite2D

var type: CoinType = CoinType.SMALL

func _ready() -> void:
	super._ready()
	add_to_group('coins')  # Add to coins group for easy finding
	update_sprite()

func update_sprite() -> void:
	# Update sprite based on coin type
	icon.texture = load(COINS[type]['icon'])
	
func use():
	Global.add_coins(COINS[type]['value'])  # Add coin value to global counter
	queue_free()  # Remove the coin from the scene

# Static function to determine coin type based on chances
static func get_random_coin_type(is_elite: bool = false) -> int:
	var chances = DEFAULT_DROP_CHANCES if not is_elite else ELITE_DROP_CHANCES
	
	# Calculate total chance
	var total_chance = 0
	for coin_type in chances:
		total_chance += chances[coin_type]
	
	# Roll a random number
	var roll = randi() % total_chance
	
	# Determine which coin type was selected
	var current_sum = 0
	for coin_type in chances:
		current_sum += chances[coin_type]
		if roll < current_sum:
			return coin_type
	
	# Fallback to SMALL coin (should never happen unless chances are misconfigured)
	return CoinType.SMALL

# Function to set coin type
func set_type(new_type: int) -> void:
	type = new_type
	update_sprite()
