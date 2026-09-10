class_name IntentHighlights
extends Node2D


# ==================================================
# VISUAL SETTINGS
# ==================================================

const MOVE_COLOR: Color = Color(
	1.0,
	0.72,
	0.15,
	0.90
)

const ATTACK_COLOR: Color = Color(
	1.0,
	0.30,
	0.12,
	0.95
)

const TARGET_FILL_COLOR: Color = Color(
	1.0,
	0.25,
	0.10,
	0.35
)

const TARGET_BORDER_COLOR: Color = Color(
	1.0,
	0.40,
	0.15,
	0.95
)

const MOVE_LINE_WIDTH: float = 2.0
const ATTACK_LINE_WIDTH: float = 2.0

const ARROW_LENGTH: float = 6.0
const ARROW_WIDTH: float = 3.0


# ==================================================
# INTENT DATA
# ==================================================

var intents: Array[EnemyIntent] = []


# ==================================================
# PUBLIC API
# ==================================================

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


# ==================================================
# DRAWING
# ==================================================

func _draw() -> void:
	for intent: EnemyIntent in intents:
		if intent == null:
			continue

		if intent.actor == null:
			continue

		if not intent.actor.is_alive:
			continue

		_draw_intent(
			intent
		)


func _draw_intent(
	intent: EnemyIntent
) -> void:
	var actor_cell: Vector2i = \
		intent.actor.grid_position

	var remaining_movement: Array[Vector2i] = \
		_get_remaining_movement_path(
			intent,
			actor_cell
		)

	var attack_origin: Vector2i = \
		actor_cell

	# --------------------------------------------------
	# MOVEMENT PLAN
	# --------------------------------------------------

	if not remaining_movement.is_empty():
		_draw_movement_path(
			actor_cell,
			remaining_movement
		)

		attack_origin = remaining_movement[
			remaining_movement.size() - 1
		]

	# --------------------------------------------------
	# ATTACK PLAN
	# --------------------------------------------------

	_draw_attack_path(
		attack_origin,
		intent.target_cell
	)

	_draw_target_cell(
		intent.target_cell
	)


# ==================================================
# MOVEMENT PATH
# ==================================================

func _draw_movement_path(
	start_cell: Vector2i,
	path: Array[Vector2i]
) -> void:
	var previous_cell: Vector2i = \
		start_cell

	for next_cell: Vector2i in path:
		_draw_cardinal_segment(
			previous_cell,
			next_cell,
			MOVE_COLOR,
			MOVE_LINE_WIDTH
		)

		previous_cell = next_cell


func _get_remaining_movement_path(
	intent: EnemyIntent,
	current_cell: Vector2i
) -> Array[Vector2i]:
	var remaining: Array[Vector2i] = []

	if intent.movement_path.is_empty():
		return remaining

	# The enemy has not moved yet.
	if current_cell == intent.planned_start_cell:
		return intent.movement_path.duplicate()

	# If the enemy has already moved through part
	# of its planned path, only draw what remains.
	var current_index: int = \
		intent.movement_path.find(
			current_cell
		)

	if current_index < 0:
		return remaining

	var next_index: int = \
		current_index + 1

	while next_index < intent.movement_path.size():
		remaining.append(
			intent.movement_path[next_index]
		)

		next_index += 1

	return remaining


# ==================================================
# ATTACK PATH
# ==================================================

func _draw_attack_path(
	origin: Vector2i,
	target: Vector2i
) -> void:
	if origin == target:
		return

	var attack_path: Array[Vector2i] = \
		_build_cardinal_attack_path(
			origin,
			target
		)

	var previous_cell: Vector2i = \
		origin

	for next_cell: Vector2i in attack_path:
		_draw_cardinal_segment(
			previous_cell,
			next_cell,
			ATTACK_COLOR,
			ATTACK_LINE_WIDTH
		)

		previous_cell = next_cell


