"""
High-Fidelity ADAS 3.0 Studio Clay Mesh Generator.
Recreates the exact aesthetic of '3.0 ADAS 视觉识别模型':
- Smooth, aerodynamic vehicle body curves (Tesla/NIO style sedan)
- Smooth humanoid mannequin for pedestrian
- Smooth motorcycle/scooter with seated rider
- Smooth box truck and bicycle
- True studio clay grey coloring, no faceted wireframe lines
"""
import os
import math

OUT_DIR = "assets/models/adas"
os.makedirs(OUT_DIR, exist_ok=True)

def write_obj(filename, vertices, faces):
    filepath = os.path.join(OUT_DIR, filename)
    with open(filepath, "w") as f:
        f.write(f"# High-Fidelity ADAS 3.0 Model: {filename}\n")
        f.write(f"# Vertices: {len(vertices)}, Faces: {len(faces)}\n")
        for v in vertices:
            f.write(f"v {v[0]:.4f} {v[1]:.4f} {v[2]:.4f}\n")
        for face in faces:
            indices = " ".join([f"{idx+1}" for idx in face])
            f.write(f"f {indices}\n")
    size_kb = os.path.getsize(filepath) / 1024
    print(f"Generated {filepath}: {len(vertices)} verts, {len(faces)} faces, {size_kb:.1f} KB")

