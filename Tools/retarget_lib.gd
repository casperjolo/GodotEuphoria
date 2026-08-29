## Shared UE5 (Manny) -> Fred (GTA/RAGE) retargeting logic.
## Rest-pose-relative retarget: the source animation's deviation from its own
## rest pose is measured in model space, then re-applied onto Fred's rest pose.
## This is what makes two rigs with different rest poses and bone axes agree.
class_name RetargetLib

## source UE5 bone name -> Fred bone name.
## Fred has 4 spine bones vs UE5's 5; clavicles hang off spine_05 in UE5 and off
## SKEL_Spine3 in Fred, so spine_05 -> Spine3 keeps the shoulder parent correct.
## spine_04 is intentionally unmapped (its rotation is small in locomotion).
const BONE_MAP := {
	"pelvis": "SKEL_Pelvis_00",

	"spine_01": "SKEL_Spine_Root_07",
	"spine_02": "SKEL_Spine1_08",
	"spine_03": "SKEL_Spine2_09",
	"spine_05": "SKEL_Spine3_010",

	"neck_01": "SKEL_Neck_1_019",
	"head": "SKEL_Head_020",

	"clavicle_l": "SKEL_L_Clavicle_011",
	"upperarm_l": "SKEL_L_UpperArm_012",
	"lowerarm_l": "SKEL_L_Forearm_013",
	"hand_l": "SKEL_L_Hand_014",

	"clavicle_r": "SKEL_R_Clavicle_015",
	"upperarm_r": "SKEL_R_UpperArm_016",
	"lowerarm_r": "SKEL_R_Forearm_017",
	"hand_r": "SKEL_R_Hand_018",

	"thigh_l": "SKEL_L_Thigh_01",
	"calf_l": "SKEL_L_Calf_02",
	"foot_l": "SKEL_L_Foot_03",
	"ball_l": "SKEL_L_Foot_end_021",

	"thigh_r": "SKEL_R_Thigh_04",
	"calf_r": "SKEL_R_Calf_05",
	"foot_r": "SKEL_R_Foot_06",
	"ball_r": "SKEL_R_Foot_end_022",
}

## The source bone whose translation carries the character through the world.
const ROOT_MOTION_BONE := "pelvis"

## Fred's skeleton root. The hip's horizontal travel is baked onto this bone so
## it can be consumed as AnimationMixer root motion, leaving the pelvis track
## carrying only the vertical bob. Without this split, playing a clip drags
## Fred's mesh metres away from his collision capsule.
const TARGET_ROOT_BONE := "_rootJoint"

## Per-skeleton cache of rest data, so we compute it once per rig.
class RigInfo:
	var skel: Skeleton3D
	var name_to_idx := {}
	var rest_local: Array[Transform3D] = []
	var rest_model: Array[Transform3D] = []
	var parents: PackedInt32Array = PackedInt32Array()

	func _init(s: Skeleton3D) -> void:
		skel = s
		var n := s.get_bone_count()
		rest_local.resize(n)
		rest_model.resize(n)
		parents.resize(n)
		for i in range(n):
			name_to_idx[s.get_bone_name(i)] = i
			rest_local[i] = s.get_bone_rest(i)
			parents[i] = s.get_bone_parent(i)
		# bones are always ordered parent-before-child in Godot
		for i in range(n):
			var p := parents[i]
			rest_model[i] = rest_local[i] if p < 0 else rest_model[p] * rest_local[i]

	func idx(bone_name: String) -> int:
		return name_to_idx.get(bone_name, -1)


## Sample the source animation's model-space pose at time `t`.
## Returns an Array[Transform3D] indexed by source bone index.
static func sample_source_model_pose(anim: Animation, src: RigInfo, t: float,
		track_cache: Dictionary) -> Array:
	var n := src.rest_local.size()
	var model: Array[Transform3D] = []
	model.resize(n)

	for i in range(n):
		var rest := src.rest_local[i]
		var loc_rot := rest.basis.get_rotation_quaternion()
		var loc_pos := rest.origin
		var scale := rest.basis.get_scale()

		var tracks: Array = track_cache.get(i, [-1, -1])
		var rot_track: int = tracks[0]
		var pos_track: int = tracks[1]

		if rot_track >= 0:
			loc_rot = anim.rotation_track_interpolate(rot_track, t)
		if pos_track >= 0:
			loc_pos = anim.position_track_interpolate(pos_track, t)

		var local := Transform3D(Basis(loc_rot).scaled(scale), loc_pos)
		var p := src.parents[i]
		model[i] = local if p < 0 else model[p] * local

	return model


