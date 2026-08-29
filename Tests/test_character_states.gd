## Test script for character states
## Run this to verify the jumping, falling, and ragdoll systems work correctly

extends Node

@onready var fred: CharacterBody3D

func _ready() -> void:
	fred = get_node_or_null("/root/World/Fred")
	if not fred:
		print("ERROR: Fred character not found!")
		get_tree().quit(1)
		return
	
	# Find state machine and ragdoll
	var state_machine := fred.find_child("StateMachine") as CharacterStateMachine
	var ragdoll := fred.find_child("EuphoriaRagdoll") as EuphoriaRagdoll
	
	if not state_machine:
		print("ERROR: StateMachine not found!")
		get_tree().quit(1)
		return
	
	if not ragdoll:
		print("ERROR: EuphoriaRagdoll not found!")
		get_tree().quit(1)
		return
	
	print("SUCCESS: All components found!")
	print("  - Fred Controller: ", fred)
	print("  - State Machine: ", state_machine)
	print("  - Ragdoll: ", ragdoll)
	
	# Connect to signals for testing
	if state_machine:
		state_machine.state_changed.connect(_on_state_changed)
		state_machine.jumped.connect(_on_jumped)
		state_machine.landed.connect(_on_landed)
		state_machine.fell.connect(_on_fell)
		state_machine.ragdoll_started.connect(_on_ragdoll_started)
		state_machine.ragdoll_ended.connect(_on_ragdoll_ended)
	
	if ragdoll:
		ragdoll.impact_detected.connect(_on_impact_detected)
	
	# Test initial state
	print("\nInitial State:")
	print("  Current State: ", state_machine.get_current_state())
	print("  Is Grounded: ", fred.is_on_floor())


func _on_state_changed(old_state: int, new_state: int) -> void:
	print("\nState Changed: %s -> %s" % [CharacterStateMachine.State.keys()[old_state], CharacterStateMachine.State.keys()[new_state]])


func _on_jumped() -> void:
	print("\nJUMPED!")


func _on_landed(impact_velocity: float) -> void:
	print("\nLANDED! Impact velocity: %.2f" % impact_velocity)


func _on_fell() -> void:
	print("\nFELL!")


func _on_ragdoll_started() -> void:
	print("\nRAGDOLL STARTED!")


func _on_ragdoll_ended() -> void:
	print("\nRAGDOLL ENDED!")


func _on_impact_detected(velocity: float, normal: Vector3) -> void:
	print("\nIMPACT DETECTED! Velocity: %.2f, Normal: %s" % [velocity, normal])


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("test_jump"):
		print("\n=== TEST: Jump ===")
		var fred := get_node_or_null("/root/World/Fred")
		if fred:
			var state_machine := fred.find_child("StateMachine") as CharacterStateMachine
			if state_machine and state_machine.can_jump():
				state_machine.force_state(CharacterStateMachine.State.JUMP)
				print("Jump triggered!")
			else:
				print("Cannot jump: state = ", state_machine.get_current_state() if state_machine else "no state machine")
		
	if Input.is_action_just_pressed("test_ragdoll"):
		print("\n=== TEST: Force Ragdoll ===")
		var fred := get_node_or_null("/root/World/Fred")
		if fred:
			var ragdoll := fred.find_child("EuphoriaRagdoll") as EuphoriaRagdoll
			if ragdoll:
				ragdoll.detect_impact(Vector3(0, -10, 0), Vector3.UP)
				print("Ragdoll triggered with impact velocity 10!")
