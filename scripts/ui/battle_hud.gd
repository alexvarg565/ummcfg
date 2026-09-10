class_name BattleHUD
extends CanvasLayer


signal attack_requested
signal end_turn_requested

signal result_continue_requested
signal result_restart_requested


# ==================================================
# TOP BAR
# ==================================================

@onready var round_label: Label = \
	$Root/TopBar/TopMargin/TopHBox/RoundLabel

@onready var initiative_bar: HBoxContainer = \
	$Root/TopBar/TopMargin/TopHBox/InitiativeBar


# ==================================================
# BOTTOM PANEL
# ==================================================

@onready var bottom_panel: PanelContainer = \
	$Root/BottomPanel

@onready var unit_name_label: Label = \
	$Root/BottomPanel/BottomMargin/BottomVBox/UnitNameLabel


# ==================================================
# UNIT STATS
# ==================================================

@onready var health_label: Label = \
	$Root/BottomPanel/BottomMargin/BottomVBox/StatsRow/HealthLabel

@onready var movement_label: Label = \
	$Root/BottomPanel/BottomMargin/BottomVBox/StatsRow/MovementLabel

@onready var initiative_label: Label = \
	$Root/BottomPanel/BottomMargin/BottomVBox/StatsRow/InitiativeLabel


# ==================================================
# WEAPON INFO
# ==================================================

@onready var weapon_label: Label = \
	$Root/BottomPanel/BottomMargin/BottomVBox/WeaponRow/WeaponLabel

@onready var damage_label: Label = \
	$Root/BottomPanel/BottomMargin/BottomVBox/WeaponRow/DamageLabel

@onready var range_label: Label = \
	$Root/BottomPanel/BottomMargin/BottomVBox/WeaponRow/RangeLabel


# ==================================================
# ACTION STATE
# ==================================================

@onready var move_state_label: Label = \
	$Root/BottomPanel/BottomMargin/BottomVBox/ActionStateRow/MoveStateLabel

@onready var action_state_label: Label = \
	$Root/BottomPanel/BottomMargin/BottomVBox/ActionStateRow/ActionStateLabel


# ==================================================
# BUTTONS
# ==================================================

@onready var attack_button: Button = \
	$Root/BottomPanel/BottomMargin/BottomVBox/ActionRow/AttackButton

@onready var end_turn_button: Button = \
	$Root/BottomPanel/BottomMargin/BottomVBox/ActionRow/EndTurnButton


# ==================================================
# OBJECTIVE PANEL
# ==================================================

@onready var objective_panel: PanelContainer = \
	$Root/ObjectivePanel

@onready var objective_title_label: Label = \
	$Root/ObjectivePanel/ObjectiveContainer/ObjectiveTitleLabel

@onready var objective_health_label: Label = \
	$Root/ObjectivePanel/ObjectiveContainer/ObjectiveHealthLabel


# ==================================================
# RESULTS OVERLAY
# ==================================================

@onready var results_overlay: ColorRect = \
	$Root/ResultsOverlay

@onready var result_title_label: Label = \
	$Root/ResultsOverlay/ResultsCenter/ResultsPanel/ResultsVBox/ResultTitleLabel

@onready var result_reason_label: Label = \
	$Root/ResultsOverlay/ResultsCenter/ResultsPanel/ResultsVBox/ResultReasonLabel

@onready var result_button: Button = \
	$Root/ResultsOverlay/ResultsCenter/ResultsPanel/ResultsVBox/ResultButton


# ==================================================
# RESULT STATE
# ==================================================

var result_was_win: bool = false


# ==================================================
# READY
# ==================================================

func _ready() -> void:
	attack_button.pressed.connect(
		_on_attack_button_pressed
	)

	end_turn_button.pressed.connect(
		_on_end_turn_button_pressed
	)

	result_button.pressed.connect(
		_on_result_button_pressed
	)

	# Prevent keyboard focus from accidentally
	# activating battle buttons.
	attack_button.focus_mode = \
		Control.FOCUS_NONE

	end_turn_button.focus_mode = \
		Control.FOCUS_NONE

	result_button.focus_mode = \
		Control.FOCUS_NONE

	objective_panel.visible = false

	results_overlay.visible = false


# ==================================================
# ROUND
# ==================================================

func set_round(
	round_number: int
) -> void:
	round_label.text = \
		"ROUND %d" % round_number


# ==================================================
# UNIT DISPLAY
# ==================================================

func show_unit(
	unit: Unit
) -> void:
	if unit == null:
		clear_unit()
		return

	bottom_panel.visible = true

	refresh_unit(
		unit
	)


