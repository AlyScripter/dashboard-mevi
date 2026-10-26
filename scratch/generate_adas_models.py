"""
Generator for ADAS 3.0 / Pony.ai style low-poly 3D models for BEV visualization.
Outputs lightweight .obj files (< 40 KB each) into assets/models/adas/.
"""
import os
import math

OUT_DIR = "assets/models/adas"
os.makedirs(OUT_DIR, exist_ok=True)

def write_obj(filename, vertices, faces, normals=None):
    filepath = os.path.join(OUT_DIR, filename)
    with open(filepath, "w") as f:
        f.write(f"# ADAS 3D Model: {filename}\n")
        f.write(f"# Vertices: {len(vertices)}, Faces: {len(faces)}\n")
        for v in vertices:
            f.write(f"v {v[0]:.4f} {v[1]:.4f} {v[2]:.4f}\n")
        if normals:
            for n in normals:
                f.write(f"vn {n[0]:.4f} {n[1]:.4f} {n[2]:.4f}\n")
            for face in faces:
                # 1-indexed
                indices = " ".join([f"{idx+1}//{idx+1}" for idx in face])
                f.write(f"f {indices}\n")
        else:
            for face in faces:
                indices = " ".join([f"{idx+1}" for idx in face])
                f.write(f"f {indices}\n")
    size_kb = os.path.getsize(filepath) / 1024
    print(f"Generated {filepath}: {len(vertices)} verts, {len(faces)} faces, {size_kb:.1f} KB")

