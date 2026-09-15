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
	var contract: ContractDefinition = \
		RunManager.get_current_contract()


	title_label.text = \
		"AVAILABLE CONTRACT"


	if contract == null:
		_show_missing_contract()
		return


	contract_name_label.text = \
		contract.display_name


	description_label.text = \
		contract.description


	progress_label.text = \
		"Reward: %d Salvage\nContracts Completed: %d\nSalvage: %d" % [
			contract.salvage_reward,
			RunManager.contracts_completed,
			RunManager.salvage
		]


	start_contract_button.text = \
		"START CONTRACT"

	start_contract_button.disabled = false


func _show_missing_contract() -> void:
	contract_name_label.text = \
		"NO CONTRACT"

	description_label.text = \
		"No contract is currently available."

	progress_label.text = \
		"Contracts Completed: %d\nSalvage: %d" % [
			RunManager.contracts_completed,
			RunManager.salvage
		]

	start_contract_button.text = \
		"UNAVAILABLE"

	start_contract_button.disabled = true


# ==================================================
# BUTTONS
# ==================================================

func _on_start_contract_pressed() -> void:
	RunManager.start_contract()
