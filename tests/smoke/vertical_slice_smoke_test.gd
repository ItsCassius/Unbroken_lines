extends SceneTree

## Headless smoke test for the RaceManager / Drivable / checkpoint seam —
## run via `godot --headless -s res://tests/smoke/vertical_slice_smoke_test.gd`.
## Builds ground/car/checkpoint entirely in code (no .tscn needed), drives
## the placeholder car straight ahead, and asserts RaceManager.race_finished
## fires within a timeout. Not a GUT unit test — an integration-level check
## that the foundation actually runs, for use in CI or on a machine with no
## Godot editor GUI. See CLAUDE.md "Manual smoke-test setup" for the
## editor-based equivalent.

const CHECKPOINT_DISTANCE := 20.0
const TIMEOUT_SECONDS := 8.0

var _car: RigidBody3D
var _race_manager: Node
var _elapsed := 0.0
var _finished := false

func _initialize() -> void:
	# `-s` entrypoint scripts compile before autoloads are registered as
	# global identifiers, so RaceManager can't be referenced by bare name
	# here — fetch it from the tree at runtime instead.
	_race_manager = get_root().get_node("RaceManager")
	_build_scene()
	_race_manager.reset()
	_race_manager.race_finished.connect(_on_race_finished)
	_race_manager.start_race()
	print("[smoke test] race started, driving toward checkpoint at -%.0fm..." % CHECKPOINT_DISTANCE)

func _build_scene() -> void:
	var root := Node3D.new()
	get_root().add_child(root)

	var ground := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(20, 1, 200)
	ground_shape.shape = ground_box
	ground.add_child(ground_shape)
	ground.position = Vector3(0, -0.5, -CHECKPOINT_DISTANCE / 2.0)
	root.add_child(ground)

	_car = RigidBody3D.new()
	_car.set_script(load("res://scripts/core/dev_smoke_test_car.gd"))
	var car_shape := CollisionShape3D.new()
	var car_box := BoxShape3D.new()
	car_box.size = Vector3(2, 1, 4)
	car_shape.shape = car_box
	_car.add_child(car_shape)
	_car.position = Vector3(0, 1, 0)
	root.add_child(_car)

	var checkpoint := Area3D.new()
	checkpoint.set_script(load("res://scripts/core/checkpoint.gd"))
	checkpoint.is_finish_line = true
	var cp_shape := CollisionShape3D.new()
	var cp_box := BoxShape3D.new()
	cp_box.size = Vector3(10, 10, 2)
	cp_shape.shape = cp_box
	checkpoint.add_child(cp_shape)
	checkpoint.position = Vector3(0, 1, -CHECKPOINT_DISTANCE)
	root.add_child(checkpoint)

func _physics_process(delta: float) -> bool:
	if _finished:
		return true # stop the main loop

	_elapsed += delta
	if _elapsed > TIMEOUT_SECONDS:
		printerr("[smoke test] FAILED: checkpoint not reached within %.0fs (car at z=%.1f)" % [TIMEOUT_SECONDS, _car.position.z])
		quit(1)
		return true

	# Full throttle, straight ahead. Bypasses dev_smoke_test_car.gd's own
	# Input.get_axis() reads (which return 0 with no display/input device
	# anyway) by calling the public apply_input() contract directly.
	_car.apply_input(0.0, 1.0, 0.0)
	return false

func _on_race_finished() -> void:
	_finished = true
	print("[smoke test] PASSED: RaceManager/Drivable/checkpoint seam OK (%.2fs, car at z=%.1f)" % [_elapsed, _car.position.z])
	quit(0)
