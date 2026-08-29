## Handles retargeting of animations from source skeleton to Fred's skeleton
extends Node
class_name Retargeter

@export var target_skeleton: Skeleton3D
@export var apply_retargeting: bool = true

var bone_mapping: BoneMapping
var source_poses: Dictionary = {}  # Cache of source poses
var _frame_offset: int = 0

func _ready() -> void:
	if not target_skeleton:
		var animated_target = get_parent().find_child("AnimatedTarget")
		if animated_target:
			# Look for Skeleton3D recursively in AnimatedTarget
			target_skeleton = animated_target.find_child("Skeleton3D", true, false)

	if target_skeleton:
		bone_mapping = BoneMapping.new(target_skeleton)
		print("Retargeter: Found skeleton with %d bones" % target_skeleton.get_bone_count())
	else:
		print("Retargeter: Warning - No target skeleton found. Retargeting disabled.")

## Apply bone transforms from a source animation to target skeleton
func apply_animation_pose(animation: Animation, frame: float) -> void:
	if not target_skeleton or not apply_retargeting:
		return

	var bone_count = target_skeleton.get_bone_count()

	# Reset transforms
	for i in range(bone_count):
		target_skeleton.set_bone_pose_position(i, Vector3.ZERO)
		target_skeleton.set_bone_pose_rotation(i, Quaternion.IDENTITY)
		target_skeleton.set_bone_pose_scale(i, Vector3.ONE)

	# Apply retargeted transforms from animation
	for track_idx in range(animation.get_track_count()):
		var track_path = animation.track_get_path(track_idx)
		var track_path_str = str(track_path)

		# Extract bone name from track path (e.g., "Skeleton3D:Hips" -> "Hips")
		var bone_name = ""
		if ":" in track_path_str:
			bone_name = track_path_str.split(":")[-1]
			# Remove the property suffix (:position, :rotation, etc.)
			bone_name = bone_name.split(":")[0]

		if bone_name and bone_name.length() > 0:
			var target_bone = bone_mapping.get_target_bone(bone_name)

			if target_bone != -1:
				# Get the transform components from the animation at this frame
				if animation.track_get_type(track_idx) == Animation.TYPE_POSITION_3D:
					var pos = _get_track_value_at(animation, track_idx, frame)
					if pos is Vector3:
						target_skeleton.set_bone_pose_position(target_bone, pos)

				elif animation.track_get_type(track_idx) == Animation.TYPE_ROTATION_3D:
					var rot = _get_track_value_at(animation, track_idx, frame)
					if rot is Quaternion:
						target_skeleton.set_bone_pose_rotation(target_bone, rot)

				elif animation.track_get_type(track_idx) == Animation.TYPE_SCALE_3D:
					var scale = _get_track_value_at(animation, track_idx, frame)
					if scale is Vector3:
						target_skeleton.set_bone_pose_scale(target_bone, scale)

## Get interpolated track value at a specific frame
func _get_track_value_at(animation: Animation, track_idx: int, frame: float) -> Variant:
	var frame_clamped = clamp(frame, 0, animation.length)
	var key_idx = animation.track_find_key(track_idx, frame_clamped, Animation.FIND_MODE_NEAREST)
	if key_idx >= 0:
		return animation.track_get_key_value(track_idx, key_idx)
	return null

## Build a pose cache from animation for faster lookups
func cache_animation_pose(animation: Animation, frame: float, bone: String = "") -> Dictionary:
	var pose = {}
	var search_bone = bone.to_lower() if bone else ""

	for track_idx in range(animation.get_track_count()):
		var track_path = animation.track_get_path(track_idx)
		var node_path = track_path.get_concatenated_subnames()

		if ":" in node_path:
			var bone_name = node_path.split(":")[1]

			if search_bone and search_bone not in bone_name.to_lower():
				continue

			var target_bone = bone_mapping.get_target_bone(bone_name)
			if target_bone == -1:
				continue

			var key_idx = animation.track_find_key(track_idx, frame, Animation.FIND_MODE_NEAREST)
			if key_idx >= 0:
				var value = animation.track_get_key_value(track_idx, key_idx)
				pose[target_bone] = value

	return pose