# -----------------------------------------------------------------------------
# 1. CAR / SEDAN EV (ADAS 3.0 Sedan)
# Normalized bounding box:
# x: -0.5 to 0.5 (width)
# y: 0.0 to 1.0 (height, ground = 0)
# z: -0.5 to 0.5 (length, +z = front bumper, -z = rear bumper)
# -----------------------------------------------------------------------------
def build_car():
    verts = []
    faces = []

    def add_vert(x, y, z):
        verts.append((x, y, z))
        return len(verts) - 1

    # 4 Wheels (octagons)
    # Wheel params: r=0.18, ground tangent at y=0 => center y=0.18
    # Front axle z=0.28, rear axle z=-0.28
    # Left wheel x=-0.44 to -0.34, Right wheel x=0.34 to 0.44
    wheel_radii = 8
    def make_wheel(cx, cy, cz, width_sign):
        w_in = cx - width_sign * 0.06
        w_out = cx + width_sign * 0.06
        v_in = []
        v_out = []
        for i in range(wheel_radii):
            ang = 2 * math.pi * i / wheel_radii
            dy = math.sin(ang) * 0.17
            dz = math.cos(ang) * 0.17
            v_in.append(add_vert(w_in, cy + dy, cz + dz))
            v_out.append(add_vert(w_out, cy + dy, cz + dz))
        # Rim face
        faces.append(v_out)
        # Tread quads
        for i in range(wheel_radii):
            i_next = (i + 1) % wheel_radii
            if width_sign > 0:
                faces.append([v_out[i], v_out[i_next], v_in[i_next], v_in[i]])
            else:
                faces.append([v_out[i_next], v_out[i], v_in[i], v_in[i_next]])

    make_wheel(0.40, 0.18, 0.28, 1)   # Right front
    make_wheel(-0.40, 0.18, 0.28, -1)  # Left front
    make_wheel(0.40, 0.18, -0.28, 1)  # Right rear
    make_wheel(-0.40, 0.18, -0.28, -1) # Left rear

    # Car body key stations along Z
    # Station format: (z, y_bottom, y_belt, y_roof, w_bot, w_belt, w_roof)
    # +Z is front!
    stations = [
        # 0: Front bumper lower lip
        {"z": 0.50, "y_bot": 0.08, "y_hood": 0.22, "y_roof": 0.22, "w_bot": 0.38, "w_hood": 0.36, "w_roof": 0.0},
        # 1: Front grille / nose
        {"z": 0.46, "y_bot": 0.10, "y_hood": 0.38, "y_roof": 0.38, "w_bot": 0.44, "w_hood": 0.42, "w_roof": 0.0},
        # 2: Headlights / Front hood edge
        {"z": 0.38, "y_bot": 0.18, "y_hood": 0.45, "y_roof": 0.45, "w_bot": 0.46, "w_hood": 0.45, "w_roof": 0.0},
        # 3: Hood mid
        {"z": 0.24, "y_bot": 0.18, "y_hood": 0.50, "y_roof": 0.50, "w_bot": 0.46, "w_hood": 0.46, "w_roof": 0.0},
        # 4: Windshield base (cowl)
        {"z": 0.14, "y_bot": 0.14, "y_hood": 0.54, "y_roof": 0.54, "w_bot": 0.47, "w_hood": 0.47, "w_roof": 0.0},
        # 5: Windshield top (header / roof front)
        {"z": -0.04, "y_bot": 0.14, "y_hood": 0.55, "y_roof": 0.95, "w_bot": 0.47, "w_hood": 0.47, "w_roof": 0.36},
        # 6: Roof crown
        {"z": -0.16, "y_bot": 0.14, "y_hood": 0.55, "y_roof": 0.96, "w_bot": 0.47, "w_hood": 0.47, "w_roof": 0.36},
        # 7: Rear window top (header)
        {"z": -0.26, "y_bot": 0.18, "y_hood": 0.54, "y_roof": 0.92, "w_bot": 0.47, "w_hood": 0.47, "w_roof": 0.35},
        # 8: Rear window base (trunk deck front)
        {"z": -0.38, "y_bot": 0.18, "y_hood": 0.52, "y_roof": 0.52, "w_bot": 0.46, "w_hood": 0.46, "w_roof": 0.0},
        # 9: Trunk lip / taillights
        {"z": -0.47, "y_bot": 0.16, "y_hood": 0.48, "y_roof": 0.48, "w_bot": 0.44, "w_hood": 0.43, "w_roof": 0.0},
        # 10: Rear bumper lower diffuser
        {"z": -0.50, "y_bot": 0.12, "y_hood": 0.32, "y_roof": 0.32, "w_bot": 0.38, "w_hood": 0.38, "w_roof": 0.0},
    ]

    st_rings = []
    for s in stations:
        z = s["z"]
        # Vertices per station:
        # 0: bottom center
        # 1: bottom right
        # 2: belt/hood right
        # 3: roof right (if roof > hood)
        # 4: roof center (if roof > hood)
        # 5: roof left
        # 6: belt/hood left
        # 7: bottom left
        has_roof = s["w_roof"] > 0
        v_bc = add_vert(0.0, s["y_bot"], z)
        v_br = add_vert(s["w_bot"], s["y_bot"], z)
        v_hr = add_vert(s["w_hood"], s["y_hood"], z)
        v_hl = add_vert(-s["w_hood"], s["y_hood"], z)
        v_bl = add_vert(-s["w_bot"], s["y_bot"], z)

        if has_roof:
            v_rr = add_vert(s["w_roof"], s["y_roof"], z)
            v_rc = add_vert(0.0, s["y_roof"] + 0.02, z)
            v_rl = add_vert(-s["w_roof"], s["y_roof"], z)
            st_rings.append({
                "bc": v_bc, "br": v_br, "hr": v_hr, "rr": v_rr,
                "rc": v_rc, "rl": v_rl, "hl": v_hl, "bl": v_bl,
                "has_roof": True
            })
        else:
            v_hc = add_vert(0.0, s["y_hood"] + 0.02, z)
            st_rings.append({
                "bc": v_bc, "br": v_br, "hr": v_hr, "rr": v_hr,
                "rc": v_hc, "rl": v_hl, "hl": v_hl, "bl": v_bl,
                "has_roof": False
            })

    # Bridge between stations
    for i in range(len(st_rings) - 1):
        r0 = st_rings[i]
        r1 = st_rings[i + 1]

        # Bottom floor
        faces.append([r0["bc"], r1["bc"], r1["br"], r0["br"]])
        faces.append([r0["bc"], r0["bl"], r1["bl"], r1["bc"]])

        # Sides lower
        faces.append([r0["br"], r1["br"], r1["hr"], r0["hr"]])
        faces.append([r0["bl"], r0["hl"], r1["hl"], r1["bl"]])

        # Upper sides / Windows
        if r0["has_roof"] or r1["has_roof"]:
            faces.append([r0["hr"], r1["hr"], r1["rr"], r0["rr"]])
            faces.append([r0["hl"], r0["rl"], r1["rl"], r1["hl"]])
            # Roof panels
            faces.append([r0["rr"], r1["rr"], r1["rc"], r0["rc"]])
            faces.append([r0["rc"], r1["rc"], r1["rl"], r0["rl"]])
        else:
            # Hood / Trunk top panels
            faces.append([r0["hr"], r1["hr"], r1["rc"], r0["rc"]])
            faces.append([r0["rc"], r1["rc"], r1["hl"], r0["hl"]])

    # Front cap
    r_front = st_rings[0]
    faces.append([r_front["bc"], r_front["br"], r_front["hr"], r_front["rc"]])
    faces.append([r_front["bc"], r_front["rc"], r_front["hl"], r_front["bl"]])

    # Rear cap
    r_rear = st_rings[-1]
    faces.append([r_rear["bc"], r_rear["rc"], r_rear["hr"], r_rear["br"]])
    faces.append([r_rear["bc"], r_rear["bl"], r_rear["hl"], r_rear["rc"]])

    return verts, faces

