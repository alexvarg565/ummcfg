class_name Unit
extends Node2D


signal selected(unit: Unit)
signal health_changed(unit: Unit, current_health: int, max_health: int)
signal died(unit: Unit)

enum Team {
	PLAYER,
	ENEMY
}


@export_group("Identity")
@export var display_name: String = "Unit"
@export var team: Team = Team.PLAYER

@export_group("Stats")
@export var max_health: int = 10
@export var movement_range: int = 3
@export var initiative: int = 10

@export_group("Equipment")
@export var weapon: WeaponDefinition


var current_health: int = 0
var grid_position: Vector2i = Vector2i.ZERO

var is_selected: bool = false
var is_active: bool = false
var is_alive: bool = true

var has_moved: bool = false
var has_acted: bool = false
var has_used_bonus_action: bool = false


@onready var selection_outline: Polygon2D = \
	$VisualRoot/SelectionOutline

@onready var health_bar: ProgressBar = \
	$HealthBar


func _ready() -> void:
	current_health = max_health
	is_alive = true

	health_bar.max_value = max_health
	health_bar.value = current_health

	selection_outline.visible = false


func set_grid_position(cell: Vector2i) -> void:
	grid_position = cell

	position = Vector2(
		cell.x * GridController.TILE_SIZE,
		cell.y * GridController.TILE_SIZE
	)


func begin_activation() -> void:
	if not is_alive:
		return

	is_active = true

	has_moved = false
	has_acted = false
	has_used_bonus_action = false


func end_activation() -> void:
	is_active = false
	deselect()


func can_move() -> bool:
	return (
		is_alive
		and is_active
		and not has_moved
	)


func can_act() -> bool:
	return (
		is_alive
		and is_active
		and not has_acted
	)


func mark_moved() -> void:
	has_moved = true


func mark_acted() -> void:
	has_acted = true


func take_damage(amount: int) -> void:
	if not is_alive:
		return

	if amount <= 0:
		return

	current_health = maxi(
		current_health - amount,
		0
	)

	health_bar.value = current_health

	health_changed.emit(
		self,
		current_health,
		max_health
	)

	print(
		display_name,
		" now has ",
		current_health,
		"/",
		max_health,
		" HP."
	)

	if current_health <= 0:
		die()


func die() -> void:
	if not is_alive:
		return

	is_alive = false
	is_active = false

	deselect()

	print(display_name, " destroyed.")

	died.emit(self)


func select() -> void:
	if not is_alive:
		return

	is_selected = true
	selection_outline.visible = true

	selected.emit(self)


func deselect() -> void:
	is_selected = false
	selection_outline.visible = false


func is_player_unit() -> bool:
	return team == Team.PLAYER


func is_enemy_unit() -> bool:
	return team == Team.ENEMY
