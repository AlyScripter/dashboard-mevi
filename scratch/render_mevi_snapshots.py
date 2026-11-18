import numpy as np
from PIL import Image, ImageDraw
import math
import time

def render_model():
    print("Loading mevi3d.obj...")
    t0 = time.time()
    verts = []
    faces = []
    face_colors = []

    mat_colors = {
        '202,209,238': (195, 205, 225), # tinted glass
        '76,76,76': (80, 82, 88),       # dark grey roof/trim
        '255,255,255': (248, 250, 252), # clean white body
        '81,63,53': (70, 65, 60),       # interior
        '25,25,25': (30, 32, 35),       # black tires & bumper
        '202,209,237': (185, 195, 215), # side windows
        '127,127,127': (170, 175, 185), # metallic wheels / accents
        '177,24,24': (235, 35, 45),     # bright red tail light brackets
    }

    cur_col = (240, 240, 240)
    with open('assets/mevi3d.obj', 'r') as f:
        for line in f:
            if line.startswith('v '):
                p = line.split()
                verts.append([float(p[1]), float(p[2]), float(p[3])])
            elif line.startswith('usemtl '):
                m = line.split()[1]
                cur_col = mat_colors.get(m, (240, 240, 240))
            elif line.startswith('f '):
                p = line.split()[1:]
                idx = [int(x.split('/')[0]) - 1 for x in p]
                if len(idx) == 3:
                    faces.append(idx)
                    face_colors.append(cur_col)
                elif len(idx) == 4:
                    faces.append([idx[0], idx[1], idx[2]])
                    faces.append([idx[0], idx[2], idx[3]])
                    face_colors.append(cur_col)
                    face_colors.append(cur_col)

    V = np.array(verts, dtype=np.float32)
    F = np.array(faces, dtype=np.int32)
    C = np.array(face_colors, dtype=np.float32)
    print(f"Loaded {len(V)} vertices, {len(F)} faces in {time.time()-t0:.2f}s")

    # Center model
    # X: center around 0
    # Y: ground at 0 (shift Y so min is 0)
    # Z: center around 0
    center_x = 0.0
    min_y = V[:, 1].min()
    center_z = (V[:, 2].min() + V[:, 2].max()) / 2.0 # ~403

    V[:, 0] -= center_x
    V[:, 1] -= min_y
    V[:, 2] -= center_z

    # Model dimensions
    # Width ~1026, Height ~1523, Length ~1511
    # Scale to ~2.0 units height so it fits camera nicely
    scale = 2.0 / 1523.0
    V *= scale
    # Now model is roughly within [-0.7, 0.7] X, [0, 2.0] Y, [-1.0, 1.0] Z
    # Center target is (0, 0.9, 0)
    target = np.array([0.0, 0.9, 0.0], dtype=np.float32)

    def render_view(cam_pos, fov_deg, img_size=(512, 512), supersample=2):
        sw = img_size[0] * supersample
        sh = img_size[1] * supersample

        # Camera coordinate frame
        forward = target - cam_pos
        forward = forward / np.linalg.norm(forward)

        up_hint = np.array([0.0, 1.0, 0.0], dtype=np.float32)
        if abs(np.dot(forward, up_hint)) > 0.99:
            # If camera is looking straight down along Y, use Z as up hint
            # When looking down from above, Front (negative Z) should point UP on screen!
            up_hint = np.array([0.0, 0.0, -1.0], dtype=np.float32)

        right = np.cross(forward, up_hint)
        right = right / np.linalg.norm(right)
        up = np.cross(right, forward)
        up = up / np.linalg.norm(up)

        # Transform vertices to camera space
        # cam_x = dot(V - cam_pos, right)
        # cam_y = dot(V - cam_pos, up)
        # cam_z = dot(V - cam_pos, forward)
        diff = V - cam_pos
        cx = np.dot(diff, right)
        cy = np.dot(diff, up)
        cz = np.dot(diff, forward)

        # Perspective projection
        tan_half_fov = math.tan(math.radians(fov_deg / 2.0))
        # Screen normalized coordinates [-1, 1]
        nx = cx / (cz * tan_half_fov)
        ny = cy / (cz * tan_half_fov)

        # To pixel coordinates
        px = (nx * 0.5 + 0.5) * sw
        py = (-ny * 0.5 + 0.5) * sh

        # Face depths & normals
        p0 = V[F[:, 0]]
        p1 = V[F[:, 1]]
        p2 = V[F[:, 2]]
        e1 = p1 - p0
        e2 = p2 - p0
        normals = np.cross(e1, e2)
        norm_len = np.linalg.norm(normals, axis=1, keepdims=True)
        norm_len[norm_len < 1e-6] = 1.0
        normals /= norm_len

        # Backface culling: dot(normal, cam_pos - face_center) > 0
        face_centers = (p0 + p1 + p2) / 3.0
        to_cam = cam_pos - face_centers
        visible = np.sum(normals * to_cam, axis=1) > 0

        # Lighting (directional key light + ambient + fill)
        light_dir = np.array([0.3, 0.8, 0.5], dtype=np.float32)
        light_dir /= np.linalg.norm(light_dir)

        ndotl = np.clip(np.sum(normals * light_dir, axis=1), 0.0, 1.0)
        ambient = 0.45
        diffuse = 0.55 * ndotl
        shade = ambient + diffuse
        shade = shade[:, np.newaxis]

        shaded_colors = np.clip(C * shade, 0, 255).astype(np.uint8)

        # Z-depth for sorting
        face_cz = (cz[F[:, 0]] + cz[F[:, 1]] + cz[F[:, 2]]) / 3.0

        # Filter visible faces
        valid_indices = np.where(visible)[0]
        # Sort back to front (largest cz first)
        sort_order = valid_indices[np.argsort(-face_cz[valid_indices])]

        # Render onto RGBA canvas using rasterization
        # Using PIL ImageDraw for polygon drawing
        img = Image.new('RGBA', (sw, sh), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)

        f_p0 = F[sort_order, 0]
        f_p1 = F[sort_order, 1]
        f_p2 = F[sort_order, 2]

        x0, y0 = px[f_p0], py[f_p0]
        x1, y1 = px[f_p1], py[f_p1]
        x2, y2 = px[f_p2], py[f_p2]
        cols = shaded_colors[sort_order]

        for i in range(len(sort_order)):
            poly = [(x0[i], y0[i]), (x1[i], y1[i]), (x2[i], y2[i])]
            c = cols[i]
            draw.polygon(poly, fill=(int(c[0]), int(c[1]), int(c[2]), 255))

        # Downsample for antialiasing
        final_img = img.resize(img_size, Image.LANCZOS)
        return final_img

    print("Rendering Top-down LiDAR BEV view...")
    # Top-down: looking from above and slightly behind (polar angle 20 deg from zenith)
    # Target is (0, 0.9, 0)
    # Dist = 3.6
    polar = math.radians(20)
    # azimuth = 0 (behind: positive Z)
    cam_y = 0.9 + 3.8 * math.cos(polar)
    cam_z = 3.8 * math.sin(polar)
    cam_top = np.array([0.0, cam_y, cam_z], dtype=np.float32)
    img_top = render_view(cam_top, fov_deg=45, img_size=(512, 512))
    img_top.save('/tmp/mevi_topdown_test.png')
    print("Saved /tmp/mevi_topdown_test.png")

    print("Rendering Perspective BEV view...")
    # Perspective BEV: rear-top perspective (polar angle 50 deg from zenith, looking at back of car)
    polar_bev = math.radians(52)
    dist_bev = 3.4
    cam_y_bev = 0.9 + dist_bev * math.cos(polar_bev)
    cam_z_bev = dist_bev * math.sin(polar_bev)
    cam_bev = np.array([0.0, cam_y_bev, cam_z_bev], dtype=np.float32)
    img_bev = render_view(cam_bev, fov_deg=45, img_size=(512, 512))
    img_bev.save('/tmp/mevi_bev_test.png')
    print("Saved /tmp/mevi_bev_test.png")

if __name__ == '__main__':
    render_model()