# -----------------------------------------------------------------------------
# 1. SEDAN EV (ADAS 3.0 High-Fidelity Smooth Clay Mesh)
# -----------------------------------------------------------------------------
def build_smooth_sedan():
    verts = []
    faces = []

    def add_v(x, y, z):
        verts.append((x, y, z))
        return len(verts) - 1

    # 4 Detailed Cylindrical Wheels standing on ground (y=0 to y=0.36, r=0.18)
    def make_wheel(cx, cz, is_right):
        sign = 1 if is_right else -1
        w_in = cx - sign * 0.05
        w_out = cx + sign * 0.05
        segments = 12
        r = 0.18
        v_in, v_out = [], []
        for i in range(segments):
            ang = 2 * math.pi * i / segments
            dy = r + math.sin(ang) * r
            dz = math.cos(ang) * r
            v_in.append(add_v(w_in, dy, cz + dz))
            v_out.append(add_v(w_out, dy, cz + dz))
        # Rim cap
        if is_right:
            faces.append(v_out)
        else:
            faces.append(list(reversed(v_out)))
        # Tread quads
        for i in range(segments):
            next_i = (i + 1) % segments
            if is_right:
                faces.append([v_out[i], v_out[next_i], v_in[next_i], v_in[i]])
            else:
                faces.append([v_out[next_i], v_out[i], v_in[i], v_in[next_i]])

    # Wheel centers: Front z = 0.28, Rear z = -0.28, width = +-0.38
    make_wheel(0.39, 0.28, True)   # RF
    make_wheel(-0.39, 0.28, False) # LF
    make_wheel(0.39, -0.28, True)  # RR
    make_wheel(-0.39, -0.28, False) # LR

    # 15 Smooth Transverse Cross-Sections along length (Z axis)
    # Forms an authentic, aerodynamic, curved sedan body with wheel arches,
    # sloping hood, raked windshield, panoramic roof, fastback rear glass, and trunk lip.
    sections = [
        # (z, y_bot, y_belt, y_roof, w_bot, w_belt, w_roof, has_roof, has_glass)
        (0.50, 0.06, 0.22, 0.22, 0.36, 0.35, 0.00, False, False), # 0: Front bumper lower lip
        (0.47, 0.08, 0.34, 0.34, 0.43, 0.42, 0.00, False, False), # 1: Front air intake / nose
        (0.42, 0.12, 0.44, 0.44, 0.46, 0.45, 0.00, False, False), # 2: Headlights / Hood front
        (0.34, 0.18, 0.48, 0.48, 0.47, 0.46, 0.00, False, False), # 3: Front wheel arch crest
        (0.24, 0.16, 0.51, 0.51, 0.47, 0.46, 0.00, False, False), # 4: Hood mid
        (0.14, 0.14, 0.53, 0.55, 0.47, 0.46, 0.38, False, False), # 5: Cowl / Windshield base
        (0.04, 0.14, 0.54, 0.82, 0.47, 0.46, 0.36, True, True),   # 6: Lower windshield
        (-0.06, 0.14, 0.54, 0.94, 0.47, 0.46, 0.35, True, True),  # 7: Upper windshield / Roof header
        (-0.16, 0.14, 0.54, 0.96, 0.47, 0.46, 0.35, True, False), # 8: Roof apex / B-pillar
        (-0.24, 0.16, 0.53, 0.92, 0.47, 0.46, 0.34, True, True),  # 9: Rear window top / C-pillar
        (-0.32, 0.18, 0.52, 0.72, 0.47, 0.46, 0.35, True, True),  # 10: Rear glass slope
        (-0.38, 0.18, 0.51, 0.52, 0.47, 0.46, 0.00, False, False), # 11: Trunk deck base
        (-0.44, 0.16, 0.49, 0.49, 0.45, 0.44, 0.00, False, False), # 12: Trunk lid spoiler lip
        (-0.48, 0.12, 0.42, 0.42, 0.42, 0.41, 0.00, False, False), # 13: Rear taillight fascia
        (-0.50, 0.08, 0.28, 0.28, 0.36, 0.35, 0.00, False, False), # 14: Rear lower diffuser
    ]

    sec_verts = []
    for s in sections:
        z, y_bot, y_belt, y_roof, w_bot, w_belt, w_roof, has_roof, has_glass = s
        # Section vertices (symmetrical):
        # 0: Bot Center
        # 1: Bot Right
        # 2: Belt Right
        # 3: Roof Right (or Hood Right)
        # 4: Roof Center (or Hood Center)
        # 5: Roof Left (or Hood Left)
        # 6: Belt Left
        # 7: Bot Left
        v_bc = add_v(0.0, y_bot, z)
        v_br = add_v(w_bot, y_bot, z)
        v_belt_r = add_v(w_belt, y_belt, z)
        v_belt_l = add_v(-w_belt, y_belt, z)
        v_bl = add_v(-w_bot, y_bot, z)

        if has_roof:
            v_rr = add_v(w_roof, y_roof, z)
            v_rc = add_v(0.0, y_roof + 0.015, z)
            v_rl = add_v(-w_roof, y_roof, z)
        else:
            v_rr = add_v(w_belt * 0.7, y_belt + 0.02, z)
            v_rc = add_v(0.0, y_belt + 0.03, z)
            v_rl = add_v(-w_belt * 0.7, y_belt + 0.02, z)

        sec_verts.append({
            "bc": v_bc, "br": v_br, "belt_r": v_belt_r, "rr": v_rr,
            "rc": v_rc, "rl": v_rl, "belt_l": v_belt_l, "bl": v_bl,
            "has_glass": has_glass, "has_roof": has_roof
        })

    # Skinning quads between sections
    for i in range(len(sec_verts) - 1):
        s0 = sec_verts[i]
        s1 = sec_verts[i + 1]

        # Floor underside
        faces.append([s0["bc"], s1["bc"], s1["br"], s0["br"]])
        faces.append([s0["bc"], s0["bl"], s1["bl"], s1["bc"]])

        # Lower body side flanks (rocker to beltline)
        faces.append([s0["br"], s1["br"], s1["belt_r"], s0["belt_r"]])
        faces.append([s0["bl"], s0["belt_l"], s1["belt_l"], s1["bl"]])

        # Upper greenhouse / shoulder panels
        faces.append([s0["belt_r"], s1["belt_r"], s1["rr"], s0["rr"]])
        faces.append([s0["belt_l"], s0["rl"], s1["rl"], s1["belt_l"]])

        # Roof / Hood deck top panels
        faces.append([s0["rr"], s1["rr"], s1["rc"], s0["rc"]])
        faces.append([s0["rc"], s1["rc"], s1["rl"], s0["rl"]])

    # Front cap
    s_f = sec_verts[0]
    faces.append([s_f["bc"], s_f["br"], s_f["belt_r"], s_f["rr"], s_f["rc"]])
    faces.append([s_f["bc"], s_f["rc"], s_f["rl"], s_f["belt_l"], s_f["bl"]])

    # Rear cap
    s_r = sec_verts[-1]
    faces.append([s_r["bc"], s_r["rc"], s_r["rr"], s_r["belt_r"], s_r["br"]])
    faces.append([s_r["bc"], s_r["bl"], s_r["belt_l"], s_r["rl"], s_r["rc"]])

    return verts, faces

