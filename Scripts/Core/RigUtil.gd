## Shared skeleton maths: analytic two-bone IK and model-space pose helpers.
##
## Everything works in the skeleton's model space (what get_bone_global_pose
## returns) and converts back to parent-local only when writing, so a chain can
## be solved without re-querying the skeleton between bones.
class_name RigUtil


## Shortest-arc rotation taking `from` onto `to`.
static func rot_between(from: Vector3, to: Vector3) -> Quaternion:
	if from.length_squared() < 1e-9 or to.length_squared() < 1e-9:
		return Quaternion.IDENTITY
	var a := from.normalized()
	var b := to.normalized()
	# Antiparallel vectors have no unique arc; pick any perpendicular axis.
	if a.dot(b) < -0.9999:
		var axis := a.cross(Vector3.UP)
		if axis.length_squared() < 1e-9:
			axis = a.cross(Vector3.RIGHT)
		return Quaternion(axis.normalized(), PI)
	return Quaternion(a, b)


## Analytic two-bone IK.
##
## Given the current model-space positions of a chain (root -> mid -> tip) and a
## target, returns the two model-space delta rotations that place the tip on the
## target. `pole_dir` chooses which way the joint bends -- knee forward, elbow
## back. Returns [root_delta, mid_delta], where mid_delta is applied *after*
## root_delta has already rotated the chain.
static func solve_two_bone(root_pos: Vector3, mid_pos: Vector3, tip_pos: Vector3,
		target: Vector3, pole_dir: Vector3) -> Array:
	var upper := mid_pos - root_pos
	var lower := tip_pos - mid_pos
	var l1 := upper.length()
	var l2 := lower.length()
	if l1 < 1e-5 or l2 < 1e-5:
		return [Quaternion.IDENTITY, Quaternion.IDENTITY]

	var to_target := target - root_pos
	if to_target.length_squared() < 1e-9:
		return [Quaternion.IDENTITY, Quaternion.IDENTITY]

	# Clamp inside the chain's reachable annulus, leaving a sliver so the joint
	# never locks perfectly straight (which would destroy the bend axis).
	var dist := clampf(to_target.length(), absf(l1 - l2) + 1e-3, l1 + l2 - 1e-3)
	var dir := to_target.normalized()

	var bend_axis := dir.cross(pole_dir)
	if bend_axis.length_squared() < 1e-9:
		bend_axis = dir.cross(Vector3.UP)
		if bend_axis.length_squared() < 1e-9:
			bend_axis = dir.cross(Vector3.RIGHT)
	bend_axis = bend_axis.normalized()

	# Law of cosines for the angle at the root between root->target and root->mid.
	var cos_root := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	var root_angle := acos(cos_root)

	var new_mid := root_pos + (Quaternion(bend_axis, root_angle) * dir) * l1
	var new_tip := root_pos + dir * dist

	var root_delta := rot_between(upper, new_mid - root_pos)
	# The lower bone has already been carried around by root_delta.
	var mid_delta := rot_between(root_delta * lower, new_tip - new_mid)
	return [root_delta, mid_delta]


## Solve a two-bone chain and write the result onto the skeleton.
## `weight` fades the correction in, so IK can blend on and off smoothly.
static func apply_two_bone(skel: Skeleton3D, root_bone: int, mid_bone: int, tip_bone: int,
		target: Vector3, pole_dir: Vector3, weight: float = 1.0) -> void:
	if root_bone < 0 or mid_bone < 0 or tip_bone < 0 or weight <= 0.0:
		return

	var root_xf := skel.get_bone_global_pose(root_bone)
	var mid_xf := skel.get_bone_global_pose(mid_bone)
	var tip_xf := skel.get_bone_global_pose(tip_bone)

	var blended_target: Vector3 = tip_xf.origin.lerp(target, clampf(weight, 0.0, 1.0))
	var deltas := solve_two_bone(root_xf.origin, mid_xf.origin, tip_xf.origin,
		blended_target, pole_dir)
	var root_delta: Quaternion = deltas[0]
	var mid_delta: Quaternion = deltas[1]

	var root_model := root_xf.basis.get_rotation_quaternion()
	var mid_model := mid_xf.basis.get_rotation_quaternion()

	var new_root_model := (root_delta * root_model).normalized()
	var new_mid_model := (mid_delta * root_delta * mid_model).normalized()

	var root_parent := skel.get_bone_parent(root_bone)
	var root_parent_model := Quaternion.IDENTITY
	if root_parent >= 0:
		root_parent_model = skel.get_bone_global_pose(root_parent).basis.get_rotation_quaternion()

	skel.set_bone_pose_rotation(root_bone, (root_parent_model.inverse() * new_root_model).normalized())
	skel.set_bone_pose_rotation(mid_bone, (new_root_model.inverse() * new_mid_model).normalized())


## Rotate a bone in model space by `delta`, writing back a parent-local pose.
static func rotate_bone_model(skel: Skeleton3D, bone: int, delta: Quaternion) -> void:
	if bone < 0:
		return
	var parent := skel.get_bone_parent(bone)
	var parent_model := Quaternion.IDENTITY
	if parent >= 0:
		parent_model = skel.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	var model := skel.get_bone_global_pose(bone).basis.get_rotation_quaternion()
	var new_model := (delta * model).normalized()
	skel.set_bone_pose_rotation(bone, (parent_model.inverse() * new_model).normalized())


## Look up several bones at once; returns -1 for any that are missing.
static func find_bones(skel: Skeleton3D, names: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for n in names:
		out.append(skel.find_bone(n))
	return out


## Frame-rate independent smoothing factor for exponential damping.
## `halflife` is the time for the remaining error to halve.
static func damp_factor(halflife: float, delta: float) -> float:
	if halflife <= 0.0:
		return 1.0
	return 1.0 - pow(0.5, delta / halflife)
