#!/usr/bin/env python3
"""
MEVI VIRTUAL MOCK VEHICLE SERVER (ROS Bridge WebSocket Emulator)
-----------------------------------------------------------------
Emulator mandiri untuk testing MEVI Dashboard tanpa mobil fisik / tanpa ROS Noetic.
Menggunakan 100% library standar Python (Zero dependencies, tanpa pip install).

Fitur:
1. Meniru WebSocket ROS Bridge pada ws://0.0.0.0:9090
2. Membuat status koneksi di menu Settings Dashboard langsung HIJAU "Connected".
3. Mengirimkan posisi GPS awal mobil (area BRIN Cisitu Lama, Bandung).
4. Menangkap perintah "Mulai Perjalanan" saat user memilih destinasi di halaman Peta.
5. Mensimulasikan pergerakan mobil secara halus (smooth movement) menyusuri rute jalan
   sampai tiba di tujuan dan memunculkan notifikasi "Sampai Tujuan".
"""

import sys
import socket
import threading
import time
import json
import math
import struct
import base64
import hashlib
import functools

print = functools.partial(print, flush=True)

HOST = "0.0.0.0"
PORT = 9090

# Titik awal posisi mobil di BRIN Cisitu Lama (depan Gedung Basic 2 BRIN)
DEFAULT_START_LAT = -6.88248358
DEFAULT_START_LON = 107.61073832

# Sample route cadangan (jika dashboard mengirim tujuan tanpa daftar waypoint)
DEFAULT_ROUTE = [
    (-6.88248358, 107.61073832),
    (-6.88243801, 107.61075495),
    (-6.88241414, 107.61078367),
    (-6.88240763, 107.61082751),
    (-6.88240980, 107.61088042),
    (-6.88241631, 107.61093484),
    (-6.88242065, 107.61100136),
    (-6.88241631, 107.61103915),
    (-6.88239895, 107.61106636),
    (-6.88237725, 107.61108450),
    (-6.88235121, 107.61109509),
    (-6.88229696, 107.61110265),
    (-6.88220148, 107.61111172),
    (-6.88200618, 107.61113137),
    (-6.88180003, 107.61115404),
    (-6.88160039, 107.61117521),
    (-6.88140508, 107.61119788),
    (-6.88133130, 107.61120695),
    (-6.88127488, 107.61123870),
    (-6.88126186, 107.61128556),
    (-6.88126620, 107.61133243),
    (-6.88128139, 107.61146546),
    (-6.88129658, 107.61160152),
    (-6.88130526, 107.61169676),
    (-6.88133564, 107.61173908),
    (-6.88137470, 107.61174816),
]


class MockVehicleState:
    def __init__(self):
        self.lock = threading.Lock()
        self.current_lat = DEFAULT_START_LAT
        self.current_lon = DEFAULT_START_LON
        self.target_lat = None
        self.target_lon = None
        self.speed_kmh = 0.0
        self.yaw_deg = 0.0
        self.navigating = False
        self.waypoints = []
        self.current_wp_idx = 0
        self.clients = set()

    def set_start_location(self, lat, lon):
        with self.lock:
            self.current_lat = lat
            self.current_lon = lon

    def set_waypoints(self, wps):
        with self.lock:
            self.waypoints = wps
            self.current_wp_idx = 0
            if wps:
                print(f"📍 [SIMULATOR] Menerima {len(wps)} waypoints rute navigasi dari Dashboard!")

    def start_navigation(self):
        with self.lock:
            self.navigating = True
            self.speed_kmh = 20.0  # Kecepatan simulasi 20 km/jam saat bergerak
            if not self.waypoints:
                if self.target_lat is not None and self.target_lon is not None:
                    self.waypoints = [
                        {"latitude": self.current_lat, "longitude": self.current_lon},
                        {"latitude": self.target_lat, "longitude": self.target_lon},
                    ]
                else:
                    self.waypoints = [{"latitude": lat, "longitude": lon} for lat, lon in DEFAULT_ROUTE]
                self.current_wp_idx = 0
            print(f"🚀 [SIMULATOR] Perjalanan DIMULAI! Mobil virtual melaju menyusuri {len(self.waypoints)} waypoints...")

    def stop_navigation(self):
        with self.lock:
            self.navigating = False
            self.speed_kmh = 0.0
            print("⏹️ [SIMULATOR] Perjalanan DIHENTIKAN.")


