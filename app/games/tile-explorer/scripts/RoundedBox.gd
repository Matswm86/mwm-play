extends RefCounted
class_name TeRoundedBox

# Procedural rounded-box ArrayMesh generator. Used for tiles, tray base and
# table top — no external 3D assets. Normals are computed analytically from
# the rounding sphere so even a coarse grid shades perfectly smooth.


# size: full extents. radius: corner rounding. divs: grid divisions per face edge.
static func build(size: Vector3, radius: float, divs: int = 8) -> ArrayMesh:
	var half: Vector3 = size * 0.5
	var r: float = min(radius, min(half.x, min(half.y, half.z)))
	var inner: Vector3 = half - Vector3(r, r, r)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 6 faces: +X -X +Y -Y +Z -Z. Each face is a (divs x divs) grid of quads
	# on the unit cube, mapped onto the rounded box.
	var faces: Array = [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
		[Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		[Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)],
		[Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)],
	]
	for f in faces:
		var normal: Vector3 = f[0]
		var up: Vector3 = f[1]
		var right: Vector3 = f[2]
		for i in divs:
			for j in divs:
				var u0: float = float(i) / float(divs) * 2.0 - 1.0
				var u1: float = float(i + 1) / float(divs) * 2.0 - 1.0
				var v0: float = float(j) / float(divs) * 2.0 - 1.0
				var v1: float = float(j + 1) / float(divs) * 2.0 - 1.0
				var p00: Vector3 = normal + right * u0 + up * v0
				var p10: Vector3 = normal + right * u1 + up * v0
				var p11: Vector3 = normal + right * u1 + up * v1
				var p01: Vector3 = normal + right * u0 + up * v1
				_emit_tri(st, p00, p10, p11, half, inner, r)
				_emit_tri(st, p00, p11, p01, half, inner, r)
	st.index()
	return st.commit()


static func _emit_tri(
	st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, half: Vector3, inner: Vector3, r: float
) -> void:
	for p in [a, b, c]:
		var q: Vector3 = p * half
		var cl := Vector3(
			clampf(q.x, -inner.x, inner.x),
			clampf(q.y, -inner.y, inner.y),
			clampf(q.z, -inner.z, inner.z)
		)
		var d: Vector3 = q - cl
		var n: Vector3 = d.normalized() if d.length() > 0.0001 else (p * half).normalized()
		st.set_normal(n)
		st.add_vertex(cl + n * r)
