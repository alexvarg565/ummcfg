class_name GridController
extends Node


const GRID_WIDTH: int = 8
const GRID_HEIGHT: int = 8
const TILE_SIZE: int = 32

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT
]


# Dynamic occupants such as mechs and enemies.
var occupied_tiles: Dictionary = {}

# Static battlefield objects such as mission
# structures.
var static_blockers: Dictionary = {}


# ==================================================
# GRID BOUNDS / COORDINATES
# ==================================================

func is_inside_grid(
	cell: Vector2i
) -> bool:
	return (
		cell.x >= 0
		and cell.x < GRID_WIDTH
		and cell.y >= 0
		and cell.y < GRID_HEIGHT
	)


func grid_to_world(
	cell: Vector2i
) -> Vector2:
	return Vector2(
		cell.x * TILE_SIZE,
		cell.y * TILE_SIZE
	)


func grid_to_world_center(
	cell: Vector2i
) -> Vector2:
	return grid_to_world(cell) + Vector2(
		TILE_SIZE / 2.0,
		TILE_SIZE / 2.0
	)


func world_to_grid(
	world_position: Vector2
) -> Vector2i:
	return Vector2i(
		floori(
			world_position.x / TILE_SIZE
		),
		floori(
			world_position.y / TILE_SIZE
		)
	)


# ==================================================
# GENERAL OCCUPANCY
# ==================================================

func is_occupied(
	cell: Vector2i
) -> bool:
	return (
		occupied_tiles.has(cell)
		or static_blockers.has(cell)
	)


# ==================================================
# UNIT OCCUPANCY
# ==================================================

func get_unit_at(
	cell: Vector2i
) -> Unit:
	return occupied_tiles.get(
		cell,
		null
	)


func register_unit(
	unit: Unit,
	cell: Vector2i
) -> bool:
	if unit == null:
		return false

	if not is_inside_grid(
		cell
	):
		return false

	if is_occupied(
		cell
	):
		return false

	occupied_tiles[cell] = unit

	unit.set_grid_position(
		cell
	)

	return true


func unregister_unit(
	unit: Unit
) -> void:
	if unit == null:
		return

	if occupied_tiles.get(
		unit.grid_position
	) == unit:
		occupied_tiles.erase(
			unit.grid_position
		)


func move_unit(
	unit: Unit,
	target_cell: Vector2i
) -> bool:
	if unit == null:
		return false

	if not is_inside_grid(
		target_cell
	):
		return false

	if is_occupied(
		target_cell
	):
		return false

	unregister_unit(
		unit
	)

	occupied_tiles[target_cell] = unit

	unit.set_grid_position(
		target_cell
	)

	return true


# ==================================================
# STATIC BLOCKERS
# ==================================================

func register_static_blocker(
	blocker: Node2D,
	cell: Vector2i
) -> bool:
	if blocker == null:
		return false

	if not is_inside_grid(
		cell
	):
		return false

	if is_occupied(
		cell
	):
		return false

	static_blockers[cell] = blocker

	return true


func unregister_static_blocker(
	cell: Vector2i
) -> void:
	static_blockers.erase(
		cell
	)


func get_static_blocker_at(
	cell: Vector2i
) -> Node2D:
	return static_blockers.get(
		cell,
		null
	)


# ==================================================
# MOVEMENT RANGE
# ==================================================

func get_reachable_cells(
	origin: Vector2i,
	movement_range: int
) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []

	var frontier: Array[Vector2i] = [
		origin
	]

	var distance_from_origin: Dictionary = {
		origin: 0
	}

	while not frontier.is_empty():
		var current: Vector2i = \
			frontier.pop_front()

		var current_distance: int = \
			distance_from_origin[current]

		if current_distance >= movement_range:
			continue

		for direction: Vector2i in \
			CARDINAL_DIRECTIONS:

			var next_cell: Vector2i = \
				current + direction

			if not is_inside_grid(
				next_cell
			):
				continue

			if distance_from_origin.has(
				next_cell
			):
				continue

			if is_occupied(
				next_cell
			):
				continue

			var next_distance: int = \
				current_distance + 1

			distance_from_origin[
				next_cell
			] = next_distance

			frontier.append(
				next_cell
			)

			reachable.append(
				next_cell
			)

	return reachable


# ==================================================
# PATHFINDING
# ==================================================

func get_shortest_path(
	origin: Vector2i,
	destination: Vector2i
) -> Array[Vector2i]:
	var empty_path: Array[Vector2i] = []

	if not is_inside_grid(
		origin
	):
		return empty_path

	if not is_inside_grid(
		destination
	):
		return empty_path

	if origin == destination:
		return empty_path

	if is_occupied(
		destination
	):
		return empty_path

	var frontier: Array[Vector2i] = [
		origin
	]

	var came_from: Dictionary = {
		origin: origin
	}

	var found_destination: bool = false

	while not frontier.is_empty():
		var current: Vector2i = \
			frontier.pop_front()

		if current == destination:
			found_destination = true
			break

		for direction: Vector2i in \
			CARDINAL_DIRECTIONS:

			var next_cell: Vector2i = \
				current + direction

			if not is_inside_grid(
				next_cell
			):
				continue

			if came_from.has(
				next_cell
			):
				continue

			if is_occupied(
				next_cell
			):
				continue

			came_from[next_cell] = \
				current

			frontier.append(
				next_cell
			)

	if not found_destination:
		return empty_path

	return _reconstruct_path(
		origin,
		destination,
		came_from
	)


func _reconstruct_path(
	origin: Vector2i,
	destination: Vector2i,
	came_from: Dictionary
) -> Array[Vector2i]:
	var reversed_path: Array[Vector2i] = []

	var current: Vector2i = \
		destination

	while current != origin:
		reversed_path.append(
			current
		)

		if not came_from.has(
			current
		):
			var empty_path: Array[Vector2i] = []
			return empty_path

		current = came_from[
			current
		]

	reversed_path.reverse()

	return reversed_path


# ==================================================
# ATTACK RANGE
# ==================================================

func get_cells_in_range(
	origin: Vector2i,
	min_range: int,
	max_range: int
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []

	for x: int in range(
		GRID_WIDTH
	):
		for y: int in range(
			GRID_HEIGHT
		):
			var cell: Vector2i = \
				Vector2i(
					x,
					y
				)

			if cell == origin:
				continue

			var distance: int = (
				absi(
					cell.x - origin.x
				)
				+ absi(
					cell.y - origin.y
				)
			)

			if distance < min_range:
				continue

			if distance > max_range:
				continue

			cells.append(
				cell
			)

	return cells