# -----------------------------------------------------------------------------
# 2. MOTORCYCLE + SEATED RIDER (ADAS 3.0 Motor)
# -----------------------------------------------------------------------------
def build_motorcycle():
    verts = []
    faces = []

    def add_vert(x, y, z):
        verts.append((x, y, z))
        return len(verts) - 1

    # Wheels (Front at z=0.36, Rear at z=-0.34, r=0.22, y_center=0.22)
    def make_bike_wheel(cz):
        r = 0.22
        w = 0.05
        segments = 8
        v_l = []
        v_r = []
        for i in range(segments):
            ang = 2 * math.pi * i / segments
            dy = math.sin(ang) * r
            dz = math.cos(ang) * r
            v_l.append(add_vert(-w, 0.22 + dy, cz + dz))
            v_r.append(add_vert(w, 0.22 + dy, cz + dz))
        faces.append(v_l)
        faces.append(list(reversed(v_r)))
        for i in range(segments):
            i_next = (i + 1) % segments
            faces.append([v_l[i], v_r[i], v_r[i_next], v_l[i_next]])

    make_bike_wheel(0.36)  # Front wheel
    make_bike_wheel(-0.34) # Rear wheel

    # Scooter Chassis & Bodywork
    # Footboard
    fb_fl = add_vert(-0.16, 0.16, 0.18)
    fb_fr = add_vert(0.16, 0.16, 0.18)
    fb_bl = add_vert(-0.16, 0.16, -0.16)
    fb_br = add_vert(0.16, 0.16, -0.16)
    faces.append([fb_fl, fb_fr, fb_br, fb_bl])

    # Front cowl / shield
    cowl_tl = add_vert(-0.14, 0.65, 0.24)
    cowl_tr = add_vert(0.14, 0.65, 0.24)
    cowl_tip = add_vert(0.0, 0.50, 0.40)
    faces.append([fb_fl, cowl_tl, cowl_tr, fb_fr])
    faces.append([cowl_tl, cowl_tip, cowl_tr])

    # Handlebars
    hb_l = add_vert(-0.24, 0.70, 0.18)
    hb_r = add_vert(0.24, 0.70, 0.18)
    hb_c = add_vert(0.0, 0.68, 0.20)
    faces.append([hb_l, hb_c, cowl_tl])
    faces.append([hb_c, hb_r, cowl_tr])

    # Seat / Saddle
    seat_fl = add_vert(-0.12, 0.52, 0.05)
    seat_fr = add_vert(0.12, 0.52, 0.05)
    seat_bl = add_vert(-0.14, 0.54, -0.26)
    seat_br = add_vert(0.14, 0.54, -0.26)
    faces.append([seat_fl, seat_fr, seat_br, seat_bl])

    # Side panels
    faces.append([fb_fl, fb_bl, seat_bl, seat_fl])
    faces.append([fb_fr, seat_fr, seat_br, fb_br])

    # Seated Rider:
    # 1. Helmet (box sphere at top, y=0.84 to 0.98, z=0.04 to 0.18)
    h_bfl = add_vert(-0.09, 0.84, 0.18)
    h_bfr = add_vert(0.09, 0.84, 0.18)
    h_bbl = add_vert(-0.09, 0.84, 0.04)
    h_bbr = add_vert(0.09, 0.84, 0.04)
    h_tfl = add_vert(-0.08, 0.98, 0.16)
    h_tfr = add_vert(0.08, 0.98, 0.16)
    h_tbl = add_vert(-0.08, 0.98, 0.06)
    h_tbr = add_vert(0.08, 0.98, 0.06)
    faces.append([h_tfl, h_tfr, h_tbr, h_tbl]) # top
    faces.append([h_bfl, h_bfr, h_tfr, h_tfl]) # front
    faces.append([h_bfr, h_bbr, h_tbr, h_tfr]) # right
    faces.append([h_bbr, h_bbl, h_tbl, h_tbr]) # back
    faces.append([h_bbl, h_bfl, h_tfl, h_tbl]) # left

    # 2. Torso (leaning forward)
    t_fl = add_vert(-0.13, 0.54, 0.02)
    t_fr = add_vert(0.13, 0.54, 0.02)
    t_bl = add_vert(-0.13, 0.54, -0.14)
    t_br = add_vert(0.13, 0.54, -0.14)
    sh_fl = add_vert(-0.16, 0.78, 0.12)
    sh_fr = add_vert(0.16, 0.78, 0.12)
    sh_bl = add_vert(-0.15, 0.78, 0.0)
    sh_br = add_vert(0.15, 0.78, 0.0)
    faces.append([sh_fl, sh_fr, sh_br, sh_bl]) # shoulders
    faces.append([t_fl, t_fr, sh_fr, sh_fl])   # chest
    faces.append([t_bl, sh_bl, sh_br, t_br])   # back
    faces.append([t_fr, t_br, sh_br, sh_fr])   # right side
    faces.append([t_fl, sh_fl, sh_bl, t_bl])   # left side

    # 3. Arms (Shoulders to handlebars)
    faces.append([sh_fl, hb_l, hb_c, sh_bl])
    faces.append([sh_fr, sh_br, hb_c, hb_r])

    # 4. Legs (Hips to knees to footboard)
    knee_l = add_vert(-0.18, 0.40, 0.14)
    knee_r = add_vert(0.18, 0.40, 0.14)
    faces.append([t_fl, knee_l, fb_fl])
    faces.append([t_fr, fb_fr, knee_r])

    return verts, faces