func refresh_unit(
	unit: Unit
) -> void:
	if unit == null:
		clear_unit()
		return

	unit_name_label.text = \
		unit.display_name

	health_label.text = \
		"HP: %d / %d" % [
			unit.current_health,
			unit.max_health
		]

	movement_label.text = \
		"MOVE: %d" % unit.movement_range

	initiative_label.text = \
		"INIT: %d" % unit.initiative


	if unit.weapon != null:
		weapon_label.text = \
			unit.weapon.display_name

		damage_label.text = \
			"DAMAGE: %s" % \
			_get_damage_text(
				unit.weapon
			)

		range_label.text = \
			"RANGE: %d-%d" % [
				unit.weapon.min_range,
				unit.weapon.max_range
			]

	else:
		weapon_label.text = \
			"NO WEAPON"

		damage_label.text = \
			"DAMAGE: --"

		range_label.text = \
			"RANGE: --"


	_refresh_action_state(
		unit
	)


func clear_unit() -> void:
	unit_name_label.text = ""

	health_label.text = ""
	movement_label.text = ""
	initiative_label.text = ""

	weapon_label.text = ""
	damage_label.text = ""
	range_label.text = ""

	move_state_label.text = ""
	action_state_label.text = ""

	attack_button.disabled = true
	end_turn_button.disabled = true


# ==================================================
# PLAYER CONTROLS
# ==================================================

func refresh_player_controls(
	unit: Unit
) -> void:
	if unit == null:
		set_player_controls_enabled(
			false
		)

		return

	_refresh_action_state(
		unit
	)

	attack_button.disabled = \
		not unit.can_act()

	end_turn_button.disabled = false


func set_player_controls_enabled(
	enabled: bool
) -> void:
	attack_button.disabled = \
		not enabled

	end_turn_button.disabled = \
		not enabled


func _refresh_action_state(
	unit: Unit
) -> void:
	if unit == null:
		move_state_label.text = ""
		action_state_label.text = ""

		return

	if unit.can_move():
		move_state_label.text = \
			"MOVE: READY"

	else:
		move_state_label.text = \
			"MOVE: USED"


	if unit.can_act():
		action_state_label.text = \
			"ACTION: READY"

	else:
		action_state_label.text = \
			"ACTION: USED"


# ==================================================
# INITIATIVE DISPLAY
# ==================================================

func refresh_initiative(
	initiative_order: Array[Unit],
	active_unit: Unit
) -> void:
	for child: Node in \
		initiative_bar.get_children():

		child.queue_free()


	for unit: Unit in initiative_order:
		if unit == null:
			continue

		if not unit.is_alive:
			continue


		var label: Label = \
			Label.new()


		if unit == active_unit:
			label.text = \
				"[ %s ]" % unit.display_name

		else:
			label.text = \
				unit.display_name


		initiative_bar.add_child(
			label
		)


# ==================================================
# OBJECTIVE HUD
# ==================================================

func show_objective(
	title: String,
	_objective_name: String,
	current_health: int,
	max_health: int
) -> void:
	objective_panel.visible = true

	objective_title_label.text = \
		title

	objective_health_label.text = \
		"GENERATOR HP: %d / %d" % [
			current_health,
			max_health
		]


func update_objective_health(
	current_health: int,
	max_health: int
) -> void:
	objective_health_label.text = \
		"GENERATOR HP: %d / %d" % [
			current_health,
			max_health
		]


func clear_objective() -> void:
	objective_panel.visible = false


# ==================================================
# RESULTS OVERLAY
# ==================================================

func show_battle_result(
	player_won: bool,
	reason: String
) -> void:
	result_was_win = player_won

	results_overlay.visible = true


	if player_won:
		result_title_label.text = \
			"CONTRACT COMPLETE"

		result_button.text = \
			"CONTINUE"

	else:
		result_title_label.text = \
			"CONTRACT FAILED"

		result_button.text = \
			"RESTART"


	result_reason_label.text = \
		reason


func hide_battle_result() -> void:
	results_overlay.visible = false


# ==================================================
# BUTTON EVENTS
# ==================================================

func _on_attack_button_pressed() -> void:
	attack_requested.emit()


func _on_end_turn_button_pressed() -> void:
	end_turn_requested.emit()


func _on_result_button_pressed() -> void:
	if result_was_win:
		result_continue_requested.emit()

	else:
		result_restart_requested.emit()


# ==================================================
# DISPLAY HELPERS
# ==================================================

func _get_damage_text(
	weapon: WeaponDefinition
) -> String:
	if weapon == null:
		return "--"


	var text: String = \
		"%dd%d" % [
			weapon.damage_dice,
			weapon.damage_sides
		]


	if weapon.damage_bonus > 0:
		text += \
			"+%d" % weapon.damage_bonus

	elif weapon.damage_bonus < 0:
		text += \
			str(
				weapon.damage_bonus
			)


	return text
