extends SceneTree

const RT = preload("res://Tools/retarget_lib.gd")

func _initialize() -> void:
	var glb = load("res://NaturalMotion/Characters/Fred.glb").instantiate()
	var skel: Skeleton3D = glb.find_child("Skeleton3D", true, false)
	var rig = RT.RigInfo.new(skel)

	# Compose the chain by hand: global_transform is unavailable outside the
	# tree, and AnimatedTarget sits at identity under Fred, so skeleton->glb-root
	# is also skeleton->character-root.
	var xf := _chain(skel, glb)
	print("skeleton transform relative to character root:")
	print("  origin = %v" % xf.origin)
	print("  basis.x = %v" % xf.basis.x)
	print("  basis.y = %v" % xf.basis.y)
	print("  basis.z = %v" % xf.basis.z)
	print("  scale   = %v" % xf.basis.get_scale())

	# --- how far below the origin do the feet sit (rest pose) ---
	var lowest := INF
	var lowest_bone := ""
	var highest := -INF
	for i in range(skel.get_bone_count()):
		var p: Vector3 = xf * rig.rest_model[i].origin
		if p.y < lowest:
			lowest = p.y
			lowest_bone = skel.get_bone_name(i)
		highest = maxf(highest, p.y)
	print("\nrest pose, in character-root space:")
	print("  lowest  y = %+.4f  (%s)" % [lowest, lowest_bone])
	print("  highest y = %+.4f" % highest)
	print("  stature   = %.4f" % (highest - lowest))
	print("  >>> lift AnimatedTarget by %+.4f to put feet on y=0" % -lowest)

	# --- which way does the mesh actually face in world space ---
	var ori: Basis = RT.rig_orientation(rig, "SKEL_Pelvis_00", "SKEL_Head_020",
		"SKEL_L_Thigh_01", "SKEL_R_Thigh_04")
	var world_up: Vector3 = (xf.basis * ori.y).normalized()
	var world_side: Vector3 = (xf.basis * ori.x).normalized()   # left -> right
	var world_fwd: Vector3 = (xf.basis * ori.z).normalized()
	print("\nin character-root space:")
	print("  up          = %v" % world_up)
	print("  left->right = %v" % world_side)
	print("  chest fwd   = %v   (side x up)" % world_fwd)

	print("\n  side x up (= character's BACK) = %s" % _describe(world_fwd))
	print("  so the mesh faces           = %s" % _describe(-world_fwd))

	# Empirical check: a forward-walk clip must travel the way the character
	# looks. This beats reasoning about handedness conventions.
	_measure_travel(xf)
	quit()

func _measure_travel(xf: Transform3D) -> void:
	var lib := ResourceLoader.load("res://Animations/Retargeted/Walk.res") as AnimationLibrary
	if lib == null:
		print("\n(no baked Walk.res to cross-check travel)")
		return
	var name := "M_Neutral_Walk_Loop_F"
	if not lib.has_animation(name):
		print("\n(no %s in Walk.res)" % name)
		return
	var anim := lib.get_animation(name)
	var track := -1
	for t in range(anim.get_track_count()):
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D \
				and String(anim.track_get_path(t)).ends_with("_rootJoint"):
			track = t
			break
	if track < 0:
		print("\n(no _rootJoint track in %s)" % name)
		return

	var p0: Vector3 = anim.position_track_interpolate(track, 0.0)
	var p1: Vector3 = anim.position_track_interpolate(track, anim.length)
	var travel_model := p1 - p0
	var travel_root := (xf.basis * travel_model)
	travel_root.y = 0.0

	print("\nforward-walk clip '%s' (%.2fs):" % [name, anim.length])
	print("  root travel, character-root space = %v  (%.2f m)"
		% [travel_root, travel_root.length()])
	if travel_root.length() > 0.01:
		var d := travel_root.normalized()
		print("  => the character walks toward %s" % _describe(d))
		print("\n  A Godot node's own forward is -Z. Required yaw to face travel dir d:")
		if d.z < -0.5:
			print("     rotation.y = atan2(-d.x, -d.z)")
		elif d.z > 0.5:
			print("     rotation.y = atan2(d.x, d.z)")
		else:
			print("     needs an explicit offset (mesh not Z-aligned)")

## Transform from `from`'s local space up into `ancestor`'s space.
func _chain(from: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = from
	while n != null and n != ancestor:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf

func _describe(v: Vector3) -> String:
	var parts := []
	if absf(v.x) > 0.5: parts.append("+X" if v.x > 0 else "-X")
	if absf(v.y) > 0.5: parts.append("+Y" if v.y > 0 else "-Y")
	if absf(v.z) > 0.5: parts.append("+Z" if v.z > 0 else "-Z")
	return "%v  ~ %s" % [v, " ".join(parts) if parts.size() > 0 else "diagonal"]
