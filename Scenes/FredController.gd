## WASD locomotion for Fred.
##
## Movement is code-driven (velocity -> move_and_slide). The baked clips carry
## their world travel on the skeleton root, which FredAnimation hands to the
## AnimationMixer as root motion, so the mesh stays on the collision capsule
## instead of sliding away. Clip choice is a simple speed threshold for now --
## this is the seam the motion matcher will replace.
##
## Now includes:
## - Jumping
## - Falling with procedural animation
## - Landing
## - Euphoria-style ragdoll on impact

extends CharacterBody3D
class_name FredController

@export var walk_speed: float = 1.8
@export var run_speed: float = 4.5
@export var acceleration: float = 12.0
@export var turn_speed: float = 10.0
@export var gravity: float = 9.8

@export_group("Jump")
@export var jump_force: float = 5.0
@export var jump_duration: float = 0.3

@export_group("Fall")
@export var fall_threshold: float = 0.1  # Time in air before considered falling
@export var fall_speed_threshold: float = 2.0  # Vertical speed to trigger fall state

@export_group("Ragdoll")
@export var enable_ragdoll: bool = true
@export var ragdoll_duration: float = 2.0  # How long to stay in ragdoll after impact
@export var impact_threshold: float = 5.0  # Velocity threshold for ragdoll activation

@export_group("Camera")
@export var mouse_sensitivity: float = 0.003
@export var pitch_min: float = -1.1
@export var pitch_max: float = 0.5
## Height of the orbit pivot -- roughly shoulder height, so the camera looks
## over Fred rather than down at him.
@export var camera_height: float = 1.45
## How far behind the pivot the camera sits.
@export var camera_distance: float = 2.2
## Lateral offset of the whole orbit. Offsetting the pivot (not just the
## camera) is what keeps Fred framed to the left while you look straight
## ahead -- the over-the-shoulder framing.
@export var shoulder_offset: float = 0.6

var _yaw := 0.0
## Starts angled down enough to keep Fred's feet inside the frame: the camera
## sits at ~1.78m and he stands 2.2m ahead, so his feet are ~39 degrees below
## the horizontal and a shallower tilt crops them off the bottom edge.
var _pitch := -0.28

@export_group("Clips")
## Fallbacks used only when motion matching is off or has no database.
@export var idle_clip: String = "Idle/M_Neutral_Stand_Idle_Loop"
@export var walk_clip: String = "Walk/M_Neutral_Walk_Loop_F"
@export var run_clip: String = "Run/M_Neutral_Run_Loop_F"

@onready var animation: FredAnimation = $FredAnimation
@onready var camera_rig: Node3D = $CameraRig
@onready var shoulder_pivot: Node3D = $CameraRig/ShoulderPivot
@onready var spring_arm: SpringArm3D = $CameraRig/ShoulderPivot/SpringArm3D
@onready var matcher: MotionMatcher = get_node_or_null("MotionMatcher")
@onready var state_machine: CharacterStateMachine = $StateMachine
@onready var ragdoll: EuphoriaRagdoll = $EuphoriaRagdoll

# State tracking
var _current_clip := ""
var _was_grounded: bool = true
var _fall_timer: float = 0.0
var _jump_timer: float = 0.0
var _land_timer: float = 0.0
var _ragdoll_timer: float = 0.0

