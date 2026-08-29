## Procedural foot planting.
##
## Raycasts under each foot, pulls it onto the ground, tilts it to the surface
## normal, and drops the hips when a foot cannot reach. Runs as a
## SkeletonModifier3D so it executes after the AnimationPlayer has posed the
## skeleton, rather than racing it in _process.
extends SkeletonModifier3D
class_name FootIK

const RigUtilC = preload("res://Scripts/Core/RigUtil.gd")

@export var enabled: bool = true

@export_group("Bones")
@export var hip_bone := "SKEL_Pelvis_00"
@export var left_chain: Array[String] = ["SKEL_L_Thigh_01", "SKEL_L_Calf_02", "SKEL_L_Foot_03"]
@export var right_chain: Array[String] = ["SKEL_R_Thigh_04", "SKEL_R_Calf_05", "SKEL_R_Foot_06"]

@export_group("Tracing")
## How far above the foot to start the trace.
@export var trace_up: float = 0.5
## How far below the foot to keep looking for ground.
@export var trace_down: float = 0.6
## Distance the ankle sits above the contact point.
@export var ankle_height: float = 0.11
@export var collision_mask: int = 1

@export_group("Planting")
## At or below this height above the ground, a foot is fully corrected.
@export var plant_full_height: float = 0.04
## Above this height the foot is mid-swing and left entirely to the animation.
## Without this fade the solver drags the swinging foot down to the floor.
@export var plant_fade_height: float = 0.22

@export_group("Feel")
## Smoothing halflife for foot height, so steps do not snap.
@export var foot_halflife: float = 0.06
## Smoothing halflife for the pelvis drop.
@export var hip_halflife: float = 0.12
## Never drop the hips further than this.
@export var max_hip_drop: float = 0.35
## Blend the whole system out when airborne.
@export var airborne_fade: float = 0.15
@export var align_to_normal: bool = true
@export var max_normal_angle: float = 0.7

var character: CharacterBody3D

var _hip := -1
var _l := PackedInt32Array()
var _r := PackedInt32Array()
var _l_offset := 0.0
var _r_offset := 0.0
var _hip_offset := 0.0
var _weight := 1.0
var _space: PhysicsDirectSpaceState3D


func _ready() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	_hip = skel.find_bone(hip_bone)
	_l = RigUtilC.find_bones(skel, left_chain)
	_r = RigUtilC.find_bones(skel, right_chain)
	if _hip < 0 or _l.has(-1) or _r.has(-1):
		push_warning("FootIK: missing bones, disabling")
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

	# Fade out in the air -- planting a foot on ground you left is worse than
	# leaving the animation alone.
	var grounded := character == null or character.is_on_floor()
	var target_weight := 1.0 if grounded else 0.0
	_weight = lerpf(_weight, target_weight, RigUtilC.damp_factor(airborne_fade, delta))
	if _weight < 0.01:
		return

	var to_world := skel.global_transform
	var to_local := to_world.affine_inverse()

	var l_hit := _trace_foot(skel, to_world, _l[2])
	var r_hit := _trace_foot(skel, to_world, _r[2])
	var l_plant := _plant_weight(l_hit)
	var r_plant := _plant_weight(r_hit)

	# Drop the hips for the SUPPORT foot -- the one nearest the ground, i.e. the
	# smaller correction. Using the larger one pulls the hips toward whichever
	# foot is mid-swing, which sinks the character a little more every step.
	# Scaled by how planted either foot is, so an airborne stride does not drop
	# the hips at all.
	var drop := minf(maxf(l_hit.offset, r_hit.offset), 0.0) * maxf(l_plant, r_plant)
	drop = maxf(drop, -max_hip_drop)
	_hip_offset = lerpf(_hip_offset, drop, RigUtilC.damp_factor(hip_halflife, delta))
	if absf(_hip_offset) > 0.001:
		var hp := skel.get_bone_pose_position(_hip)
		var up_local := (to_local.basis * Vector3.UP).normalized()
		skel.set_bone_pose_position(_hip, hp + up_local * _hip_offset * _weight)

	_l_offset = lerpf(_l_offset, l_hit.offset, RigUtilC.damp_factor(foot_halflife, delta))
	_r_offset = lerpf(_r_offset, r_hit.offset, RigUtilC.damp_factor(foot_halflife, delta))

	_solve_leg(skel, to_world, to_local, _l, l_hit, _l_offset, _weight * l_plant)
	_solve_leg(skel, to_world, to_local, _r, r_hit, _r_offset, _weight * r_plant)


## How much this foot should be corrected: fully when it is on or under the
## ground, fading to nothing once it is clearly mid-swing.
func _plant_weight(hit: FootHit) -> float:
	if not hit.valid:
		return 0.0
	var height := -hit.offset   # positive means the foot is above the ground
	var span: float = maxf(plant_fade_height - plant_full_height, 0.001)
	return 1.0 - clampf((height - plant_full_height) / span, 0.0, 1.0)


class FootHit:
	var valid := false
	var point := Vector3.ZERO
	var normal := Vector3.UP
	var offset := 0.0


func _trace_foot(skel: Skeleton3D, to_world: Transform3D, foot_bone: int) -> FootHit:
	var hit := FootHit.new()
	var foot_world: Vector3 = to_world * skel.get_bone_global_pose(foot_bone).origin
	var from := foot_world + Vector3.UP * trace_up
	var to := foot_world - Vector3.UP * trace_down

	var params := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	params.hit_from_inside = false
	var res := _space.intersect_ray(params)
	if res.is_empty():
		return hit

	hit.valid = true
	hit.point = res.position
	hit.normal = res.normal
	# Positive: ground is above the animated foot, so lift. Negative: drop.
	hit.offset = (hit.point.y + ankle_height) - foot_world.y
	return hit


func _solve_leg(skel: Skeleton3D, to_world: Transform3D, to_local: Transform3D,
		chain: PackedInt32Array, hit: FootHit, offset: float, weight: float) -> void:
	if not hit.valid or weight < 0.01:
		return

	var foot_world: Vector3 = to_world * skel.get_bone_global_pose(chain[2]).origin
	var target_world := foot_world + Vector3.UP * offset
	var target_local: Vector3 = to_local * target_world

	# Bend the knee toward where it already points, so the solver keeps the
	# animation's natural knee direction instead of inventing one.
	var thigh: Vector3 = skel.get_bone_global_pose(chain[0]).origin
	var knee: Vector3 = skel.get_bone_global_pose(chain[1]).origin
	var ankle: Vector3 = skel.get_bone_global_pose(chain[2]).origin
	var pole := knee - (thigh + ankle) * 0.5
	if pole.length_squared() < 1e-8:
		pole = (to_local.basis * Vector3.FORWARD)

	RigUtilC.apply_two_bone(skel, chain[0], chain[1], chain[2], target_local, pole, weight)

	if align_to_normal:
		var n_local: Vector3 = (to_local.basis * hit.normal).normalized()
		var up_local: Vector3 = (to_local.basis * Vector3.UP).normalized()
		var tilt := RigUtilC.rot_between(up_local, n_local)
		var angle := up_local.angle_to(n_local)
		if angle > max_normal_angle:
			tilt = RigUtilC.rot_between(up_local, up_local.slerp(n_local, max_normal_angle / angle))
		RigUtilC.rotate_bone_model(skel, chain[2],
			Quaternion.IDENTITY.slerp(tilt, weight))
