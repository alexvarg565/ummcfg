extends Node


const CONTRACT_SCREEN_SCENE: String = \
	"res://scenes/run/contract_screen.tscn"

const BATTLE_SCENE: String = \
	"res://scenes/battle/battle.tscn"


# ==================================================
# TEMPORARY CONTRACT DATA
# ==================================================
#
# Once we create proper ContractDefinition resources,
# rewards will live there instead.
#
# For now Settlement Defense is our only contract,
# so a fixed reward keeps the system simple.
# ==================================================

const SETTLEMENT_DEFENSE_SALVAGE_REWARD: int = 25


# ==================================================
# RUN STATE
# ==================================================

var contracts_completed: int = 0
var salvage: int = 0


# ==================================================
# CONTRACT FLOW
# ==================================================

func start_contract() -> void:
	get_tree().change_scene_to_file(
		BATTLE_SCENE
	)


func complete_contract() -> void:
	contracts_completed += 1

	add_salvage(
		SETTLEMENT_DEFENSE_SALVAGE_REWARD
	)

	go_to_contract_screen()


func go_to_contract_screen() -> void:
	get_tree().change_scene_to_file(
		CONTRACT_SCREEN_SCENE
	)


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

	go_to_contract_screen()
