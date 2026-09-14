extends Node


const CONTRACT_SCREEN_SCENE: String = \
	"res://scenes/run/contract_screen.tscn"

const BATTLE_SCENE: String = \
	"res://scenes/battle/battle.tscn"


var contracts_completed: int = 0


# ==================================================
# CONTRACT FLOW
# ==================================================

func start_contract() -> void:
	get_tree().change_scene_to_file(
		BATTLE_SCENE
	)


func complete_contract() -> void:
	contracts_completed += 1

	go_to_contract_screen()


func go_to_contract_screen() -> void:
	get_tree().change_scene_to_file(
		CONTRACT_SCREEN_SCENE
	)


# ==================================================
# RUN RESET
# ==================================================

func reset_run() -> void:
	contracts_completed = 0

	go_to_contract_screen()
