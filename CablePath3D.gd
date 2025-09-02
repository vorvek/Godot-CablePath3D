@tool
extends Path3D
class_name CablePath3D

@export var mesh_name: String = "CableMesh"

@export_range(0.001, 1.0, 0.001) var cable_thickness: float = 0.01:
	set(value):
		cable_thickness = value
		_update_cable()

@export var cable_material: Material:
	set(value):
		cable_material = value
		_update_cable()

@export_range(0.001, 1.0, 0.001) var path_interval: float = 0.05:
	set(value):
		path_interval = value
		_update_cable()

@export_range(0.001, 10.0, 0.001) var path_u_distance: float = 1.0:
	set(value):
		path_u_distance = value
		_update_cable()

@export_group("Cable Baking")
@export var regenerate_mesh: bool = false:
	set(value):
		if value:
			_update_cable()
			regenerate_mesh = false # Reset the button

var _mesh_instance: MeshInstance3D
var _debug_material: StandardMaterial3D

func _init() -> void:
	_debug_material = StandardMaterial3D.new()
	_debug_material.albedo_color = Color(1, 0, 0)
	_debug_material.metallic = 0.0
	_debug_material.roughness = 0.5
	
func _ready() -> void:
	# Find the existing MeshInstance3D or create a new one.
	# This prevents creating duplicates when the scene loads.
	_mesh_instance = find_child(mesh_name)
	if not _mesh_instance:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = mesh_name
		add_child(_mesh_instance)
		
	# Set owner for proper scene serialization in editor
	if Engine.is_editor_hint() and is_inside_tree():
		_mesh_instance.owner = get_tree().edited_scene_root
	
	# Connect to curve changes in editor
	if Engine.is_editor_hint():
		var curve_obj: Curve3D = get_curve()
		if curve_obj and not curve_obj.changed.is_connected(_update_cable):
			curve_obj.changed.connect(_update_cable)
	
	_update_cable()

func _exit_tree() -> void:
	# Disconnect from curve changes to prevent errors
	if Engine.is_editor_hint():
		var curve_obj: Curve3D = get_curve()
		if curve_obj and curve_obj.changed.is_connected(_update_cable):
			curve_obj.changed.disconnect(_update_cable)

func _update_cable() -> void:
	if not is_instance_valid(_mesh_instance):
		# If for some reason the mesh instance is not valid, try to find it again.
		_mesh_instance = find_child(mesh_name)
		if not is_instance_valid(_mesh_instance):
			# If still not found, it's an error. We should not create it here.
			printerr("CablePath3D: MeshInstance3D not found and could not be created.")
			return
			
	var mesh: ArrayMesh = _create_cable_mesh()
	if mesh:
		_mesh_instance.mesh = mesh
		
		# Apply material with fallback to debug material
		if cable_material:
			# Create a duplicate of the material to avoid shared instances
			var material_instance = cable_material.duplicate()
			_mesh_instance.material_override = material_instance
		else:
			_mesh_instance.material_override = _debug_material

# Core mesh generation
func _create_cable_mesh() -> ArrayMesh:
	var curve_obj: Curve3D = get_curve()
	if curve_obj == null or curve_obj.get_point_count() < 2:
		return null
	
	var total_length: float = curve_obj.get_baked_length()
	if total_length <= 0:
		return null
	
	var segments: int = max(1, ceil(total_length / path_interval))
	var circle_resolution: int = 8 
	
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	
	for i in segments + 1:
		var t: float = float(i) / segments
		var distance_along_curve: float = t * total_length
		
		@warning_ignore_start("shadowed_variable_base_class")
		var transform: Transform3D = curve_obj.sample_baked_with_rotation(distance_along_curve, false)
		var position: Vector3 = transform.origin
		@warning_ignore_restore("shadowed_variable_base_class")
		# unused
		# var tangent: Vector3 = -transform.basis.z.normalized()
		var normal: Vector3 = transform.basis.y.normalized()
		var binormal: Vector3 = transform.basis.x.normalized()
		
		# Generate circle vertices at this point
		for j in circle_resolution:
			var angle: float = TAU * float(j) / float(circle_resolution)
			
			# Parametric equation for a circle in 3D space
			var circle_pos: Vector3 = binormal * cos(angle) * cable_thickness + normal * sin(angle) * cable_thickness
			vertices.append(position + circle_pos)
			
			var vertex_normal: Vector3 = circle_pos.normalized()
			normals.append(vertex_normal)
			
			uvs.append(Vector2(float(j) / float(circle_resolution), float(i) * path_u_distance))
	
	# Generate indices
	for i in segments:
		for j in circle_resolution:
			var current: int = i * circle_resolution + j
			var next: int = current + circle_resolution
			var next_vertex: int = i * circle_resolution + ((j + 1) % circle_resolution)
			var next_next: int = next_vertex + circle_resolution
			
			# First triangle
			indices.append(current)
			indices.append(next_vertex)
			indices.append(next)
			
			# Second triangle
			indices.append(next_vertex)
			indices.append(next_next)
			indices.append(next)
	
	# Create the mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return mesh

# Manually update the cable
func regenerate_cable() -> void:
	_update_cable()
