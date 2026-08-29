## Confirms the root/pelvis split is correct in the baked clips:
## the root bone should carry all the travel and turn, while the pelvis should
## stay put apart from its vertical bob.
extends SceneTree

func _initialize() -> void:
	var lib := ResourceLoader.load("res://Animations/Retargeted/Walk.res") as AnimationLibrary
	if lib == null:
		print("no Walk.res"); quit(1); return

	for name in ["M_Neutral_Walk_Loop_F", "M_Neutral_Walk_Loop_LL", "M_Neutral_Walk_Loop_B"]:
		if not lib.has_animation(name):
			continue
		_report(lib.get_animation(name), name)
	quit()

func _report(anim: Animation, name: String) -> void:
	var root_pos := _track(anim, "_rootJoint", Animation.TYPE_POSITION_3D)
	var root_rot := _track(anim, "_rootJoint", Animation.TYPE_ROTATION_3D)
	var hip_pos := _track(anim, "SKEL_Pelvis_00", Animation.TYPE_POSITION_3D)

	print("\n--- %s  (%.2fs) ---" % [name, anim.length])
	if root_pos < 0 or hip_pos < 0:
		print("  missing tracks: root_pos=%d hip_pos=%d" % [root_pos, hip_pos])
		return

	var r0: Vector3 = anim.position_track_interpolate(root_pos, 0.0)
	var r1: Vector3 = anim.position_track_interpolate(root_pos, anim.length)
	print("  root travel        %.3f m" % r0.distance_to(r1))

	if root_rot >= 0:
		var q0: Quaternion = anim.rotation_track_interpolate(root_rot, 0.0)
		var q1: Quaternion = anim.rotation_track_interpolate(root_rot, anim.length)
		print("  root turn          %.1f deg" % rad_to_deg(q0.angle_to(q1)))
	else:
		print("  root turn          (no rotation track)")

	# The pelvis should bob, not travel. Anything approaching the root's travel
	# means the body is moving out from under the collision capsule.
	var lo := Vector3.INF
	var hi := -Vector3.INF
	var steps := 40
	for i in range(steps + 1):
		var p: Vector3 = anim.position_track_interpolate(hip_pos, anim.length * i / steps)
		lo = lo.min(p)
		hi = hi.max(p)
	var spread := hi - lo
	print("  pelvis spread      %.3f m  (%v)" % [spread.length(), spread])
	print("  %s" % ("PASS - pelvis stays put" if spread.length() < 0.25
		else "FAIL - pelvis is travelling with the clip"))

func _track(anim: Animation, bone: String, type: int) -> int:
	for t in range(anim.get_track_count()):
		if anim.track_get_type(t) == type and String(anim.track_get_path(t)).ends_with(bone):
			return t
	return -1
