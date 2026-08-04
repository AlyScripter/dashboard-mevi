# Modul Data

Modul ini menampilkan halaman visualisasi data sensor dan telemetri kendaraan MEVI.

## Struktur Folder

```
data/
├── data_page.dart           # Halaman utama dengan PageView
├── data_index.dart          # Barrel export file
├── models/                  # Model data
├── utils/                   # Fungsi pembantu
└── widgets/                 # Komponen UI
    ├── charts/              # Grafik real-time
    ├── sensors/             # Visualisasi sensor
    ├── navigation/          # Widget trajectory
    ├── control/             # Kontrol kendaraan
    ├── status/              # Status sistem
    └── ui/                  # Komponen UI umum
```

---

## File Utama

### `data_page.dart`
Halaman utama dengan 4 tab yang bisa di-swipe:
1. **Lidar Visualization** - Visualisasi radar 2D
2. **Steering & CTE Analysis** - Grafik sudut kemudi dan error tracking
3. **Trajectory Planning** - Peta trajectory waypoint
4. **Control System** - Grafik kecepatan dan IMU

---

## Daftar Widget

### Folder `charts/`

| Widget | Fungsi |
|--------|--------|
| `cte_chart.dart` | Grafik Cross-Track Error (jarak dari jalur ideal) |
| `steering_angle_chart.dart` | Grafik sudut kemudi real-time |
| `speed_chart.dart` | Grafik kecepatan kendaraan |
| `imu_chart.dart` | Grafik data IMU (akselerasi, kecepatan sudut) |
| `lidar_graph_widget.dart` | Line chart jarak lidar per sudut |
| `ultrasonic_graph_widget.dart` | Grafik sensor ultrasonik |
| `chart_container.dart` | Container wrapper untuk semua chart |

### Folder `sensors/`

| Widget | Fungsi |
|--------|--------|
| `enhanced_lidar_visualization.dart` | Visualisasi radar 360° dengan mode tampilan |
| `lidar_painters.dart` | Custom painters untuk render lidar |
| `sensor_status_row.dart` | Baris status sensor (connected/disconnected) |

### Folder `navigation/`

| Widget | Fungsi |
|--------|--------|
| `simple_trajectory_widget.dart` | Menampilkan waypoint & jalur yang direncanakan |

### Folder `ui/`

| Widget | Fungsi |
|--------|--------|
| `data_page_header.dart` | Header dengan tombol recording dan judul halaman |

---

## Topic ROS yang Digunakan

| Topic | Tipe | Fungsi |
|-------|------|--------|
| `/scan` | sensor_msgs/LaserScan | Data lidar 2D Hokuyo |
| `/velodyne_points` | sensor_msgs/PointCloud2 | Data lidar 3D Velodyne |
| `/steering_angle` | Float32 | Sudut kemudi saat ini |
| `/cte` | Float32 | Cross-Track Error |
| `/velocity` | Float32 | Kecepatan kendaraan |
| `/sensor/imu` | sensor_msgs/Imu | Data IMU |
| `/ultrasonic_data` | Float64 | Jarak sensor ultrasonik |

---

## Cara Penggunaan

```dart
DataPage()  // Langsung panggil tanpa parameter
```

Widget ini otomatis terhubung ke ROS dan menampilkan data real-time.

---

## Fitur Utama

- **PageView Swipeable**: 4 halaman dengan gesture swipe
- **Recording Data**: Tombol record untuk menyimpan data ke CSV
- **Real-time Charts**: Grafik yang update live dari ROS
- **Lidar Visualization**: Radar 360° dengan multiple view modes
- **Responsive Design**: Menyesuaikan ukuran layar (tablet/laptop)
