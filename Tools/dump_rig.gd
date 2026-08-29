extends SceneTree

func _initialize() -> void:
	print("\n########## FRED SKELETON ##########")
	_dump_fred()
	print("\n########## SOURCE ANIMATION FBX ##########")
	_dump_source()
	quit()

func _dump_fred() -> void:
	var scene = load("res://NaturalMotion/Characters/Fred.glb")
	if scene == null:
		print("  !! could not load Fred.glb")
		return
	var inst = scene.instantiate()
	var skel = inst.find_child("Skeleton3D", true, false)
	if skel == null:
		print("  !! no Skeleton3D")
		inst.free()
		return
	print("  bone_count = %d" % skel.get_bone_count())
	for i in range(skel.get_bone_count()):
		print("    [%2d] %-28s parent=%d" % [i, skel.get_bone_name(i), skel.get_bone_parent(i)])
	var ap = inst.find_child("AnimationPlayer", true, false)
	print("  AnimationPlayer: %s" % ("FOUND" if ap else "NONE"))
	inst.free()

func _dump_source() -> void:
	var dir = DirAccess.open("res://Animations/Walk")
	if dir == null:
		print("  !! cannot open res://Animations/Walk")
		return
	dir.list_dir_begin()
	var picked := ""
	var f = dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.get_extension().to_lower() == "fbx":
			picked = f
			break
		f = dir.get_next()
	dir.list_dir_end()
	if picked == "":
		print("  !! no FBX found")
		return

	var path = "res://Animations/Walk/" + picked
	print("  file: %s" % path)
	var res = load(path)
	print("  loaded type: %s" % (res.get_class() if res else "NULL"))
	if not (res is PackedScene):
		return

	var inst = res.instantiate()
	print("  --- node tree ---")
	_print_tree(inst, 2)

	var skel = inst.find_child("Skeleton3D", true, false)
	if skel:
		print("  --- source skeleton (%d bones) ---" % skel.get_bone_count())
		for i in range(skel.get_bone_count()):
			print("    [%2d] %-28s parent=%d" % [i, skel.get_bone_name(i), skel.get_bone_parent(i)])
	else:
		print("  --- no Skeleton3D in source ---")

	var ap = inst.find_child("AnimationPlayer", true, false)
	if ap == null:
		print("  --- no AnimationPlayer in source ---")
		inst.free()
		return

	print("  --- animation libraries ---")
	for lib_name in ap.get_animation_library_list():
		var lib = ap.get_animation_library(lib_name)
		print("    library '%s': %s" % [lib_name, str(lib.get_animation_list())])

	var list = ap.get_animation_list()
	print("  animation_list = %s" % str(list))
	if list.size() > 0:
		var anim = ap.get_animation(list[0])
		print("  --- '%s' length=%.3f tracks=%d ---" % [list[0], anim.length, anim.get_track_count()])
		var n = min(anim.get_track_count(), 30)
		for t in range(n):
			print("    track %2d  type=%d  path=%s" % [t, anim.track_get_type(t), str(anim.track_get_path(t))])
		if anim.get_track_count() > n:
			print("    ... %d more tracks" % (anim.get_track_count() - n))
	inst.free()

func _print_tree(node: Node, indent: int) -> void:
	var pad = ""
	for i in range(indent):
		pad += " "
	print("%s%s (%s)" % [pad, node.name, node.get_class()])
	for c in node.get_children():
		_print_tree(c, indent + 2)