## Build {src_bone_idx: [rotation_track_idx, position_track_idx]} for one animation.
static func build_track_cache(anim: Animation, src: RigInfo) -> Dictionary:
	var cache := {}
	for track_idx in range(anim.get_track_count()):
		var path := anim.track_get_path(track_idx)
		var bone_name := String(path.get_subname(0)) if path.get_subname_count() > 0 else ""
		if bone_name == "":
			continue
		var bi := src.idx(bone_name)
		if bi < 0:
			continue
		if not cache.has(bi):
			cache[bi] = [-1, -1]
		var ttype := anim.track_get_type(track_idx)
		if ttype == Animation.TYPE_ROTATION_3D:
			cache[bi][0] = track_idx
		elif ttype == Animation.TYPE_POSITION_3D:
			cache[bi][1] = track_idx
	return cache


## Pelvis-to-foot distance, used to scale root translation so a tall rig's
## stride does not overshoot on a shorter one. Measured as a 3D distance
## because the two rigs do not share an up axis.
static func rig_leg_length(rig: RigInfo, hip_bone: String, foot_bone: String) -> float:
	var h := rig.idx(hip_bone)
	var f := rig.idx(foot_bone)
	if h < 0 or f < 0:
		return 1.0
	return rig.rest_model[h].origin.distance_to(rig.rest_model[f].origin)


## Orthonormal basis describing how a rig is oriented in its own model space,
## derived from its rest pose: +Y along hips->head, +X along left->right hip.
## Lets us convert motion between rigs with different up/forward conventions
## (the UE5 source is Y-up; Fred's GTA rig is Z-up) without hardcoding axes.
static func rig_orientation(rig: RigInfo, hip: String, head: String,
		left_thigh: String, right_thigh: String) -> Basis:
	var h := rig.idx(hip)
	var hd := rig.idx(head)
	var lt := rig.idx(left_thigh)
	var rt := rig.idx(right_thigh)
	if h < 0 or hd < 0 or lt < 0 or rt < 0:
		return Basis.IDENTITY

	var up := (rig.rest_model[hd].origin - rig.rest_model[h].origin).normalized()
	var raw_side := (rig.rest_model[rt].origin - rig.rest_model[lt].origin).normalized()
	if up.length_squared() < 0.5 or raw_side.length_squared() < 0.5:
		return Basis.IDENTITY

	var fwd := raw_side.cross(up).normalized()
	var side := up.cross(fwd).normalized()
	return Basis(side, up, fwd)


## Rotation taking source model space into target model space.
static func space_change(src: RigInfo, tgt: RigInfo) -> Quaternion:
	var src_basis := rig_orientation(src, "pelvis", "head", "thigh_l", "thigh_r")
	var tgt_basis := rig_orientation(tgt, "SKEL_Pelvis_00", "SKEL_Head_020",
		"SKEL_L_Thigh_01", "SKEL_R_Thigh_04")
	return (tgt_basis * src_basis.inverse()).get_rotation_quaternion().normalized()


