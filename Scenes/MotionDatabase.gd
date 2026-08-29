## Stores and manages motion features from all animations
extends Resource
class_name MotionDatabase

## Dictionary mapping animation names to their feature sequences
var motion_features: Dictionary = {}

## Mapping of locomotion types to animations
var locomotion_types: Dictionary = {
	"idle": [],
	"walk": [],
	"run": [],
	"sprint": [],
	"jump": [],
	"crouch": [],
	"aim": [],
	"traversal": [],
}

## Add a feature sequence for an animation
func add_animation_features(animation_name: String, features: Array[MotionFeature]) -> void:
	motion_features[animation_name] = features
	if features.size() > 0:
		var anim_type = features[0].locomotion_type
		if anim_type in locomotion_types:
			if animation_name not in locomotion_types[anim_type]:
				locomotion_types[anim_type].append(animation_name)

## Get all features for an animation
func get_animation_features(animation_name: String) -> Array[MotionFeature]:
	if animation_name in motion_features:
		return motion_features[animation_name]
	return []

## Find the best matching frame across all animations or a specific type
func find_best_match(target_feature: MotionFeature, locomotion_type: String = "", max_results: int = 1) -> Array:
	var candidates = []
	var search_types = [locomotion_type] if locomotion_type else locomotion_types.keys()

	for anim_type in search_types:
		if anim_type not in locomotion_types:
			continue

		for anim_name in locomotion_types[anim_type]:
			if anim_name in motion_features:
				for feature in motion_features[anim_name]:
					var distance = target_feature.distance_to(feature)
					candidates.append({
						"feature": feature,
						"distance": distance,
						"animation": anim_name,
						"frame": feature.frame,
					})

	# Sort by distance
	candidates.sort_custom(func(a, b): return a["distance"] < b["distance"])

	# Return top results
	return candidates.slice(0, min(max_results, candidates.size()))

## Find transitions between animations (for smooth blending)
func find_transition(from_feature: MotionFeature, to_locomotion_type: String) -> Dictionary:
	var candidates = find_best_match(from_feature, to_locomotion_type, 5)
	if candidates.size() > 0:
		return candidates[0]
	return {}

## Get feature at specific time in animation
func get_feature_at_time(animation_name: String, time: float) -> MotionFeature:
	if animation_name not in motion_features:
		return MotionFeature.new()

	var features = motion_features[animation_name]
	if features.size() == 0:
		return MotionFeature.new()

	# Binary search for closest frame
	var low = 0
	var high = features.size() - 1

	while low < high:
		var mid = (low + high) / 2
		if features[mid].time < time:
			low = mid + 1
		else:
			high = mid

	return features[low] if low < features.size() else features[features.size() - 1]

## Save database to resource file
func save_to_file(path: String) -> bool:
	return ResourceSaver.save(self, path) == OK

## Clear all data
func clear() -> void:
	motion_features.clear()
	for key in locomotion_types:
		locomotion_types[key].clear()
