## Main motion matching system - finds and blends between matching animations
extends Node
class_name MotionMatcher

@export var database_path: String = "res://Data/motion_database.tres"
@export var transition_blend_time: float = 0.25
@export var enable_debug: bool = false

@onready var animated_target = get_parent().find_child("AnimatedTarget")
@onready var retargeter: Retargeter = get_parent().find_child("Retargeter")
@onready var root_neutraliser: Node = get_parent().find_child("RootMotionNeutraliser")

var motion_database: MotionDatabase
var anim_player: AnimationPlayer

# Current state
var current_animation: String = ""
var current_frame: float = 0.0
var current_feature: MotionFeature
var blend_progress: float = 0.0
var is_blending: bool = false

# Desired motion parameters (input)
var desired_velocity: Vector3 = Vector3.ZERO
var desired_heading: float = 0.0
var desired_direction: Vector3 = Vector3.ZERO
var desired_locomotion_type: String = "idle"

func _ready() -> void:
	# Find animation player - search recursively in AnimatedTarget
	if not animated_target:
		animated_target = get_parent().find_child("AnimatedTarget")

	if animated_target:
		anim_player = animated_target.find_child("AnimationPlayer", true, false)

	if not anim_player:
		print("MotionMatcher: Warning - No AnimationPlayer found under AnimatedTarget. Searching whole scene...")
		anim_player = get_tree().root.find_child("AnimationPlayer", true, false)

	if not anim_player:
		print("MotionMatcher: No AnimationPlayer found in scene. Animations will not load.")
		return

	# Load motion database
	if ResourceLoader.exists(database_path):
		motion_database = load(database_path)
	else:
		print("MotionMatcher: Database not found at %s, will be populated at runtime" % database_path)
		motion_database = MotionDatabase.new()

	current_feature = MotionFeature.new()

## Process motion matching every frame
func _process(delta: float) -> void:
	if not anim_player:
		print_debug("MotionMatcher: Waiting for AnimationPlayer to be ready...")
		return

	# Initialize on first frame
	if motion_database == null:
		motion_database = MotionDatabase.new()

	# Update current feature with desired motion
	current_feature.local_velocity = desired_velocity
	current_feature.heading = desired_heading
	current_feature.motion_direction = desired_direction
	current_feature.locomotion_type = desired_locomotion_type

	# Find best matching animation frame if database is populated
	if motion_database.motion_features.size() > 0:
		var best_match = motion_database.find_best_match(current_feature, desired_locomotion_type, 1)

		if best_match.size() > 0:
			var match = best_match[0]
			_transition_to_animation(match["animation"], match["frame"], delta)
		elif not is_blending:
			# Fallback to idle if no match found
			if desired_locomotion_type != "idle":
				desired_locomotion_type = "idle"

	# Update animation playback
	if anim_player and current_animation and anim_player.has_animation(current_animation):
		anim_player.seek(current_frame)

	if enable_debug:
		_debug_draw()

## Transition to a new animation
func _transition_to_animation(animation_name: String, frame: int, delta: float) -> void:
	if animation_name == current_animation:
		# Same animation, just update frame
		current_frame = frame
		current_feature = motion_database.get_feature_at_time(animation_name, frame / 30.0)  # Assuming 30 FPS
		return

	# Different animation - start blending
	if is_blending or current_animation == "":
		# Hard switch if already blending or no current animation
		current_animation = animation_name
		current_frame = frame
		is_blending = false
		blend_progress = 0.0

		if anim_player.has_animation(animation_name):
			anim_player.play(animation_name)
			anim_player.seek(frame / 30.0)
	else:
		# Start smooth blend
		is_blending = true
		blend_progress = 0.0

		# Queue the new animation
		var new_animation = animation_name
		if anim_player.has_animation(new_animation):
			anim_player.play(new_animation)
			anim_player.seek(frame / 30.0)

## Set desired motion parameters for matching
func set_desired_motion(velocity: Vector3, heading: float, direction: Vector3 = Vector3.ZERO, locomotion: String = "idle") -> void:
	desired_velocity = velocity
	desired_heading = heading
	desired_direction = direction if direction.length() > 0 else velocity.normalized()
	desired_locomotion_type = locomotion

