class_name IntentHighlights
extends Node2D


const TARGET_COLOR := Color(1.0, 0.45, 0.1, 0.40)
const LINE_COLOR := Color(1.0, 0.60, 0.15, 0.90)

const LINE_WIDTH: float = 2.0
const ARROW_LENGTH: float = 7.0
const ARROW_WIDTH: float = 4.0

var intents: Array[EnemyIntent] = []


func show_intents(
	new_intents: Array[EnemyIntent]
) -> void:
	intents = new_intents.duplicate()
	queue_redraw()


func clear() -> void:
	intents.clear()
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	for intent: EnemyIntent in intents:
		if intent == null:
			continue

		if intent.actor == null:
			continue

		if not intent.actor.is_alive:
			continue

		_draw_target_cell(
			intent.target_cell
		)

		_draw_intent_line(
			intent.actor.grid_position,
			intent.target_cell
		)


func _draw_target_cell(
	cell: Vector2i
) -> void:
	var tile_size: float = \
		float(GridController.TILE_SIZE)

	var draw_position := Vector2(
		cell.x * tile_size,
		cell.y * tile_size
	)

	draw_rect(
		Rect2(
			draw_position,
			Vector2(
				tile_size,
				tile_size
			)
		),
		TARGET_COLOR,
		true
	)


func _draw_intent_line(
	source_cell: Vector2i,
	target_cell: Vector2i
) -> void:
	var source_center := \
		_get_cell_center(source_cell)

	var target_center := \
		_get_cell_center(target_cell)

	var direction: Vector2 = \
		target_center - source_center

	if direction.length_squared() == 0.0:
		return

	var normalized_direction: Vector2 = \
		direction.normalized()

	# Pull the line inward so it doesn't start/end
	# directly in the center of the unit sprites.
	var padding: float = 10.0

	var line_start: Vector2 = \
		source_center + (
			normalized_direction * padding
		)

	var line_end: Vector2 = \
		target_center - (
			normalized_direction * padding
		)

	draw_line(
		line_start,
		line_end,
		LINE_COLOR,
		LINE_WIDTH,
		false
	)

	_draw_arrow_head(
		line_end,
		normalized_direction
	)


func _draw_arrow_head(
	tip: Vector2,
	direction: Vector2
) -> void:
	var perpendicular := Vector2(
		-direction.y,
		direction.x
	)

	var base: Vector2 = \
		tip - (
			direction * ARROW_LENGTH
		)

	var left_point: Vector2 = \
		base + (
			perpendicular * ARROW_WIDTH
		)

	var right_point: Vector2 = \
		base - (
			perpendicular * ARROW_WIDTH
		)

	draw_line(
		tip,
		left_point,
		LINE_COLOR,
		LINE_WIDTH,
		false
	)

	draw_line(
		tip,
		right_point,
		LINE_COLOR,
		LINE_WIDTH,
		false
	)


func _get_cell_center(
	cell: Vector2i
) -> Vector2:
	var half_tile: float = \
		GridController.TILE_SIZE / 2.0

	return Vector2(
		cell.x * GridController.TILE_SIZE
			+ half_tile,
		cell.y * GridController.TILE_SIZE
			+ half_tile
	)