func _ready() -> void:
	# Fall back to whatever the libraries actually contain, so a renamed or
	# missing clip degrades to something playable instead of silence.
	idle_clip = _resolve(idle_clip, "Idle", ["Stand_Idle_Loop", "Idle_Loop", "Idle"])
	walk_clip = _resolve(walk_clip, "Walk", ["Walk_Loop_F", "Walk_Loop", "Walk"])
	run_clip = _resolve(run_clip, "Run", ["Run_Loop_F", "Run_Loop", "Run"])
	# Motion matching drives clip choice when it has a database; the three
	# fallback clips only run if it is disabled or the bake is missing.
	if matcher and matcher.enabled:
		matcher.setup(animation.anim_player, animation.skeleton)
		matcher.inertializer = animation.inertializer
	if matcher == null or not matcher.enabled:
		print("FredController clips -> idle:%s walk:%s run:%s" % [idle_clip, walk_clip, run_clip])
		_play(idle_clip)

	animation.bind_character(self)

	# Initialize state machine
	if state_machine:
		state_machine.setup(self, animation.anim_player, animation.skeleton)
		state_machine.walk_speed = walk_speed
		state_machine.run_speed = run_speed
		state_machine.jump_force = jump_force
		state_machine.jump_duration = jump_duration
		state_machine.fall_threshold = fall_threshold
		state_machine.fall_speed_threshold = fall_speed_threshold

	# Initialize ragdoll
	if enable_ragdoll and ragdoll:
		ragdoll.gravity_multiplier = 1.0
		ragdoll.ragdoll_duration = ragdoll_duration
		ragdoll.impact_threshold = impact_threshold
		ragdoll.enable()
		
		# Connect ragdoll signals to state machine
		ragdoll.ragdoll_started.connect(state_machine._on_ragdoll_started)
		ragdoll.ragdoll_ended.connect(state_machine._on_ragdoll_ended)
		ragdoll.impact_detected.connect(state_machine._on_impact_detected)

	# The rig is a child of Fred for convenience, but it must not inherit his
	# yaw: he turns to face the direction he is moving, and that direction is
	# derived from the camera basis. Left as a normal child, the two feed back
	# into each other and he spins on the spot when strafing.
	camera_rig.top_level = true

	# Drive the rig from the exported values so it can be retuned in the
	# inspector without editing the scene hierarchy.
	shoulder_pivot.position = Vector3(shoulder_offset, 0.0, 0.0)
	spring_arm.spring_length = camera_distance
	# Fred is on collision layer 2; leaving him out of the arm's mask stops the
	# camera from colliding with its own character and snapping to his back.
	spring_arm.collision_mask = 1

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, pitch_min, pitch_max)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE \
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			else Input.MOUSE_MODE_CAPTURED

## Pick `preferred` if it exists, else the first clip in `category` matching a
## hint, else the first clip in that category.
func _resolve(preferred: String, category: String, hints: Array) -> String:
	if animation == null:
		return preferred
	var clips := animation.get_clips_in(category)
	if clips.is_empty():
		return ""
	if animation.anim_player.has_animation(preferred):
		return preferred
	for hint in hints:
		for c in clips:
			if hint in c:
				return c
	return clips[0]

