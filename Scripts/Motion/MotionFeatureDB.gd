## Pose-feature database for motion matching.
##
## One feature vector per animation frame, stored in flat PackedFloat32Arrays
## so a search is a tight loop over contiguous memory rather than a walk over
## thousands of objects.
##
## Built offline by Tools/bake_features.gd, queried by Scripts/Motion/MotionMatcher.gd.
extends Resource
class_name MotionFeatureDB

## Future times (seconds) the trajectory is sampled at.
const TRAJ_TIMES: Array[float] = [0.33, 0.66, 1.0]

# --- feature layout, 27 floats per pose ---
#   0.. 5  trajectory position   3 points x (x, z)   in character-local space
#   6..11  trajectory facing     3 points x (x, z)
#  12..14  left foot position    (x, y, z)
#  15..17  right foot position
#  18..20  left foot velocity
#  21..23  right foot velocity
#  24..26  hip velocity
const F_TRAJ_POS := 0
const F_TRAJ_DIR := 6
const F_FOOT_L_POS := 12
const F_FOOT_R_POS := 15
const F_FOOT_L_VEL := 18
const F_FOOT_R_VEL := 21
const F_HIP_VEL := 24
const FEATURE_SIZE := 27

## Flat feature data, pose_count * FEATURE_SIZE, already normalised.
@export var features: PackedFloat32Array = PackedFloat32Array()
## Per pose: index into clip_names.
@export var clip_ids: PackedInt32Array = PackedInt32Array()
## Per pose: playback time within its clip.
@export var times: PackedFloat32Array = PackedFloat32Array()
## Per pose: ground speed in m/s, used for bucketing.
@export var speeds: PackedFloat32Array = PackedFloat32Array()
## Per pose: index of the pose one frame later in the same clip, or -1 at the
## end of a clip. Poses are stored speed-sorted, so frames of a clip are NOT
## adjacent -- without this link there is no cheap way to ask "what happens if
## I just keep playing?", and the matcher ends up re-picking a clip every query.
@export var next_pose: PackedInt32Array = PackedInt32Array()
## Full clip names, e.g. "Walk/M_Neutral_Walk_Loop_F".
@export var clip_names: PackedStringArray = PackedStringArray()

## Per-dimension mean and standard deviation used to normalise. A query must be
## normalised the same way or the weights mean nothing.
@export var means: PackedFloat32Array = PackedFloat32Array()
@export var stds: PackedFloat32Array = PackedFloat32Array()

## Speed bucketing. Poses are sorted by speed and bucket_starts[i] gives the
## first pose index at or above bucket i's lower bound, so a query can skip
## most of the database instead of scanning ~100k poses every time.
@export var bucket_bounds: PackedFloat32Array = PackedFloat32Array()
@export var bucket_starts: PackedInt32Array = PackedInt32Array()


func pose_count() -> int:
	return clip_ids.size()


func clip_name_of(pose: int) -> String:
	if pose < 0 or pose >= clip_ids.size():
		return ""
	var id := clip_ids[pose]
	return clip_names[id] if id >= 0 and id < clip_names.size() else ""


## Normalise a raw feature vector in place using the baked statistics.
func normalise(raw: PackedFloat32Array) -> PackedFloat32Array:
	var out := raw.duplicate()
	for i in range(mini(out.size(), FEATURE_SIZE)):
		var s: float = stds[i] if i < stds.size() else 1.0
		if s < 1e-6:
			s = 1.0
		out[i] = (out[i] - means[i]) / s
	return out


## Pose index range [from, to) covering every bucket that overlaps
## [speed - tolerance, speed + tolerance].
func bucket_range(speed: float, tolerance: float) -> Vector2i:
	var n := pose_count()
	if bucket_starts.is_empty():
		return Vector2i(0, n)
	var lo := speed - tolerance
	var hi := speed + tolerance
	var first := 0
	var last := n
	for i in range(bucket_bounds.size()):
		if bucket_bounds[i] <= lo:
			first = bucket_starts[i]
	for i in range(bucket_bounds.size()):
		if bucket_bounds[i] > hi:
			last = bucket_starts[i]
			break
	if last < first:
		last = n
	return Vector2i(first, last)