state = MockVehicleState()


def compute_bearing(lat1, lon1, lat2, lon2):
    """Hitung sudut rotasi arah hadap mobil (heading / yaw) dalam derajat"""
    y = math.sin(math.radians(lon2 - lon1)) * math.cos(math.radians(lat2))
    x = math.cos(math.radians(lat1)) * math.sin(math.radians(lat2)) - math.sin(
        math.radians(lat1)
    ) * math.cos(math.radians(lat2)) * math.cos(math.radians(lon2 - lon1))
    bearing = (math.degrees(math.atan2(y, x)) + 360) % 360
    return bearing


def encode_ws_frame(message: str) -> bytes:
    """Encode string JSON menjadi RFC 6455 WebSocket Text Frame (Unmasked dari Server)"""
    payload = message.encode("utf-8")
    length = len(payload)
    if length <= 125:
        header = bytes([0x81, length])
    elif length <= 65535:
        header = struct.pack("!BBH", 0x81, 126, length)
    else:
        header = struct.pack("!BBQ", 0x81, 127, length)
    return header + payload


def decode_ws_frame(data: bytes):
    """Decode RFC 6455 WebSocket Frame dari Client (Masked)"""
    if len(data) < 2:
        return None, 0
    opcode = data[0] & 0x0F
    masked = (data[1] & 0x80) != 0
    payload_len = data[1] & 0x7F

    offset = 2
    if payload_len == 126:
        if len(data) < 4:
            return None, 0
        payload_len = struct.unpack("!H", data[2:4])[0]
        offset = 4
    elif payload_len == 127:
        if len(data) < 10:
            return None, 0
        payload_len = struct.unpack("!Q", data[2:10])[0]
        offset = 10

    if masked:
        if len(data) < offset + 4 + payload_len:
            return None, 0
        mask_key = data[offset : offset + 4]
        offset += 4
        raw_payload = data[offset : offset + payload_len]
        decoded = bytes([b ^ mask_key[i % 4] for i, b in enumerate(raw_payload)])
    else:
        if len(data) < offset + payload_len:
            return None, 0
        decoded = data[offset : offset + payload_len]

    total_consumed = offset + payload_len
    return (opcode, decoded), total_consumed


def broadcast_ros_msg(topic: str, msg_type: str, data_val):
    """Kirim pesan standar ROS Bridge ke seluruh client dashboard yang terhubung"""
    if isinstance(data_val, dict):
        payload = {"op": "publish", "topic": topic, "msg": data_val}
    else:
        payload = {"op": "publish", "topic": topic, "msg": {"data": data_val}}

    frame = encode_ws_frame(json.dumps(payload))
    with state.lock:
        dead_clients = []
        for client in list(state.clients):
            try:
                client.sendall(frame)
            except Exception:
                dead_clients.append(client)
        for dc in dead_clients:
            state.clients.discard(dc)


def handle_client_message(msg_str: str):
    """Parsing perintah yang dikirim dari Flutter Dashboard (TripService / Settings)"""
    try:
        obj = json.loads(msg_str)
        op = obj.get("op")
        topic = obj.get("topic")

        if op == "publish":
            msg = obj.get("msg", {})

            # 1. Menangkap waypoints rute yang dipilih pengguna di Peta
            if topic == "/waypoints_array":
                raw_data = msg.get("data")
                if isinstance(raw_data, str):
                    try:
                        raw_data = json.loads(raw_data)
                    except Exception:
                        pass
                if isinstance(raw_data, list):
                    state.set_waypoints(raw_data)

            # 2. Menangkap koordinat tujuan
            elif topic == "/destination_coordinate":
                raw_data = msg.get("data")
                if isinstance(raw_data, str):
                    try:
                        raw_data = json.loads(raw_data)
                    except Exception:
                        pass
                if isinstance(raw_data, dict):
                    state.target_lat = raw_data.get("y") or raw_data.get("lat")
                    state.target_lon = raw_data.get("x") or raw_data.get("lon")
                elif isinstance(msg, dict):
                    state.target_lat = msg.get("y") or msg.get("lat") or msg.get("x")
                    state.target_lon = msg.get("x") or msg.get("lon") or msg.get("y")
                print(f"🎯 [SIMULATOR] Destinasi tujuan terdaftar: ({state.target_lat}, {state.target_lon})")

            elif topic == "/destination_lat":
                state.target_lat = msg.get("data")
                print(f"🎯 [SIMULATOR] Destinasi Lat: {state.target_lat}")

            elif topic == "/destination_lon":
                state.target_lon = msg.get("data")
                print(f"🎯 [SIMULATOR] Destinasi Lon: {state.target_lon}")

            # 3. Menangkap perintah navigasi ('start' / 'stop')
            elif topic == "/navigation_command":
                cmd = str(msg.get("data", "")).strip().lower()
                if cmd == "start":
                    state.start_navigation()
                elif cmd == "stop":
                    state.stop_navigation()

    except Exception as e:
        print(f"⚠️ [SIMULATOR] Gagal parse pesan: {e}")


