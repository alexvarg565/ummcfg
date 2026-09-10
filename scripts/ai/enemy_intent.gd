class_name EnemyIntent
extends RefCounted


var actor: Unit

# Where the enemy was standing when this plan was created.
var planned_start_cell: Vector2i

# The individual grid cells the enemy plans to move through.
#
# The starting cell is NOT included.
#
# Example:
# Enemy begins at (1, 3)
# movement_path = [(2, 3), (3, 3)]
var movement_path: Array[Vector2i] = []

# The tile the enemy has committed to attacking.
var target_cell: Vector2i

var weapon: WeaponDefinition


func _init(
	new_actor: Unit,
	new_target_cell: Vector2i,
	new_weapon: WeaponDefinition
) -> void:
	actor = new_actor
	target_cell = new_target_cell
	weapon = new_weapon

	if actor != null:
		planned_start_cell = actor.grid_position


# ==================================================
# MOVEMENT PLAN
# ==================================================

func set_movement_path(
	new_path: Array[Vector2i]
) -> void:
	movement_path = new_path.duplicate()


func get_move_destination() -> Vector2i:
	if movement_path.is_empty():
		if actor != null:
			return actor.grid_position

		return planned_start_cell

	return movement_path[
		movement_path.size() - 1
	]


func has_planned_movement() -> bool:
	return not movement_path.is_empty()


# ==================================================
# PLAN TRANSLATION
# ==================================================

func translate_plan(
	offset: Vector2i
) -> void:
	if offset == Vector2i.ZERO:
		return

	planned_start_cell += offset
	target_cell += offset

	for index: int in range(
		movement_path.size()
	):
		movement_path[index] += offset
