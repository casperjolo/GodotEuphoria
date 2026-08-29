## Builds the motion-matching pose database from the retargeted animation
## libraries.
##
##   godot --headless --path . --script res://Tools/bake_features.gd
##
## Reads Animations/Retargeted/*.res, evaluates every clip frame by forward
## kinematics over Fred's rig, and writes Animations/motion_features.res.
extends SceneTree

const RT = preload("res://Tools/retarget_lib.gd")
const DB = preload("res://Scripts/Motion/MotionFeatureDB.gd")

const LIB_DIR := "res://Animations/Retargeted"
const OUT_PATH := "res://Animations/motion_features.res"
## 15Hz is plenty for matching and halves the search space. The played-back
## animation still runs at its full rate; this only sets how finely the database
## samples candidate poses.
const SAMPLE_FPS := 15.0

## Only locomotion is matched against. Jumps, traversal and aim offsets are
## triggered explicitly rather than searched, and including them would both
## bloat the search and let the matcher pick a vault mid-stroll.
const CATEGORIES := ["Idle", "Walk", "Run", "Sprint"]

## Speed buckets in m/s. Poses are sorted into these so a query only scans
## clips moving at roughly the right speed.
const BUCKETS: Array[float] = [0.0, 0.4, 1.0, 1.8, 2.8, 4.0, 6.0]

var rig
var hip_bone := -1
var foot_l_bone := -1
var foot_r_bone := -1
var root_bone := -1
## The character's forward in skeleton model space, at rest.
var rest_fwd := Vector3.FORWARD
## Pelvis rest orientation, so per-frame facing can be taken as the pelvis's
## deviation from rest applied to rest_fwd.
var hip_rest_rot := Quaternion.IDENTITY


