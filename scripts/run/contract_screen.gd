extends Control


@onready var title_label: Label = \
	$Center/ContractPanel/Margin/VBox/TitleLabel

@onready var contract_name_label: Label = \
	$Center/ContractPanel/Margin/VBox/ContractNameLabel

@onready var description_label: Label = \
	$Center/ContractPanel/Margin/VBox/DescriptionLabel

@onready var progress_label: Label = \
	$Center/ContractPanel/Margin/VBox/ProgressLabel

@onready var start_contract_button: Button = \
	$Center/ContractPanel/Margin/VBox/StartContractButton


# ==================================================
# READY
# ==================================================

func _ready() -> void:
	start_contract_button.focus_mode = \
		Control.FOCUS_NONE

	start_contract_button.pressed.connect(
		_on_start_contract_pressed
	)

	_refresh_screen()


# ==================================================
# DISPLAY
# ==================================================

func _refresh_screen() -> void:
	title_label.text = \
		"AVAILABLE CONTRACT"

	contract_name_label.text = \
		"SETTLEMENT DEFENSE"

	description_label.text = \
		"Protect the generator and destroy all attackers."

	progress_label.text = \
		"Contracts Completed: %d" \
		% RunManager.contracts_completed

	start_contract_button.text = \
		"START CONTRACT"


# ==================================================
# BUTTONS
# ==================================================

func _on_start_contract_pressed() -> void:
	RunManager.start_contract()
