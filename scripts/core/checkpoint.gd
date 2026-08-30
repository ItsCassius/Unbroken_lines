extends Area3D

## Generic checkpoint trigger — wires a placed Area3D to RaceManager.
## Foundation glue only: real track layout/geometry/surface data is
## scripts/track/'s job (see design_principles.md §3); this exists so that
## unit doesn't have to invent the RaceManager wiring from scratch.

@export var checkpoint_id: int = 0
@export var is_finish_line: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body is Drivable:
		return
	if is_finish_line:
		RaceManager.finish_race()
	else:
		RaceManager.report_checkpoint(checkpoint_id)
