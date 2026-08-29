## Reaching instinct: puts a hand on nearby geometry.
##
## People brush a wall they are squeezing past and put a palm out when they get
## close to something. This casts a small fan of rays out from each shoulder and,
## when one finds a surface inside arm's reach, IKs that hand onto the contact
## point with the palm turned to the surface.
##
## Runs as a SkeletonModifier3D so it layers on top of whatever the motion
## matcher is playing.
extends SkeletonModifier3D
class_name WallTouch

const RigUtilC = preload("res://Scripts/Core/RigUtil.gd")

@export var enabled: bool = true

@export_group("Bones")
@export var left_chain: Array[String] = ["SKEL_L_UpperArm_012", "SKEL_L_Forearm_013", "SKEL_L_Hand_014"]
@export var right_chain: Array[String] = ["SKEL_R_UpperArm_016", "SKEL_R_Forearm_017", "SKEL_R_Hand_018"]
@export var chest_bone := "SKEL_Spine3_010"

@export_group("Reach")
## Longest distance a hand will reach out to touch something.
@export var reach: float = 0.62
## Start blending the hand in once a surface is nearer than this.
@export var engage_distance: float = 0.85
## Rays are cast at these yaw offsets (radians) from straight out to the side,
## so the hand finds walls slightly ahead as well as directly beside.
@export var probe_angles: Array[float] = [-0.6, -0.25, 0.0, 0.25]
@export var collision_mask: int = 1

@export_group("Feel")
## How strongly the hand commits when a surface is found.
@export var max_weight: float = 0.85
## Halflife for blending the hand on and off.
@export var blend_halflife: float = 0.16
## Stop reaching above this ground speed -- sprinting people do not trail a
## hand along the wall.
@export var max_speed: float = 3.0

var character: CharacterBody3D

var _chest := -1
var _l := PackedInt32Array()
var _r := PackedInt32Array()
var _l_weight := 0.0
var _r_weight := 0.0
var _l_target := Vector3.ZERO
var _r_target := Vector3.ZERO
var _l_normal := Vector3.ZERO
var _r_normal := Vector3.ZERO
var _space: PhysicsDirectSpaceState3D


func _ready() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	_chest = skel.find_bone(chest_bone)
	_l = RigUtilC.find_bones(skel, left_chain)
	_r = RigUtilC.find_bones(skel, right_chain)
	if _chest < 0 or _l.has(-1) or _r.has(-1):
		push_warning("WallTouch: missing bones, disabling")
		enabled = false


func _process_modification() -> void:
	var skel := get_skeleton()
	if not enabled or skel == null:
		return
	if _space == null:
		_space = skel.get_world_3d().direct_space_state
		if _space == null:
			return

	var delta := get_process_delta_time()
	var to_world := skel.global_transform
	var to_local := to_world.affine_inverse()

	var speed := 0.0
	if character:
		speed = Vector2(character.velocity.x, character.velocity.z).length()
	var speed_gate := 1.0 - clampf(speed / maxf(max_speed, 0.01), 0.0, 1.0)

	_update_side(skel, to_world, delta, speed_gate, true)
	_update_side(skel, to_world, delta, speed_gate, false)

	_apply_side(skel, to_local, _l, _l_weight, _l_target, _l_normal)
	_apply_side(skel, to_local, _r, _r_weight, _r_target, _r_normal)


func _update_side(skel: Skeleton3D, to_world: Transform3D, delta: float,
		speed_gate: float, is_left: bool) -> void:
	var chain := _l if is_left else _r
	var shoulder_world: Vector3 = to_world * skel.get_bone_global_pose(chain[0]).origin

	# Outward direction for this arm, in world space, flattened to the ground.
	var chest_xf := skel.get_bone_global_pose(_chest)
	var side_world: Vector3 = (to_world.basis * chest_xf.basis.x).normalized()
	if is_left:
		side_world = -side_world
	side_world.y = 0.0
	if side_world.length_squared() < 1e-6:
		return
	side_world = side_world.normalized()
	var fwd_world := Vector3.UP.cross(side_world).normalized()

	var best_dist := INF
	var best_point := Vector3.ZERO
	var best_normal := Vector3.UP

	for a in probe_angles:
		var dir := (side_world * cos(a) + fwd_world * sin(a)).normalized()
		var params := PhysicsRayQueryParameters3D.create(
			shoulder_world, shoulder_world + dir * engage_distance, collision_mask)
		var res := _space.intersect_ray(params)
		if res.is_empty():
			continue
		var d: float = shoulder_world.distance_to(res.position)
		if d < best_dist:
			best_dist = d
			best_point = res.position
			best_normal = res.normal

	var target_weight := 0.0
	if best_dist < engage_distance:
		# Full commitment when the wall is at arm's length or closer, easing off
		# as it gets further away.
		var closeness := 1.0 - clampf(
			(best_dist - reach) / maxf(engage_distance - reach, 0.01), 0.0, 1.0)
		target_weight = closeness * max_weight * speed_gate
		# Stand the palm off the surface a little so it does not sink in.
		var contact := best_point + best_normal * 0.045
		if is_left:
			_l_target = contact
			_l_normal = best_normal
		else:
			_r_target = contact
			_r_normal = best_normal

	var k := RigUtilC.damp_factor(blend_halflife, delta)
	if is_left:
		_l_weight = lerpf(_l_weight, target_weight, k)
	else:
		_r_weight = lerpf(_r_weight, target_weight, k)


func _apply_side(skel: Skeleton3D, to_local: Transform3D, chain: PackedInt32Array,
		weight: float, target_world: Vector3, normal_world: Vector3) -> void:
	if weight < 0.01:
		return
	var target_local: Vector3 = to_local * target_world

	# Elbows bend away from the body and downward.
	var shoulder: Vector3 = skel.get_bone_global_pose(chain[0]).origin
	var elbow: Vector3 = skel.get_bone_global_pose(chain[1]).origin
	var wrist: Vector3 = skel.get_bone_global_pose(chain[2]).origin
	var pole := elbow - (shoulder + wrist) * 0.5
	if pole.length_squared() < 1e-8:
		pole = to_local.basis * Vector3.DOWN

	RigUtilC.apply_two_bone(skel, chain[0], chain[1], chain[2], target_local, pole, weight)

	# Turn the palm to face the surface.
	if normal_world.length_squared() > 1e-6:
		var n_local: Vector3 = (to_local.basis * normal_world).normalized()
		var palm: Vector3 = skel.get_bone_global_pose(chain[2]).basis.y.normalized()
		var turn := RigUtilC.rot_between(palm, -n_local)
		RigUtilC.rotate_bone_model(skel, chain[2], Quaternion.IDENTITY.slerp(turn, weight))
