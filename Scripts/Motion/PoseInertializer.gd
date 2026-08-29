## Inertialized transitions.
##
## Motion matching cuts between clips constantly, and AnimationPlayer's
## cross-fade is the wrong tool for it: seeking to a matched frame discards the
## fade, and overlapping fades smear the pose.
##
## Instead the clip is cut hard, and the *difference* between the pose we were
## showing and the pose we cut to is captured and decayed to zero over a short
## window. The character therefore always plays exactly one clip -- what you see
## is that clip plus a shrinking correction -- so transitions stay smooth without
## any blending machinery, and there is nothing to stall or stack up.
extends SkeletonModifier3D
class_name PoseInertializer

@export var enabled: bool = true
## Time for the captured discontinuity to fade out. Longer is smoother but
## drags the old pose along; ~0.25s reads well for locomotion.
@export var duration: float = 0.25

var _offset_rot: Array[Quaternion] = []
var _offset_pos: PackedVector3Array = PackedVector3Array()
var _last_rot: Array[Quaternion] = []
var _last_pos: PackedVector3Array = PackedVector3Array()
var _time := 1e9
var _pending := false
var _ready_pose := false


func _ready() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	var n := skel.get_bone_count()
	_offset_rot.resize(n)
	_last_rot.resize(n)
	_offset_pos.resize(n)
	_last_pos.resize(n)
	for i in range(n):
		_offset_rot[i] = Quaternion.IDENTITY
		_last_rot[i] = Quaternion.IDENTITY


## Called by the matcher the moment it switches clips. The capture itself
## happens on the next skeleton update, once the new clip has posed the rig.
func trigger() -> void:
	if _ready_pose:
		_pending = true


func _process_modification() -> void:
	var skel := get_skeleton()
	if not enabled or skel == null:
		return
	var n := mini(skel.get_bone_count(), _last_rot.size())

	if _pending:
		# Diff against what was actually on screen last frame, not against the
		# raw animated pose. A switch landing while an earlier correction is
		# still decaying would otherwise drop that correction outright, and the
		# leftover of the previous clip visibly snaps away.
		for i in range(n):
			var cur_r := skel.get_bone_pose_rotation(i)
			_offset_rot[i] = (_last_rot[i] * cur_r.inverse()).normalized()
			_offset_pos[i] = _last_pos[i] - skel.get_bone_pose_position(i)
		_time = 0.0
		_pending = false

	if _time < duration:
		# Smoothstep the correction out, so it leaves without a velocity kink.
		var x := 1.0 - clampf(_time / maxf(duration, 1e-4), 0.0, 1.0)
		var w := x * x * (3.0 - 2.0 * x)
		for i in range(n):
			if not _offset_rot[i].is_equal_approx(Quaternion.IDENTITY):
				var corr := Quaternion.IDENTITY.slerp(_offset_rot[i], w)
				skel.set_bone_pose_rotation(i, (corr * skel.get_bone_pose_rotation(i)).normalized())
			if _offset_pos[i].length_squared() > 1e-10:
				skel.set_bone_pose_position(i, skel.get_bone_pose_position(i) + _offset_pos[i] * w)
		_time += get_process_delta_time()

	# Record the displayed pose -- correction included -- so the next capture
	# measures the discontinuity against something continuous.
	for i in range(n):
		_last_rot[i] = skel.get_bone_pose_rotation(i)
		_last_pos[i] = skel.get_bone_pose_position(i)
	_ready_pose = true
