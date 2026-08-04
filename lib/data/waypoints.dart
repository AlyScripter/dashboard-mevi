import '../model/location.dart';

/// Waypoints untuk rute BRIN yang lebih bersih dan akurat
/// Total: 33 waypoints dari start hingga finish (versi lebih halus)
///
/// POI (Point of Interest) bisa kamu sesuaikan lagi setelah test rute baru.
/// Untuk saat ini, POI legacy tetap ada (gedung10/labAutonomous/dll) biar tidak
/// merusak fitur lama di dashboard.
class Waypoints {
  // Waypoint 1 - Start
  static const wp01 = Location(
    name: "WP 01 - Start",
    latitude: -6.88248358,
    longitude: 107.61073832,
  );

  // Waypoint 2
  static const wp02 = Location(
    name: "WP 02",
    latitude: -6.88243801,
    longitude: 107.61075495,
  );

  // Waypoint 3
  static const wp03 = Location(
    name: "WP 03",
    latitude: -6.88241414,
    longitude: 107.61078367,
  );

  // Waypoint 4
  static const wp04 = Location(
    name: "WP 04",
    latitude: -6.88240763,
    longitude: 107.61082751,
  );

  // Waypoint 5
  static const wp05 = Location(
    name: "WP 05",
    latitude: -6.88240980,
    longitude: 107.61088042,
  );

  // Waypoint 6
  static const wp06 = Location(
    name: "WP 06",
    latitude: -6.88241631,
    longitude: 107.61093484,
  );

  // Waypoint 7
  static const wp07 = Location(
    name: "WP 07",
    latitude: -6.88242065,
    longitude: 107.61100136,
  );

  // Waypoint 8
  static const wp08 = Location(
    name: "WP 08",
    latitude: -6.88241631,
    longitude: 107.61103915,
  );

  // Waypoint 9
  static const wp09 = Location(
    name: "WP 09",
    latitude: -6.88239895,
    longitude: 107.61106636,
  );

  // Waypoint 10
  static const wp10 = Location(
    name: "WP 10",
    latitude: -6.88237725,
    longitude: 107.61108450,
  );

  // Waypoint 11
  static const wp11 = Location(
    name: "WP 11",
    latitude: -6.88235121,
    longitude: 107.61109509,
  );

  // Waypoint 12
  static const wp12 = Location(
    name: "WP 12",
    latitude: -6.88229696,
    longitude: 107.61110265,
  );

  // Waypoint 13
  static const wp13 = Location(
    name: "WP 13",
    latitude: -6.88220148,
    longitude: 107.61111172,
  );

  // Waypoint 14
  static const wp14 = Location(
    name: "WP 14",
    latitude: -6.88200618,
    longitude: 107.61113137,
  );

  // Waypoint 15
  static const wp15 = Location(
    name: "WP 15",
    latitude: -6.88180003,
    longitude: 107.61115404,
  );

  // Waypoint 16
  static const wp16 = Location(
    name: "WP 16",
    latitude: -6.88160039,
    longitude: 107.61117521,
  );

  // Waypoint 17
  static const wp17 = Location(
    name: "WP 17",
    latitude: -6.88140508,
    longitude: 107.61119788,
  );

  // Waypoint 18
  static const wp18 = Location(
    name: "WP 18",
    latitude: -6.88133130,
    longitude: 107.61120695,
  );

  // Waypoint 19
  static const wp19 = Location(
    name: "WP 19",
    latitude: -6.88127488,
    longitude: 107.61123870,
  );

  // Waypoint 20
  static const wp20 = Location(
    name: "WP 20",
    latitude: -6.88126186,
    longitude: 107.61128556,
  );

  // Waypoint 21
  static const wp21 = Location(
    name: "WP 21",
    latitude: -6.88126620,
    longitude: 107.61133243,
  );

  // Waypoint 22
  static const wp22 = Location(
    name: "WP 22",
    latitude: -6.88128139,
    longitude: 107.61146546,
  );

  // Waypoint 23
  static const wp23 = Location(
    name: "WP 23",
    latitude: -6.88129658,
    longitude: 107.61160152,
  );

  // Waypoint 24
  static const wp24 = Location(
    name: "WP 24",
    latitude: -6.88130526,
    longitude: 107.61169676,
  );

  // Waypoint 25
  static const wp25 = Location(
    name: "WP 25",
    latitude: -6.88133564,
    longitude: 107.61173908,
  );

  // Waypoint 26
  static const wp26 = Location(
    name: "WP 26",
    latitude: -6.88137470,
    longitude: 107.61174816,
  );

