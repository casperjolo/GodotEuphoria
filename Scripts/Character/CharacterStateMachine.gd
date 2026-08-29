## Character State Machine
##
## Manages character states including:
## - Idle
## - Walk
## - Run
## - Jump
## - Fall
## - Land
## - Ragdoll
## - Recover
##
## Integrates with EuphoriaRagdoll for physics-based falling and impact reactions.
## This is a hierarchical state machine that handles transitions between states
## and coordinates with the ragdoll system for NaturalMotion Euphoria-style physics.

extends Node
class_name CharacterStateMachine

# State enum
enum State {
	IDLE,
	WALK,
	RUN,
	JUMP,
	FALL,
	LAND,
	RAGDOLL,
	RECOVER
}

# Signals
signal state_changed(old_state: State, new_state: State)
signal jumped
signal landed(impact_velocity: float)
signal fell
signal ragdoll_started
signal ragdoll_ended

# State properties
@export var current_state: State = State.IDLE
@export var previous_state: State = State.IDLE

# Movement settings
@export var walk_speed: float = 1.8
@export var run_speed: float = 4.5
@export var jump_force: float = 5.0
@export var jump_duration: float = 0.3
@export var gravity: float = 9.8

# Fall settings
@export var fall_threshold: float = 0.1  # Time in air before considered falling
@export var fall_speed_threshold: float = 2.0  # Vertical speed to trigger fall state
@export var land_recovery_time: float = 0.3

# References
var character_body: CharacterBody3D
var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var ragdoll: EuphoriaRagdoll

# State timers
var jump_timer: float = 0.0
var fall_timer: float = 0.0
var land_timer: float = 0.0
var recovery_timer: float = 0.0

# Movement state
var is_sprinting: bool = false
var move_direction: Vector3 = Vector3.ZERO
var move_speed: float = 0.0
var velocity: Vector3 = Vector3.ZERO

# Jump state
var is_jumping: bool = false
var jump_start_height: float = 0.0
var jump_velocity: Vector3 = Vector3.ZERO

# Fall state
var is_falling: bool = false
var fall_start_height: float = 0.0
var fall_velocity: Vector3 = Vector3.ZERO
var was_grounded: bool = true

# Landing state
var impact_velocity: float = 0.0
var impact_normal: Vector3 = Vector3.UP


func _ready() -> void:
	# Find required nodes
	var parent := get_parent()
	if parent:
		character_body = parent as CharacterBody3D
		if not character_body:
			character_body = parent.find_child("CharacterBody3D") as CharacterBody3D
		
		# Find animation player
		var anim_target := parent.find_child("AnimatedTarget")
		if anim_target:
			skeleton = anim_target.find_child("Skeleton3D") as Skeleton3D
			animation_player = anim_target.find_child("AnimationPlayer") as AnimationPlayer
		
		# Find or create ragdoll
		ragdoll = parent.find_child("EuphoriaRagdoll") as EuphoriaRagdoll
		if not ragdoll:
			var ragdoll_node := EuphoriaRagdoll.new()
			ragdoll_node.name = "EuphoriaRagdoll"
			parent.add_child(ragdoll_node)
			ragdoll = ragdoll_node
			ragdoll.enable()
		
	# Connect ragdoll signals
	if ragdoll:
		ragdoll.ragdoll_started.connect(_on_ragdoll_started)
		ragdoll.ragdoll_ended.connect(_on_ragdoll_ended)
		ragdoll.impact_detected.connect(_on_impact_detected)


func setup(character: CharacterBody3D, anim_player: AnimationPlayer, skel: Skeleton3D) -> void:
	character_body = character
	animation_player = anim_player
	skeleton = skel


func update(delta: float, input_direction: Vector3, sprinting: bool) -> void:
	# Store input
	move_direction = input_direction
	is_sprinting = sprinting
	
	# Update velocity from character body
	if character_body:
		velocity = character_body.velocity
		was_grounded = character_body.is_on_floor()
	
	# State machine update
	_update_state_machine(delta)
	
	# Update ragdoll
	if ragdoll:
		ragdoll._process(delta)


func _update_state_machine(delta: float) -> void:
	var new_state := current_state
	
	match current_state:
		State.IDLE:
			new_state = _update_idle(delta)
			
		State.WALK:
			new_state = _update_walk(delta)
			
		State.RUN:
			new_state = _update_run(delta)
			
		State.JUMP:
			new_state = _update_jump(delta)
			
		State.FALL:
			new_state = _update_fall(delta)
			
		State.LAND:
			new_state = _update_land(delta)
			
		State.RAGDOLL:
			new_state = _update_ragdoll(delta)
			
		State.RECOVER:
			new_state = _update_recover(delta)
	
	# Handle state transitions
	if new_state != current_state:
		_change_state(new_state)


