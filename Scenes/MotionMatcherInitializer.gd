## Initializes the motion matching system on scene load
extends Node
class_name MotionMatcherInitializer

@export var auto_load_animations: bool = true
@export var auto_build_database: bool = true

@onready var motion_matcher: MotionMatcher = get_parent().find_child("MotionMatcher")
@onready var animation_loader: AnimationLoader = get_parent().find_child("AnimationLoader")
@onready var retargeter: Retargeter = get_parent().find_child("Retargeter")
@onready var fbx_importer: FBXAnimationImporter = get_parent().find_child("FBXAnimationImporter")

var initialization_complete: bool = false

func _ready() -> void:
	# Ensure all components are found
	if not motion_matcher:
		push_error("MotionMatcherInitializer: MotionMatcher not found")
		return

	if not animation_loader:
		push_error("MotionMatcherInitializer: AnimationLoader not found")
		return

	if not retargeter:
		push_error("MotionMatcherInitializer: Retargeter not found")
		return

	# Wait a frame for all _ready() calls to complete
	await get_tree().process_frame

	# Wait for FBX importer to load animations (if it exists)
	if fbx_importer:
		print("MotionMatcherInitializer: Waiting for FBX animations to import...")
		await get_tree().process_frame  # Give importer time to finish

	# Initialize systems
	if auto_load_animations:
		print("MotionMatcherInitializer: Loading animations into motion matcher...")
		animation_loader.load_all_animations()

	if auto_build_database:
		print("MotionMatcherInitializer: Building motion database...")
		motion_matcher.build_database_from_animations()

	# Verify animations loaded
	var anim_count = motion_matcher.motion_database.motion_features.size()
	if anim_count > 0:
		print("MotionMatcherInitializer: SUCCESS - %d animations in database" % anim_count)
	else:
		print("MotionMatcherInitializer: WARNING - No animations in database")

	print("MotionMatcherInitializer: Motion matching system ready")
	initialization_complete = true

func is_ready() -> bool:
	return initialization_complete
