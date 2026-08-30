extends Drivable

## Temporary placeholder car for the foundation smoke test ONLY. Reads raw
## input directly instead of going through a real input system, and applies
## crude forces instead of real suspension/tire physics.
##
## Delete this once scripts/vehicle/ and scripts/input/ have real
## implementations — it exists purely to prove the Drivable/RaceManager/
## checkpoint seam works end to end. Not part of any claimable work unit.

const FORWARD_FORCE := 12.0
const STEER_TORQUE := 4.0

func _physics_process(_delta: float) -> void:
	var throttle := Input.get_axis("ui_down", "ui_up")
	var steer := Input.get_axis("ui_left", "ui_right")
	apply_input(steer, throttle, 0.0)

func apply_input(steer: float, throttle: float, _brake: float) -> void:
	apply_central_force(-global_transform.basis.z * throttle * FORWARD_FORCE)
	apply_torque(Vector3.UP * steer * STEER_TORQUE)
