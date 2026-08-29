## Owns Fred's AnimationPlayer.
##
## Fred.glb ships with a Skeleton3D but no AnimationPlayer, so we build one at
## runtime as a sibling of the skeleton. Its default root_node ("..") resolves
## to the skeleton's parent, which is what makes the baked tracks -- addressed
## as "Skeleton3D:<bone>" -- resolve without any per-scene path fixups.
##
## Clips come from res://Animations/Retargeted/<Category>.res, produced by
## Tools/bake_retargeted.gd. They are already retargeted from the source UE5
## rig onto Fred's GTA rig, so they play directly with no runtime cost.
extends Node
class_name FredAnimation

const LIB_DIR := "res://Animations/Retargeted"
const ROOT_BONE := "_rootJoint"

@export var debug_selftest: bool = false

var anim_player: AnimationPlayer
var skeleton: Skeleton3D

var _selftest_frames := 0
var _selftest_samples: Array[Vector3] = []
var _selftest_hips: Array[Vector3] = []

func _ready() -> void:
	var animated_target := get_parent().find_child("AnimatedTarget") if get_parent() else null
	if animated_target == null:
		push_error("FredAnimation: no AnimatedTarget under %s" % get_parent())
		return

	skeleton = animated_target.find_child("Skeleton3D", true, false)
	if skeleton == null:
		push_error("FredAnimation: no Skeleton3D under AnimatedTarget")
		return

	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	skeleton.get_parent().add_child(anim_player)

	# The baker puts each clip's world travel on the skeleton root. Declaring it
	# as the root motion track excludes it from the pose, so Fred animates in
	# place on his collision capsule; the displacement stays available through
	# anim_player.get_root_motion_position() for anything that wants it.
	anim_player.root_motion_track = NodePath("Skeleton3D:" + ROOT_BONE)

	var loaded := _load_libraries()
	print("FredAnimation: %d clips across %d libraries" % [loaded, anim_player.get_animation_library_list().size()])

	if debug_selftest:
		set_process(true)
	else:
		set_process(false)

## Load every baked category library. Clip names become "<Category>/<clip>".
func _load_libraries() -> int:
	var dir := DirAccess.open(LIB_DIR)
	if dir == null:
		push_error("FredAnimation: %s not found - run Tools/bake_retargeted.gd" % LIB_DIR)
		return 0

	var total := 0
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.get_extension() == "res":
			var lib := ResourceLoader.load(LIB_DIR + "/" + f) as AnimationLibrary
			if lib != null:
				var cat := f.get_basename()
				anim_player.add_animation_library(cat, lib)
				total += lib.get_animation_list().size()
		f = dir.get_next()
	dir.list_dir_end()
	return total

## All clip names, e.g. "Walk/M_Neutral_Walk_Box_F_LL_Lfoot".
func get_clips() -> PackedStringArray:
	return anim_player.get_animation_list() if anim_player else PackedStringArray()

## Clip names within one category, e.g. category "Walk".
func get_clips_in(category: String) -> PackedStringArray:
	var out := PackedStringArray()
	if anim_player == null:
		return out
	var lib := anim_player.get_animation_library(category)
	if lib == null:
		return out
	for n in lib.get_animation_list():
		out.append("%s/%s" % [category, n])
	return out

## FBX clips import as one-shots; locomotion needs them cycling, so opt into
## looping per playback rather than mutating every clip at bake time (jumps and
## traversal moves must still play once).
func play(clip: String, blend: float = 0.15, loop: bool = true) -> void:
	if anim_player == null or not anim_player.has_animation(clip):
		return
	var anim := anim_player.get_animation(clip)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	anim_player.play(clip, blend)

# --- self test -------------------------------------------------------------
# Confirms the skeleton actually moves once real frames are running, which the
# headless --script harness cannot show (Skeleton3D defers pose flushes).

func _process(_delta: float) -> void:
	if not debug_selftest or anim_player == null:
		return
	_selftest_frames += 1

	if _selftest_frames == 1:
		var clip := "Walk/M_Neutral_Walk_Loop_F"
		if not anim_player.has_animation(clip):
			var walk := get_clips_in("Walk")
			if walk.is_empty():
				print("SELFTEST: no Walk clips"); get_tree().quit(1); return
			clip = walk[0]
		print("SELFTEST: playing %s" % clip)
		play(clip)
		return

	var lf := skeleton.find_bone("SKEL_L_Foot_03")
	var hip := skeleton.find_bone("SKEL_Pelvis_00")
	if _selftest_frames % 10 == 0 and _selftest_samples.size() < 8:
		var p := skeleton.get_bone_global_pose(lf).origin
		var h := skeleton.get_bone_global_pose(hip).origin
		_selftest_samples.append(p)
		_selftest_hips.append(h)
		print("  frame %3d  Lfoot=%v  hip=%v" % [_selftest_frames, p, h])

	if _selftest_samples.size() >= 8:
		var travel := 0.0
		for a in _selftest_samples:
			for b in _selftest_samples:
				travel = maxf(travel, a.distance_to(b))
		# With root motion consumed the pelvis should sway within a stride, not
		# march off across the level, so bound its spread rather than its motion.
		var hip_spread := 0.0
		for a in _selftest_hips:
			for b in _selftest_hips:
				hip_spread = maxf(hip_spread, a.distance_to(b))

		var animating := travel > 0.02
		var in_place := hip_spread < 0.5
		print("SELFTEST: foot travel = %.3f m | hip spread = %.3f m" % [travel, hip_spread])
		print("SELFTEST: skeleton animating .... %s" % ("PASS" if animating else "FAIL"))
		print("SELFTEST: root motion consumed .. %s" % ("PASS" if in_place else "FAIL - mesh is drifting"))
		get_tree().quit(0 if (animating and in_place) else 1)
