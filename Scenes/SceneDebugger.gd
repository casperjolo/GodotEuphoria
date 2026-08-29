## Debug script to help diagnose scene structure and component issues
extends Node
class_name SceneDebugger

func _ready() -> void:
	var separator = _make_separator("=")
	print("\n" + separator)
	print("SCENE STRUCTURE DIAGNOSTIC")
	print(separator)

	await get_tree().process_frame

	_print_scene_structure()
	_check_components()
	_check_animations()

	print(separator + "\n")

## Build a repeated-character separator line
func _make_separator(character: String, length: int = 60) -> String:
	var result = ""
	for i in range(length):
		result += character
	return result

## Print the complete scene hierarchy
func _print_scene_structure() -> void:
	print("\nScene Hierarchy:")
	print(_make_separator("-"))
	_print_node(get_tree().root, 0)

## Recursively print node structure
func _print_node(node: Node, depth: int) -> void:
	var indent = _make_separator("  ", depth)
	var type_name = node.get_class()

	# Highlight important nodes
	var marker = ""
	if "AnimationPlayer" in type_name:
		marker = " ← ANIMATION PLAYER"
	elif "Skeleton3D" in type_name:
		marker = " ← SKELETON"
	elif "AnimatedTarget" in node.name or "Fred" in node.name:
		marker = " ← CHARACTER"

	print("%s%s (%s)%s" % [indent, node.name, type_name, marker])

	for child in node.get_children():
		_print_node(child, depth + 1)

## Check if all components are found
func _check_components() -> void:
	print("\nComponent Check:")
	print(_make_separator("-"))

	var parent = get_parent()
	var results = []

	# Check each component
	var motion_matcher = parent.find_child("MotionMatcher")
	results.append(["MotionMatcher", motion_matcher != null])

	var animation_loader = parent.find_child("AnimationLoader")
	results.append(["AnimationLoader", animation_loader != null])

	var retargeter = parent.find_child("Retargeter")
	results.append(["Retargeter", retargeter != null])

	var animated_target = parent.find_child("AnimatedTarget")
	results.append(["AnimatedTarget", animated_target != null])

	# Check for nested nodes
	if animated_target:
		var anim_player = animated_target.find_child("AnimationPlayer", true, false)
		results.append(["  └─ AnimationPlayer", anim_player != null])

		var skeleton = animated_target.find_child("Skeleton3D", true, false)
		results.append(["  └─ Skeleton3D", skeleton != null])

		if skeleton:
			var bone_count = skeleton.get_bone_count()
			results.append(["    └─ Bones", bone_count > 0, " (%d bones)" % bone_count])

	# Print results
	for result in results:
		var status = "✓" if result[1] else "✗"
		var extra = result[2] if result.size() > 2 else ""
		print("%s %s%s" % [status, result[0], extra])

## Check animations in AnimationPlayer
func _check_animations() -> void:
	print("\nAnimations Check:")
	print(_make_separator("-"))

	var parent = get_parent()
	var animated_target = parent.find_child("AnimatedTarget")

	if not animated_target:
		print("✗ AnimatedTarget not found")
		return

	var anim_player = animated_target.find_child("AnimationPlayer", true, false)
	if not anim_player:
		print("✗ AnimationPlayer not found")
		return

	var lib = anim_player.get_animation_library("")
	if not lib:
		print("✗ No animation library found")
		return

	var anim_list = lib.get_animation_list()
	print("✓ Found %d animations" % anim_list.size())

	if anim_list.size() > 0:
		print("\nAnimation List (first 10):")
		for i in range(min(10, anim_list.size())):
			var anim_name = anim_list[i]
			var anim = lib.get_animation(anim_name)
			print("  - %s (length: %.2fs, tracks: %d)" % [
				anim_name,
				anim.length,
				anim.get_track_count()
			])

		if anim_list.size() > 10:
			print("  ... and %d more" % (anim_list.size() - 10))
	else:
		print("⚠ No animations loaded!")
		print("  Make sure FBX files are in Animations/ folders")
		print("  Godot must import them first (Project > Tools > Reimport)")

## Generate a diagnostic report
func generate_report() -> String:
	var report = "\n### DIAGNOSTIC REPORT ###\n"

	var parent = get_parent()
	var animated_target = parent.find_child("AnimatedTarget")

	if animated_target:
		var anim_player = animated_target.find_child("AnimationPlayer", true, false)
		var skeleton = animated_target.find_child("Skeleton3D", true, false)

		report += "\nAnimationPlayer: %s\n" % ("FOUND" if anim_player else "MISSING")
		report += "Skeleton3D: %s\n" % ("FOUND" if skeleton else "MISSING")

		if anim_player:
			var lib = anim_player.get_animation_library("")
			report += "Animations: %d\n" % (lib.get_animation_list().size() if lib else 0)

		if skeleton:
			report += "Bones: %d\n" % skeleton.get_bone_count()
	else:
		report += "\nAnimatedTarget: MISSING\n"

	return report

## Call this from console to debug
func print_diagnostic() -> void:
	_print_scene_structure()
	_check_components()
	_check_animations()