func _update_idle(delta: float) -> State:
	# Check for movement
	if move_direction.length_squared() > 0.01:
		if is_sprinting:
			return State.RUN
		else:
			return State.WALK
		
	# Check for jump
	if Input.is_action_just_pressed("jump") and character_body and character_body.is_on_floor():
		return State.JUMP
		
	# Check for fall
	if character_body and not character_body.is_on_floor():
		return State.FALL
		
	return State.IDLE


func _update_walk(delta: float) -> State:
	# Check for stop
	if move_direction.length_squared() < 0.01:
		return State.IDLE
		
	# Check for run
	if is_sprinting:
		return State.RUN
		
	# Check for jump
	if Input.is_action_just_pressed("jump") and character_body and character_body.is_on_floor():
		return State.JUMP
		
	# Check for fall
	if character_body and not character_body.is_on_floor():
		return State.FALL
		
	return State.WALK


func _update_run(delta: float) -> State:
	# Check for stop
	if move_direction.length_squared() < 0.01:
		return State.IDLE
		
	# Check for walk (no longer sprinting)
	if not is_sprinting:
		return State.WALK
		
	# Check for jump
	if Input.is_action_just_pressed("jump") and character_body and character_body.is_on_floor():
		return State.JUMP
		
	# Check for fall
	if character_body and not character_body.is_on_floor():
		return State.FALL
		
	return State.RUN


func _update_jump(delta: float) -> State:
	# Update jump timer
	jump_timer += delta
	
	# Check if jump duration has ended or we're falling
	if jump_timer >= jump_duration or (character_body and character_body.velocity.y < 0):
		# Transition to fall if not grounded
		if character_body and not character_body.is_on_floor():
			return State.FALL
		else:
			# Landed immediately (short hop)
			return State.LAND
		
	# Check for fall if we start descending
	if character_body and character_body.velocity.y < -0.1:
		return State.FALL
		
	return State.JUMP


func _update_fall(delta: float) -> State:
	# Update fall timer
	fall_timer += delta
	
	# Notify ragdoll we're falling
	if ragdoll and ragdoll.state != EuphoriaRagdoll.State.FALLING:
		ragdoll.start_falling()
	
	# Check for landing
	if character_body and character_body.is_on_floor():
		# Calculate impact velocity
		impact_velocity = character_body.velocity.length()
		impact_normal = character_body.floor_normal()
		
		# Check if impact is significant
		if impact_velocity > fall_speed_threshold or fall_timer > fall_threshold:
			# Significant fall - trigger ragdoll
			if ragdoll and ragdoll.ragdoll_on_impact:
				return State.RAGDOLL
			else:
				return State.LAND
		else:
			# Minor fall - just land
			return State.LAND
		
	return State.FALL


func _update_land(delta: float) -> State:
	# Update land timer
	land_timer += delta
	
	# Check if we can recover
	if land_timer >= land_recovery_time:
		# Return to appropriate state based on input
		if move_direction.length_squared() > 0.01:
			if is_sprinting:
				return State.RUN
			else:
				return State.WALK
		else:
			return State.IDLE
		
	return State.LAND


func _update_ragdoll(delta: float) -> State:
	# Ragdoll is controlled by the EuphoriaRagdoll component
	# We just wait for it to signal recovery
	if ragdoll and ragdoll.state == EuphoriaRagdoll.State.RECOVERING:
		return State.RECOVER
		
	return State.RAGDOLL


func _update_recover(delta: float) -> State:
	# Update recovery timer
	recovery_timer += delta
	
	# Check if recovery is complete
	if ragdoll and ragdoll.state == EuphoriaRagdoll.State.ANIMATED:
		# Return to appropriate state based on input
		if move_direction.length_squared() > 0.01:
			if is_sprinting:
				return State.RUN
			else:
				return State.WALK
		else:
			return State.IDLE
		
	return State.RECOVER


func _change_state(new_state: State) -> void:
	var old_state := current_state
	current_state = new_state
	
	# Emit signal
	emit_signal("state_changed", old_state, new_state)
	
	# Handle state entry
	match new_state:
		State.JUMP:
			_on_enter_jump()
			
		State.FALL:
			_on_enter_fall()
			
		State.LAND:
			_on_enter_land()
			
		State.RAGDOLL:
			_on_enter_ragdoll()
			
		State.RECOVER:
			_on_enter_recover()
			_:
			pass
	
	# Handle state exit
	match old_state:
		State.JUMP:
			_on_exit_jump()
			
		State.FALL:
			_on_exit_fall()
			
		State.RAGDOLL:
			_on_exit_ragdoll()
			_:
			pass


