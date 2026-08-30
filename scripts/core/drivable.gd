class_name Drivable
extends RigidBody3D

## Contract every drivable vehicle implements — see design_principles.md §1a.
## Concrete vehicles (scripts/vehicle/*.gd) extend this and override
## apply_input(); nothing outside a Drivable subclass should reach into its
## internals directly — read state through this contract, not a specific
## car script's internals.

signal crashed

func apply_input(_steer: float, _throttle: float, _brake: float) -> void:
	pass # Override in a concrete vehicle implementation.
