## Bakes every source FBX in res://Animations/<Category>/ into animations
## retargeted onto Fred's skeleton, saved as one AnimationLibrary per category.
## Run:  godot --headless --path <proj> --script res://Tools/bake_retargeted.gd
extends SceneTree

const RT = preload("res://Tools/retarget_lib.gd")

const SRC_ROOT := "res://Animations"
const OUT_DIR := "res://Animations/Retargeted"
const FPS := 30.0
const TRACK_PREFIX := "Skeleton3D"

# Skip a key when it is within this angle of the previous one (radians).
const ROT_EPSILON := 0.0015
const POS_EPSILON := 0.0005

var tgt_rig
var categories: Array[String] = []

func _initialize() -> void:
	var fred = load("res://NaturalMotion/Characters/Fred.glb").instantiate()
	get_root().add_child(fred)
	var tgt_skel: Skeleton3D = fred.find_child("Skeleton3D", true, false)
	if tgt_skel == null:
		push_error("bake: Fred has no Skeleton3D")
		quit(1)
		return
	tgt_rig = RT.RigInfo.new(tgt_skel)
	print("Fred rig: %d bones" % tgt_skel.get_bone_count())

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	categories = _list_categories()
	print("categories: %s\n" % str(categories))

	var grand_total := 0
	var grand_failed := 0
	for cat in categories:
		var r := _bake_category(cat)
		grand_total += r[0]
		grand_failed += r[1]

	print("\n=== BAKE COMPLETE: %d animations, %d failures ===" % [grand_total, grand_failed])
	quit(0)

func _list_categories() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(SRC_ROOT)
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if d.current_is_dir() and not n.begins_with(".") and n != "Retargeted":
			out.append(n)
		n = d.get_next()
	d.list_dir_end()
	out.sort()
	return out

func _bake_category(cat: String) -> Array:
	var folder := SRC_ROOT + "/" + cat
	var files := _list_fbx(folder)
	if files.is_empty():
		print("%-28s (no FBX, skipped)" % cat)
		return [0, 0]

	var lib := AnimationLibrary.new()
	var ok := 0
	var failed := 0

	for i in range(files.size()):
		var path := folder + "/" + files[i]
		var anim := _bake_one(path)
		if anim == null:
			failed += 1
			continue
		# "/" separates library from clip in AnimationPlayer, so it cannot
		# appear inside a clip name -- flatten sub-folders into the name.
		var anim_name := files[i].get_basename().replace("/", "_")
		if lib.has_animation(anim_name):
			anim_name += "_%d" % i
		lib.add_animation(anim_name, anim)
		ok += 1
		if ok % 100 == 0:
			print("  %s ... %d/%d" % [cat, ok, files.size()])

	var out_path := OUT_DIR + "/" + cat + ".res"
	var err := ResourceSaver.save(lib, out_path)
	print("%-28s %4d baked, %2d failed -> %s%s"
		% [cat, ok, failed, out_path, "" if err == OK else "  (SAVE ERROR %d)" % err])
	return [ok, failed]

## Returns paths relative to `folder`; recurses so categories that group their
## clips into sub-folders (Traversal/Vault, Traversal/Climb, ...) are included.
func _list_fbx(folder: String, prefix: String = "") -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(folder)
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if d.current_is_dir():
			if not n.begins_with("."):
				out.append_array(_list_fbx(folder + "/" + n, prefix + n + "/"))
		elif n.get_extension().to_lower() == "fbx":
			out.append(prefix + n)
		n = d.get_next()
	d.list_dir_end()
	out.sort()
	return out

func _bake_one(path: String) -> Animation:
	var res = ResourceLoader.load(path)
	if not (res is PackedScene):
		return null
	var inst = res.instantiate()
	var src_skel: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	var src_ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	if src_skel == null or src_ap == null:
		inst.free()
		return null

	var names := src_ap.get_animation_list()
	if names.size() == 0:
		inst.free()
		return null
	var src_anim: Animation = src_ap.get_animation(names[0])

	var src_rig = RT.RigInfo.new(src_skel)
	var baked: Animation = RT.retarget_animation(src_anim, src_rig, tgt_rig, FPS, TRACK_PREFIX)
	_prune_redundant_keys(baked)
	inst.free()
	return baked

## Drop keys that barely differ from the previous one. Locomotion clips leave
## several bones (clavicles, neck) almost static, so this trims file size
## substantially without visible change.
func _prune_redundant_keys(anim: Animation) -> void:
	for tr in range(anim.get_track_count()):
		var ttype := anim.track_get_type(tr)
		var k := anim.track_get_key_count(tr) - 2   # always keep first and last
		while k >= 1:
			var prev = anim.track_get_key_value(tr, k - 1)
			var cur = anim.track_get_key_value(tr, k)
			var next_v = anim.track_get_key_value(tr, k + 1)
			var redundant := false
			if ttype == Animation.TYPE_ROTATION_3D:
				redundant = (prev as Quaternion).angle_to(cur) < ROT_EPSILON \
					and (cur as Quaternion).angle_to(next_v) < ROT_EPSILON
			elif ttype == Animation.TYPE_POSITION_3D:
				redundant = (prev as Vector3).distance_to(cur) < POS_EPSILON \
					and (cur as Vector3).distance_to(next_v) < POS_EPSILON
			if redundant:
				anim.track_remove_key(tr, k)
			k -= 1
