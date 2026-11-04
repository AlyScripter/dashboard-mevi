"""
Generates lib/services/adas_mesh_service.dart with pre-compiled 3D mesh tables
for Car (SUV from assets/3d/Suv Mobil/), Motorcycle (assets/3d/motorcycle/), Pedestrian (assets/3d/Pedestrian/), Bicycle, and Truck.
"""
import os
import sys
import math
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_suv_mesh import generate_suv_mesh
from generate_motorcycle_mesh import generate_motorcycle_mesh
from generate_pedestrian_mesh import generate_pedestrian_mesh

def parse_obj(filepath):
    verts = []
    faces = []
    with open(filepath, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if parts[0] == "v":
                verts.append([float(parts[1]), float(parts[2]), float(parts[3])])
            elif parts[0] == "f":
                f_idx = []
                for p in parts[1:]:
                    idx = int(p.split("/")[0]) - 1
                    f_idx.append(idx)
                faces.append(f_idx)
    return verts, faces

def calc_normal(p0, p1, p2):
    ax, ay, az = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
    bx, by, bz = p2[0] - p0[0], p2[1] - p0[1], p2[2] - p0[2]
    nx = ay * bz - az * by
    ny = az * bx - ax * bz
    nz = ax * by - ay * bx
    l = math.sqrt(nx*nx + ny*ny + nz*nz)
    if l < 1e-6:
        return (0.0, 1.0, 0.0)
    return (nx / l, ny / l, nz / l)

def generate_dart_mesh_service():
    suv_verts, suv_faces = generate_suv_mesh()
    moto_verts, moto_faces = generate_motorcycle_mesh()
    ped_verts, ped_faces = generate_pedestrian_mesh()

    other_models = {
        "truck": "assets/models/adas/truck.obj",
        "bicycle": "assets/models/adas/bicycle.obj",
    }

    dart = []
    dart.append("// GENERATED ADAS 3.0 STUDIO CLAY 3D MESH SERVICE -- ZERO LATENCY, 60 FPS")
    dart.append("// Upgraded with authentic high-fidelity SUV, Motorcycle, and Pedestrian models from assets/3d/.")
    dart.append("import 'dart:typed_data';")
    dart.append("import '../ui/core/widgets/sensors/models/detected_3d_object.dart';")
    dart.append("")
    dart.append("class AdasMeshFace {")
    dart.append("  final List<int> indices;")
    dart.append("  final double nx, ny, nz;")
    dart.append("  final bool isGlass;")
    dart.append("  final bool isWheel;")
    dart.append("  final bool isLightAccent;")
    dart.append("  final int matId;")
    dart.append("")
    dart.append("  const AdasMeshFace({")
    dart.append("    required this.indices,")
    dart.append("    required this.nx,")
    dart.append("    required this.ny,")
    dart.append("    required this.nz,")
    dart.append("    this.isGlass = false,")
    dart.append("    this.isWheel = false,")
    dart.append("    this.isLightAccent = false,")
    dart.append("    this.matId = 0,")
    dart.append("  });")
    dart.append("}")
    dart.append("")
    dart.append("class AdasMeshData {")
    dart.append("  final Float32List vertices; // [x, y, z, x, y, z, ...]")
    dart.append("  final List<AdasMeshFace> faces;")
    dart.append("")
    dart.append("  const AdasMeshData({")
    dart.append("    required this.vertices,")
    dart.append("    required this.faces,")
    dart.append("  });")
    dart.append("}")
    dart.append("")
    dart.append("class AdasMeshService {")
    dart.append("  AdasMeshService._();")
    dart.append("")

    # --- SUV CAR MESH ---
    dart.append(f"  // ==========================================================================")
    dart.append(f"  // CAR / SUV MESH DATA ({len(suv_verts)} vertices, {len(suv_faces)} faces)")
    dart.append(f"  // High-fidelity mesh matching assets/3d/Suv Mobil/suv_model_gray_lite.obj")
    dart.append(f"  // ==========================================================================")
    v_str = ", ".join([f"{coord:.4f}" for v in suv_verts for coord in v])
    dart.append(f"  static final Float32List _carVertices = Float32List.fromList([")
    dart.append(f"    {v_str}")
    dart.append("  ]);")
    dart.append("")

    dart.append(f"  static final List<AdasMeshFace> _carFaces = [")
    for f in suv_faces:
        indices_str = ", ".join(map(str, f['indices']))
        props = []
        if f['isGlass']: props.append("isGlass: true")
        if f['isWheel']: props.append("isWheel: true")
        if f['isLightAccent']: props.append("isLightAccent: true")
        if f.get('matId', 0) != 0: props.append(f"matId: {f['matId']}")
        extra = (", " + ", ".join(props)) if props else ""
        dart.append(f"    AdasMeshFace(indices: [{indices_str}], nx: {f['nx']:.3f}, ny: {f['ny']:.3f}, nz: {f['nz']:.3f}{extra}),")
    dart.append("  ];")
    dart.append("")
    dart.append(f"  static final AdasMeshData carMesh = AdasMeshData(")
    dart.append(f"    vertices: _carVertices,")
    dart.append(f"    faces: _carFaces,")
    dart.append("  );")
    dart.append("")

    # --- MOTORCYCLE MESH ---
    dart.append(f"  // ==========================================================================")
    dart.append(f"  // MOTORCYCLE MESH DATA ({len(moto_verts)} vertices, {len(moto_faces)} faces)")
    dart.append(f"  // High-fidelity mesh matching assets/3d/motorcycle/motorcycle_model_gray_lite.obj")
    dart.append(f"  // ==========================================================================")
    moto_v_str = ", ".join([f"{coord:.4f}" for v in moto_verts for coord in v])
    dart.append(f"  static final Float32List _motorcycleVertices = Float32List.fromList([")
    dart.append(f"    {moto_v_str}")
    dart.append("  ]);")
    dart.append("")

    dart.append(f"  static final List<AdasMeshFace> _motorcycleFaces = [")
    for f in moto_faces:
        indices_str = ", ".join(map(str, f['indices']))
        props = []
        if f['isGlass']: props.append("isGlass: true")
        if f['isWheel']: props.append("isWheel: true")
        if f['isLightAccent']: props.append("isLightAccent: true")
        if f.get('matId', 0) != 0: props.append(f"matId: {f['matId']}")
        extra = (", " + ", ".join(props)) if props else ""
        dart.append(f"    AdasMeshFace(indices: [{indices_str}], nx: {f['nx']:.3f}, ny: {f['ny']:.3f}, nz: {f['nz']:.3f}{extra}),")
    dart.append("  ];")
    dart.append("")
    dart.append(f"  static final AdasMeshData motorcycleMesh = AdasMeshData(")
    dart.append(f"    vertices: _motorcycleVertices,")
    dart.append(f"    faces: _motorcycleFaces,")
    dart.append("  );")
    dart.append("")

    # --- PEDESTRIAN MESH ---
    dart.append(f"  // ==========================================================================")
    dart.append(f"  // PEDESTRIAN MESH DATA ({len(ped_verts)} vertices, {len(ped_faces)} faces)")
    dart.append(f"  // High-fidelity mesh matching assets/3d/Pedestrian/pedestrian_model_gray_lite.obj")
    dart.append(f"  // ==========================================================================")
    ped_v_str = ", ".join([f"{coord:.4f}" for v in ped_verts for coord in v])
    dart.append(f"  static final Float32List _pedestrianVertices = Float32List.fromList([")
    dart.append(f"    {ped_v_str}")
    dart.append("  ]);")
    dart.append("")

    dart.append(f"  static final List<AdasMeshFace> _pedestrianFaces = [")
    for f in ped_faces:
        indices_str = ", ".join(map(str, f['indices']))
        props = []
        if f.get('matId', 0) != 0: props.append(f"matId: {f['matId']}")
        extra = (", " + ", ".join(props)) if props else ""
        dart.append(f"    AdasMeshFace(indices: [{indices_str}], nx: {f['nx']:.3f}, ny: {f['ny']:.3f}, nz: {f['nz']:.3f}{extra}),")
    dart.append("  ];")
    dart.append("")
    dart.append(f"  static final AdasMeshData pedestrianMesh = AdasMeshData(")
    dart.append(f"    vertices: _pedestrianVertices,")
    dart.append(f"    faces: _pedestrianFaces,")
    dart.append("  );")
    dart.append("")

    # --- OTHER MODELS ---
    for name, path in other_models.items():
        verts, faces = parse_obj(path)
        dart.append(f"  // ==========================================================================")
        dart.append(f"  // {name.upper()} MESH DATA ({len(verts)} vertices, {len(faces)} faces)")
        dart.append(f"  // ==========================================================================")
        
        v_str = ", ".join([f"{coord:.4f}" for v in verts for coord in v])
        dart.append(f"  static final Float32List _{name}Vertices = Float32List.fromList([")
        dart.append(f"    {v_str}")
        dart.append("  ]);")
        dart.append("")

        dart.append(f"  static final List<AdasMeshFace> _{name}Faces = [")
        for f in faces:
            p0 = verts[f[0]]
            p1 = verts[f[1]]
            p2 = verts[f[2]] if len(f) > 2 else verts[f[0]]
            nx, ny, nz = calc_normal(p0, p1, p2)
            
            is_wheel = False
            is_glass = False
            is_light = False

            avg_y = sum(verts[i][1] for i in f) / len(f)
            avg_z = sum(verts[i][2] for i in f) / len(f)

            if name == "truck":
                if max(f) < 144:
                    is_wheel = True
                elif 0.50 < avg_y < 0.90 and avg_z > 0.16:
                    is_glass = True
            elif name == "bicycle":
                if max(f) < 48:
                    is_wheel = True

            indices_str = ", ".join(map(str, f))
            props = []
            if is_glass: props.append("isGlass: true")
            if is_wheel: props.append("isWheel: true")
            if is_light: props.append("isLightAccent: true")
            extra = (", " + ", ".join(props)) if props else ""

            dart.append(f"    AdasMeshFace(indices: [{indices_str}], nx: {nx:.3f}, ny: {ny:.3f}, nz: {nz:.3f}{extra}),")
        dart.append("  ];")
        dart.append("")
        dart.append(f"  static final AdasMeshData {name}Mesh = AdasMeshData(")
        dart.append(f"    vertices: _{name}Vertices,")
        dart.append(f"    faces: _{name}Faces,")
        dart.append("  );")
        dart.append("")

    dart.append("  static AdasMeshData getMeshForClass(Detected3DClass cls) {")
    dart.append("    switch (cls) {")
    dart.append("      case Detected3DClass.car:")
    dart.append("        return carMesh;")
    dart.append("      case Detected3DClass.motorcycle:")
    dart.append("        return motorcycleMesh;")
    dart.append("      case Detected3DClass.pedestrian:")
    dart.append("        return pedestrianMesh;")
    dart.append("      case Detected3DClass.truck:")
    dart.append("        return truckMesh;")
    dart.append("      case Detected3DClass.bicycle:")
    dart.append("        return bicycleMesh;")
    dart.append("      default:")
    dart.append("        return carMesh;")
    dart.append("    }")
    dart.append("  }")
    dart.append("}")
    dart.append("")

    content = "\n".join(dart)
    out_file = "lib/services/adas_mesh_service.dart"
    with open(out_file, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Generated {out_file}: {len(content)} bytes")

if __name__ == '__main__':
    generate_dart_mesh_service()