# -----------------------------------------------------------------------------
# 3. PEDESTRIAN (Humanoid Walking/Standing)
# -----------------------------------------------------------------------------
def build_pedestrian():
    verts = []
    faces = []

    def add_vert(x, y, z):
        verts.append((x, y, z))
        return len(verts) - 1

    # Head (y=0.84 to 0.98)
    head_w = 0.10
    head_d = 0.11
    h_bfl = add_vert(-head_w, 0.84, head_d)
    h_bfr = add_vert(head_w, 0.84, head_d)
    h_bbl = add_vert(-head_w, 0.84, -head_d)
    h_bbr = add_vert(head_w, 0.84, -head_d)
    h_tfl = add_vert(-head_w*0.8, 0.98, head_d*0.8)
    h_tfr = add_vert(head_w*0.8, 0.98, head_d*0.8)
    h_tbl = add_vert(-head_w*0.8, 0.98, -head_d*0.8)
    h_tbr = add_vert(head_w*0.8, 0.98, -head_d*0.8)
    faces.append([h_tfl, h_tfr, h_tbr, h_tbl])
    faces.append([h_bfl, h_bfr, h_tfr, h_tfl])
    faces.append([h_bfr, h_bbr, h_tbr, h_tfr])
    faces.append([h_bbr, h_bbl, h_tbl, h_tbr])
    faces.append([h_bbl, h_bfl, h_tfl, h_tbl])

    # Torso (Chest + Waist, y=0.48 to 0.80)
    sh_w = 0.20
    sh_d = 0.12
    w_w = 0.15
    w_d = 0.10
    s_fl = add_vert(-sh_w, 0.80, sh_d)
    s_fr = add_vert(sh_w, 0.80, sh_d)
    s_bl = add_vert(-sh_w, 0.80, -sh_d)
    s_br = add_vert(sh_w, 0.80, -sh_d)
    w_fl = add_vert(-w_w, 0.48, w_d)
    w_fr = add_vert(w_w, 0.48, w_d)
    w_bl = add_vert(-w_w, 0.48, -w_d)
    w_br = add_vert(w_w, 0.48, -w_d)
    faces.append([s_fl, s_fr, s_br, s_bl]) # shoulders top
    faces.append([w_fl, w_fr, s_fr, s_fl]) # chest front
    faces.append([w_fr, w_br, s_br, s_fr]) # chest right
    faces.append([w_br, w_bl, s_bl, s_br]) # back
    faces.append([w_bl, w_fl, s_fl, s_bl]) # chest left

    # Left Leg (Forward stride: z forward to 0.12, foot at y=0)
    ll_tfl = add_vert(-0.14, 0.48, 0.08)
    ll_tfr = add_vert(-0.02, 0.48, 0.08)
    ll_tbl = add_vert(-0.14, 0.48, -0.06)
    ll_tbr = add_vert(-0.02, 0.48, -0.06)
    ll_bfl = add_vert(-0.13, 0.0, 0.14)
    ll_bfr = add_vert(-0.03, 0.0, 0.14)
    ll_bbl = add_vert(-0.13, 0.0, 0.02)
    ll_bbr = add_vert(-0.03, 0.0, 0.02)
    faces.append([ll_bfl, ll_bfr, ll_tfr, ll_tfl])
    faces.append([ll_bfr, ll_bbr, ll_tbr, ll_tfr])
    faces.append([ll_bbr, ll_bbl, ll_tbl, ll_tbr])
    faces.append([ll_bbl, ll_bfl, ll_tfl, ll_tbl])

    # Right Leg (Back stride: z backward to -0.12, foot at y=0)
    rl_tfl = add_vert(0.02, 0.48, 0.08)
    rl_tfr = add_vert(0.14, 0.48, 0.08)
    rl_tbl = add_vert(0.02, 0.48, -0.06)
    rl_tbr = add_vert(0.14, 0.48, -0.06)
    rl_bfl = add_vert(0.03, 0.0, -0.02)
    rl_bfr = add_vert(0.13, 0.0, -0.02)
    rl_bbl = add_vert(0.03, 0.0, -0.14)
    rl_bbr = add_vert(0.13, 0.0, -0.14)
    faces.append([rl_bfl, rl_bfr, rl_tfr, rl_tfl])
    faces.append([rl_bfr, rl_bbr, rl_tbr, rl_tfr])
    faces.append([rl_bbr, rl_bbl, rl_tbl, rl_tbr])
    faces.append([rl_bbl, rl_bfl, rl_tfl, rl_tbl])

    # Left Arm (Swing slightly back)
    la_bfl = add_vert(-0.25, 0.38, -0.06)
    la_bfr = add_vert(-0.19, 0.38, -0.06)
    la_bbl = add_vert(-0.25, 0.38, -0.14)
    la_bbr = add_vert(-0.19, 0.38, -0.14)
    faces.append([la_bfl, la_bfr, s_fl, s_bl])
    faces.append([la_bfr, la_bbr, s_bl, s_fl])

    # Right Arm (Swing slightly forward)
    ra_bfl = add_vert(0.19, 0.38, 0.14)
    ra_bfr = add_vert(0.25, 0.38, 0.14)
    ra_bbl = add_vert(0.19, 0.38, 0.06)
    ra_bbr = add_vert(0.25, 0.38, 0.06)
    faces.append([ra_bfl, ra_bfr, s_fr, s_br])
    faces.append([ra_bfr, ra_bbr, s_br, s_fr])

    return verts, faces

