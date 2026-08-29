## Motion matching.
##
## Every query interval it builds a feature vector describing where the player
## wants to go and how the character is currently posed, finds the nearest pose
## in the baked database, and jumps the AnimationPlayer there if it beats simply
## continuing the current clip.
##
## The database is built by Tools/bake_features.gd. Search cost is kept sane by
## only scanning poses whose ground speed is near the requested speed -- without
## that bucketing this would be a 58k-pose linear scan several times a second.
extends Node
class_name MotionMatcher

const DB = preload("res://Scripts/Motion/MotionFeatureDB.gd")
const RigUtilC = preload("res://Scripts/Core/RigUtil.gd")

@export var enabled: bool = true
@export var database_path: String = "res://Animations/motion_features.res"

@export_group("Search")
## How often to re-query, in seconds. Matching every frame is wasteful and
## makes the character jittery; 10Hz is the usual choice.
@export var query_interval: float = 0.1
## Only poses within this much of the current ground speed are considered.
## Widening this multiplies the search cost -- at 1.2 it spans nearly the whole
## database and the query stops fitting in a frame.
@export var speed_tolerance: float = 0.5
## A candidate must beat continuing the current clip by this factor before we
## switch. Lower is stricter; at 0.7 a candidate has to be 30% better, which is
## what stops the character flickering between near-identical poses.
@export var switch_margin: float = 0.7
## Never switch clips more often than this.
@export var min_clip_time: float = 0.25

## Smoothing is done by PoseInertializer, not by AnimationPlayer: seeking to a
## matched frame cancels a cross-fade anyway, so clips are cut hard here and the
## resulting pose discontinuity is decayed away instead.
var inertializer: PoseInertializer

@export_group("Weights")
## Trajectory outweighs pose: we want the clip that goes where the player asked,
## and pose similarity mainly exists to keep the switch from popping.
@export var weight_traj_pos: float = 2.0
## Direction is what separates a forward walk from a strafe at the same speed,
## and speed bucketing has already made them neighbours in the search -- so this
## carries most of the burden of not picking a sideways clip.
@export var weight_traj_dir: float = 2.5
@export var weight_foot_pos: float = 0.5
@export var weight_foot_vel: float = 0.25
@export var weight_hip_vel: float = 0.4

@export_group("Trajectory")
## Halflife for the predicted approach to the desired velocity. Lower reacts
## faster and picks sharper turns.
@export var trajectory_halflife: float = 0.22

# --- inputs, written by the controller each frame ---
var desired_velocity: Vector3 = Vector3.ZERO
var desired_facing: Vector3 = Vector3.FORWARD
var current_velocity: Vector3 = Vector3.ZERO

var db: MotionFeatureDB
var anim_player: AnimationPlayer
var skeleton: Skeleton3D

var _weights: PackedFloat32Array
var _since_query := 0.0
var _since_switch := 0.0
var _current_pose := -1
var _current_clip := ""
var _rig_up := Vector3.UP
var _rest_fwd := Vector3.FORWARD
var _hip_rest_rot := Quaternion.IDENTITY
var _hip := -1
var _foot_l := -1
var _foot_r := -1
var _prev_foot_l := Vector3.ZERO
var _prev_foot_r := Vector3.ZERO
var _prev_hip := Vector3.ZERO
var _have_prev := false
var _clip_first := PackedInt32Array()

## Last search stats, useful for debugging.
var last_cost := 0.0
var last_scanned := 0


func setup(player: AnimationPlayer, skel: Skeleton3D) -> void:
	anim_player = player
	skeleton = skel
	_hip = skel.find_bone("SKEL_Pelvis_00")
	_foot_l = skel.find_bone("SKEL_L_Foot_03")
	_foot_r = skel.find_bone("SKEL_R_Foot_06")

	# Match the bake's frame exactly: up from hips->head, side from left->right
	# thigh, forward as their cross negated. No bone axis is assumed to point
	# anywhere -- Fred's rig is Z-up in model space, so -Z on the pelvis is
	# roughly vertical, not forward.
	var head := skel.find_bone("SKEL_Head_020")
	var lt := skel.find_bone("SKEL_L_Thigh_01")
	var rt := skel.find_bone("SKEL_R_Thigh_04")
	if _hip >= 0 and head >= 0 and lt >= 0 and rt >= 0:
		var hip_rest := skel.get_bone_global_rest(_hip).origin
		var head_rest := skel.get_bone_global_rest(head).origin
		_rig_up = (head_rest - hip_rest).normalized()
		var raw_side := (skel.get_bone_global_rest(rt).origin
			- skel.get_bone_global_rest(lt).origin).normalized()
		var back := raw_side.cross(_rig_up).normalized()
		_rest_fwd = -back
		_hip_rest_rot = skel.get_bone_global_rest(_hip).basis.get_rotation_quaternion()

	db = ResourceLoader.load(database_path) as MotionFeatureDB
	if db == null:
		push_warning("MotionMatcher: no database at %s - run Tools/bake_features.gd" % database_path)
		enabled = false
		return

	_build_weights()
	_index_clip_starts()
	print("MotionMatcher: %d poses over %d clips" % [db.pose_count(), db.clip_names.size()])