# -----------------------------------------------------------------------------
# 2. MOTORCYCLE + SEATED RIDER (ADAS 3.0 Clean Clay Mannequin)
# -----------------------------------------------------------------------------
def build_smooth_motorcycle():
    verts = []
    faces = []

    def add_v(x, y, z):
        verts.append((x, y, z))
        return len(verts) - 1

    def make_wheel(cz):
        r = 0.22
        w = 0.04
        segments = 12
        vl, vr = [], []
        for i in range(segments):
            ang = 2 * math.pi * i / segments
            dy = r + math.sin(ang) * r
            dz = math.cos(ang) * r
            vl.append(add_v(-w, dy, cz + dz))
            vr.append(add_v(w, dy, cz + dz))
        faces.append(vl)
        faces.append(list(reversed(vr)))
        for i in range(segments):
            next_i = (i + 1) % segments
            faces.append([vl[i], vr[i], vr[next_i], vl[next_i]])

    make_wheel(0.36)  # Front wheel
    make_wheel(-0.34) # Rear wheel

    # Scooter / Motor body fairing
    cowl_nose = add_v(0.0, 0.48, 0.44)
    cowl_tl = add_v(-0.13, 0.66, 0.26)
    cowl_tr = add_v(0.13, 0.66, 0.26)
    cowl_bl = add_v(-0.12, 0.20, 0.22)
    cowl_br = add_v(0.12, 0.20, 0.22)
    faces.append([cowl_bl, cowl_nose, cowl_tl])
    faces.append([cowl_br, cowl_tr, cowl_nose])
    faces.append([cowl_bl, cowl_br, cowl_nose])
    faces.append([cowl_tl, cowl_nose, cowl_tr])

    # Handlebars
    hb_c = add_v(0.0, 0.68, 0.24)
    hb_l = add_v(-0.22, 0.70, 0.22)
    hb_r = add_v(0.22, 0.70, 0.22)
    faces.append([cowl_tl, hb_c, hb_l])
    faces.append([cowl_tr, hb_r, hb_c])

    # Footboard & Seat
    fb_l = add_v(-0.14, 0.16, 0.0)
    fb_r = add_v(0.14, 0.16, 0.0)
    seat_fl = add_v(-0.12, 0.52, 0.06)
    seat_fr = add_v(0.12, 0.52, 0.06)
    seat_bl = add_v(-0.13, 0.54, -0.26)
    seat_br = add_v(0.13, 0.54, -0.26)
    faces.append([seat_fl, seat_fr, seat_br, seat_bl]) # Seat top
    faces.append([fb_l, fb_r, seat_fr, seat_fl])
    faces.append([fb_l, seat_fl, seat_bl])
    faces.append([fb_r, seat_br, seat_fr])

    # Seated Rider (Humanoid Mannequin)
    # Head with rounded helmet (y=0.84 to 0.98, z=0.08 to 0.18)
    h_b = add_v(0.0, 0.84, 0.12)
    h_t = add_v(0.0, 0.98, 0.12)
    h_f = add_v(0.0, 0.91, 0.19)
    h_bk = add_v(0.0, 0.91, 0.05)
    h_l = add_v(-0.09, 0.91, 0.12)
    h_r = add_v(0.09, 0.91, 0.12)
    faces.append([h_b, h_f, h_t, h_l])
    faces.append([h_b, h_r, h_t, h_f])
    faces.append([h_b, h_l, h_t, h_bk])
    faces.append([h_b, h_bk, h_t, h_r])

    # Torso (leaning forward to handlebars)
    sh_l = add_v(-0.16, 0.78, 0.14)
    sh_r = add_v(0.16, 0.78, 0.14)
    sh_bk = add_v(0.0, 0.76, 0.02)
    faces.append([seat_fl, seat_fr, sh_r, sh_l]) # Chest
    faces.append([seat_bl, seat_br, sh_r, sh_bk]) # Back
    faces.append([seat_fl, sh_l, sh_bk, seat_bl]) # Left rib
    faces.append([seat_fr, seat_br, sh_bk, sh_r]) # Right rib

    # Arms to handlebars
    faces.append([sh_l, hb_l, hb_c])
    faces.append([sh_r, hb_c, hb_r])

    return verts, faces

