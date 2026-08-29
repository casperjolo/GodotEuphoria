## Recolours Fred's body meshes.
##
## Fred.glb's 21 body parts all share one imported white StandardMaterial3D.
## We duplicate that material and override only its albedo, rather than
## assigning a material built from scratch -- a fresh StandardMaterial3D would
## reset cull mode, shading and specular to engine defaults, which is what made
## the backfaces show through and the shading go black.
##
## The duplicate is made once and shared by every mesh, so this stays a single
## material and a single draw-call setup.
extends Node
class_name FredMaterial

@export var tint: Color = Color("6688eb")
@export var target_path: NodePath = ^"../AnimatedTarget"

var _material: StandardMaterial3D

func _ready() -> void:
	apply()

func apply() -> void:
	var root := get_node_or_null(target_path)
	if root == null:
		push_error("FredMaterial: nothing at %s" % target_path)
		return
	_material = null
	var count := _apply_to(root)
	print("FredMaterial: recoloured %d meshes to %s" % [count, tint.to_html(false)])

func _apply_to(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if _material == null:
			_material = _make_material(mi)
		if _material:
			mi.material_override = _material
			count += 1
	for child in node.get_children():
		count += _apply_to(child)
	return count

## Copy the imported material so every property it set is preserved, then
## change the colour. Falls back to a plain material if the mesh has none.
func _make_material(mi: MeshInstance3D) -> StandardMaterial3D:
	var source := mi.get_active_material(0)
	var mat: StandardMaterial3D
	if source is StandardMaterial3D:
		mat = (source as StandardMaterial3D).duplicate()
	else:
		mat = StandardMaterial3D.new()
	mat.resource_name = "Euphoria Blue"
	mat.albedo_color = tint
	return mat