## First pose of each clip, so a looped clip can re-enter its chain of links
## when playback wraps back to zero.
func _index_clip_starts() -> void:
	_clip_first = PackedInt32Array()
	_clip_first.resize(db.clip_names.size())
	_clip_first.fill(-1)
	for i in range(db.pose_count()):
		var id := db.clip_ids[i]
		if id < 0 or id >= _clip_first.size():
			continue
		if _clip_first[id] < 0 or db.times[i] < db.times[_clip_first[id]]:
			_clip_first[id] = i


func _build_weights() -> void:
	_weights = PackedFloat32Array()
	_weights.resize(DB.FEATURE_SIZE)
	for i in range(6):
		_weights[DB.F_TRAJ_POS + i] = weight_traj_pos
		_weights[DB.F_TRAJ_DIR + i] = weight_traj_dir
	for i in range(3):
		_weights[DB.F_FOOT_L_POS + i] = weight_foot_pos
		_weights[DB.F_FOOT_R_POS + i] = weight_foot_pos
		_weights[DB.F_FOOT_L_VEL + i] = weight_foot_vel
		_weights[DB.F_FOOT_R_VEL + i] = weight_foot_vel
		_weights[DB.F_HIP_VEL + i] = weight_hip_vel


func _process(delta: float) -> void:
	if not enabled or db == null or anim_player == null:
		return
	_since_query += delta
	_since_switch += delta
	if _since_query < query_interval:
		return
	_since_query = 0.0
	_query()


func _query() -> void:
	# Track playback before anything else, so the continuation cost describes
	# where we actually are rather than where we were when we last switched.
	_advance_current()

	if _since_switch < min_clip_time:
		return

	var raw := _build_query()
	var q := db.normalise(raw)

	# Bucket on the speed we are actually moving at. Bucketing on the desired
	# speed asks for poses the body has not reached yet, which is itself a
	# source of thrash while accelerating.
	var speed := Vector2(current_velocity.x, current_velocity.z).length()
	var span := db.bucket_range(speed, speed_tolerance)
	last_scanned = span.y - span.x

	# Seed the search with the cost of simply continuing, already discounted by
	# the switch margin. Anything that cannot beat that is not worth having, so
	# the inner loop's early-exit rejects almost every candidate within a few
	# dimensions instead of running all 27.
	var continue_cost := INF
	if _current_pose >= 0:
		continue_cost = _cost_at(_current_pose, q, INF)

	var best := -1
	var best_cost := INF
	var have_bound := false
	if continue_cost < INF:
		best_cost = continue_cost * switch_margin
		have_bound = true

	var feats := db.features
	var n := DB.FEATURE_SIZE
	var start := span.x

	# With no continuation to beat, the early-exit has nothing to reject
	# against and every candidate costs a full 27-dimension compare -- a frame
	# hitch. Score one candidate outright to establish a bound first.
	if not have_bound and span.y > span.x:
		best = start
		best_cost = _cost_at(start, q, INF)
		start += 1

	for i in range(start, span.y):
		var cost := 0.0
		var base := i * n
		for k in range(n):
			var d: float = feats[base + k] - q[k]
			cost += d * d * _weights[k]
			if cost >= best_cost:
				break
		if cost < best_cost:
			best_cost = cost
			best = i
	last_cost = best_cost

	# Nothing beat continuing - leave the clip alone.
	if best < 0:
		return

	var clip := db.clip_name_of(best)
	if clip == "":
		return
	# Same clip and nearly the same phase: no point restarting it.
	if clip == _current_clip and absf(db.times[best] - _current_time()) < 0.2:
		_current_pose = best
		return

	_play_pose(best, clip)


func _play_pose(pose: int, clip: String) -> void:
	if not anim_player.has_animation(clip):
		return
	var anim := anim_player.get_animation(clip)
	if anim:
		# Matched clips are often single steps. Looping them means a clip that
		# outlives its match keeps moving instead of ending and freezing.
		anim.loop_mode = Animation.LOOP_LINEAR
	anim_player.play(clip, 0.0)
	anim_player.seek(db.times[pose], true)
	if inertializer:
		inertializer.trigger()
	_current_pose = pose
	_current_clip = clip
	_since_switch = 0.0