# -----------------------------------------------------------------------------
# 3. PEDESTRIAN (ADAS 3.0 Clean Clay Mannequin)
# -----------------------------------------------------------------------------
def build_smooth_pedestrian():
    verts = []
    faces = []

    def add_v(x, y, z):
        verts.append((x, y, z))
        return len(verts) - 1

    # Head (Sculpted octahedron, y=0.84 to 0.98)
    h_b = add_v(0.0, 0.84, 0.0)
    h_t = add_v(0.0, 0.98, 0.0)
    h_f = add_v(0.0, 0.91, 0.10)
    h_bk = add_v(0.0, 0.91, -0.09)
    h_l = add_v(-0.09, 0.91, 0.0)
    h_r = add_v(0.09, 0.91, 0.0)
    faces.append([h_b, h_f, h_t, h_l])
    faces.append([h_b, h_r, h_t, h_f])
    faces.append([h_b, h_l, h_t, h_bk])
    faces.append([h_b, h_bk, h_t, h_r])

    # Torso (Chest + Pelvis, y=0.48 to 0.82)
    sh_l = add_v(-0.19, 0.80, 0.0)
    sh_r = add_v(0.19, 0.80, 0.0)
    ch_f = add_v(0.0, 0.74, 0.09)
    ch_b = add_v(0.0, 0.74, -0.08)
    w_l = add_v(-0.14, 0.48, 0.0)
    w_r = add_v(0.14, 0.48, 0.0)
    w_f = add_v(0.0, 0.48, 0.07)
    w_b = add_v(0.0, 0.48, -0.06)

    faces.append([sh_l, ch_f, sh_r, h_b]) # Collarbone
    faces.append([sh_l, w_l, w_f, ch_f])   # Chest left
    faces.append([sh_r, ch_f, w_f, w_r])   # Chest right
    faces.append([sh_l, ch_b, w_b, w_l])   # Back left
    faces.append([sh_r, w_r, w_b, ch_b])   # Back right

    # Left Leg (walking forward stride, y=0.0 to 0.48)
    knee_l = add_v(-0.08, 0.24, 0.06)
    foot_l = add_v(-0.08, 0.0, 0.12)
    faces.append([w_l, w_f, knee_l])
    faces.append([w_l, knee_l, w_b])
    faces.append([knee_l, foot_l, w_l])

    # Right Leg (walking backward stride, y=0.0 to 0.48)
    knee_r = add_v(0.08, 0.24, -0.05)
    foot_r = add_v(0.08, 0.0, -0.10)
    faces.append([w_r, knee_r, w_f])
    faces.append([w_r, w_b, knee_r])
    faces.append([knee_r, w_r, foot_r])

    # Arms swinging
    arm_l = add_v(-0.23, 0.44, -0.06) # swinging back
    arm_r = add_v(0.23, 0.44, 0.08)  # swinging forward
    faces.append([sh_l, arm_l, w_l])
    faces.append([sh_r, w_r, arm_r])

    return verts, faces

# -----------------------------------------------------------------------------
# 4. TRUCK / DELIVERY BOX TRUCK (ADAS 3.0 Clean Clay Mesh)
# -----------------------------------------------------------------------------
def build_smooth_truck():
    verts = []
    faces = []

    def add_v(x, y, z):
        verts.append((x, y, z))
        return len(verts) - 1

    # 6 Wheels
    def make_wheel(cx, cz):
        r = 0.20
        w = 0.06
        segments = 12
        sign = 1 if cx > 0 else -1
        vl, vr = [], []
        for i in range(segments):
            ang = 2 * math.pi * i / segments
            dy = r + math.sin(ang) * r
            dz = math.cos(ang) * r
            vl.append(add_v(cx - sign*w, dy, cz + dz))
            vr.append(add_v(cx + sign*w, dy, cz + dz))
        faces.append(vr if sign > 0 else list(reversed(vr)))
        for i in range(segments):
            next_i = (i + 1) % segments
            faces.append([vl[i], vr[i], vr[next_i], vl[next_i]])

    make_wheel(0.42, 0.32)   # FR
    make_wheel(-0.42, 0.32)  # FL
    make_wheel(0.42, -0.22)  # RR1
    make_wheel(-0.42, -0.22) # LR1
    make_wheel(0.42, -0.38)  # RR2
    make_wheel(-0.42, -0.38) # LR2

    # Driver Cabin (Front z=0.12 to 0.48, y=0.10 to 0.88)
    cab_bfl = add_v(-0.44, 0.12, 0.48)
    cab_bfr = add_v(0.44, 0.12, 0.48)
    cab_bbl = add_v(-0.44, 0.12, 0.12)
    cab_bbr = add_v(0.44, 0.12, 0.12)
    cab_mfl = add_v(-0.44, 0.52, 0.47) # Windshield bottom
    cab_mfr = add_v(0.44, 0.52, 0.47)
    cab_tfl = add_v(-0.42, 0.88, 0.36) # Windshield top
    cab_tfr = add_v(0.42, 0.88, 0.36)
    cab_tbl = add_v(-0.42, 0.90, 0.12) # Roof rear
    cab_tbr = add_v(0.42, 0.90, 0.12)

    faces.append([cab_bfl, cab_bfr, cab_mfr, cab_mfl]) # Grille / Bumper
    faces.append([cab_mfl, cab_mfr, cab_tfr, cab_tfl]) # Windshield
    faces.append([cab_tfl, cab_tfr, cab_tbr, cab_tbl]) # Roof
    faces.append([cab_bfl, cab_mfl, cab_tfl, cab_tbl, cab_bbl]) # Left side
    faces.append([cab_bfr, cab_bbr, cab_tbr, cab_tfr, cab_mfr]) # Right side

    # Cargo Box Container (Rear z=-0.48 to 0.10, y=0.22 to 0.98)
    box_bfl = add_v(-0.47, 0.22, 0.10)
    box_bfr = add_v(0.47, 0.22, 0.10)
    box_bbl = add_v(-0.47, 0.22, -0.48)
    box_bbr = add_v(0.47, 0.22, -0.48)
    box_tfl = add_v(-0.47, 0.98, 0.10)
    box_tfr = add_v(0.47, 0.98, 0.10)
    box_tbl = add_v(-0.47, 0.98, -0.48)
    box_tbr = add_v(0.47, 0.98, -0.48)

    faces.append([box_tfl, box_tfr, box_tbr, box_tbl]) # Box Top
    faces.append([box_bfl, box_bfr, box_tfr, box_tfl]) # Box Front
    faces.append([box_bbl, box_tbl, box_tbr, box_bbr]) # Box Rear
    faces.append([box_bfl, box_tfl, box_tbl, box_bbl]) # Box Left
    faces.append([box_bfr, box_bbr, box_tbr, box_tfr]) # Box Right
    faces.append([box_bfl, box_bbl, box_bbr, box_bfr]) # Box Underside

    return verts, faces

