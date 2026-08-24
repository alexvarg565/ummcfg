class_name BattleHUD
extends CanvasLayer


signal attack_requested
signal end_turn_requested


@onready var round_label: Label = \
	$Root/TopBar/TopMargin/TopHBox/RoundLabel

@onready var initiative_bar: HBoxContainer = \
	$Root/TopBar/TopMargin/TopHBox/InitiativeBar

@onready var unit_name_label: Label = \
	$Root/BottomPanel/BottomMargin/BottomVBox/UnitNameLabel

@onready var health_label: Label = \
	$Root/BottomPanel/BottomMargin/BottomVBox/StatsRow/HealthLabel

@onready var movement_label: Label = \
	$Root/BottomPanel/BottomMargin/BottomVBox/StatsRow/MovementLabel

@onready var initiative_label: Label = \
	$Root/BottomPanel/BottomMargin/BottomVBox/StatsRow/InitiativeLabel

@onready var weapon_label: Label = \
	$Root/BottomPanel/BottomMargin/BottomVBox/WeaponRow/WeaponLabel

@onready var damage_label: Label = \
	$Root/BottomPanel/BottomMargin/BottomVBox/WeaponRow/DamageLabel

@onready var range_label: Label = \
	$Root/BottomPanel/BottomMargin/BottomVBox/WeaponRow/RangeLabel

@onready var move_state_label: Label = \
	$Root/BottomPanel/BottomMargin/BottomVBox/ActionStateRow/MoveStateLabel

@onready var action_state_label: Label = \
	$Root/BottomPanel/BottomMargin/BottomVBox/ActionStateRow/ActionStateLabel

@onready var attack_button: Button = \
	$Root/BottomPanel/BottomMargin/BottomVBox/ActionRow/AttackButton

@onready var end_turn_button: Button = \
	$Root/BottomPanel/BottomMargin/BottomVBox/ActionRow/EndTurnButton


func _ready() -> void:
	attack_button.focus_mode = Control.FOCUS_NONE
	end_turn_button.focus_mode = Control.FOCUS_NONE

	attack_button.pressed.connect(
		_on_attack_button_pressed
	)

	end_turn_button.pressed.connect(
		_on_end_turn_button_pressed
	)

	clear_unit()
	set_player_controls_enabled(false)

# ==================================================
# BUTTONS
# ==================================================

func _on_attack_button_pressed() -> void:
	attack_requested.emit()


func _on_end_turn_button_pressed() -> void:
	end_turn_requested.emit()


# ==================================================
# ROUND
# ==================================================

func set_round(round_number: int) -> void:
	round_label.text = "ROUND %d" % round_number


# ==================================================
# INITIATIVE
# ==================================================

func set_initiative_order(
	units: Array[Unit],
	active_unit: Unit
) -> void:
	_clear_initiative_bar()

	for unit: Unit in units:
		if unit == null:
			continue

		if not unit.is_alive:
			continue

		var label: Label = Label.new()

		if unit == active_unit:
			label.text = "> %s %d" % [
				unit.display_name,
				unit.initiative
			]
		else:
			label.text = "%s %d" % [
				unit.display_name,
				unit.initiative
			]

		initiative_bar.add_child(label)


func refresh_initiative(
	units: Array[Unit],
	active_unit: Unit
) -> void:
	set_initiative_order(
		units,
		active_unit
	)


func _clear_initiative_bar() -> void:
	for child: Node in initiative_bar.get_children():
		child.queue_free()


# ==================================================
# ACTIVE UNIT
# ==================================================

func show_unit(unit: Unit) -> void:
	if unit == null:
		clear_unit()
		return

	unit_name_label.text = unit.display_name

	health_label.text = "HP %d/%d" % [
		unit.current_health,
		unit.max_health
	]

	movement_label.text = "MOVE %d" % \
		unit.movement_range

	initiative_label.text = "INIT %d" % \
		unit.initiative

	_refresh_action_state(unit)

	if unit.is_player_unit():
		refresh_player_controls(unit)
	else:
		set_player_controls_enabled(false)

	if unit.weapon == null:
		weapon_label.text = "NO WEAPON"
		damage_label.text = ""
		range_label.text = ""
		return

	weapon_label.text = \
		unit.weapon.display_name

	damage_label.text = "DMG %dd%d" % [
		unit.weapon.damage_dice,
		unit.weapon.damage_sides
	]

	if unit.weapon.damage_bonus > 0:
		damage_label.text += "+%d" % \
			unit.weapon.damage_bonus

	elif unit.weapon.damage_bonus < 0:
		damage_label.text += "%d" % \
			unit.weapon.damage_bonus

	range_label.text = "RNG %d-%d" % [
		unit.weapon.min_range,
		unit.weapon.max_range
	]


func refresh_unit(unit: Unit) -> void:
	show_unit(unit)


func _refresh_action_state(unit: Unit) -> void:
	if unit == null:
		move_state_label.text = ""
		action_state_label.text = ""
		return

	if not unit.is_player_unit():
		move_state_label.text = ""
		action_state_label.text = ""
		return

	if unit.has_moved:
		move_state_label.text = "MOVE: USED"
	else:
		move_state_label.text = "MOVE: READY"

	if unit.has_acted:
		action_state_label.text = "ACTION: USED"
	else:
		action_state_label.text = "ACTION: READY"


func clear_unit() -> void:
	unit_name_label.text = "NO ACTIVE UNIT"

	health_label.text = ""
	movement_label.text = ""
	initiative_label.text = ""

	weapon_label.text = ""
	damage_label.text = ""
	range_label.text = ""

	move_state_label.text = ""
	action_state_label.text = ""


# ==================================================
# CONTROLS
# ==================================================

func set_player_controls_enabled(
	enabled: bool
) -> void:
	attack_button.disabled = not enabled
	end_turn_button.disabled = not enabled


func refresh_player_controls(
	unit: Unit
) -> void:
	if unit == null:
		set_player_controls_enabled(false)
		return

	if not unit.is_player_unit():
		set_player_controls_enabled(false)
		return

	end_turn_button.disabled = false
	attack_button.disabled = not unit.can_act()
