# MEVI Dashboard - Autonomous Electric Vehicle Telemetry & Control

[![Flutter](https://img.shields.io/badge/Flutter-3.8.1+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![ROS Noetic](https://img.shields.io/badge/ROS-Noetic-22314E?logo=ros&logoColor=white)](http://wiki.ros.org/noetic)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Windows%20%7C%20macOS%20%7C%20Android-informational)](https://flutter.dev/multi-platform)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Aplikasi dashboard modern berbasis **Flutter** untuk memantau telemetri *real-time*, visualisasi **Bird's Eye View (BEV) 3D**, *sensor fusion*, streaming kamera stereo, navigasi GPS otonom, dan antarmuka kontrol platform kendaraan listrik otonom **MEVI**.

<p align="center">
  <img src="docs/Tampilan%20Dashboard.png" alt="Tampilan MEVI Dashboard" width="100%">
</p>

---

## 📋 Daftar Isi

- [Fitur Utama & Modul Sistem](#-fitur-utama--modul-sistem)
- [Arsitektur Sistem & Alur Data](#-arsitektur-sistem--alur-data)
- [Daftar Topik ROS (Pub & Sub)](#-daftar-topik-ros-pub--sub)
- [Instalasi & Menjalankan](#-instalasi--menjalankan)
- [Mode Pengoperasian](#-mode-pengoperasian)
  - [1. Live Mode (Kendaraan Nyata)](#1-live-mode-kendaraan-nyata)
  - [2. Rosbag Mode (Playback Data Uji)](#2-rosbag-mode-playback-data-uji)
  - [3. Dummy / Simulation Mode](#3-dummy--simulation-mode)
- [Perekaman Data Sensor (CSV Recording)](#-perekaman-data-sensor-csv-recording)
- [Troubleshooting](#-troubleshooting)
- [Penulis & Lisensi](#-penulis--lisensi)

---

## ✨ Fitur Utama & Modul Sistem

| Modul | Deskripsi & Fungsionalitas |
| :--- | :--- |
| **BEV 3D & Point Cloud** | Visualisasi 3D kendaraan MEVI (`.glb`) dengan *local asset server* (Shelf), proyeksi lajur jalan (*road lanes*), lintasan *waypoints*, serta *bounding box* rintangan 3D dan *point cloud* LiDAR hasil *sensor fusion*. Dilengkapi konsol transmisi PRND, indikator baterai, dan panel lampu/hazard alert. |
| **Live Camera Feed** | Streaming video *real-time* kamera stereo **ZED 2i** (RGB & Depth) melalui HTTP MJPEG (`web_video_server` port 8080) dengan kontrol *stream selector* responsif. |
| **Navigasi GPS & Peta** | Peta interaktif berbasis OpenStreetMap/Google Maps dengan pencarian tujuan, *waypoint trajectory generation*, batas kecepatan operasional (20 km/jam) untuk estimasi waktu tempuh realistis, dan deteksi *destination reached*. |
| **Grafik Telemetri Real-Time** | Pemantauan grafik dinamis untuk Speedometer, Sudut Kemudi (*Steering Angle*), Cross-Track Error (CTE), Heading Error, Baterai, serta orientasi IMU 9-DoF (Roll, Pitch, Yaw) dengan *high-contrast tooltip*. |
| **Data Recording & Export** | Fitur perekaman telemetri berkala ke format **CSV** dengan mode Manual, Auto (Goal), atau Continuous dengan pilihan laju frekuensi (2 Hz hingga 20 Hz). |
| **Settings & Reconnect** | Pengaturan *data source* (Live / Rosbag / Simulator), konfigurasi alamat IP ROS Bridge (WebSocket port 9090) dan Camera Server (port 8080) dengan status koneksi interaktif dan tombol rekoneksi instan. |
| **Desain Modern & Responsif** | Tampilan bernuansa *tech blue* dan *clean slate white*, hierarki visual yang jelas, serta dukungan tema terang (*light mode*) dan gelap (*dark mode*). |

---

## 🏗️ Arsitektur Sistem & Alur Data

Sistem komunikasi dan pengolahan data terbagi menjadi 4 lapisan utama:

```
[1. MOBIL MEVI] ---> (topik ROS) ---> [Komputer Onboard Jetson AGX]
                                                │
                          ┌─────────────────────┴─────────────────────┐
                   (berkas rosbag)                              (topik citra)
                          │                                           │
                          ▼                                           ▼
            [2. PEMROSESAN DATA (Python)]               [Web Video Server (8080)]
            - Kalibrasi LiDAR-Kamera                                  │
            - YOLO-seg & Sensor Fusion                                │
            - Segmentasi LiDAR 3D                                     │
            - Payload BEV & Streaming JSON (roslibpy)                 │
                          │                                           │
                          ▼                                           │
              [Rosbridge Server (9090)]                               │
                          │ (WebSocket)                               │ (HTTP Stream)
                          ▼                                           ▼
            ┌───────────────────────────────────────────────────────────┐
            │               4. DASHBOARD APP (FLUTTER)                  │
            │  BEV 3D • Point Cloud • Peta & Navigasi • Grafik • Data   │
            └───────────────────────────────────────────────────────────┘
```

> 📐 **Diagram Vektor & Draw.io**:
> - File gambar arsitektur resolusi tinggi: [`docs/diagram_arsitektur_mevi.png`](docs/diagram_arsitektur_mevi.png)
> - File vektor SVG: [`docs/diagram_drawio_preview.svg`](docs/diagram_drawio_preview.svg)
> - File template Draw.io siap edit: [`docs/diagram_arsitektur_mevi.drawio`](docs/diagram_arsitektur_mevi.drawio)

### Rincian 4 Lapisan Arsitektur

1. **Mobil MEVI (Physical & Hardware Layer)**:
   - Terdiri dari sensor fisik: **LiDAR 3D**, **Kamera Stereo ZED 2i** (RGB + Depth), **IMU**, **RTK-GPS**, dan **Odometri**.
   - Data sensor diakuisisi oleh **NVIDIA Jetson AGX** dan direkam secara tersinkronisasi ke berkas `.bag` (*rosbag*).
2. **Pemrosesan Data (Python - Perception Layer)**:
   - **Ekstraksi & Sinkronisasi Rosbag**: Penyesuaian stempel waktu (*timestamps*) dan pembentukan *waypoint* koordinat *ego-frame*.
   - **Kalibrasi LiDAR–Kamera**: Proyeksi matriks ekstrinsik 3D-ke-2D dan intrinsik lensa.
   - **Deteksi Objek & Sensor Fusion**: Segmentasi *instance* rintangan menggunakan **YOLO-seg** dipadukan dengan citra RGB, *depth map*, dan *point cloud* LiDAR.
   - **Segmentasi LiDAR 3D**: Pemfilteran bidang tanah (*ground plane removal*) dan *clustering* rintangan geometris.
   - **Penyusunan Payload BEV & Streaming Frame**: Serialisasi data koordinat titik, *bounding box* rintangan, dan *waypoint* jalur ke format JSON via pustaka `roslibpy`.
3. **ROS1 Noetic Environment (Middleware / Bridge Layer)**:
   - **Rosbridge Server (WebSocket, port 9090)**: Menjembatani pertukaran data JSON dua arah antara ROS Noetic dan aplikasi Flutter.
   - **Web Video Server (HTTP, port 8080)**: Mengalirkan umpan video kamera ZED 2i berkecepatan tinggi dalam format MJPEG.
4. **Dashboard App (Flutter Application Layer)**:
   - Memproses data telemetri berkecepatan tinggi, merender animasi mobil MEVI dan lingkungan 3D, memplot rute perjalanan di peta, serta menampilkan visualisasi grafik performa.

---

## 📡 Daftar Topik ROS (Pub & Sub)

### 1. Topik yang Disubscribe (Data Masuk ke Dashboard)

| Kategori | Topik ROS | Tipe Data | Keterangan |
| :--- | :--- | :--- | :--- |
| **Posisi & Gerak** | `/latitude`, `/longitude` | `std_msgs/Float64` | Koordinat posisi GPS kendaraan |
| | `/velocity`, `/speedometer` | `std_msgs/Float32` | Kecepatan aktual kendaraan (m/s & km/h) |
| | `/sensor/imu`, `/imu`, `/0dataz` | `sensor_msgs/Imu` / `Float32` | Data orientasi (Yaw, Pitch, Roll) & akselerasi linier |
| **Kendali & Error** | `/steering_angle` | `std_msgs/Float32` | Sudut kemudi roda depan (derajat) |
| | `/cte` | `std_msgs/Float32` | *Cross-Track Error* terhadap jalur referensi (meter) |
| | `/heading_error` | `std_msgs/Float32` | Selisih sudut hadap kendaraan terhadap target (derajat) |
| **Status Kendaraan** | `/battery_percentage` | `std_msgs/Float32` | Indikator daya sisa baterai kendaraan (%) |
| | `/gear_state` | `std_msgs/String` | Status transmisi gigi (`P`, `R`, `N`, `D`) |
| **Sensor Lingkungan** | `/scan` | `sensor_msgs/LaserScan` | Data jarak pemindaian sensor LiDAR 2D |
| | `/velodyne_points` | `sensor_msgs/PointCloud2` | *Point cloud* 3D lingkungan sekitar |
| **Persepsi BEV 3D** | `/bev/points` | `std_msgs/String` (JSON) | Titik-titik *point cloud* terpilih untuk visualisasi |
| | `/bev/objects` | `std_msgs/String` (JSON) | Objek deteksi 3D (*bounding boxes*, label, posisi) |
| | `/bev/waypoints` | `std_msgs/String` (JSON) | Jalur lintasan navigasi kendaraan |
| | `/bev/lanes` | `std_msgs/String` (JSON) | Batas marka dan koridor lajur jalan |
| **Kontrol Keamanan (CBF)** | `/cbf/status`, `/cbf/barrier_value` | `std_msgs/String` / `Float32` | Status *Control Barrier Function* & nilai batas keselamatan |
| | `/navigation_status` | `std_msgs/String` (JSON) | Status eksekusi navigasi otonom |

### 2. Topik Kamera (HTTP Video Stream Port 8080)

| Topik Kamera | Tipe Data | Keterangan |
| :--- | :--- | :--- |
| `/zed2i/zed_node/left/image_rect_color` | `sensor_msgs/Image` | Umpan visual kamera depan ZED 2i warna terkalibrasi |
| `/camera/image_raw` | `sensor_msgs/Image` | *Fallback stream* citra kamera onboard |

### 3. Topik yang Dipublish (Perintah Keluar dari Dashboard)

| Topik ROS | Tipe Data | Keterangan |
| :--- | :--- | :--- |
| `/waypoints_array` | `std_msgs/String` (JSON) | Daftar koordinat *waypoint* rute tujuan dari peta |
| `/destination_coordinate` | `std_msgs/String` (JSON) | Titik koordinat target akhir navigasi |
| `/navigation_command` | `std_msgs/String` | Perintah operasional navigasi (`START`, `STOP`, `PAUSE`) |
| `/cbf/target_waypoint` | `geometry_msgs/Point` | Koordinat target langsung untuk kontroler CBF |
| `/cbf/emergency_stop` | `std_msgs/Bool` | Pemicu rem darurat manual (*Emergency E-Stop*) |
| `/vehicle/control_mode` | `std_msgs/String` | Pemilihan mode kendali (*Manual* / *Autonomous*) |
| `/vehicle/gear_command` | `std_msgs/String` | Perintah perpindahan gigi dari konsol UI (`P`, `R`, `N`, `D`) |

---

## 🚀 Instalasi & Menjalankan

### Prasyarat
- **Flutter SDK**: `>= 3.8.1`
- **Dart SDK**: `>= 3.8.1`
- **Docker & Docker Compose** (opsional, untuk simulasi dan *rosbag playback*)
- **ROS Noetic** (untuk integrasi langsung di lingkungan robotik Linux)

### Langkah Instalasi

```bash
# 1. Clone repository
git clone https://github.com/AlyScripter/dashboard-mevi.git
cd dashboard-mevi

# 2. Unduh paket dependensi
flutter pub get

# 3. Jalankan aplikasi pada platform target (contoh: Windows / Linux)
flutter run -d windows
# atau untuk Linux
flutter run -d linux
```

---

## 🎮 Mode Pengoperasian

Aplikasi mendukung 3 mode pengoperasian yang dapat dipilih melalui menu **Settings**:

### 1. Live Mode (Kendaraan Nyata)
Digunakan saat pengujian langsung pada mobil MEVI di lapangan.
- Hubungkan laptop/perangkat dashboard ke jaringan Wi-Fi kendaraan.
- Masukkan IP Jetson onboard pada menu **Settings** (contoh: `192.168.1.100`).
- Port default: `9090` (WebSocket) dan `8080` (HTTP Video Server).
- Klik tombol **Reconnect / Connect**.

### 2. Rosbag Mode (Playback Data Uji)
Digunakan untuk pengujian algoritma dan simulasi tanpa memerlukan kendaraan fisik.
- Masuk ke direktori deployment:
  ```bash
  cd deployment
  ./start_rosbag.sh
  ```
- Di dashboard menu **Settings**, atur host ke `localhost` atau `127.0.0.1` port `9090`.
- Data pergerakan sensor, video kamera, dan pembacaan telemetri akan dimainkan ulang secara otomatis.

### 3. Dummy / Simulation Mode
Digunakan saat pengembangan antarmuka antarmuka UI tanpa koneksi ke jaringan ROS.
- Jalankan script simulator:
  ```bash
  python3 deployment/simulator/test.py
  ```
- Dashboard juga memiliki mekanisme *fallback* data dummy internal untuk pengujian tata letak komponen visual.

---

## 📊 Perekaman Data Sensor (CSV Recording)

Fitur recording memungkinkan pengguna mengumpulkan dan mengekspor seluruh rekaman telemetri kendaraan ke berkas `.csv`:

1. Buka halaman menu **Data**.
2. Pada panel atas, tentukan mode perekaman:
   - **Manual**: Mulai dan berhenti melalui tombol *Record*.
   - **Auto (Goal)**: Otomatis merekam saat navigasi menuju tujuan aktif dan berhenti saat mencapai tujuan.
   - **Continuous**: Merekam terus-menerus selama terhubung ke jembatan ROS.
3. Atur frekuensi *sampling rate* (2 Hz, 4 Hz, 10 Hz, atau 20 Hz).
4. Klik tombol **🔴 Record** untuk memulai.
5. Klik **⏹️ Stop** saat selesai. Berkas otomatis tersimpan di:
   - **Windows**: `C:\Users\[User]\Documents\MEVI_Recordings\`
   - **Linux**: `~/Documents/MEVI_Recordings/`
   - **Android**: `/storage/emulated/0/Android/data/.../MEVI_Recordings/`

---

## 🛠️ Troubleshooting

| Gejala Masalah | Penyebab Umum | Langkah Solusi |
| :--- | :--- | :--- |
| **WebSocket gagal terhubung** | IP tidak cocok atau service Rosbridge belum aktif | Pastikan node `rosbridge_websocket` berjalan pada port 9090 (`roslaunch rosbridge_server rosbridge_websocket.launch`). Periksa koneksi IP dan firewall. |
| **Video kamera tidak muncul** | `web_video_server` belum berjalan | Jalankan `rosrun web_video_server web_video_server` di terminal Jetson/host pada port 8080 dan pastikan topik kamera aktif. |
| **Model 3D MEVI blank di Windows** | Pembatasan akses `file://` di Chromium | Aplikasi sudah dilengkapi server internal *Shelf* (`LocalAssetServerService`) di port lokal. Pastikan port lokal tidak terblokir antivirus. |
| **GPS tidak bergerak di peta** | Node sensor GPS belum mempublikasikan koordinat | Periksa apakah topik `/latitude` dan `/longitude` mengirimkan data melalui perintah `rostopic echo /latitude`. |

---

## 👨‍💻 Penulis & Lisensi

- **Author**: **Muhammad Haidar Aly**
- **GitHub**: [@AlyScripter](https://github.com/AlyScripter)
- **LinkedIn**: [Muhammad Haidar Aly](https://linkedin.com/in/muhammad-haidar-aly)
- **Instagram**: [@alyyyys_](https://instagram.com/alyyyys_)
- **Repository**: [https://github.com/AlyScripter/dashboard-mevi](https://github.com/AlyScripter/dashboard-mevi)

[![GitHub](https://img.shields.io/badge/GitHub-AlyScripter-181717?logo=github&logoColor=white)](https://github.com/AlyScripter)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Muhammad_Haidar_Aly-0A66C2?logo=linkedin&logoColor=white)](https://linkedin.com/in/muhammad-haidar-aly)
[![Instagram](https://img.shields.io/badge/Instagram-@alyyyys__-E4405F?logo=instagram&logoColor=white)](https://instagram.com/alyyyys_)

Proyek ini dilisensikan di bawah perlindungan lisensi **[MIT License](LICENSE)**.
