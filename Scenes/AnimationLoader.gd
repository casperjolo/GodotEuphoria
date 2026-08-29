## Loads and organizes animations from loaded AnimationPlayer
extends Node
class_name AnimationLoader

@onready var anim_player: AnimationPlayer = get_node_or_null("../AnimatedTarget").find_child("AnimationPlayer") if has_node("../AnimatedTarget") else null

var loaded_animations: Dictionary = {}  # anim_name -> Animation resource
var animation_metadata: Dictionary = {}  # anim_name -> metadata

func _ready() -> void:
	# Wait a frame for all nodes to initialize
	await get_tree().process_frame

	# Find AnimationPlayer in the scene
	var parent = get_parent()
	if parent:
		var animated_target = parent.find_child("AnimatedTarget")
		if animated_target:
			# Look for AnimationPlayer recursively
			anim_player = animated_target.find_child("AnimationPlayer", true, false)

	if not anim_player:
		print("AnimationLoader: No AnimationPlayer found yet, trying again...")
		# Try one more time with deeper search
		anim_player = get_tree().root.find_child("AnimationPlayer", true, false)

	if not anim_player:
		print("AnimationLoader: Warning - No AnimationPlayer found")
	else:
		print("AnimationLoader: Found AnimationPlayer with %d animations" % anim_player.get_animation_list().size())

## Load all animations currently in AnimationPlayer
func load_all_animations() -> bool:
	if not anim_player:
		push_error("AnimationLoader: AnimationPlayer not found")
		return false

	loaded_animations.clear()
	animation_metadata.clear()

	# Get all animations from AnimationPlayer
	var lib = anim_player.get_animation_library("")
	if not lib:
		print("AnimationLoader: No default animation library found")
		return false

	for anim_name in lib.get_animation_list():
		var animation = lib.get_animation(anim_name)
		if animation:
			loaded_animations[anim_name] = animation

			# Categorize by animation name
			var category = _categorize_animation(anim_name)
			animation_metadata[anim_name] = {
				"name": anim_name,
				"type": category,
				"length": animation.length,
				"track_count": animation.get_track_count(),
			}

	print("AnimationLoader: Loaded %d animations from AnimationPlayer" % loaded_animations.size())
	return loaded_animations.size() > 0

## Categorize animation based on its name
func _categorize_animation(anim_name: String) -> String:
	var lower_name = anim_name.to_lower()

	var categories = ["walk", "run", "sprint", "jump", "crouch", "aim", "idle", "traversal"]
	for category in categories:
		if category in lower_name:
			return category

	return "idle"  # Default to idle

## Get all loaded animation names
func get_loaded_animations() -> PackedStringArray:
	return PackedStringArray(loaded_animations.keys())

## Get animation by name
func get_animation(name: String) -> Animation:
	if name in loaded_animations:
		return loaded_animations[name]
	return null

## Get metadata for animation
func get_animation_metadata(name: String) -> Dictionary:
	if name in animation_metadata:
		return animation_metadata[name]
	return {}

## Get count of loaded animations
func get_animation_count() -> int:
	return loaded_animations.size()

## Get all animations of a specific type
func get_animations_by_type(type: String) -> PackedStringArray:
	var result = PackedStringArray()
	for anim_name in animation_metadata:
		if animation_metadata[anim_name]["type"] == type:
			result.append(anim_name)
	return result

## Set the AnimationPlayer manually (in case auto-detection fails)
func set_animation_player(player: AnimationPlayer) -> void:
	anim_player = player
	print("AnimationLoader: AnimationPlayer set manually")
