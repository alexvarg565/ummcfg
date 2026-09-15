extends Node


const CONTRACT_SCREEN_SCENE: String = \
	"res://scenes/run/contract_screen.tscn"


# ==================================================
# CONTRACT DATA
# ==================================================

const SETTLEMENT_DEFENSE: ContractDefinition = \
	preload(
		"res://data/contracts/settlement_defense.tres"
	)

const TEST_CONTRACT: ContractDefinition = \
	preload(
		"res://data/contracts/test_contract.tres"
	)


var available_contracts: Array[ContractDefinition] = []

var current_contract: ContractDefinition = null


# ==================================================
# RUN STATE
# ==================================================

var contracts_completed: int = 0

var salvage: int = 0


# ==================================================
# READY
# ==================================================

func _ready() -> void:
	_setup_available_contracts()


# ==================================================
# CONTRACT SETUP
# ==================================================

func _setup_available_contracts() -> void:
	available_contracts.clear()

	available_contracts.append(
		SETTLEMENT_DEFENSE
	)

	available_contracts.append(
		TEST_CONTRACT
	)


	# Default to Settlement Defense when starting
	# a fresh run.
	if current_contract == null:
		current_contract = \
			SETTLEMENT_DEFENSE


# ==================================================
# CONTRACT SELECTION
# ==================================================

func select_contract(
	contract: ContractDefinition
) -> void:
	if contract == null:
		return

	if contract not in available_contracts:
		push_error(
			"Cannot select contract: contract is not available."
		)

		return

	current_contract = contract


func get_current_contract() -> ContractDefinition:
	return current_contract


func get_available_contracts() -> Array[ContractDefinition]:
	return available_contracts


# ==================================================
# CONTRACT FLOW
# ==================================================

func start_contract() -> void:
	if current_contract == null:
		push_error(
			"Cannot start contract: no contract selected."
		)

		return


	if current_contract.battle_scene == null:
		push_error(
			"Cannot start contract: selected contract has no battle scene."
		)

		return


	get_tree().change_scene_to_packed(
		current_contract.battle_scene
	)


func complete_contract() -> void:
	if current_contract == null:
		push_error(
			"Cannot complete contract: no current contract."
		)

		return


	contracts_completed += 1


	add_salvage(
		current_contract.salvage_reward
	)


	go_to_contract_screen()


func go_to_contract_screen() -> void:
	get_tree().change_scene_to_file(
		CONTRACT_SCREEN_SCENE
	)


# ==================================================
# CONTRACT INFORMATION
# ==================================================

func get_current_salvage_reward() -> int:
	if current_contract == null:
		return 0

	return current_contract.salvage_reward


# ==================================================
# SALVAGE
# ==================================================

func add_salvage(
	amount: int
) -> void:
	if amount <= 0:
		return

	salvage += amount


# ==================================================
# RUN RESET
# ==================================================

func reset_run() -> void:
	contracts_completed = 0

	salvage = 0

	current_contract = \
		SETTLEMENT_DEFENSE

	go_to_contract_screen()
