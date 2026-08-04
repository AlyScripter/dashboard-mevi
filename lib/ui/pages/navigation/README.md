# Modul Navigasi

Modul ini menangani semua fungsionalitas navigasi berbasis peta untuk dashboard MEVI.

## Struktur Folder

```
navigation/
├── navigation_page.dart      # Wrapper halaman dengan BlocProvider
├── navigation_widget.dart    # Widget utama navigasi (895 baris)
├── bloc/                     # State management
│   ├── navigation_cubit.dart
│   └── navigation_state.dart
├── widgets/                  # Komponen UI
├── utils/                    # Fungsi pembantu
└── services/                 # Service khusus navigasi
```

---

## File Utama

### `navigation_widget.dart`
Widget inti yang berisi semua logika navigasi:
- Integrasi stream GPS dari ROS (`/latitude`, `/longitude`)
- Perhitungan rute (internal & eksternal)
- Gesture peta (pan, rotate, zoom)
- Deteksi kedatangan otomatis
- Notifikasi dalam aplikasi

### `navigation_page.dart`
Wrapper sederhana yang menyediakan:
- `NavigationCubit` via `BlocProvider`
- Koordinat destinasi default
- Props callback untuk info rute

---

## Daftar Widget

| Widget | Fungsi |
|--------|--------|
| `map_view.dart` | Menampilkan peta Flutter Map dengan tile layer dan marker |
| `search_bar_widget.dart` | Input pencarian lokasi dengan autocomplete |
| `search_results_widget.dart` | Menampilkan hasil pencarian lokasi |
| `heading_hud.dart` | Menampilkan kompas arah heading kendaraan |
| `current_location_marker.dart` | Marker posisi kendaraan saat ini di peta |
| `destination_marker.dart` | Marker titik tujuan dengan animasi |
| `route_polyline.dart` | Garis rute dari posisi ke tujuan |
| `center_on_car_button.dart` | Tombol untuk memusatkan peta ke posisi kendaraan |
| `fit_route_button.dart` | Tombol untuk menyesuaikan zoom ke seluruh rute |
| `in_app_notification_widget.dart` | Menampilkan notifikasi popup di atas peta |
| `loading_indicator.dart` | Indikator loading saat menghitung rute |

---

## Detail Widget

### `map_view.dart`
Komponen peta menggunakan `flutter_map`:
- Menampilkan tile dari OpenStreetMap
- Mendukung gesture zoom, pan, dan rotasi
- Menampilkan semua marker dan polyline

### `search_bar_widget.dart`
Fitur pencarian lengkap:
- Autocomplete dari data lokal (GeoJSON)
- Pencarian online via Nominatim API
- Keyboard navigation support

### `heading_hud.dart`
Head-Up Display untuk orientasi:
- Menampilkan kompas digital
- Sinkron dengan yaw dari ROS (`/yaw`)
- Animasi rotasi halus

### `destination_marker.dart`
Marker interaktif untuk tujuan:
- Animasi pulse saat aktif
- Info popup dengan nama lokasi
- Drag-and-drop support

### `route_polyline.dart`
Visualisasi rute:
- Garis berwarna dengan gradien
- Animasi drawing effect
- Update real-time saat posisi berubah

### `in_app_notification_widget.dart`
Sistem notifikasi overlay:
- Tipe: info, success, warning, error
- Auto-dismiss dengan timer
- Animasi slide-in/out

---

## Topic ROS yang Digunakan

| Topic | Tipe | Fungsi |
|-------|------|--------|
| `/latitude` | Float64 | Latitude GPS saat ini |
| `/longitude` | Float64 | Longitude GPS saat ini |
| `/yaw` | Float32 | Heading/orientasi kendaraan |
| `/destination_coordinate` | geometry_msgs/Point | Kirim koordinat tujuan ke kendaraan |

---

## Cara Penggunaan

```dart
NavigationPage(
  onRouteInfo: (name, distanceKm, eta) {
    // Callback saat rute dihitung
  },
  onClearRouteInfo: () {
    // Callback saat rute dibersihkan
  },
  onRouteCompleted: () {
    // Callback saat sampai tujuan
  },
  navigationKey: myGlobalKey,
)
```

---

## Fitur Utama

- **Dukungan GeoJSON**: Memuat POI dari data GeoJSON
- **Auto-routing**: Menghitung rute mengikuti jalur yang ditentukan
- **Tracking Real-time**: Posisi live dari GPS via ROS
- **Deteksi Kedatangan**: Otomatis selesai saat dalam radius 10m dari tujuan
