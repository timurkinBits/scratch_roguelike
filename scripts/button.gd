extends Node2D

@onready var key_edit: LineEdit = $LineEdit

var key: int = 0

func _ready() -> void:
	key_edit.visible = false
	key_edit.text = ""
