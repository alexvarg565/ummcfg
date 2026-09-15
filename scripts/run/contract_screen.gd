extends Control


# ==================================================
# REFERENCES
# ==================================================

@onready var title_label: Label = \
	$Center/ContractPanel/Margin/VBox/TitleLabel

@onready var contract_list: VBoxContainer = \
	$Center/ContractPanel/Margin/VBox/ContractList

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


	_build_contract_list()

	_refresh_contract_details()


# ==================================================
# CONTRACT LIST
# ==================================================

func _build_contract_list() -> void:
	_clear_contract_list()


	var available_contracts: Array[ContractDefinition] = \
		RunManager.get_available_contracts()


	for contract: ContractDefinition in \
		available_contracts:

		if contract == null:
			continue


		var button: Button = \
			Button.new()


		button.focus_mode = \
			Control.FOCUS_NONE


		if contract == \
			RunManager.get_current_contract():

			button.text = \
				"[SELECTED] %s" \
				% contract.display_name

		else:

			button.text = \
				contract.display_name


		button.pressed.connect(
			_on_contract_selected.bind(
				contract
			)
		)


		contract_list.add_child(
			button
		)


func _clear_contract_list() -> void:
	for child: Node in \
		contract_list.get_children():

		child.queue_free()


# ==================================================
# CONTRACT SELECTION
# ==================================================

func _on_contract_selected(
	contract: ContractDefinition
) -> void:
	RunManager.select_contract(
		contract
	)


	_build_contract_list()

	_refresh_contract_details()


# ==================================================
# CONTRACT DETAILS
# ==================================================

func _refresh_contract_details() -> void:
	var contract: ContractDefinition = \
		RunManager.get_current_contract()


	title_label.text = \
		"AVAILABLE CONTRACTS"


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


# ==================================================
# MISSING CONTRACT
# ==================================================

func _show_missing_contract() -> void:
	contract_name_label.text = \
		"NO CONTRACT"


	description_label.text = \
		"No contract is currently selected."


	progress_label.text = \
		"Contracts Completed: %d\nSalvage: %d" % [
			RunManager.contracts_completed,
			RunManager.salvage
		]


	start_contract_button.text = \
		"UNAVAILABLE"


	start_contract_button.disabled = true


# ==================================================
# START CONTRACT
# ==================================================

func _on_start_contract_pressed() -> void:
	RunManager.start_contract()