## Manually set a specific animation and frame
func set_animation(animation_name: String, frame: float = 0.0) -> void:
	if not anim_player:
		return

	if anim_player.has_animation(animation_name):
		current_animation = animation_name
		current_frame = frame
		anim_player.play(animation_name)
		anim_player.seek(frame)
		is_blending = false

## Get current playback position
func get_current_frame() -> float:
	return current_frame if anim_player else 0.0

## Get current animation name
func get_current_animation() -> String:
	return current_animation

## Build motion database from loaded animations
func build_database_from_animations() -> void:
	if not anim_player:
		return

	motion_database.clear()

	for anim_name in anim_player.get_animation_list():
		var animation = anim_player.get_animation(anim_name)
		var features = _extract_features_from_animation(animation, anim_name)
		motion_database.add_animation_features(anim_name, features)

	print("MotionMatcher: Built database with %d animations" % motion_database.motion_features.size())

## Extract motion features from an animation
func _extract_features_from_animation(animation: Animation, anim_name: String) -> Array[MotionFeature]:
	var features: Array[MotionFeature] = []
	var frame_time = 1.0 / 30.0  # Assume 30 FPS

	# Determine locomotion type from animation name
	var locomotion_type = "idle"
	var lower_name = anim_name.to_lower()
	for loco_type in ["walk", "run", "sprint", "jump", "crouch", "idle"]:
		if loco_type in lower_name:
			locomotion_type = loco_type
			break

	# Sample animation at regular intervals
	for frame in range(0, int(animation.length / frame_time)):
		var time = frame * frame_time
		if time > animation.length:
			break

		var feature = MotionFeature.new(frame, anim_name)
		feature.time = time
		feature.locomotion_type = locomotion_type

		# Extract joint positions and velocities
		# This is simplified - in a real system, you'd calculate from bone positions
		feature.root_position = _get_animation_root_position(animation, time)
		if frame > 0:
			var prev_pos = _get_animation_root_position(animation, time - frame_time)
			feature.root_velocity = (feature.root_position - prev_pos) / frame_time

		# Get foot positions
		feature.left_foot.position = _get_bone_position(animation, time, "LeftFoot")
		feature.right_foot.position = _get_bone_position(animation, time, "RightFoot")

		# Estimate foot contact (simplified - checks if foot is low)
		var hips_y = _get_bone_position(animation, time, "Hips").y
		feature.left_foot.is_contact = feature.left_foot.position.y < (hips_y - 0.8)
		feature.right_foot.is_contact = feature.right_foot.position.y < (hips_y - 0.8)

		features.append(feature)

	return features

## Get root position from animation
func _get_animation_root_position(animation: Animation, time: float) -> Vector3:
	# Look for root motion or hips position
	for track_idx in range(animation.get_track_count()):
		var path = animation.track_get_path(track_idx)
		if ("Hips" in path or "Root" in path) and animation.track_get_type(track_idx) == Animation.TYPE_POSITION_3D:
			var key_idx = animation.track_find_key(track_idx, time, Animation.FIND_MODE_NEAREST)
			if key_idx >= 0:
				return animation.track_get_key_value(track_idx, key_idx)

	return Vector3.ZERO

## Get bone position from animation
func _get_bone_position(animation: Animation, time: float, bone_name: String) -> Vector3:
	for track_idx in range(animation.get_track_count()):
		var path = animation.track_get_path(track_idx)
		if bone_name in path and animation.track_get_type(track_idx) == Animation.TYPE_POSITION_3D:
			var key_idx = animation.track_find_key(track_idx, time, Animation.FIND_MODE_NEAREST)
			if key_idx >= 0:
				return animation.track_get_key_value(track_idx, key_idx)

	return Vector3.ZERO

func _debug_draw() -> void:
	if enable_debug:
		print("Motion Matcher - Animation: %s, Frame: %.2f, Type: %s, Velocity: %.2f" % [
			current_animation,
			current_frame,
			desired_locomotion_type,
			desired_velocity.length()
		])