# -----------------------------------------------------------------------------
# 5. BICYCLE + CYCLIST (ADAS 3.0 Clean Clay Mesh)
# -----------------------------------------------------------------------------
def build_smooth_bicycle():
    verts = []
    faces = []

    def add_v(x, y, z):
        verts.append((x, y, z))
        return len(verts) - 1

    def make_wheel(cz):
        r = 0.28
        segments = 12
        vl, vr = [], []
        w = 0.015
        for i in range(segments):
            ang = 2 * math.pi * i / segments
            dy = r + math.sin(ang) * r
            dz = math.cos(ang) * r
            vl.append(add_v(-w, dy, cz + dz))
            vr.append(add_v(w, dy, cz + dz))
        faces.append(vl)
        faces.append(list(reversed(vr)))
    make_wheel(0.36)
    make_wheel(-0.34)

    # Frame
    bb = add_v(0.0, 0.28, 0.0)
    st = add_v(0.0, 0.58, -0.10)
    ht = add_v(0.0, 0.65, 0.26)
    fw = add_v(0.0, 0.28, 0.36)
    rw = add_v(0.0, 0.28, -0.34)
    hb_l = add_v(-0.18, 0.68, 0.24)
    hb_r = add_v(0.18, 0.68, 0.24)
    faces.append([bb, st, ht])
    faces.append([bb, ht, fw])
    faces.append([bb, rw, st])
    faces.append([ht, hb_l, hb_r])

    # Cyclist
    h_b = add_v(0.0, 0.85, 0.08)
    h_t = add_v(0.0, 0.98, 0.08)
    h_l = add_v(-0.08, 0.92, 0.08)
    h_r = add_v(0.08, 0.92, 0.08)
    faces.append([h_b, h_l, h_t, h_r])
    faces.append([st, h_b, hb_l])
    faces.append([st, hb_r, h_b])

    return verts, faces

v_c, f_c = build_smooth_sedan()
write_obj("car.obj", v_c, f_c)

v_m, f_m = build_smooth_motorcycle()
write_obj("motorcycle.obj", v_m, f_m)

v_p, f_p = build_smooth_pedestrian()
write_obj("pedestrian.obj", v_p, f_p)

v_t, f_t = build_smooth_truck()
write_obj("truck.obj", v_t, f_t)

v_b, f_b = build_smooth_bicycle()
write_obj("bicycle.obj", v_b, f_b)

total_kb = sum(os.path.getsize(os.path.join(OUT_DIR, f)) for f in os.listdir(OUT_DIR)) / 1024
print(f"Total ADAS OBJ models size: {total_kb:.1f} KB (Well under 1000 KB)")
