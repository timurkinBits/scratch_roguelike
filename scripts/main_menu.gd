extends CanvasLayer

@onready var buttons: VBoxContainer = $VBoxContainer
@onready var about: Label = $about

func _ready() -> void:
	about.visible = false

func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_close_game_pressed() -> void:
	get_tree().quit()


func _on_about_game_pressed() -> void:
	buttons.visible = false
	about.visible = true


func _on_close_about_game_pressed() -> void:
	buttons.visible = true
	about.visible = false