# -----------------------------------------------------------------------------
# 4. TRUCK (Box Truck / Cargo Carrier)
# -----------------------------------------------------------------------------
def build_truck():
    verts = []
    faces = []

    def add_vert(x, y, z):
        verts.append((x, y, z))
        return len(verts) - 1

    # 6 Wheels
    def make_truck_wheel(cx, cz):
        r = 0.20
        w = 0.07
        segments = 8
        sign = 1 if cx > 0 else -1
        w_in = cx - sign * w
        w_out = cx + sign * w
        v_in, v_out = [], []
        for i in range(segments):
            ang = 2 * math.pi * i / segments
            dy = math.sin(ang) * r
            dz = math.cos(ang) * r
            v_in.append(add_vert(w_in, 0.20 + dy, cz + dz))
            v_out.append(add_vert(w_out, 0.20 + dy, cz + dz))
        faces.append(v_out)
        for i in range(segments):
            i_next = (i + 1) % segments
            faces.append([v_out[i], v_out[i_next], v_in[i_next], v_in[i]])

    make_truck_wheel(0.42, 0.34)   # Front Right
    make_truck_wheel(-0.42, 0.34)  # Front Left
    make_truck_wheel(0.42, -0.22)  # Rear Axle 1 Right
    make_truck_wheel(-0.42, -0.22) # Rear Axle 1 Left
    make_truck_wheel(0.42, -0.38)  # Rear Axle 2 Right
    make_truck_wheel(-0.42, -0.38) # Rear Axle 2 Left

    # Driver Cabin (Front, z=0.15 to 0.48, y=0.14 to 0.85)
    c_bfl = add_vert(-0.45, 0.16, 0.48)
    c_bfr = add_vert(0.45, 0.16, 0.48)
    c_bbl = add_vert(-0.45, 0.16, 0.15)
    c_bbr = add_vert(0.45, 0.16, 0.15)
    c_tfl = add_vert(-0.43, 0.85, 0.38)
    c_tfr = add_vert(0.43, 0.85, 0.38)
    c_tbl = add_vert(-0.43, 0.88, 0.15)
    c_tbr = add_vert(0.43, 0.88, 0.15)

    # Windshield divider
    c_ws_l = add_vert(-0.44, 0.52, 0.47)
    c_ws_r = add_vert(0.44, 0.52, 0.47)

    faces.append([c_bfl, c_bfr, c_ws_r, c_ws_l]) # Lower grille / bumper
    faces.append([c_ws_l, c_ws_r, c_tfr, c_tfl]) # Windshield
    faces.append([c_tfl, c_tfr, c_tbr, c_tbl])   # Roof
    faces.append([c_bfl, c_tfl, c_tbl, c_bbl])   # Left side
    faces.append([c_bfr, c_bbr, c_tbr, c_tfr])   # Right side

    # Cargo Box (Rear, z=-0.48 to 0.14, y=0.25 to 0.98, full width x=-0.48 to 0.48)
    box_bfl = add_vert(-0.48, 0.25, 0.14)
    box_bfr = add_vert(0.48, 0.25, 0.14)
    box_bbl = add_vert(-0.48, 0.25, -0.48)
    box_bbr = add_vert(0.48, 0.25, -0.48)
    box_tfl = add_vert(-0.48, 0.98, 0.14)
    box_tfr = add_vert(0.48, 0.98, 0.14)
    box_tbl = add_vert(-0.48, 0.98, -0.48)
    box_tbr = add_vert(0.48, 0.98, -0.48)

    faces.append([box_tfl, box_tfr, box_tbr, box_tbl]) # Box Top
    faces.append([box_bfl, box_bfr, box_tfr, box_tfl]) # Box Front
    faces.append([box_bbl, box_tbl, box_tbr, box_bbr]) # Box Rear
    faces.append([box_bfl, box_tfl, box_tbl, box_bbl]) # Box Left
    faces.append([box_bfr, box_bbr, box_tbr, box_tfr]) # Box Right
    faces.append([box_bfl, box_bbl, box_bbr, box_bfr]) # Box Floor

    return verts, faces

