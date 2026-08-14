class_name Unit
extends Node2D


signal selected(unit: Unit)

@export var display_name: String = "Test Mech"
@export var max_health: int = 10
@export var movement_range: int = 3

var current_health: int = 0
var grid_position: Vector2i = Vector2i.ZERO
var is_selected: bool = false

@onready var selection_outline: Polygon2D = \
	$VisualRoot/SelectionOutline

@onready var health_bar: ProgressBar = \
	$HealthBar


func _ready() -> void:
	current_health = max_health

	health_bar.max_value = max_health
	health_bar.value = current_health

	selection_outline.visible = false


func set_grid_position(cell: Vector2i) -> void:
	grid_position = cell

	position = Vector2(
		cell.x * GridController.TILE_SIZE,
		cell.y * GridController.TILE_SIZE
	)


func select() -> void:
	is_selected = true
	selection_outline.visible = true
	selected.emit(self)


func deselect() -> void:
	is_selected = false
	selection_outline.visible = false
