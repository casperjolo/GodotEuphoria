## Defines bone name mappings between source animations and target skeleton
class_name BoneMapping

# Standard humanoid bone names found in most motion capture libraries
const SOURCE_BONES = {
	"hips": "Hips",
	"spine": "Spine",
	"chest": "Chest",
	"neck": "Neck",
	"head": "Head",

	# Left arm
	"left_shoulder": "LeftShoulder",
	"left_arm": "LeftArm",
	"left_forearm": "LeftForeArm",
	"left_hand": "LeftHand",

	# Right arm
	"right_shoulder": "RightShoulder",
	"right_arm": "RightArm",
	"right_forearm": "RightForeArm",
	"right_hand": "RightHand",

	# Left leg
	"left_upleg": "LeftUpLeg",
	"left_leg": "LeftLeg",
	"left_foot": "LeftFoot",
	"left_toes": "LeftToes",

	# Right leg
	"right_upleg": "RightUpLeg",
	"right_leg": "RightLeg",
	"right_foot": "RightFoot",
	"right_toes": "RightToes",
}

# Fred's actual skeleton bone names (will be auto-detected)
var target_bones: Dictionary = {}
var source_to_target_map: Dictionary = {}

func _init(skeleton: Skeleton3D) -> void:
	_scan_skeleton(skeleton)
	_build_mapping()

## Scan the skeleton to find available bones
func _scan_skeleton(skeleton: Skeleton3D) -> void:
	target_bones.clear()
	for i in range(skeleton.get_bone_count()):
		var bone_name = skeleton.get_bone_name(i)
		var lower_name = bone_name.to_lower()
		target_bones[lower_name] = i

## Build mapping by matching source bones to target bones
func _build_mapping() -> void:
	source_to_target_map.clear()

	for key in SOURCE_BONES:
		var source_name = SOURCE_BONES[key]
		var lower_source = source_name.to_lower()

		# Try exact match first
		if lower_source in target_bones:
			source_to_target_map[source_name] = target_bones[lower_source]
			continue

		# Try partial match
		for target_lower in target_bones:
			if source_name.to_lower().contains(target_lower) or target_lower.contains(source_name.to_lower()):
				source_to_target_map[source_name] = target_bones[target_lower]
				break

## Get the target bone index for a source bone name
func get_target_bone(source_bone: String) -> int:
	if source_bone in source_to_target_map:
		return source_to_target_map[source_bone]

	# Fallback: try case-insensitive lookup
	var lower_source = source_bone.to_lower()
	for target_lower in target_bones:
		if lower_source == target_lower:
			return target_bones[target_lower]

	return -1

## Check if source bone is mapped
func has_mapping(source_bone: String) -> bool:
	return get_target_bone(source_bone) != -1