# -----------------------------------------------------------------------------
# 5. BICYCLE + CYCLIST
# -----------------------------------------------------------------------------
def build_bicycle():
    verts = []
    faces = []

    def add_vert(x, y, z):
        verts.append((x, y, z))
        return len(verts) - 1

    # 2 Thin Wheels (r=0.28, z=0.36 and -0.34)
    def make_bike_wheel(cz):
        r = 0.28
        segments = 8
        v = []
        for i in range(segments):
            ang = 2 * math.pi * i / segments
            v.append(add_vert(0.0, 0.28 + math.sin(ang)*r, cz + math.cos(ang)*r))
        faces.append(v)
    make_bike_wheel(0.36)
    make_bike_wheel(-0.34)

    # Frame diamond
    bb = add_vert(0.0, 0.28, 0.0)      # Bottom bracket
    st = add_vert(0.0, 0.58, -0.10)    # Seat tube top
    ht = add_vert(0.0, 0.65, 0.26)     # Head tube
    fw = add_vert(0.0, 0.28, 0.36)     # Front hub
    rw = add_vert(0.0, 0.28, -0.34)    # Rear hub
    hb_l = add_vert(-0.18, 0.68, 0.24)
    hb_r = add_vert(0.18, 0.68, 0.24)

    faces.append([bb, st, ht])
    faces.append([bb, ht, fw])
    faces.append([bb, rw, st])
    faces.append([ht, hb_l, hb_r])

    # Cyclist (Torso + Helmet)
    h_b = add_vert(0.0, 0.85, 0.08)
    h_t = add_vert(0.0, 0.98, 0.08)
    h_l = add_vert(-0.08, 0.92, 0.08)
    h_r = add_vert(0.08, 0.92, 0.08)
    faces.append([h_b, h_l, h_t, h_r])
    faces.append([st, h_b, hb_l])
    faces.append([st, hb_r, h_b])

    return verts, faces

# Generate all models
v_car, f_car = build_car()
write_obj("car.obj", v_car, f_car)

v_moto, f_moto = build_motorcycle()
write_obj("motorcycle.obj", v_moto, f_moto)

v_ped, f_ped = build_pedestrian()
write_obj("pedestrian.obj", v_ped, f_ped)

v_truck, f_truck = build_truck()
write_obj("truck.obj", v_truck, f_truck)

v_bike, f_bike = build_bicycle()
write_obj("bicycle.obj", v_bike, f_bike)

total_kb = sum(os.path.getsize(os.path.join(OUT_DIR, f)) for f in os.listdir(OUT_DIR)) / 1024
print(f"\nSUCCESS! Total ADAS assets size: {total_kb:.1f} KB (Target < 1000 KB)")
