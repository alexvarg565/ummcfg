class_name WeaponDefinition
extends Resource


@export_group("Identity")
@export var display_name: String = "Test Cannon"

@export_group("Range")
@export var min_range: int = 1
@export var max_range: int = 3

@export_group("Damage")
@export var damage_dice: int = 1
@export var damage_sides: int = 6
@export var damage_bonus: int = 0

@export_group("Effects")
@export_range(0, 4, 1) var push_distance: int = 0
