## Looking instinct: head and upper body turn toward what the character is
## paying attention to.
##
## While moving, attention goes where they are heading. While idle, it drifts to
## points of interest -- nearby physics bodies if any are around, otherwise
## wandering glances -- with the occasional hold, so the character does not
## sweep the room like a turret.
##
## The turn is distributed across the spine so the whole torso participates
## instead of the neck snapping alone.
extends SkeletonModifier3D
class_name IdleLook

const RigUtilC = preload("res://Scripts/Core/RigUtil.gd")

@export var enabled: bool = true

@export_group("Bones")
@export var head_bone := "SKEL_Head_020"
@export var neck_bone := "SKEL_Neck_1_019"
## Spine bones that share the turn, listed from the hips outward.
@export var spine_bones: Array[String] = ["SKEL_Spine2_09", "SKEL_Spine3_010"]

@export_group("Limits")
## Maximum yaw away from straight ahead, radians.
@export var max_yaw: float = 1.15
@export var max_pitch: float = 0.5
## Fraction of the turn taken by the head; the rest is spread over neck and spine.
@export var head_share: float = 0.55
@export var neck_share: float = 0.3

@export_group("Attention")
@export var look_halflife: float = 0.28
## Radius searched for something worth looking at while idle.
@export var interest_radius: float = 7.0
@export var interest_mask: int = 1 + 2 + 4
## Seconds a glance is held before picking somewhere new.
@export var glance_min: float = 1.4
@export var glance_max: float = 3.6
## Ground speed above which attention locks to the direction of travel.
@export var moving_speed: float = 0.4

var character: CharacterBody3D

var _head := -1
var _neck := -1
var _spine := PackedInt32Array()
var _current := Vector3.ZERO      ## smoothed look direction, character-local
var _target := Vector3.FORWARD
var _glance_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _space: PhysicsDirectSpaceState3D


func _ready() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	_rng.randomize()
	_head = skel.find_bone(head_bone)
	_neck = skel.find_bone(neck_bone)
	_spine = RigUtilC.find_bones(skel, spine_bones)
	if _head < 0:
		push_warning("IdleLook: no head bone, disabling")
		enabled = false
	_current = Vector3.FORWARD
	_target = Vector3.FORWARD


func _process_modification() -> void:
	var skel := get_skeleton()
	if not enabled or skel == null or character == null:
		return

	var delta := get_process_delta_time()
	_glance_timer -= delta

	var speed := Vector2(character.velocity.x, character.velocity.z).length()
	if speed > moving_speed:
		# Moving: look where we are going, in the character's own frame.
		var v := character.velocity
		v.y = 0.0
		var local: Vector3 = character.global_transform.basis.inverse() * v.normalized()
		_target = local
		_glance_timer = 0.0
	elif _glance_timer <= 0.0:
		_target = _pick_glance()
		_glance_timer = _rng.randf_range(glance_min, glance_max)

	_current = _current.slerp(_target, RigUtilC.damp_factor(look_halflife, delta)).normalized()

	# Character-local yaw/pitch, clamped to something a neck can do.
	var yaw := clampf(atan2(_current.x, -_current.z), -max_yaw, max_yaw)
	var pitch := clampf(asin(clampf(_current.y, -1.0, 1.0)), -max_pitch, max_pitch)

	var spine_share := maxf(1.0 - head_share - neck_share, 0.0)
	_turn(skel, _head, yaw * head_share, pitch * head_share)
	_turn(skel, _neck, yaw * neck_share, pitch * neck_share)
	if _spine.size() > 0:
		var per := spine_share / _spine.size()
		for b in _spine:
			_turn(skel, b, yaw * per, pitch * per)


## Apply a yaw/pitch in the skeleton's model space to one bone.
func _turn(skel: Skeleton3D, bone: int, yaw: float, pitch: float) -> void:
	if bone < 0 or (absf(yaw) < 0.0005 and absf(pitch) < 0.0005):
		return
	var skel_basis := skel.global_transform.basis
	var up_local: Vector3 = (skel_basis.inverse() * Vector3.UP).normalized()
	var right_local: Vector3 = (skel_basis.inverse() * character.global_transform.basis.x).normalized()
	var rot := Quaternion(up_local, yaw) * Quaternion(right_local, pitch)
	RigUtilC.rotate_bone_model(skel, bone, rot)


## Choose somewhere to look: a nearby body if there is one, else a plausible
## idle glance biased toward the front.
func _pick_glance() -> Vector3:
	var poi := _nearest_interest()
	if poi != Vector3.ZERO:
		var local: Vector3 = character.global_transform.affine_inverse() * poi
		if local.length_squared() > 1e-6:
			return local.normalized()

	var yaw := _rng.randf_range(-max_yaw, max_yaw)
	var pitch := _rng.randf_range(-max_pitch * 0.5, max_pitch * 0.7)
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)).normalized()


## Nearest physics body worth a glance, or ZERO if nothing is around.
func _nearest_interest() -> Vector3:
	var skel := get_skeleton()
	if skel == null:
		return Vector3.ZERO
	if _space == null:
		_space = skel.get_world_3d().direct_space_state
		if _space == null:
			return Vector3.ZERO

	var shape := SphereShape3D.new()
	shape.radius = interest_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.collision_mask = interest_mask
	params.transform = Transform3D(Basis(), character.global_position + Vector3.UP * 1.2)
	params.exclude = [character.get_rid()]

	var hits := _space.intersect_shape(params, 8)
	var best := Vector3.ZERO
	var best_d := INF
	for h in hits:
		var col = h.get("collider")
		if col == null or not (col is Node3D):
			continue
		# Static world geometry is not interesting; moving things are.
		if col is StaticBody3D:
			continue
		var p: Vector3 = (col as Node3D).global_position
		var d: float = character.global_position.distance_to(p)
		if d < best_d:
			best_d = d
			best = p
	return best
