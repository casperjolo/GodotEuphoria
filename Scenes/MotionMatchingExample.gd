## Example: How to use the motion matching system
## This script shows the basic API for controlling Fred's motion
extends Node
class_name MotionMatchingExample

# Reference to the motion matcher
@onready var motion_matcher: MotionMatcher = get_node("../MotionMatcher")

# Example 1: Basic setup
func example_basic_setup() -> void:
	print("Example 1: Basic Setup")

	# Build the motion database from loaded animations
	motion_matcher.build_database_from_animations()
	print("Motion database built")

# Example 2: Simple movement
func example_simple_movement(velocity: Vector3, heading: float) -> void:
	print("Example 2: Simple Movement")

	# Set desired motion parameters
	# velocity: character's movement speed
	# heading: character's facing direction (in radians)
	# direction: optional, movement direction
	motion_matcher.set_desired_motion(velocity, heading, velocity.normalized())

	# The motion matcher will automatically find and play the best animation

# Example 3: Query motion database
func example_query_database() -> void:
	print("Example 3: Query Motion Database")

	var db = motion_matcher.motion_database

	# Find best match for a specific motion state
	var target = MotionFeature.new()
	target.local_velocity = Vector3(0, 0, 5.0)  # Moving forward at 5 units/sec
	target.heading = 0.0  # Facing forward
	target.locomotion_type = "walk"

	var matches = db.find_best_match(target, "walk", 5)  # Get top 5 matches

	for match in matches:
		print("Match: %s (frame %d, distance: %.2f)" % [
			match["animation"],
			match["frame"],
			match["distance"]
		])

# Example 4: Get animations by type
func example_get_animations_by_type() -> void:
	print("Example 4: Get Animations by Type")

	var loader = motion_matcher.get_parent().find_child("AnimationLoader")
	if not loader:
		return

	var walk_anims = loader.get_animations_by_type("walk")
	print("Walk animations: %d" % walk_anims.size())

	for anim_name in walk_anims:
		var meta = loader.get_animation_metadata(anim_name)
		print("  - %s (length: %.2f)" % [anim_name, meta["length"]])

# Example 5: Manual animation control
func example_manual_control() -> void:
	print("Example 5: Manual Animation Control")

	# Manually set a specific animation
	motion_matcher.set_animation("Idle", 0.0)

	# Get current playback info
	var current = motion_matcher.get_current_animation()
	var frame = motion_matcher.get_current_frame()
	print("Current animation: %s at frame %.2f" % [current, frame])

# Example 6: Advanced motion matching with weights
func example_advanced_matching() -> void:
	print("Example 6: Advanced Motion Matching")

	# Create a specific motion query
	var target = MotionFeature.new()
	target.local_velocity = Vector3(0, 0, 7.5)  # Fast movement
	target.heading = PI / 4  # Moving northeast
	target.locomotion_type = "run"

	# Get matches and check their details
	var matches = motion_matcher.motion_database.find_best_match(target, "run", 1)

	if matches.size() > 0:
		var best = matches[0]
		var feature = best["feature"]

		print("Best match found:")
		print("  Animation: %s" % best["animation"])
		print("  Frame: %d" % best["frame"])
		print("  Distance: %.2f" % best["distance"])
		print("  Matched velocity: %.2f" % feature.local_velocity.length())
		print("  Matched heading: %.2f" % feature.heading)

# Example 7: Monitor motion database
func example_database_info() -> void:
	print("Example 7: Database Information")

	var db = motion_matcher.motion_database

	print("Total animations: %d" % db.motion_features.size())

	for anim_name in db.motion_features:
		var features = db.motion_features[anim_name]
		print("  %s: %d frames" % [anim_name, features.size()])

# Example 8: Dynamic locomotion type switching
func example_locomotion_switching() -> void:
	print("Example 8: Locomotion Type Switching")

	var player_velocity = Vector3.ZERO
	var player_heading = 0.0

	# Simulate input and automatic type switching
	var input_magnitude = 0.5

	if input_magnitude < 0.1:
		# Idle
		motion_matcher.set_desired_motion(Vector3.ZERO, player_heading, Vector3.ZERO, "idle")
	elif input_magnitude < 0.5:
		# Walk
		player_velocity = Vector3.FORWARD * 5.0
		motion_matcher.set_desired_motion(player_velocity, player_heading, player_velocity.normalized(), "walk")
	else:
		# Run
		player_velocity = Vector3.FORWARD * 8.0
		motion_matcher.set_desired_motion(player_velocity, player_heading, player_velocity.normalized(), "run")

# Example 9: Feature distance calculation
func example_feature_distance() -> void:
	print("Example 9: Feature Distance")

	# Create two motion features
	var f1 = MotionFeature.new()
	f1.local_velocity = Vector3(0, 0, 5.0)
	f1.heading = 0.0
	f1.left_foot.is_contact = true
	f1.right_foot.is_contact = false

	var f2 = MotionFeature.new()
	f2.local_velocity = Vector3(0, 0, 5.2)
	f2.heading = 0.1
	f2.left_foot.is_contact = false
	f2.right_foot.is_contact = true

	# Calculate distance between them
	var distance = f1.distance_to(f2)
	print("Distance between features: %.2f" % distance)

	# With custom weights
	var custom_weights = {
		"velocity": 5.0,  # Make velocity matching very important
		"position": 0.5,  # Make position matching less important
	}
	var weighted_distance = f1.distance_to(f2, custom_weights)
	print("Weighted distance: %.2f" % weighted_distance)

# Example 10: Save and load database
func example_save_load_database() -> void:
	print("Example 10: Save/Load Database")

	var db_path = "user://motion_database.tres"

	# Save the database
	if motion_matcher.motion_database.save_to_file(db_path):
		print("Database saved to: %s" % db_path)

	# Load it back
	if ResourceLoader.exists(db_path):
		var loaded_db = load(db_path)
		print("Database loaded: %d animations" % loaded_db.motion_features.size())

# Run all examples
func run_all_examples() -> void:
	print("\n=== Motion Matching System Examples ===\n")

	example_basic_setup()
	print()

	example_simple_movement(Vector3(0, 0, 5), 0)
	print()

	example_query_database()
	print()

	example_get_animations_by_type()
	print()

	example_manual_control()
	print()

	example_advanced_matching()
	print()

	example_database_info()
	print()

	example_locomotion_switching()
	print()

	example_feature_distance()
	print()

	example_save_load_database()
	print()

	print("=== Examples Complete ===\n")
