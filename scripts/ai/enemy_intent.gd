class_name EnemyIntent
extends RefCounted


var actor: Unit
var target_cell: Vector2i
var weapon: WeaponDefinition


func _init(
	intent_actor: Unit,
	intent_target_cell: Vector2i,
	intent_weapon: WeaponDefinition
) -> void:
	actor = intent_actor
	target_cell = intent_target_cell
	weapon = intent_weapon
