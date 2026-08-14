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

var occupied_tiles: Dictionary = {}


func is_inside_grid(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.x < GRID_WIDTH
		and cell.y >= 0
		and cell.y < GRID_HEIGHT
	)


func grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * TILE_SIZE,
		cell.y * TILE_SIZE
	)


func grid_to_world_center(cell: Vector2i) -> Vector2:
	return grid_to_world(cell) + Vector2(
		TILE_SIZE / 2.0,
		TILE_SIZE / 2.0
	)


func world_to_grid(world_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_position.x / TILE_SIZE),
		floori(world_position.y / TILE_SIZE)
	)


func is_occupied(cell: Vector2i) -> bool:
	return occupied_tiles.has(cell)


func get_unit_at(cell: Vector2i) -> Unit:
	return occupied_tiles.get(cell, null)


func register_unit(unit: Unit, cell: Vector2i) -> bool:
	if not is_inside_grid(cell):
		return false

	if is_occupied(cell):
		return false

	occupied_tiles[cell] = unit
	unit.set_grid_position(cell)

	return true


func unregister_unit(unit: Unit) -> void:
	if occupied_tiles.get(unit.grid_position) == unit:
		occupied_tiles.erase(unit.grid_position)


func move_unit(unit: Unit, target_cell: Vector2i) -> bool:
	if not is_inside_grid(target_cell):
		return false

	if is_occupied(target_cell):
		return false

	unregister_unit(unit)

	occupied_tiles[target_cell] = unit
	unit.set_grid_position(target_cell)

	return true


func get_reachable_cells(
	origin: Vector2i,
	movement_range: int
) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = []

	var frontier: Array[Vector2i] = [origin]

	var distance_from_origin: Dictionary = {
		origin: 0
	}

	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var current_distance: int = distance_from_origin[current]

		if current_distance >= movement_range:
			continue

		for direction: Vector2i in CARDINAL_DIRECTIONS:
			var next_cell: Vector2i = current + direction

			if not is_inside_grid(next_cell):
				continue

			if distance_from_origin.has(next_cell):
				continue

			if is_occupied(next_cell):
				continue

			var next_distance: int = current_distance + 1

			distance_from_origin[next_cell] = next_distance
			frontier.append(next_cell)
			reachable.append(next_cell)

	return reachable