func _initialize() -> void:
	var fred = load("res://NaturalMotion/Characters/Fred.glb").instantiate()
	var skel: Skeleton3D = fred.find_child("Skeleton3D", true, false)
	if skel == null:
		push_error("bake_features: Fred has no Skeleton3D")
		quit(1)
		return
	rig = RT.RigInfo.new(skel)
	hip_bone = rig.idx("SKEL_Pelvis_00")
	foot_l_bone = rig.idx("SKEL_L_Foot_03")
	foot_r_bone = rig.idx("SKEL_R_Foot_06")
	root_bone = rig.idx("_rootJoint")

	# Fred's rig is Z-up in model space, so no bone axis can be assumed to be
	# "forward" -- the pelvis's own -Z points roughly vertically here. Take the
	# rig's orientation from its rest pose instead. rig_orientation's z column
	# is side x up, which is the character's BACK, so forward is its negation.
	var ori: Basis = RT.rig_orientation(rig, "SKEL_Pelvis_00", "SKEL_Head_020",
		"SKEL_L_Thigh_01", "SKEL_R_Thigh_04")
	var up: Vector3 = ori.y
	rest_fwd = -ori.z
	hip_rest_rot = rig.rest_model[hip_bone].basis.get_rotation_quaternion()
	print("rig up = %v   rest forward = %v" % [up, rest_fwd])

	var raw: Array[PackedFloat32Array] = []
	var clip_ids := PackedInt32Array()
	var times := PackedFloat32Array()
	var speeds := PackedFloat32Array()
	var clip_names := PackedStringArray()

	for cat in CATEGORIES:
		var lib := ResourceLoader.load("%s/%s.res" % [LIB_DIR, cat]) as AnimationLibrary
		if lib == null:
			print("  (no %s.res, skipping)" % cat)
			continue
		var n := 0
		for anim_name in lib.get_animation_list():
			var anim := lib.get_animation(anim_name)
			var full := "%s/%s" % [cat, anim_name]
			var clip_id := clip_names.size()
			clip_names.append(full)
			n += _extract_clip(anim, clip_id, up, raw, clip_ids, times, speeds)
		print("%-8s %4d clips -> %6d poses" % [cat, lib.get_animation_list().size(), n])

	var total := raw.size()
	print("\ntotal poses: %d" % total)
	if total == 0:
		push_error("bake_features: nothing extracted")
		quit(1)
		return

	# --- sort by speed so buckets become contiguous ranges ---
	var order := range(total)
	order.sort_custom(func(a, b): return speeds[a] < speeds[b])

	var db = DB.new()
	db.clip_names = clip_names
	db.features = PackedFloat32Array()
	db.features.resize(total * DB.FEATURE_SIZE)
	db.clip_ids = PackedInt32Array(); db.clip_ids.resize(total)
	db.times = PackedFloat32Array(); db.times.resize(total)
	db.speeds = PackedFloat32Array(); db.speeds.resize(total)

	# Inverse permutation, so we can translate "the next frame of this clip"
	# from pre-sort indices into post-sort ones.
	var inv := PackedInt32Array()
	inv.resize(total)
	for out_i in range(total):
		var src: int = order[out_i]
		var vec: PackedFloat32Array = raw[src]
		for k in range(DB.FEATURE_SIZE):
			db.features[out_i * DB.FEATURE_SIZE + k] = vec[k]
		db.clip_ids[out_i] = clip_ids[src]
		db.times[out_i] = times[src]
		db.speeds[out_i] = speeds[src]
		inv[src] = out_i

	# Raw poses were appended clip by clip in frame order, so src+1 is the next
	# frame whenever it belongs to the same clip.
	db.next_pose = PackedInt32Array()
	db.next_pose.resize(total)
	for src in range(total):
		var link := -1
		if src + 1 < total and clip_ids[src + 1] == clip_ids[src]:
			link = inv[src + 1]
		db.next_pose[inv[src]] = link

	# --- normalise each dimension ---
	var means := PackedFloat32Array(); means.resize(DB.FEATURE_SIZE)
	var stds := PackedFloat32Array(); stds.resize(DB.FEATURE_SIZE)
	for k in range(DB.FEATURE_SIZE):
		var sum := 0.0
		for i in range(total):
			sum += db.features[i * DB.FEATURE_SIZE + k]
		var mean := sum / total
		var var_sum := 0.0
		for i in range(total):
			var d: float = db.features[i * DB.FEATURE_SIZE + k] - mean
			var_sum += d * d
		var sd := sqrt(var_sum / total)
		means[k] = mean
		stds[k] = sd if sd > 1e-6 else 1.0
	for i in range(total):
		for k in range(DB.FEATURE_SIZE):
			var at := i * DB.FEATURE_SIZE + k
			db.features[at] = (db.features[at] - means[k]) / stds[k]
	db.means = means
	db.stds = stds

	# --- bucket boundaries over the speed-sorted array ---
	db.bucket_bounds = PackedFloat32Array(BUCKETS)
	db.bucket_starts = PackedInt32Array()
	var cursor := 0
	for b in BUCKETS:
		while cursor < total and db.speeds[cursor] < b:
			cursor += 1
		db.bucket_starts.append(cursor)

	var err := ResourceSaver.save(db, OUT_PATH)
	print("\nsaved %s  (%s)" % [OUT_PATH, "ok" if err == OK else "ERROR %d" % err])
	print("clips: %d   poses: %d   floats: %d" % [clip_names.size(), total, db.features.size()])
	quit(0)