  // Waypoint 27
  static const wp27 = Location(
    name: "WP 27",
    latitude: -6.88142895,
    longitude: 107.61174664,
  );

  // Waypoint 28
  static const wp28 = Location(
    name: "WP 28",
    latitude: -6.88149839,
    longitude: 107.61173606,
  );

  // Waypoint 29
  static const wp29 = Location(
    name: "WP 29",
    latitude: -6.88156350,
    longitude: 107.61172699,
  );

  // Waypoint 30
  static const wp30 = Location(
    name: "WP 30",
    latitude: -6.88180437,
    longitude: 107.61170129,
  );

  // Waypoint 31
  static const wp31 = Location(
    name: "WP 31",
    latitude: -6.88200618,
    longitude: 107.61168164,
  );

  // Waypoint 32
  static const wp32 = Location(
    name: "WP 32",
    latitude: -6.88220365,
    longitude: 107.61165896,
  );

  // Waypoint 33 - Final (Finish)
  static const wp33 = Location(
    name: "WP 33 - Finish",
    latitude: -6.88240546,
    longitude: 107.61163629,
  );

  /// List semua waypoints dalam urutan (keliling penuh)
  static const List<Location> allWaypoints = [
    wp01, wp02, wp03, wp04, wp05, wp06, wp07, wp08, wp09, wp10,
    wp11, wp12, wp13, wp14, wp15, wp16, wp17, wp18, wp19, wp20,
    wp21, wp22, wp23, wp24, wp25, wp26, wp27, wp28, wp29, wp30,
    wp31, wp32, wp33,
  ];

  // ============================================================
  // WAYPOINTS KE LOKASI TERTENTU (berdasarkan rute sebenarnya)
  // ============================================================

  /// Waypoints ke "Gedung 10" (sementara: potong di sekitar belokan awal)
  /// Silakan kamu adjust index-nya setelah lihat rute real di lapangan.
  static const List<Location> toGedung10 = [
    wp01, wp02, wp03, wp04, wp05, wp06, wp07, wp08, wp09, wp10,
    wp11, wp12, wp13,
  ];

  /// Waypoints ke "Lab Autonomous" (sementara)
  static const List<Location> toLabAutonomous = [
    wp01, wp02, wp03, wp04, wp05, wp06, wp07, wp08, wp09, wp10,
    wp11, wp12, wp13, wp14, wp15, wp16, wp17, wp18, wp19, wp20,
    wp21, wp22,
  ];

  /// Waypoints ke "Gedung 80" (sementara: dekat start)
  static const List<Location> toGedung80 = [
    wp01, wp02, wp03, wp04,
  ];

  /// Waypoints ke "Taman BRIN" (sementara)
  static const List<Location> toTamanBRIN = [
    wp01, wp02, wp03, wp04, wp05, wp06, wp07, wp08, wp09, wp10,
    wp11, wp12, wp13, wp14, wp15, wp16, wp17, wp18, wp19, wp20,
    wp21, wp22, wp23, wp24,
  ];

  /// Waypoints ke tujuan akhir (keliling penuh)
  static const List<Location> toPosSatpam = allWaypoints;

  // ============================================================
  // POI DESTINATIONS (titik tujuan akhir)
  // ============================================================

  /// Gedung 10 BRIN (legacy - boleh kamu revisi nanti)
  static const gedung10 = Location(
    name: "Gedung 10 - BRIN",
    latitude: -6.881784050362436,
    longitude: 107.6111333063233,
  );

  /// Lab Autonomous BRIN (legacy - boleh kamu revisi nanti)
  static const labAutonomous = Location(
    name: "Lab Autonomous - BRIN",
    latitude: -6.881283780406986,
    longitude: 107.6114400048955,
  );

  /// Gedung 80 BRIN (legacy - boleh kamu revisi nanti)
  static const gedung80 = Location(
    name: "Gedung 80 - BRIN",
    latitude: -6.882398919774277,
    longitude: 107.610898305495,
  );

  /// Taman BRIN (legacy - boleh kamu revisi nanti)
  static const tamanBRIN = Location(
    name: "Taman - BRIN",
    latitude: -6.882229538516845,
    longitude: 107.6116054510044,
  );

  /// Finish (sesuaikan nama kalau tetap mau "Pos Satpam")
  static const posSatpam = Location(
    name: "Finish - BRIN",
    latitude: -6.88240546,
    longitude: 107.61163629,
  );

  // Legacy aliases untuk backward compatibility
  static const start = wp01;
  static const finalPoint = wp33;
}
