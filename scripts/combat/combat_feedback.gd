class_name CombatFeedback
extends Node2D


const FLOAT_DISTANCE: float = 10.0
const FLOAT_DURATION: float = 0.55


func show_damage(
	cell: Vector2i,
	damage: int
) -> void:
	show_text(
		cell,
		"-%d" % damage
	)


func show_miss(
	cell: Vector2i
) -> void:
	show_text(
		cell,
		"MISS"
	)


func show_text(
	cell: Vector2i,
	text_value: String
) -> void:
	var label := Label.new()

	label.text = text_value

	label.horizontal_alignment = \
		HORIZONTAL_ALIGNMENT_CENTER

	label.vertical_alignment = \
		VERTICAL_ALIGNMENT_CENTER

	# Keep the feedback above normal battlefield elements.
	label.z_index = 50

	add_child(label)

	var start_position: Vector2 = \
		_get_feedback_position(cell)

	label.position = start_position

	# Give it roughly one tile of width so text
	# centers over the unit/tile.
	label.size = Vector2(
		GridController.TILE_SIZE,
		16
	)

	var tween: Tween = create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		label,
		"position:y",
		start_position.y - FLOAT_DISTANCE,
		FLOAT_DURATION
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		label,
		"modulate:a",
		0.0,
		FLOAT_DURATION
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN
	)

	tween.finished.connect(
		label.queue_free
	)


func _get_feedback_position(
	cell: Vector2i
) -> Vector2:
	return Vector2(
		cell.x * GridController.TILE_SIZE,
		cell.y * GridController.TILE_SIZE - 8
	)
