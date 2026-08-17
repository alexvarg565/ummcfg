class_name InitiativeController
extends Node


func build_order(units: Array[Unit]) -> Array[Unit]:
	var ordered_units: Array[Unit] = []

	for unit: Unit in units:
		if unit != null:
			ordered_units.append(unit)

	ordered_units.sort_custom(_sort_by_initiative)

	return ordered_units


func _sort_by_initiative(a: Unit, b: Unit) -> bool:
	if a.initiative == b.initiative:
		return a.display_name < b.display_name

	return a.initiative > b.initiative
