## Imports FBX animation files and loads them into AnimationPlayer
extends Node
class_name FBXAnimationImporter

@export var auto_import: bool = true
@export var animation_folders: Array[String] = [
	"res://Animations/Idle/",
	"res://Animations/Walk/",
	"res://Animations/Run/",
	"res://Animations/Sprint/",
	"res://Animations/Jump/",
	"res://Animations/Crouch/",
	"res://Animations/AimOffset/",
	"res://Animations/Traversal/",
]

var anim_player: AnimationPlayer = null
var imported_animations: Dictionary = {}

func _ready() -> void:
	await get_tree().process_frame

	if not anim_player:
		var animated_target = get_parent().find_child("AnimatedTarget") if get_parent() else null
		if animated_target:
			anim_player = animated_target.find_child("AnimationPlayer", true, false)

	if not anim_player:
		print("FBXAnimationImporter: AnimationPlayer not found")
		return

	if auto_import:
		print("FBXAnimationImporter: Starting animation import...")
		import_all_animations()
		print("FBXAnimationImporter: Import complete. Loaded %d animations" % imported_animations.size())

## Import all animations from folders
func import_all_animations() -> void:
	for folder_path in animation_folders:
		import_animations_from_folder(folder_path)

## Import animations from a specific folder
func import_animations_from_folder(folder_path: String) -> int:
	var dir = DirAccess.open(folder_path)
	if not dir:
		print("FBXAnimationImporter: Cannot open folder: %s" % folder_path)
		return 0

	var count = 0
	dir.list_dir_begin()

	var file_name = dir.get_next()
	while file_name != "":
		if not file_name.starts_with("."):
			var ext = file_name.get_extension().to_lower()
			if ext in ["fbx", "glb", "gltf"]:
				var full_path = folder_path.path_join(file_name)
				if import_animation_file(full_path):
					count += 1

		file_name = dir.get_next()

	if count > 0:
		print("FBXAnimationImporter: Loaded %d animations from %s" % [count, folder_path])

	return count

## Import a single animation file
func import_animation_file(file_path: String) -> bool:
	if not ResourceLoader.exists(file_path):
		return false

	# An imported FBX/GLB/GLTF resolves to a PackedScene; a .res/.tres may be an Animation.
	var resource = ResourceLoader.load(file_path)
	if resource == null:
		return false

	if resource is PackedScene:
		return extract_animations_from_scene(resource, file_path)

	if resource is Animation:
		var anim_name = file_path.get_file().get_basename()
		add_animation_to_player(anim_name, resource)
		imported_animations[anim_name] = file_path
		return true

	return false

## Extract animations from an imported scene
func extract_animations_from_scene(scene: PackedScene, file_path: String) -> bool:
	if not anim_player:
		return false

	# Instantiate to access AnimationPlayer
	var temp_instance = scene.instantiate()
	if not temp_instance:
		return false

	var scene_anim_player = temp_instance.find_child("AnimationPlayer", true, false)
	if not scene_anim_player:
		temp_instance.queue_free()
		return false

	var lib = scene_anim_player.get_animation_library("")
	if not lib:
		temp_instance.queue_free()
		return false

	var anim_list = lib.get_animation_list()
	var imported_count = 0

	for anim_name in anim_list:
		var anim = lib.get_animation(anim_name)
		if anim:
			add_animation_to_player(anim_name, anim)
			imported_animations[anim_name] = file_path
			imported_count += 1

	temp_instance.queue_free()
	return imported_count > 0

## Add animation to the target AnimationPlayer
func add_animation_to_player(anim_name: String, animation: Animation) -> void:
	if not anim_player:
		return

	# Get or create animation library
	var lib = anim_player.get_animation_library("")
	if not lib:
		lib = AnimationLibrary.new()
		anim_player.add_animation_library("", lib)

	# Add animation with unique name
	var unique_name = anim_name
	var counter = 1
	while lib.has_animation(unique_name):
		unique_name = "%s_%d" % [anim_name, counter]
		counter += 1

	lib.add_animation(unique_name, animation)

## Get all imported animations
func get_imported_animations() -> Dictionary:
	return imported_animations.duplicate()

## Get animation count
func get_animation_count() -> int:
	return imported_animations.size()

## List all imported animation names
func list_animations() -> PackedStringArray:
	if not anim_player:
		return PackedStringArray()

	var lib = anim_player.get_animation_library("")
	if lib:
		return lib.get_animation_list()

	return PackedStringArray()

## Force reload all animations
func reload_animations() -> void:
	# Clear existing animations
	if anim_player:
		var lib = anim_player.get_animation_library("")
		if lib:
			for anim_name in lib.get_animation_list():
				lib.remove_animation(anim_name)

	imported_animations.clear()
	import_all_animations()