func _physics_process(delta: float) -> void:
	# Camera follows Fred's position but keeps its own orientation.
	camera_rig.global_position = global_position + Vector3.UP * camera_height
	camera_rig.rotation = Vector3(_pitch, _yaw, 0.0)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprinting := Input.is_action_pressed("sprint")

	# Check for jump input
	var want_jump := Input.is_action_just_pressed("jump")
	
	# Move relative to where the camera is facing.
	var basis := camera_rig.global_transform.basis
	var forward := -basis.z
	var right := basis.x
	forward.y = 0.0
	right.y = 0.0
	# Re-normalise after flattening: pitching the camera shortens the forward
	# vector, which would otherwise bias diagonal input toward strafing.
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
	if right.length_squared() > 0.0001:
		right = right.normalized()
	var dir := (right * input.x + forward * -input.y).normalized()

	# Update state machine
	if state_machine:
		state_machine.update(delta, dir, sprinting)
	
	# Handle movement based on current state
	var target_speed := 0.0
	if dir.length_squared() > 0.01:
		target_speed = run_speed if sprinting else walk_speed

	var target_vel := dir * target_speed
	
	# Apply movement based on state
	if state_machine and state_machine.is_in_ragdoll():
		# Ragdoll controls movement - disable normal movement but allow some air control
		if not is_on_floor():
			# In air during ragdoll, allow minimal control
			velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta * 0.2)
			velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta * 0.2)
		else:
			# On ground in ragdoll, stop horizontal movement
			velocity.x = move_toward(velocity.x, 0.0, acceleration * delta * 2.0)
			velocity.z = move_toward(velocity.z, 0.0, acceleration * delta * 2.0)
	else:
		# Normal movement
			
		State.JUMP:
			# In jump state, maintain horizontal velocity but don't apply gravity yet
			# (gravity is handled by the jump itself)
			velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
			velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)
			
		State.FALL:
			# In fall state, maintain some air control
			velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta * 0.5)
			velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta * 0.5)
			
		_:
			# Normal movement
			velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
			velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)

	# Handle jump
	if want_jump and state_machine and state_machine.can_jump():
		state_machine.force_state(CharacterStateMachine.State.JUMP)
		velocity.y = jump_force
		_jump_timer = 0.0

	# Handle gravity and floor
	if is_on_floor():
		# Track landing
		if not _was_grounded:
			# Just landed
			if state_machine and (state_machine.get_current_state() == CharacterStateMachine.State.JUMP or 
				state_machine.get_current_state() == CharacterStateMachine.State.FALL):
				# Check if we should ragdoll
				if enable_ragdoll and ragdoll and velocity.y < -impact_threshold:
					# Significant impact - trigger ragdoll
					ragdoll.detect_impact(velocity, floor_normal())
					state_machine.force_state(CharacterStateMachine.State.RAGDOLL)
				elif state_machine:
					state_machine.force_state(CharacterStateMachine.State.LAND)
			
		velocity.y = 0.0
		_was_grounded = true
		_fall_timer = 0.0
	else:
		# In air
		velocity.y -= gravity * delta
		_was_grounded = false
		
		# Track fall time
		if not is_on_floor():
			_fall_timer += delta
			
			# Transition to fall state if falling long enough or fast enough
			if state_machine:
				if _fall_timer > fall_threshold or velocity.y < -fall_speed_threshold:
					if state_machine.get_current_state() != CharacterStateMachine.State.FALL and
					   state_machine.get_current_state() != CharacterStateMachine.State.JUMP:
						state_machine.force_state(CharacterStateMachine.State.FALL)
						if ragdoll:
							ragdoll.start_falling()

	# Update ragdoll physics
	if ragdoll and ragdoll.is_in_ragdoll():
		ragdoll._physics_process(delta)

	# Only move_and_slide if not in full ragdoll mode
	# In ragdoll mode, physics are handled by the ragdoll system
	if not (ragdoll and ragdoll.state == EuphoriaRagdoll.State.RAGDOLL):
		move_and_slide()
	else:
		# In ragdoll mode, we still need to update the position
		# but physics are applied directly to the body
		move_and_slide()

	# Face the direction of travel. Fred's mesh looks down -Z, the same way a
	# Godot node does, so the yaw pointing him along d is atan2(-d.x, -d.z).
	# atan2(d.x, d.z) is the +Z-facing-mesh form and turns him 180 degrees --
	# he then moonwalks with his face to the camera.
	if dir.length_squared() > 0.01:
		var want := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, want, turn_speed * delta)

	# Update motion matcher
	if matcher and matcher.enabled and not (state_machine and state_machine.is_in_ragdoll()):
		# Hand the matcher intent, not a clip name: where we want to go, how
		# fast, and which way we are facing. It picks the pose.
		matcher.desired_velocity = target_vel
		matcher.current_velocity = Vector3(velocity.x, 0.0, velocity.z)
		matcher.desired_facing = -global_transform.basis.z
	else:
		_update_clip(Vector2(velocity.x, velocity.z).length(), sprinting)

func _update_clip(speed: float, sprinting: bool) -> void:
	var want := idle_clip
	if speed > 0.15:
		want = run_clip if sprinting else walk_clip
	_play(want)

func _play(clip: String) -> void:
	if clip == "" or clip == _current_clip:
		return
	_current_clip = clip
	if animation:
		animation.play(clip)
