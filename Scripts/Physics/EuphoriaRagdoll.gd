## Euphoria-style procedural ragdoll.
##
## Implements NaturalMotion Euphoria engine style ragdoll physics:
## - Physics-based ragdoll that reacts to impacts
## - Procedural falling with air resistance
## - Impact detection and reaction
## - Smooth recovery from ragdoll state
##
## This works with CharacterBody3D's move_and_slide by modifying velocity
## and applying forces. The character goes limp and reacts to impacts.

extends Node
class_name EuphoriaRagdoll

# Physics parameters
@export var gravity_multiplier: float = 1.0
@export var air_resistance: float = 0.1
@export var ragdoll_duration: float = 2.0  # How long to stay in ragdoll after impact
@export var recovery_time: float = 0.5  # Time to blend back to animation
@export var impact_threshold: float = 5.0  # Velocity threshold for ragdoll activation
@export var impact_force_multiplier: float = 1.5

# Ragdoll settings
@export var enable_ragdoll: bool = true
@export var ragdoll_on_fall: bool = true
@export var ragdoll_on_impact: bool = true

# Signals
signal ragdoll_started
signal ragdoll_ended
signal impact_detected(impact_velocity: float, impact_normal: Vector3)

# State
enum State {
	DISABLED,
	ANIMATED,
	FALLING,  # Procedural falling
	RAGDOLL,  # Full physics ragdoll
	RECOVERING
}

var state: State = State.DISABLED
var character_body: CharacterBody3D
var skeleton: Skeleton3D

# Fall tracking
var fall_start_time: float = 0.0
var fall_start_height: float = 0.0
var fall_velocity: Vector3 = Vector3.ZERO
var is_falling: bool = false

# Impact tracking
var impact_time: float = 0.0
var impact_velocity: float = 0.0
var impact_normal: Vector3 = Vector3.UP
var was_grounded: bool = true

# Recovery
var recovery_timer: float = 0.0

# Ragdoll forces
var ragdoll_force: Vector3 = Vector3.ZERO
var ragdoll_torque: Vector3 = Vector3.ZERO

# Original velocity for blending
var original_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	# Find character body
	character_body = get_parent() as CharacterBody3D
	if not character_body:
		character_body = get_parent().find_child("CharacterBody3D") as CharacterBody3D
		
	if character_body:
		# Find skeleton
		var anim_target := character_body.find_child("AnimatedTarget")
		if anim_target:
			skeleton = anim_target.find_child("Skeleton3D") as Skeleton3D
		
		# Start in animated mode
		state = State.ANIMATED


func enable() -> void:
	if not enable_ragdoll:
		return
	state = State.ANIMATED


func disable() -> void:
	state = State.DISABLED


func start_falling() -> void:
	if state == State.FALLING or state == State.RAGDOLL:
		return
	
	if not character_body or not character_body.is_on_floor():
		is_falling = true
		fall_start_time = Time.get_ticks_msec() / 1000.0
		fall_start_height = character_body.global_position.y
		fall_velocity = character_body.velocity
		was_grounded = false
		
		state = State.FALLING
		emit_signal("ragdoll_started")


func stop_falling() -> void:
	is_falling = false


func detect_impact(velocity: Vector3, normal: Vector3) -> void:
	# Check if impact is significant enough to trigger ragdoll
	var speed := velocity.length()
	var vertical_speed := velocity.y
	
	# Only trigger ragdoll for significant downward impacts
	if (speed > impact_threshold or vertical_speed < -impact_threshold) and ragdoll_on_impact:
		impact_velocity = speed
		impact_normal = normal
		impact_time = Time.get_ticks_msec() / 1000.0
		
		# Store original velocity for blending
		original_velocity = character_body.velocity if character_body else Vector3.ZERO
		
		# Apply impact forces
		ragdoll_force = velocity * impact_force_multiplier
		ragdoll_torque = normal.cross(velocity) * impact_force_multiplier * 0.5
		
		# Transition to ragdoll state
		state = State.RAGDOLL
		
		emit_signal("impact_detected", impact_velocity, impact_normal)


func update_fall_physics(delta: float) -> void:
	if state != State.FALLING or not character_body:
		return
	
	# Procedural falling - apply air resistance
	var vel := character_body.velocity
	var speed := vel.length()
	if speed > 0.1:
		var air_resist := vel.normalized() * speed * speed * air_resistance * delta
		character_body.velocity -= air_resist
		
	# Track fall velocity
	fall_velocity = character_body.velocity


func update_ragdoll(delta: float) -> void:
	if state != State.RAGDOLL or not character_body:
		return
	
	# In ragdoll mode, apply physics forces
	var current_time := Time.get_ticks_msec() / 1000.0
	var elapsed := current_time - impact_time
	
	# Calculate force factor (decays over ragdoll duration)
	var force_factor := 1.0 - min(1.0, elapsed / ragdoll_duration)
	
	# Apply gravity
	character_body.add_central_force(Vector3.DOWN * 9.8 * gravity_multiplier * delta)
	
	# Apply impact forces (decaying)
	if elapsed < ragdoll_duration:
		character_body.add_central_force(ragdoll_force * force_factor * delta)
		character_body.add_torque(ragdoll_torque * force_factor * delta)
	
	# Damping - slow down horizontal movement
	var horizontal_vel := Vector3(character_body.velocity.x, 0, character_body.velocity.z)
	if horizontal_vel.length() > 0.1:
		character_body.velocity -= horizontal_vel.normalized() * 0.5 * delta
	
	# Check if ragdoll duration has expired
	if elapsed >= ragdoll_duration:
		state = State.RECOVERING
		recovery_timer = 0.0


func update_recovery(delta: float) -> void:
	if state != State.RECOVERING:
		return
	
	recovery_timer += delta
	
	# Blend back to normal control
	var recover_factor := min(1.0, recovery_timer / recovery_time)
	
	# Smoothly restore original velocity
	if character_body:
		character_body.velocity = character_body.velocity.lerp(original_velocity, recover_factor * delta * 2.0)
	
	# Check if recovery is complete
	if recovery_timer >= recovery_time:
		state = State.ANIMATED
		emit_signal("ragdoll_ended")


func _process(delta: float) -> void:
	if not enable_ragdoll or state == State.DISABLED:
		return
	
	match state:
		State.FALLING:
			update_fall_physics(delta)
			# Check for landing
			if character_body and character_body.is_on_floor():
				if was_grounded:
					# Just touched ground after falling
					detect_impact(character_body.velocity, character_body.floor_normal())
					was_grounded = true
				else:
					was_grounded = true
					stop_falling()
					state = State.ANIMATED
			else:
				was_grounded = false
			
		State.RAGDOLL:
			update_ragdoll(delta)
			
		State.RECOVERING:
			update_recovery(delta)
			
		_:
			pass


func _physics_process(delta: float) -> void:
	# Handle character body physics when in ragdoll mode
	if state == State.RAGDOLL and character_body:
		# In ragdoll mode, physics are applied in update_ragdoll
		pass


func get_state() -> State:
	return state


func is_in_ragdoll() -> bool:
	return state == State.RAGDOLL or state == State.RECOVERING


func is_falling() -> bool:
	return state == State.FALLING


func reset() -> void:
	state = State.ANIMATED
	is_falling = false
	was_grounded = true
	fall_velocity = Vector3.ZERO
	ragdoll_force = Vector3.ZERO
	ragdoll_torque = Vector3.ZERO
	impact_velocity = 0.0
	impact_normal = Vector3.UP
	recovery_timer = 0.0
