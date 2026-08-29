extends SceneTree

const RT = preload("res://Tools/retarget_lib.gd")
const SRC_FBX := "res://Animations/Walk/M_Neutral_Walk_Box_F_LL_Lfoot.FBX"

var tgt_skel: Skeleton3D
var tgt_rig
var out_anim: Animation

func _initialize() -> void:
	var fred = load("res://NaturalMotion/Characters/Fred.glb").instantiate()
	get_root().add_child(fred)
	tgt_skel = fred.find_child("Skeleton3D", true, false)

	var src_inst = load(SRC_FBX).instantiate()
	get_root().add_child(src_inst)
	var src_skel: Skeleton3D = src_inst.find_child("Skeleton3D", true, false)
	var src_ap: AnimationPlayer = src_inst.find_child("AnimationPlayer", true, false)
	var src_anim: Animation = src_ap.get_animation("Unreal Take")

	var src_rig = RT.RigInfo.new(src_skel)
	tgt_rig = RT.RigInfo.new(tgt_skel)

	var src_basis: Basis = RT.rig_orientation(src_rig, "pelvis", "head", "thigh_l", "thigh_r")
	var tgt_basis: Basis = RT.rig_orientation(tgt_rig, "SKEL_Pelvis_00", "SKEL_Head_020",
		"SKEL_L_Thigh_01", "SKEL_R_Thigh_04")
	print("source up axis = %v" % src_basis.y)
	print("target up axis = %v" % tgt_basis.y)
	print("source leg len = %.4f" % RT.rig_leg_length(src_rig, "pelvis", "foot_l"))
	print("target leg len = %.4f" % RT.rig_leg_length(tgt_rig, "SKEL_Pelvis_00", "SKEL_L_Foot_03"))

	# --- diagnose source sampling ---
	var tc: Dictionary = RT.build_track_cache(src_anim, src_rig)
	print("\nsource anim: length=%.3f tracks=%d" % [src_anim.length, src_anim.get_track_count()])
	print("track cache entries = %d" % tc.size())
	var t0 := String(src_anim.track_get_path(0))
	print("track0 path=%s subnames=%d subname0=%s"
		% [t0, src_anim.track_get_path(0).get_subname_count(),
		   String(src_anim.track_get_path(0).get_subname(0)) if src_anim.track_get_path(0).get_subname_count() > 0 else "-"])
	var pi: int = src_rig.idx("pelvis")
	var tl: int = src_rig.idx("thigh_l")
	print("pelvis idx=%d cache=%s | thigh_l idx=%d cache=%s"
		% [pi, str(tc.get(pi, "MISSING")), tl, str(tc.get(tl, "MISSING"))])
	for tt in [0.0, 0.5, 1.0, 1.5]:
		var raw: Quaternion = src_anim.rotation_track_interpolate(tc[tl][0], tt)
		var m: Array = RT.sample_source_model_pose(src_anim, src_rig, tt, tc)
		print("  t=%.2f  raw thigh_l track=%s  model thigh_l=%s  pelvis=%s"
			% [tt, str(raw), str(m[tl].basis.get_rotation_quaternion()), str(m[pi].origin)])

	out_anim = RT.retarget_animation(src_anim, src_rig, tgt_rig, 30.0, "Skeleton3D")
	print("retargeted: length=%.3f tracks=%d" % [out_anim.length, out_anim.get_track_count()])

	# --- inspect the baked output keys ---
	for tr in range(out_anim.get_track_count()):
		if String(out_anim.track_get_path(tr)).ends_with("SKEL_L_Thigh_01") \
				and out_anim.track_get_type(tr) == Animation.TYPE_ROTATION_3D:
			print("out track %d (L thigh rot) keys=%d" % [tr, out_anim.track_get_key_count(tr)])
			for k in range(min(4, out_anim.track_get_key_count(tr))):
				print("    key %d t=%.3f val=%s"
					% [k, out_anim.track_get_key_time(tr, k), str(out_anim.track_get_key_value(tr, k))])
			break

	var up: Vector3 = tgt_basis.y
	var hip: int = tgt_rig.idx("SKEL_Pelvis_00")
	var head: int = tgt_rig.idx("SKEL_Head_020")
	var lf: int = tgt_rig.idx("SKEL_L_Foot_03")
	var rf: int = tgt_rig.idx("SKEL_R_Foot_06")

	# Evaluate the baked animation by pure forward kinematics over Fred's
	# hierarchy - independent of Skeleton3D's pose caching.
	var out_cache: Dictionary = RT.build_track_cache(out_anim, tgt_rig)
	print("baked-track cache entries = %d" % out_cache.size())

	print("\n--- pose over time, heights along Fred's up axis (m) ---")
	print("%6s %8s %8s %8s %8s %10s" % ["t", "hip", "head", "Lfoot", "Rfoot", "skelLfoot"])
	var nan_count := 0
	var lf_positions := []
	var skel_lf_positions := []
	var samples := 8
	for i in range(samples):
		var t := out_anim.length * float(i) / float(samples)
		var m: Array = RT.sample_source_model_pose(out_anim, tgt_rig, t, out_cache)
		var hp: Vector3 = m[hip].origin
		var hd: Vector3 = m[head].origin
		var lfp: Vector3 = m[lf].origin
		var rfp: Vector3 = m[rf].origin
		lf_positions.append(lfp)
		if is_nan(hp.x) or is_nan(hd.x) or is_nan(lfp.x) or is_nan(rfp.x):
			nan_count += 1
		# cross-check through the actual Skeleton3D the game will drive
		_apply_pose(t)
		var skel_lf: Vector3 = tgt_skel.get_bone_global_pose(lf).origin
		skel_lf_positions.append(skel_lf)
		print("%6.2f %8.3f %8.3f %8.3f %8.3f %10.3f"
			% [t, hp.dot(up), hd.dot(up), lfp.dot(up), rfp.dot(up), skel_lf.dot(up)])

	var mq: Array = RT.sample_source_model_pose(out_anim, tgt_rig, out_anim.length * 0.25, out_cache)
	var hp: Vector3 = mq[hip].origin
	var hd: Vector3 = mq[head].origin
	var lfp: Vector3 = mq[lf].origin
	var rfp: Vector3 = mq[rf].origin
	var stature: float = hd.dot(up) - minf(lfp.dot(up), rfp.dot(up))

	var skel_travel := 0.0
	for a in skel_lf_positions:
		for b in skel_lf_positions:
			skel_travel = maxf(skel_travel, a.distance_to(b))

	var max_foot_travel := 0.0
	for a in lf_positions:
		for b in lf_positions:
			max_foot_travel = maxf(max_foot_travel, a.distance_to(b))

	print("\n--- checks ---")
	_check("no NaNs in pose", nan_count == 0)
	_check("head above hips", hd.dot(up) > hp.dot(up))
	_check("left foot below hips", lfp.dot(up) < hp.dot(up))
	_check("right foot below hips", rfp.dot(up) < hp.dot(up))
	_check("stature plausible 1.2-2.2m (got %.2f)" % stature, stature > 1.2 and stature < 2.2)
	_check("left foot travels, via FK (%.3fm)" % max_foot_travel, max_foot_travel > 0.05)
	_check("left foot travels, via Skeleton3D (%.3fm)" % skel_travel, skel_travel > 0.05)
	quit()

## Drive Fred's skeleton straight from the retargeted tracks.
func _apply_pose(t: float) -> void:
	tgt_skel.reset_bone_poses()
	for tr in range(out_anim.get_track_count()):
		var path := out_anim.track_get_path(tr)
		if path.get_subname_count() == 0:
			continue
		var bi: int = tgt_rig.idx(String(path.get_subname(0)))
		if bi < 0:
			continue
		match out_anim.track_get_type(tr):
			Animation.TYPE_ROTATION_3D:
				tgt_skel.set_bone_pose_rotation(bi, out_anim.rotation_track_interpolate(tr, t))
			Animation.TYPE_POSITION_3D:
				tgt_skel.set_bone_pose_position(bi, out_anim.position_track_interpolate(tr, t))
	tgt_skel.force_update_all_bone_transforms()

func _check(label: String, ok: bool) -> void:
	print("%s %s" % ["  PASS" if ok else "  FAIL", label])