func _on_enter_jump() -> void:
	jump_timer = 0.0
	is_jumping = true
	
	# Apply jump force
	if character_body:
		jump_start_height = character_body.global_position.y
		jump_velocity = Vector3.UP * jump_force
		character_body.velocity.y = jump_force
		
	# Play jump animation
	if animation_player:
		# Find a jump animation
		var jump_anim := _find_animation("Jump")
		if jump_anim != "":
			var anim := animation_player.get_animation(jump_anim)
			if anim:
				anim.loop_mode = Animation.LOOP_NONE
			animation_player.play(jump_anim, 0.1)
		
	emit_signal("jumped")


func _on_exit_jump() -> void:
	is_jumping = false


func _on_enter_fall() -> void:
	fall_timer = 0.0
	is_falling = true
	
	if character_body:
		fall_start_height = character_body.global_position.y
		fall_velocity = character_body.velocity
		
	# Play fall animation if available
	if animation_player:
		var fall_anim := _find_animation("Fall")
		if fall_anim == "":
			# Try to find any falling animation
			var clips := animation_player.get_animation_list()
			for clip in clips:
				if "fall" in clip.to_lower() or "drop" in clip.to_lower():
					fall_anim = clip
					break
			
		if fall_anim != "":
			var anim := animation_player.get_animation(fall_anim)
			if anim:
				anim.loop_mode = Animation.LOOP_NONE
			animation_player.play(fall_anim, 0.15)
		
	emit_signal("fell")


func _on_exit_fall() -> void:
	is_falling = false


func _on_enter_land() -> void:
	land_timer = 0.0
	
	# Play land animation
	if animation_player:
		var land_anim := _find_animation("Land")
		if land_anim == "":
			# Try to find any landing animation
			var clips := animation_player.get_animation_list()
			for clip in clips:
				if "land" in clip.to_lower():
					land_anim = clip
					break
			
		if land_anim != "":
			var anim := animation_player.get_animation(land_anim)
			if anim:
				anim.loop_mode = Animation.LOOP_NONE
			animation_player.play(land_anim, 0.1)
		
	emit_signal("landed", impact_velocity)


func _on_enter_ragdoll() -> void:
	# Ragdoll is handled by EuphoriaRagdoll component
	if ragdoll:
		ragdoll.detect_impact(character_body.velocity if character_body else Vector3.ZERO, 
			character_body.floor_normal() if character_body else Vector3.UP)
		
	emit_signal("ragdoll_started")


func _on_exit_ragdoll() -> void:
	emit_signal("ragdoll_ended")


func _on_enter_recover() -> void:
	recovery_timer = 0.0


func _on_ragdoll_started() -> void:
	# Sync state with ragdoll
	if current_state != State.RAGDOLL and current_state != State.RECOVER:
		_change_state(State.RAGDOLL)


func _on_ragdoll_ended() -> void:
	# Ragdoll has finished, transition to recover or appropriate state
	if current_state == State.RAGDOLL:
		_change_state(State.RECOVER)


func _on_impact_detected(velocity: float, normal: Vector3) -> void:
	impact_velocity = velocity
	impact_normal = normal
	
	# If we're in fall state and impact is detected, transition to ragdoll
	if current_state == State.FALL:
		_change_state(State.RAGDOLL)


func _find_animation(category: String) -> String:
	if not animation_player:
		return ""
		
	# Check if there's a library for this category
	var lib := animation_player.get_animation_library(category)
	if lib:
		var animations := lib.get_animation_list()
		if animations.size() > 0:
			return "%s/%s" % [category, animations[0]]
		
	# Try to find any animation with the category name
	var all_anims := animation_player.get_animation_list()
	for anim in all_anims:
		if category in anim:
			return anim
		
	return ""


func get_current_state() -> State:
	return current_state


func is_jumping() -> bool:
	return current_state == State.JUMP


func is_falling() -> bool:
	return current_state == State.FALL


func is_landing() -> bool:
	return current_state == State.LAND


func is_in_ragdoll() -> bool:
	return current_state == State.RAGDOLL or current_state == State.RECOVER


func can_jump() -> bool:
	# Can jump if grounded and not in special states
	return (character_body and character_body.is_on_floor() and 
		current_state != State.JUMP and 
		current_state != State.FALL and 
		current_state != State.RAGDOLL and 
		current_state != State.RECOVER)


func force_state(new_state: State) -> void:
	"""Force a state change, bypassing normal transition logic"""
	_change_state(new_state)
