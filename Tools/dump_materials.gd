extends SceneTree

func _initialize() -> void:
	var fred = load("res://NaturalMotion/Characters/Fred.glb").instantiate()
	get_root().add_child(fred)
	var mi := _first_mesh(fred)
	if mi == null:
		print("no MeshInstance3D"); quit(); return

	var mat := mi.get_active_material(0)
	print("=== ORIGINAL MATERIAL on %s ===" % mi.name)
	if mat is StandardMaterial3D:
		var m := mat as StandardMaterial3D
		print("  albedo_color     = %s" % m.albedo_color)
		print("  shading_mode     = %d   (0=Unshaded 1=PerPixel 2=PerVertex)" % m.shading_mode)
		print("  cull_mode        = %d   (0=Back 1=Front 2=Disabled)" % m.cull_mode)
		print("  diffuse_mode     = %d" % m.diffuse_mode)
		print("  specular_mode    = %d" % m.specular_mode)
		print("  metallic         = %.3f" % m.metallic)
		print("  roughness        = %.3f" % m.roughness)
		print("  transparency     = %d" % m.transparency)
		print("  blend_mode       = %d" % m.blend_mode)
		print("  no_depth_test    = %s" % m.no_depth_test)
		print("  disable_receive_shadows = %s" % m.disable_receive_shadows)
		print("  vertex_color_use_as_albedo = %s" % m.vertex_color_use_as_albedo)

	# Are the normals sane? Sample a few and compare against the outward
	# direction from the mesh's own centre -- flipped normals read as inside-out.
	var mesh := mi.mesh
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	print("\n=== MESH %s: %d verts, %d normals ===" % [mi.name, verts.size(), norms.size()])
	if norms.size() > 0:
		var centre := Vector3.ZERO
		for v in verts:
			centre += v
		centre /= verts.size()
		var outward := 0
		var inward := 0
		for i in range(verts.size()):
			var to_surface := (verts[i] - centre).normalized()
			if to_surface.dot(norms[i]) >= 0.0:
				outward += 1
			else:
				inward += 1
		print("  normals pointing outward: %d" % outward)
		print("  normals pointing inward:  %d   <-- inside-out if this dominates" % inward)

func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for c in node.get_children():
		var r := _first_mesh(c)
		if r:
			return r
	return null
