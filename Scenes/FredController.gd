## WASD locomotion for Fred.
##
## Movement is code-driven (velocity -> move_and_slide). The baked clips carry
## their world travel on the skeleton root, which FredAnimation hands to the
## AnimationMixer as root motion, so the mesh stays on the collision capsule
## instead of sliding away. Clip choice is a simple speed threshold for now --
## this is the seam the motion matcher will replace.
extends CharacterBody3D
class_name FredController

@export var walk_speed: float = 1.8
@export var run_speed: float = 4.5
@export var acceleration: float = 12.0
@export var turn_speed: float = 10.0
@export var gravity: float = 9.8

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
@export var idle_clip: String = "Idle/M_Neutral_Stand_Idle_Loop"
@export var walk_clip: String = "Walk/M_Neutral_Walk_Loop_F"
@export var run_clip: String = "Run/M_Neutral_Run_Loop_F"

@onready var animation: FredAnimation = $FredAnimation
@onready var camera_rig: Node3D = $CameraRig
@onready var shoulder_pivot: Node3D = $CameraRig/ShoulderPivot
@onready var spring_arm: SpringArm3D = $CameraRig/ShoulderPivot/SpringArm3D

var _current_clip := ""

func _ready() -> void:
	# Fall back to whatever the libraries actually contain, so a renamed or
	# missing clip degrades to something playable instead of silence.
	idle_clip = _resolve(idle_clip, "Idle", ["Stand_Idle_Loop", "Idle_Loop", "Idle"])
	walk_clip = _resolve(walk_clip, "Walk", ["Walk_Loop_F", "Walk_Loop", "Walk"])
	run_clip = _resolve(run_clip, "Run", ["Run_Loop_F", "Run_Loop", "Run"])
	print("FredController clips -> idle:%s walk:%s run:%s" % [idle_clip, walk_clip, run_clip])
	_play(idle_clip)

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

	var target_speed := 0.0
	if dir.length_squared() > 0.01:
		target_speed = run_speed if sprinting else walk_speed

	var target_vel := dir * target_speed
	velocity.x = move_toward(velocity.x, target_vel.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, acceleration * delta)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	move_and_slide()

	# Face the direction of travel. Fred's mesh looks down -Z, the same way a
	# Godot node does, so the yaw pointing him along d is atan2(-d.x, -d.z).
	# atan2(d.x, d.z) is the +Z-facing-mesh form and turns him 180 degrees --
	# he then moonwalks with his face to the camera.
	if dir.length_squared() > 0.01:
		var want := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, want, turn_speed * delta)

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