## Retarget one source animation onto the target rig, returning a new Animation
## whose tracks address `track_prefix + ":" + fred_bone_name`.
static func retarget_animation(anim: Animation, src: RigInfo, tgt: RigInfo,
		fps: float, track_prefix: String) -> Animation:
	var out := Animation.new()
	out.length = anim.length
	out.loop_mode = anim.loop_mode

	var track_cache := build_track_cache(anim, src)

	# The two rigs differ in both scale and up axis; C converts a motion
	# expressed in source model space into target model space.
	var C := space_change(src, tgt)
	var C_inv := C.inverse()

	var hip_scale := 1.0
	var src_leg := rig_leg_length(src, "pelvis", "foot_l")
	var tgt_leg := rig_leg_length(tgt, "SKEL_Pelvis_00", "SKEL_L_Foot_03")
	if src_leg > 0.0001:
		hip_scale = tgt_leg / src_leg

	# Create one rotation track per mapped bone (+ a position track for the hips).
	var rot_track_of := {}   # tgt_idx -> out track idx
	var pos_track_of := {}
	for src_name in BONE_MAP:
		var tgt_name: String = BONE_MAP[src_name]
		var si := src.idx(src_name)
		var ti := tgt.idx(tgt_name)
		if si < 0 or ti < 0:
			continue
		var rt := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(rt, NodePath(track_prefix + ":" + tgt_name))
		out.track_set_interpolation_type(rt, Animation.INTERPOLATION_LINEAR)
		rot_track_of[ti] = rt
		if src_name == ROOT_MOTION_BONE:
			var pt := out.add_track(Animation.TYPE_POSITION_3D)
			out.track_set_path(pt, NodePath(track_prefix + ":" + tgt_name))
			out.track_set_interpolation_type(pt, Animation.INTERPOLATION_LINEAR)
			pos_track_of[ti] = pt

	# Separate track for world travel, consumed as root motion at runtime.
	var root_idx := tgt.idx(TARGET_ROOT_BONE)
	var root_track := -1
	if root_idx >= 0:
		root_track = out.add_track(Animation.TYPE_POSITION_3D)
		out.track_set_path(root_track, NodePath(track_prefix + ":" + TARGET_ROOT_BONE))
		out.track_set_interpolation_type(root_track, Animation.INTERPOLATION_LINEAR)

	var up_tgt := rig_orientation(tgt, "SKEL_Pelvis_00", "SKEL_Head_020",
		"SKEL_L_Thigh_01", "SKEL_R_Thigh_04").y

	var step := 1.0 / fps
	var frame_count := int(ceil(anim.length / step)) + 1

	for frame in range(frame_count):
		var t := minf(frame * step, anim.length)
		var src_model := sample_source_model_pose(anim, src, t, track_cache)

		# First pass: compute every mapped bone's target model-space rotation.
		var tgt_model_rot := {}
		for src_name in BONE_MAP:
			var tgt_name: String = BONE_MAP[src_name]
			var si := src.idx(src_name)
			var ti := tgt.idx(tgt_name)
			if si < 0 or ti < 0:
				continue
			var src_now: Quaternion = src_model[si].basis.get_rotation_quaternion()
			var src_rest: Quaternion = src.rest_model[si].basis.get_rotation_quaternion()
			var tgt_rest: Quaternion = tgt.rest_model[ti].basis.get_rotation_quaternion()
			# deviation from source rest, rotated into target space, then
			# re-applied on top of the target's own rest orientation
			var deviation := src_now * src_rest.inverse()
			var deviation_tgt := C * deviation * C_inv
			tgt_model_rot[ti] = (deviation_tgt * tgt_rest).normalized()

		# Second pass: convert model-space to parent-local for each target bone.
		for ti in rot_track_of:
			var model_rot: Quaternion = tgt_model_rot[ti]
			var parent_rot := _nearest_mapped_parent_rot(ti, tgt, tgt_model_rot)
			var local_rot := (parent_rot.inverse() * model_rot).normalized()
			out.rotation_track_insert_key(rot_track_of[ti], t, local_rot)

		# Hip translation, rotated into target space and scaled between the rigs,
		# then split: vertical bob stays on the pelvis, horizontal travel moves
		# to the skeleton root so it can be consumed as root motion.
		for ti in pos_track_of:
			var si := src.idx(ROOT_MOTION_BONE)
			var delta: Vector3 = C * (src_model[si].origin - src.rest_model[si].origin) * hip_scale
			var vertical := up_tgt * delta.dot(up_tgt)
			var horizontal := delta - vertical

			var model_pos: Vector3 = tgt.rest_model[ti].origin + vertical
			var p := tgt.parents[ti]
			var local_pos := model_pos
			if p >= 0:
				var parent_rot := _nearest_mapped_parent_rot(ti, tgt, tgt_model_rot)
				local_pos = parent_rot.inverse() * (model_pos - tgt.rest_model[p].origin)
			out.position_track_insert_key(pos_track_of[ti], t, local_pos)

			if root_track >= 0:
				out.position_track_insert_key(root_track, t,
					tgt.rest_local[root_idx].origin + horizontal)

	return out


## Walk up the target hierarchy until we hit a bone we actually animated;
## unmapped intermediates keep their rest orientation.
static func _nearest_mapped_parent_rot(ti: int, tgt: RigInfo, tgt_model_rot: Dictionary) -> Quaternion:
	var p := tgt.parents[ti]
	while p >= 0:
		if tgt_model_rot.has(p):
			return tgt_model_rot[p]
		p = tgt.parents[p]
	return Quaternion.IDENTITY