def client_thread(conn, addr):
    """Menangani koneksi satu client WebSocket Dashboard"""
    print(f"🟢 [SIMULATOR] Dashboard TERHUBUNG dari {addr[0]}:{addr[1]}")
    with state.lock:
        state.clients.add(conn)

    # 1. Lakukan HTTP Handshake WebSocket RFC 6455
    buffer = b""
    try:
        while b"\r\n\r\n" not in buffer:
            chunk = conn.recv(1024)
            if not chunk:
                return
            buffer += chunk

        req_str = buffer.decode("utf-8", errors="ignore")
        headers = {}
        for line in req_str.split("\r\n")[1:]:
            if ":" in line:
                k, v = line.split(":", 1)
                headers[k.strip().lower()] = v.strip()

        sec_key = headers.get("sec-websocket-key")
        if not sec_key:
            conn.close()
            return

        guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        accept_key = base64.b64encode(hashlib.sha1((sec_key + guid).encode()).digest()).decode()

        response = (
            "HTTP/1.1 101 Switching Protocols\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Accept: {accept_key}\r\n\r\n"
        )
        conn.sendall(response.encode())
        print(f"🤝 [SIMULATOR] Handshake WebSocket Sukses! Status di Settings Dashboard berubah HIJAU.")

        # 2. Kirim status awal ke dashboard seketika
        init_lat = state.current_lat
        init_lon = state.current_lon
        broadcast_ros_msg("/latitude", "std_msgs/Float64", init_lat)
        broadcast_ros_msg("/longitude", "std_msgs/Float64", init_lon)
        broadcast_ros_msg("/velocity", "std_msgs/Float32", 0.0)
        broadcast_ros_msg("/yaw", "std_msgs/Float32", state.yaw_deg)
        broadcast_ros_msg("/navigation_status", "std_msgs/String", "idle")

        # 3. Loop mendengarkan pesan dari Dashboard
        recv_buf = b""
        while True:
            chunk = conn.recv(4096)
            if not chunk:
                break
            recv_buf += chunk

            while True:
                res, consumed = decode_ws_frame(recv_buf)
                if res is None:
                    break
                recv_buf = recv_buf[consumed:]
                opcode, payload_bytes = res
                if opcode == 0x8:  # Close frame
                    return
                elif opcode == 0x9:  # Ping -> balas Pong
                    conn.sendall(bytes([0x8A, 0x00]))
                elif opcode == 0x1:  # Text frame
                    text = payload_bytes.decode("utf-8", errors="ignore")
                    handle_client_message(text)

    except Exception as e:
        print(f"ℹ️ [SIMULATOR] Client disconnected ({e})")
    finally:
        with state.lock:
            state.clients.discard(conn)
        conn.close()


