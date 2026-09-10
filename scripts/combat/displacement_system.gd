class_name DisplacementSystem
extends Node


const PUSH_DURATION: float = 0.14


@onready var grid_controller: GridController = \
	$"../GridController"


func try_push(
	attacker: Unit,
	target: Unit,
	distance: int
) -> bool:
	if attacker == null:
		return false

	if target == null:
		return false

	if not attacker.is_alive:
		return false

	if not target.is_alive:
		return false

	if distance <= 0:
		return false

	var direction: Vector2i = \
		get_push_direction(
			attacker.grid_position,
			target.grid_position
		)

	if direction == Vector2i.ZERO:
		return false

	var destination: Vector2i = \
		target.grid_position

	for _step: int in range(
		distance
	):
		var next_cell: Vector2i = \
			destination + direction

		if not grid_controller.is_inside_grid(
			next_cell
		):
			return false

		if grid_controller.is_occupied(
			next_cell
		):
			return false

		destination = next_cell

	if destination == target.grid_position:
		return false

	# Save the current rendered position before
	# GridController updates the logical position.
	var old_visual_position: Vector2 = \
		target.position

	var moved: bool = \
		grid_controller.move_unit(
			target,
			destination
		)

	if not moved:
		return false

	# GridController has now:
	#
	# 1. updated occupancy
	# 2. updated target.grid_position
	# 3. snapped target.position to the new cell
	#
	# Save that correct final position.
	var new_visual_position: Vector2 = \
		target.position

	# Temporarily put the sprite back where it
	# visually started.
	target.position = \
		old_visual_position

	_animate_push(
		target,
		new_visual_position
	)

	return true


func get_push_direction(
	attacker_cell: Vector2i,
	target_cell: Vector2i
) -> Vector2i:
	var delta: Vector2i = \
		target_cell - attacker_cell

	# Push is cardinal only.
	#
	# A diagonal relationship currently deals
	# damage normally but produces no displacement.
	if (
		delta.x != 0
		and delta.y != 0
	):
		return Vector2i.ZERO

	if delta.x > 0:
		return Vector2i.RIGHT

	if delta.x < 0:
		return Vector2i.LEFT

	if delta.y > 0:
		return Vector2i.DOWN

	if delta.y < 0:
		return Vector2i.UP

	return Vector2i.ZERO


func _animate_push(
	target: Unit,
	destination_position: Vector2
) -> void:
	if target == null:
		return

	var tween: Tween = \
		create_tween()

	tween.tween_property(
		target,
		"position",
		destination_position,
		PUSH_DURATION
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)
