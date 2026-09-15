class_name ContractDefinition
extends Resource


# ==================================================
# IDENTITY
# ==================================================

@export_group("Identity")

@export var contract_id: StringName = &""

@export var display_name: String = "Contract"

@export_multiline var description: String = ""


# ==================================================
# MISSION
# ==================================================

@export_group("Mission")

@export var battle_scene: PackedScene


# ==================================================
# REWARDS
# ==================================================

@export_group("Rewards")

@export_range(0, 9999, 1)
var salvage_reward: int = 0
