extends Node

## Autoload singleton — the single source of truth for race/session state.
## See design_principles.md §1 ("single source of truth") and §1a
## (autoloads). Nothing outside this file mutates `state` directly; go
## through the methods below so an illegal transition (e.g. a checkpoint
## reported before the race has started) is rejected rather than silently
## corrupting state.

enum State { COUNTDOWN, RACING, FINISHED }

signal state_changed(new_state: State)
signal checkpoint_passed(checkpoint_id: int)
signal race_finished

var state: State = State.COUNTDOWN

func start_race() -> void:
	if state != State.COUNTDOWN:
		return
	_set_state(State.RACING)

func report_checkpoint(checkpoint_id: int) -> void:
	if state != State.RACING:
		return
	checkpoint_passed.emit(checkpoint_id)

func finish_race() -> void:
	if state != State.RACING:
		return
	_set_state(State.FINISHED)
	race_finished.emit()

func reset() -> void:
	_set_state(State.COUNTDOWN)

func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(new_state)