## Walk _current_pose forward to match playback, following the successor links
## baked into the database. Poses are stored speed-sorted, so this link is the
## only cheap way to follow a clip through the array.
func _advance_current() -> void:
	if _current_pose < 0 or db.next_pose.is_empty():
		return
	if _current_clip != "" and anim_player.current_animation != _current_clip:
		# Something else took over playback; stop pretending we know the pose.
		_current_pose = -1
		return

	var t := _current_time()
	# Looping clips send the playhead back to zero; re-enter the chain at the
	# clip's first pose rather than stranding the pointer at its end.
	if db.times[_current_pose] - t > 0.3:
		var id := db.clip_ids[_current_pose]
		if id >= 0 and id < _clip_first.size() and _clip_first[id] >= 0:
			_current_pose = _clip_first[id]

	# Follow links until the next pose would overshoot the playhead. Bounded so
	# a bad link can never spin here.
	var guard := 256
	while guard > 0:
		var nxt: int = db.next_pose[_current_pose]
		if nxt < 0:
			break
		if db.times[nxt] > t:
			break
		_current_pose = nxt
		guard -= 1


func _current_time() -> float:
	return anim_player.current_animation_position if anim_player else 0.0


## Assemble the raw (un-normalised) query vector: predicted trajectory from
## player intent, current pose read off the live skeleton.
func _build_query() -> PackedFloat32Array:
	var vec := PackedFloat32Array()
	vec.resize(DB.FEATURE_SIZE)

	# --- trajectory, in the character's own ground frame ---
	var fwd := desired_facing
	fwd.y = 0.0
	if fwd.length_squared() < 1e-6:
		fwd = Vector3(0, 0, -1)
	fwd = fwd.normalized()
	var side := Vector3.UP.cross(fwd).normalized()

	var pos := Vector3.ZERO
	var vel := current_velocity
	var t := 0.0
	var step := 1.0 / 30.0
	for ti in range(DB.TRAJ_TIMES.size()):
		var target_t: float = DB.TRAJ_TIMES[ti]
		while t < target_t:
			var k := RigUtilC.damp_factor(trajectory_halflife, step)
			vel = vel.lerp(desired_velocity, k)
			pos += vel * step
			t += step
		vec[DB.F_TRAJ_POS + ti * 2] = pos.dot(side)
		vec[DB.F_TRAJ_POS + ti * 2 + 1] = pos.dot(fwd)
		var d := vel
		d.y = 0.0
		d = d.normalized() if d.length_squared() > 1e-6 else fwd
		vec[DB.F_TRAJ_DIR + ti * 2] = d.dot(side)
		vec[DB.F_TRAJ_DIR + ti * 2 + 1] = d.dot(fwd)

	# --- pose, from the skeleton, in the same frame the bake used ---
	if skeleton and _hip >= 0 and _foot_l >= 0 and _foot_r >= 0:
		var hip_xf := skeleton.get_bone_global_pose(_hip)
		var hip_p := hip_xf.origin
		var lf := skeleton.get_bone_global_pose(_foot_l).origin
		var rf := skeleton.get_bone_global_pose(_foot_r).origin

		var deviation: Quaternion = hip_xf.basis.get_rotation_quaternion() * _hip_rest_rot.inverse()
		var m_fwd: Vector3 = deviation * _rest_fwd
		m_fwd = (m_fwd - _rig_up * m_fwd.dot(_rig_up))
		if m_fwd.length_squared() < 1e-6:
			m_fwd = _rest_fwd
		m_fwd = m_fwd.normalized()
		var m_side := _rig_up.cross(m_fwd).normalized()

		_put3(vec, DB.F_FOOT_L_POS, _rel(lf, hip_p, m_side, _rig_up, m_fwd))
		_put3(vec, DB.F_FOOT_R_POS, _rel(rf, hip_p, m_side, _rig_up, m_fwd))

		if _have_prev:
			var dt: float = maxf(query_interval, 1e-3)
			_put3(vec, DB.F_FOOT_L_VEL, _rel((lf - _prev_foot_l) / dt, Vector3.ZERO, m_side, _rig_up, m_fwd))
			_put3(vec, DB.F_FOOT_R_VEL, _rel((rf - _prev_foot_r) / dt, Vector3.ZERO, m_side, _rig_up, m_fwd))
			_put3(vec, DB.F_HIP_VEL, _rel((hip_p - _prev_hip) / dt, Vector3.ZERO, m_side, _rig_up, m_fwd))
		_prev_foot_l = lf
		_prev_foot_r = rf
		_prev_hip = hip_p
		_have_prev = true

	return vec


func _cost_at(pose: int, q: PackedFloat32Array, cutoff: float) -> float:
	var cost := 0.0
	var base := pose * DB.FEATURE_SIZE
	for k in range(DB.FEATURE_SIZE):
		var d: float = db.features[base + k] - q[k]
		cost += d * d * _weights[k]
		if cost >= cutoff:
			return cost
	return cost


func _rel(p: Vector3, origin: Vector3, side: Vector3, up: Vector3, fwd: Vector3) -> Vector3:
	var d := p - origin
	return Vector3(d.dot(side), d.dot(up), d.dot(fwd))


func _put3(vec: PackedFloat32Array, at: int, v: Vector3) -> void:
	vec[at] = v.x
	vec[at + 1] = v.y
	vec[at + 2] = v.z