def simulation_vehicle_loop():
    """
    Loop simulasi pergerakan mobil secara real-time pada 10 Hz (tiap 100ms).
    Mobil meluncur mulus dari titik awal menyusuri waypoints ke lokasi tujuan.
    """
    # Kecepatan simulasi: ~5.5 m/s (~20 km/jam), per tick 100ms bergerak ~0.55m
    STEP_METERS = 0.55

    while True:
        time.sleep(0.1)  # 10 Hz

        with state.lock:
            is_nav = state.navigating
            wps = list(state.waypoints)
            wp_idx = state.current_wp_idx
            cur_lat = state.current_lat
            cur_lon = state.current_lon
            cur_yaw = state.yaw_deg
            cur_speed = state.speed_kmh

        if is_nav and wps and wp_idx < len(wps):
            target_wp = wps[wp_idx]
            t_lat = target_wp.get("latitude", cur_lat)
            t_lon = target_wp.get("longitude", cur_lon)

            # Hitung jarak meter dengan proyeksi datar sederhana (1 derajat lat ~ 111.000 meter)
            dy = (t_lat - cur_lat) * 111000.0
            dx = (t_lon - cur_lon) * (111000.0 * math.cos(math.radians(cur_lat)))
            dist_m = math.sqrt(dx * dx + dy * dy)

            if dist_m < 2.5:  # Waypoint tercapai jika jarak < 2.5 meter
                wp_idx += 1
                with state.lock:
                    state.current_wp_idx = wp_idx
                    if wp_idx >= len(wps):
                        state.navigating = False
                        state.speed_kmh = 0.0
                        print("🏁 [SIMULATOR] SAMPAI TUJUAN! Seluruh waypoints telah selesai dilewati.")
                        broadcast_ros_msg("/navigation_status", "std_msgs/String", "completed")
                        broadcast_ros_msg("/trip_status", "std_msgs/String", "reached")
                    else:
                        wp_name = wps[wp_idx].get("name", f"WP-{wp_idx+1}")
                        print(f"➡️ [SIMULATOR] Melewati WP {wp_idx}/{len(wps)}: Menuju {wp_name}")
            else:
                # Bergerak maju ke arah waypoint berikutnya
                ratio = min(STEP_METERS, dist_m) / dist_m
                cur_lat += (t_lat - cur_lat) * ratio
                cur_lon += (t_lon - cur_lon) * ratio
                cur_yaw = compute_bearing(cur_lat, cur_lon, t_lat, t_lon)
                cur_speed = 20.0

                with state.lock:
                    state.current_lat = cur_lat
                    state.current_lon = cur_lon
                    state.yaw_deg = cur_yaw
                    state.speed_kmh = cur_speed

        # Broadcast telemetri ke Dashboard secara berkala
        # 1. GPS Latitude & Longitude (menggerakkan mobil di peta secara mulus)
        broadcast_ros_msg("/latitude", "std_msgs/Float64", cur_lat)
        broadcast_ros_msg("/longitude", "std_msgs/Float64", cur_lon)

        # 2. Speedometer (kecepatan dalam m/s sesuai parser ros_service)
        speed_ms = (cur_speed * 1000.0) / 3600.0
        broadcast_ros_msg("/velocity", "std_msgs/Float32", speed_ms)

        # 3. Orientasi Heading / Yaw
        broadcast_ros_msg("/yaw", "std_msgs/Float32", cur_yaw)

        # 4. Status Navigasi & Jarak
        nav_status = "navigating" if is_nav else "idle"
        broadcast_ros_msg("/navigation_status", "std_msgs/String", nav_status)
        broadcast_ros_msg("/wp_index", "std_msgs/Float32", float(wp_idx))


def start_server():
    print("=" * 65)
    print("🚗 MEVI VIRTUAL MOCK VEHICLE SERVER (ROS Bridge 9090 Emulator)")
    print("=" * 65)
    print(f"📡 Mendengarkan WebSocket pada ws://0.0.0.0:{PORT}")
    print("💡 CARA PENGGUNAAN:")
    print("   1. Biarkan skrip ini tetap berjalan di terminal.")
    print("   2. Jalankan Dashboard Flutter ('flutter run').")
    print("   3. Di Dashboard, buka menu Settings -> pilih 'Live (Vehicle Stream)'.")
    print("   4. Di Quick Presets klik 'Local (localhost)' -> Tekan 'Save & Apply'.")
    print("      -> Status koneksi akan langsung berubah HIJAU 'Connected'!")
    print("   5. Buka halaman Peta -> Pilih tujuan di list -> Klik 'Mulai Perjalanan'.")
    print("      -> Mobil virtual akan berjalan mulus sampai tujuan di peta!")
    print("=" * 65)

    # Jalankan loop simulasi di background thread
    sim_th = threading.Thread(target=simulation_vehicle_loop, daemon=True)
    sim_th.start()

    # Buat TCP Server socket untuk WebSocket
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen(5)

    try:
        while True:
            conn, addr = server.accept()
            t = threading.Thread(target=client_thread, args=(conn, addr), daemon=True)
            t.start()
    except KeyboardInterrupt:
        print("\n🛑 Mock Server dihentikan.")
    finally:
        server.close()


if __name__ == "__main__":
    start_server()
