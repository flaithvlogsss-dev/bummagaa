class_name MeshBuilder
extends RefCounted
## MeshBuilder — merges primitive meshes into one ArrayMesh with per-vertex colour.
##
## Purpose: every low-poly prop/block becomes ONE mesh instance (colour in COLOR.rgb,
##   snow exposure in COLOR.a, emission in UV2.x, material id (WorldTextures) in UV2.y). Far fewer draw calls and only one
##   per-instance shader variable (the occlusion fade). Identical props share a cached mesh.

static var _cache: Dictionary = {}

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _uv2 := PackedVector2Array()
var _indices := PackedInt32Array()


static func cached(key: String) -> ArrayMesh:
	return _cache.get(key)


static func store(key: String, mesh: ArrayMesh) -> void:
	_cache[key] = mesh


static func clear_cache() -> void:
	_cache.clear()


func add(mesh: PrimitiveMesh, xform: Transform3D, color: Color, snow: float = 1.0, emission: float = 0.0, material: int = 0) -> void:
	var arrays := mesh.get_mesh_arrays()
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var base := _verts.size()
	var nbasis := xform.basis.inverse().transposed()
	var c := Color(color.r, color.g, color.b, snow)
	var e := Vector2(emission, float(material))
	for i in v.size():
		_verts.append(xform * v[i])
		_normals.append((nbasis * n[i]).normalized())
		_colors.append(c)
		_uv2.append(e)
	if idx.is_empty():
		for i in v.size():
			_indices.append(base + i)
	else:
		for i in idx:
			_indices.append(base + i)


func is_empty() -> bool:
	return _verts.is_empty()


func commit() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TEX_UV2] = _uv2
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	if not _verts.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
