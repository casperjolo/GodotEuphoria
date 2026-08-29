## Stores motion features for a single frame in an animation
class_name MotionFeature

class JointFeature:
	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var is_contact: bool = false
	func _init(pos: Vector3 = Vector3.ZERO, vel: Vector3 = Vector3.ZERO, contact: bool = false) -> void:
		position = pos
		velocity = vel
		is_contact = contact

# Frame information
var frame: int = 0
var time: float = 0.0
var animation_name: String = ""

# Character root motion
var root_position: Vector3 = Vector3.ZERO
var root_velocity: Vector3 = Vector3.ZERO
var root_rotation: Quaternion = Quaternion.IDENTITY

# Locomotion
var local_velocity: Vector3 = Vector3.ZERO  # Velocity relative to character
var heading: float = 0.0  # Character facing direction
var motion_direction: Vector3 = Vector3.ZERO  # Desired movement direction

# Joint features (left foot, right foot, left hand, right hand)
var left_foot: JointFeature = JointFeature.new()
var right_foot: JointFeature = JointFeature.new()
var left_hand: JointFeature = JointFeature.new()
var right_hand: JointFeature = JointFeature.new()

# Locomotion type tags
var locomotion_type: String = ""  # "idle", "walk", "run", "sprint", "jump", etc.

func _init(frame_num: int = 0, anim_name: String = "") -> void:
	frame = frame_num
	animation_name = anim_name

## Calculate distance to another feature (for matching)
func distance_to(other: MotionFeature, weights: Dictionary = {}) -> float:
	var default_weights = {
		"position": 1.0,
		"velocity": 2.0,
		"foot_contact": 1.5,
		"direction": 1.0,
	}

	for key in weights:
		default_weights[key] = weights[key]

	var distance = 0.0

	# Position difference
	distance += root_position.distance_to(other.root_position) * default_weights["position"]

	# Velocity difference
	distance += local_velocity.distance_to(other.local_velocity) * default_weights["velocity"]

	# Foot position differences
	distance += left_foot.position.distance_to(other.left_foot.position) * default_weights["position"] * 0.5
	distance += right_foot.position.distance_to(other.right_foot.position) * default_weights["position"] * 0.5

	# Foot velocity differences
	distance += left_foot.velocity.distance_to(other.left_foot.velocity) * default_weights["velocity"] * 0.5
	distance += right_foot.velocity.distance_to(other.right_foot.velocity) * default_weights["velocity"] * 0.5

	# Contact state differences
	if left_foot.is_contact != other.left_foot.is_contact:
		distance += default_weights["foot_contact"]
	if right_foot.is_contact != other.right_foot.is_contact:
		distance += default_weights["foot_contact"]

	# Heading/direction difference
	var heading_diff = angle_difference(heading, other.heading)
	distance += heading_diff * default_weights["direction"]

	return distance

## Helper function to calculate angle difference
func angle_difference(a: float, b: float) -> float:
	var diff = fmod(b - a + PI, TAU) - PI
	return abs(diff)

func _to_string() -> String:
	return "%s[frame:%d, vel:%.2f, type:%s]" % [
		animation_name, frame,
		local_velocity.length(),
		locomotion_type
	]