func _build_cardinal_attack_path(
	origin: Vector2i,
	target: Vector2i
) -> Array[Vector2i]:
	var path: Array[Vector2i] = []

	var current: Vector2i = \
		origin

	var x_distance: int = \
		absi(
			target.x - current.x
		)

	var y_distance: int = \
		absi(
			target.y - current.y
		)

	# Draw along the larger axis first.
	#
	# This keeps the visualization predictable
	# while ensuring every segment is strictly:
	#
	# ↑ ↓ ← →
	if x_distance >= y_distance:
		current = _append_horizontal_steps(
			path,
			current,
			target
		)

		current = _append_vertical_steps(
			path,
			current,
			target
		)

	else:
		current = _append_vertical_steps(
			path,
			current,
			target
		)

		current = _append_horizontal_steps(
			path,
			current,
			target
		)

	return path


func _append_horizontal_steps(
	path: Array[Vector2i],
	start: Vector2i,
	target: Vector2i
) -> Vector2i:
	var current: Vector2i = \
		start

	while current.x != target.x:
		var step_x: int = 0

		if target.x > current.x:
			step_x = 1

		elif target.x < current.x:
			step_x = -1

		current += Vector2i(
			step_x,
			0
		)

		path.append(
			current
		)

	return current


func _append_vertical_steps(
	path: Array[Vector2i],
	start: Vector2i,
	target: Vector2i
) -> Vector2i:
	var current: Vector2i = \
		start

	while current.y != target.y:
		var step_y: int = 0

		if target.y > current.y:
			step_y = 1

		elif target.y < current.y:
			step_y = -1

		current += Vector2i(
			0,
			step_y
		)

		path.append(
			current
		)

	return current


# ==================================================
# CARDINAL SEGMENTS
# ==================================================

func _draw_cardinal_segment(
	from_cell: Vector2i,
	to_cell: Vector2i,
	color: Color,
	line_width: float
) -> void:
	if from_cell == to_cell:
		return

	var difference: Vector2i = \
		to_cell - from_cell

	# Stored movement paths should already be
	# cardinal. This protects the renderer from
	# accidentally drawing a diagonal line.
	if (
		difference.x != 0
		and difference.y != 0
	):
		return

	var start_position: Vector2 = \
		_cell_center(
			from_cell
		)

	var end_position: Vector2 = \
		_cell_center(
			to_cell
		)

	draw_line(
		start_position,
		end_position,
		color,
		line_width,
		false
	)

	_draw_arrowhead(
		start_position,
		end_position,
		color,
		line_width
	)


func _draw_arrowhead(
	start_position: Vector2,
	end_position: Vector2,
	color: Color,
	line_width: float
) -> void:
	var segment: Vector2 = \
		end_position - start_position

	if segment.length_squared() <= 0.0:
		return

	var direction: Vector2 = \
		segment.normalized()

	var perpendicular: Vector2 = \
		Vector2(
			-direction.y,
			direction.x
		)

	# Place the arrow inside the tile-to-tile
	# segment rather than directly over the unit.
	var arrow_tip: Vector2 = \
		start_position.lerp(
			end_position,
			0.72
		)

	var arrow_base: Vector2 = \
		arrow_tip - (
			direction * ARROW_LENGTH
		)

	var left_point: Vector2 = \
		arrow_base + (
			perpendicular * ARROW_WIDTH
		)

	var right_point: Vector2 = \
		arrow_base - (
			perpendicular * ARROW_WIDTH
		)

	draw_line(
		arrow_tip,
		left_point,
		color,
		line_width,
		false
	)

	draw_line(
		arrow_tip,
		right_point,
		color,
		line_width,
		false
	)


# ==================================================
# TARGET CELL
# ==================================================

func _draw_target_cell(
	cell: Vector2i
) -> void:
	var tile_size: float = \
		float(
			GridController.TILE_SIZE
		)

	var cell_position := Vector2(
		cell.x * tile_size,
		cell.y * tile_size
	)

	var target_rect := Rect2(
		cell_position,
		Vector2(
			tile_size,
			tile_size
		)
	)

	draw_rect(
		target_rect,
		TARGET_FILL_COLOR,
		true
	)

	draw_rect(
		target_rect,
		TARGET_BORDER_COLOR,
		false,
		2.0
	)


# ==================================================
# COORDINATE HELPERS
# ==================================================

func _cell_center(
	cell: Vector2i
) -> Vector2:
	var tile_size: float = \
		float(
			GridController.TILE_SIZE
		)

	return Vector2(
		cell.x * tile_size
			+ tile_size / 2.0,

		cell.y * tile_size
			+ tile_size / 2.0
	)
