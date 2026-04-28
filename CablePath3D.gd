@tool
extends Path3D
class_name CablePath3D

const _GENERATED_MESH_NAME := "GeneratedMesh"
const _GENERATED_MESH_META := "_cable_path_3d_generated"

@export_range(0.001, 1.0, 0.001) var cable_thickness: float = 0.01:
	set(value):
		cable_thickness = max(value, 0.001)
		_request_update()

@export var cable_material: Material:
	set(value):
		cable_material = value
		_request_update()

@export_range(0.001, 1.0, 0.001) var path_interval: float = 0.05:
	set(value):
		path_interval = max(value, 0.001)
		_request_update()

@export_range(0.001, 10.0, 0.001) var path_u_distance: float = 1.0:
	set(value):
		path_u_distance = max(value, 0.001)
		_request_update()

@export_range(3, 64, 1) var radial_segments: int = 8:
	set(value):
		radial_segments = max(value, 3)
		_request_update()

@export_group("Cable Baking")
@export var regenerate_mesh: bool = false:
	set(value):
		if value:
			_request_update()
		regenerate_mesh = false

var _mesh_instance: MeshInstance3D
var _debug_material: StandardMaterial3D
var _connected_curve: Curve3D
var _update_queued := false

func _init() -> void:
	_debug_material = StandardMaterial3D.new()
	_debug_material.albedo_color = Color(1, 0, 0)
	_debug_material.metallic = 0.0
	_debug_material.roughness = 0.5

func _enter_tree() -> void:
	if not curve_changed.is_connected(_request_update):
		curve_changed.connect(_request_update)
	
	_connect_curve_changed()

func _ready() -> void:
	_update_cable()

func _exit_tree() -> void:
	if curve_changed.is_connected(_request_update):
		curve_changed.disconnect(_request_update)
	
	_disconnect_curve_changed()

func _request_update() -> void:
	if not is_inside_tree():
		return
	
	if _update_queued:
		return
	
	_update_queued = true
	call_deferred("_update_cable")

func _connect_curve_changed() -> void:
	var curve_obj: Curve3D = get_curve()
	if _connected_curve == curve_obj:
		return
	
	_disconnect_curve_changed()
	_connected_curve = curve_obj
	
	if _connected_curve and not _connected_curve.changed.is_connected(_request_update):
		_connected_curve.changed.connect(_request_update)

func _disconnect_curve_changed() -> void:
	if _connected_curve and _connected_curve.changed.is_connected(_request_update):
		_connected_curve.changed.disconnect(_request_update)
	
	_connected_curve = null

func _update_cable() -> void:
	_update_queued = false
	_connect_curve_changed()

	var mesh: ArrayMesh = _create_cable_mesh()
	if mesh == null:
		var existing_mesh_instance: MeshInstance3D = _get_existing_mesh_instance()
		if existing_mesh_instance:
			existing_mesh_instance.mesh = null
		return
	
	var mesh_instance: MeshInstance3D = _get_or_create_mesh_instance()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = cable_material if cable_material else _debug_material

func _get_or_create_mesh_instance() -> MeshInstance3D:
	_mesh_instance = _get_existing_mesh_instance()
	if _mesh_instance:
		return _mesh_instance
	
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = _GENERATED_MESH_NAME
	_mesh_instance.set_meta(_GENERATED_MESH_META, true)
	add_child(_mesh_instance)
	
	if Engine.is_editor_hint() and is_inside_tree():
		var edited_scene_root: Node = get_tree().edited_scene_root
		if edited_scene_root:
			_mesh_instance.owner = edited_scene_root
	
	return _mesh_instance

func _get_existing_mesh_instance() -> MeshInstance3D:
	if is_instance_valid(_mesh_instance) and _mesh_instance.get_parent() == self:
		return _mesh_instance
	
	_mesh_instance = get_node_or_null(_GENERATED_MESH_NAME) as MeshInstance3D
	if _mesh_instance:
		_mesh_instance.set_meta(_GENERATED_MESH_META, true)
	
	return _mesh_instance

# Core mesh generation
func _create_cable_mesh() -> ArrayMesh:
	var curve_obj: Curve3D = get_curve()
	if curve_obj == null or curve_obj.get_point_count() < 2:
		return null
	
	var total_length: float = curve_obj.get_baked_length()
	if total_length <= 0:
		return null
	
	var segments: int = max(1, int(ceil(total_length / max(path_interval, 0.001))))
	var circle_resolution: int = max(radial_segments, 3)
	
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	
	for i in range(segments + 1):
		var t: float = float(i) / segments
		var distance_along_curve: float = t * total_length
		
		var sample_transform: Transform3D = curve_obj.sample_baked_with_rotation(distance_along_curve, false)
		var position: Vector3 = sample_transform.origin
		var normal: Vector3 = sample_transform.basis.y.normalized()
		var binormal: Vector3 = sample_transform.basis.x.normalized()
		
		# Generate circle vertices at this point
		for j in range(circle_resolution):
			var angle: float = TAU * float(j) / float(circle_resolution)
			
			# Parametric equation for a circle in 3D space
			var circle_pos: Vector3 = binormal * cos(angle) * cable_thickness + normal * sin(angle) * cable_thickness
			vertices.append(position + circle_pos)
			
			var vertex_normal: Vector3 = circle_pos.normalized()
			normals.append(vertex_normal)
			
			uvs.append(Vector2(float(j) / float(circle_resolution), float(i) * path_u_distance))
	
	# Generate indices
	for i in range(segments):
		for j in range(circle_resolution):
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
