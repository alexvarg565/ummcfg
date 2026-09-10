class_name ObjectiveStructure
extends Node2D


signal health_changed(
	structure: ObjectiveStructure,
	current_health: int,
	max_health: int
)

signal destroyed(
	structure: ObjectiveStructure
)


@export var display_name: String = "Settlement Generator"
@export var max_health: int = 15


var current_health: int = 0
var grid_position: Vector2i = Vector2i.ZERO
var is_destroyed: bool = false


# ==================================================
# READY
# ==================================================

func _ready() -> void:
	current_health = max_health
	is_destroyed = false


# ==================================================
# GRID POSITION
# ==================================================

func set_grid_position(
	cell: Vector2i
) -> void:
	grid_position = cell

	position = Vector2(
		cell.x * GridController.TILE_SIZE,
		cell.y * GridController.TILE_SIZE
	)


# ==================================================
# DAMAGE
# ==================================================

func take_damage(
	damage: int
) -> void:
	if is_destroyed:
		return

	if damage <= 0:
		return

	current_health = maxi(
		current_health - damage,
		0
	)

	health_changed.emit(
		self,
		current_health,
		max_health
	)

	if current_health <= 0:
		_destroy()


func _destroy() -> void:
	if is_destroyed:
		return

	is_destroyed = true

	destroyed.emit(
		self
	)

	visible = false