## Sample one clip and append a feature vector per frame.
func _extract_clip(anim: Animation, clip_id: int, up: Vector3,
		out_raw: Array[PackedFloat32Array], out_clip: PackedInt32Array,
		out_time: PackedFloat32Array, out_speed: PackedFloat32Array) -> int:
	var cache: Dictionary = RT.build_track_cache(anim, rig)
	var step := 1.0 / SAMPLE_FPS
	var frames := int(anim.length / step)
	if frames < 2:
		return 0

	# Evaluate the whole clip once; trajectory features need to look ahead.
	var root_pos: Array[Vector3] = []
	var facing: Array[Vector3] = []
	var foot_l: Array[Vector3] = []
	var foot_r: Array[Vector3] = []
	var hip: Array[Vector3] = []

	for f in range(frames):
		var m: Array = RT.sample_source_model_pose(anim, rig, f * step, cache)
		var origin: Vector3 = m[root_bone].origin if root_bone >= 0 else Vector3.ZERO
		root_pos.append(_flatten(origin, up))
		# Facing = how far the pelvis has turned from its rest orientation,
		# applied to the rig's rest forward. The retarget carries no root
		# rotation track, so the hips are what tells us which way he is pointing.
		var hip_rot: Quaternion = m[hip_bone].basis.get_rotation_quaternion()
		var deviation: Quaternion = hip_rot * hip_rest_rot.inverse()
		facing.append(_flatten_dir(deviation * rest_fwd, up))
		foot_l.append(m[foot_l_bone].origin)
		foot_r.append(m[foot_r_bone].origin)
		hip.append(m[hip_bone].origin)

	# Poses need the full look-ahead horizon to be real. Clamping it to the end
	# of a short clip fabricates a trajectory that flattens out, which reads as
	# "about to stop" and matches queries it has no business matching.
	var horizon := int(DB.TRAJ_TIMES[DB.TRAJ_TIMES.size() - 1] * SAMPLE_FPS)
	var last_usable := frames - horizon
	if last_usable <= 0:
		return 0

	var count := 0
	for f in range(last_usable):
		# Character-local frame at f: origin at the root, +Z along facing.
		var o: Vector3 = root_pos[f]
		var fwd: Vector3 = facing[f]
		if fwd.length_squared() < 1e-6:
			fwd = Vector3(0, 0, 1)
		var side: Vector3 = up.cross(fwd).normalized()
		var to_local := func(v: Vector3) -> Vector2:
			var d: Vector3 = v - o
			return Vector2(d.dot(side), d.dot(fwd))

		var vec := PackedFloat32Array()
		vec.resize(DB.FEATURE_SIZE)

		# Trajectory. The direction feature is where the character is TRAVELLING,
		# not where it is looking: a strafe and a forward walk both keep the body
		# pointed forward, so facing cannot tell them apart. The runtime query
		# builds this from velocity, so the two must agree.
		for t_i in range(DB.TRAJ_TIMES.size()):
			var ahead: int = mini(f + int(DB.TRAJ_TIMES[t_i] * SAMPLE_FPS), frames - 1)
			var p: Vector2 = to_local.call(root_pos[ahead])
			vec[DB.F_TRAJ_POS + t_i * 2] = p.x
			vec[DB.F_TRAJ_POS + t_i * 2 + 1] = p.y

			var back: int = maxi(ahead - 1, 0)
			var travel: Vector3 = root_pos[ahead] - root_pos[back]
			var d: Vector3
			if travel.length_squared() > 1e-8:
				d = travel.normalized()
			else:
				# Standing still has no travel direction; fall back to facing,
				# which the query also does when velocity is near zero.
				d = facing[ahead]
			vec[DB.F_TRAJ_DIR + t_i * 2] = d.dot(side)
			vec[DB.F_TRAJ_DIR + t_i * 2 + 1] = d.dot(fwd)

		# pose: feet relative to the hips, so height differences do not dominate
		_put3(vec, DB.F_FOOT_L_POS, _rel(foot_l[f], hip[f], side, up, fwd))
		_put3(vec, DB.F_FOOT_R_POS, _rel(foot_r[f], hip[f], side, up, fwd))

		var prev: int = maxi(f - 1, 0)
		var dt: float = step if f > 0 else step
		_put3(vec, DB.F_FOOT_L_VEL, _rel_vel(foot_l[f], foot_l[prev], dt, side, up, fwd))
		_put3(vec, DB.F_FOOT_R_VEL, _rel_vel(foot_r[f], foot_r[prev], dt, side, up, fwd))
		_put3(vec, DB.F_HIP_VEL, _rel_vel(hip[f], hip[prev], dt, side, up, fwd))

		# ground speed for bucketing
		var nxt: int = mini(f + 1, frames - 1)
		var speed: float = root_pos[nxt].distance_to(root_pos[prev]) / (step * maxf(nxt - prev, 1))

		out_raw.append(vec)
		out_clip.append(clip_id)
		out_time.append(f * step)
		out_speed.append(speed)
		count += 1
	return count


func _flatten(v: Vector3, up: Vector3) -> Vector3:
	return v - up * v.dot(up)


func _flatten_dir(v: Vector3, up: Vector3) -> Vector3:
	var f := _flatten(v, up)
	return f.normalized() if f.length_squared() > 1e-8 else Vector3.ZERO


func _rel(p: Vector3, origin: Vector3, side: Vector3, up: Vector3, fwd: Vector3) -> Vector3:
	var d := p - origin
	return Vector3(d.dot(side), d.dot(up), d.dot(fwd))


func _rel_vel(cur: Vector3, prev: Vector3, dt: float, side: Vector3, up: Vector3, fwd: Vector3) -> Vector3:
	var v := (cur - prev) / maxf(dt, 1e-5)
	return Vector3(v.dot(side), v.dot(up), v.dot(fwd))


func _put3(vec: PackedFloat32Array, at: int, v: Vector3) -> void:
	vec[at] = v.x
	vec[at + 1] = v.y
	vec[at + 2] = v.z
