import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:dashboardmevi/services/ros_service.dart';
import 'package:dashboardmevi/ui/core/widgets/sensors/car_3d_viewer_widget.dart';

/// BEV/SDC — render titik LiDAR terwarnai per kelas + bounding box objek +
/// garis waypoint + model 3D mobil MEVI (ego), gaya preview Open3D.
///
/// ============================================================
/// REVISI (Tahap 6e) — ringkasan
/// ============================================================
/// 1. **Ikon "tangan" di atas mobil & mobil "geol-geol" = SATU akar
///    masalah yang sama.** Bukan kursor mouse: itu *interaction prompt*
///    bawaan `<model-viewer>` (ikon tangan + animasi wiggle kanan-kiri).
///    Diperbaiki di sumbernya, `local_asset_server_service.dart`
///    (`camera-controls` dibuang, `interaction-prompt="none"`).
///
/// 2. **Mobil sekarang mengikuti waypoint.** Arah hadap ego dihitung dari
///    titik waypoint (lookahead [_egoLookaheadMeters] m di depan), diperhalus
///    (EMA + deadband + animasi) supaya tidak bergetar, lalu diterapkan
///    sebagai rotasi Flutter (`Transform`) — gratis, tanpa JS ke WebView.
///    Rotasi juga ikut kamera orbit (drag-rotate), jadi mobil selalu
///    sejajar dengan garis waypoint di layar. Matikan lewat
///    [_egoFollowWaypoint] = false.
///
/// 3. **Optimasi memori/CPU** (ringkas, detail di penjelasan revisi):
///    - WebView model 3D TIDAK lagi dibuat-hancurkan tiap kamera berputar
///      (dulu: dibuang tiap ego "di belakang kamera", lalu init ulang
///      WebView2 penuh), dan TIDAK lagi di-resize tiap zoom (ukuran tetap
///      [_egoWebViewPx], skala lewat Transform).
///    - Opsional (default aktif, [_egoUseSnapshot]): model 3D difoto sekali
///      (PNG transparan), lalu WebView2 DIBUANG dan diganti gambar biasa —
///      menghemat ratusan MB. Kalau snapshot gagal/tidak transparan, tetap
///      pakai WebView live (perilaku lama, tapi sudah tanpa goyang & tangan).
///    - Titik dikelompokkan per kelas SEKALI saat frame datang (bukan tiap
///      paint), proyeksi 3D->2D tanpa alokasi objek per titik, buffer
///      scratch dipakai ulang, titik di luar layar di-skip.
///    - Grid tanah di-cache (hanya dibangun ulang kalau kamera berubah).
///    - Update frame/drag/zoom TIDAK memanggil setState -> pohon widget
///      tidak di-rebuild; hanya painter yang repaint (via `repaint:`).
///    - Bug pinch-zoom diperbaiki (skala kumulatif dulu dipakai berulang
///      sehingga zoom melonjak eksponensial).
///    - Baris titik yang rusak dulu jadi titik palsu di (0,0,0) — sekarang
///      dilewati.
///
/// ============================================================
/// REVISI (Tahap 6f) — objek terdeteksi ala streetscape.gl
/// ============================================================
/// ============================================================
/// REVISI (Tahap 6g) — tema terang/gelap
/// ============================================================
/// Latar visualisasi mengikuti tema: mode gelap tetap 0xFF05070C, mode
/// terang jadi putih. Warna elemen lain ikut menyesuaikan supaya tetap
/// terbaca di atas putih: grid tanah, teks info, legenda, tepi box, dan
/// lencana objek. Model mobil ego (putih) diberi bayangan lembut di mode
/// terang (siluet dari snapshot, atau bayangan blob kalau masih WebView).
///
/// Bounding box objek sekarang berupa BOX PADAT (bukan wireframe): tiap
/// sisi yang menghadap kamera diisi warna dengan shading per sisi (atas
/// paling terang), disortir dari jauh ke dekat. Di atas tiap box ada
/// lencana (bubble) berisi ikon jenis objek (mobil / orang / sepeda) +
/// ID objek dari field `id` di payload (`#138`). Ikon memakai glyph
/// Material Icons (vektor, tanpa aset gambar baru).
///
/// Skema payload Fase 5 (tidak berubah):
///   `pts: [[x,y,z,class_id], ...]`, `obj: [{id,cls,cx,cy,cz,l,w,h,yaw}]`,
///   `wp: [[x,y], ...]` (waypoint ego-frame dari Fase 1b).
class BevPointCloudView extends StatefulWidget {
  const BevPointCloudView({super.key});

  @override
  State<BevPointCloudView> createState() => _BevPointCloudViewState();
}

/// Sama persis dengan class_color_map.json (Fase 5) -- cuma dipakai selagi
/// nunggu pesan resmi dari /bev/class_color_map.
const Map<int, Color> _fallbackClassColors = {
  0: Color(0xFFE6007E), // Unknown
  1: Color(0xFF1F4E9C), // Road
  2: Color(0xFF2E8B2E), // Vegetation
  3: Color(0xFFC97B2E), // Building
  4: Color(0xFF00E5FF), // Vehicle
  5: Color(0xFFFF4D4D), // Person
};

const Map<int, String> _fallbackClassNames = {
  0: 'Unknown',
  1: 'Road',
  2: 'Vegetation',
  3: 'Building',
  4: 'Vehicle',
  5: 'Person',
};

/// Panjang mobil kanonik (meter) -- buat menghitung skala layar model ego.
const double _egoLengthMeters = 4.2;

/// Koreksi sudut hadap model mevi3d untuk tampilan ego BEV/SDC.
/// Nilai 0 karena Car3DViewerWidget (Windows/Web) sudah secara internal
/// menerapkan Car3DConstants.forwardYawOffsetDeg (180 deg) agar model menghadap
/// ke depan (+x). Nilai 180 sebelumnya menyebabkan sudut total menjadi 360/0 derajat
/// sehingga mobil menghadap terbalik ke belakang.
const double _bevEgoYawFixDeg = 0;

// ---------------------------------------------------------------------
// Pengaturan ego (mobil 3D) -- semua bisa di-tuning di sini.
// ---------------------------------------------------------------------

/// true = arah hadap mobil mengikuti waypoint. false = selalu lurus (+x).
const bool _egoFollowWaypoint = true;

/// Jarak lookahead (meter) titik waypoint yang dijadikan target arah.
/// Makin besar = makin halus/stabil tapi makin "telat" belok.
const double _egoLookaheadMeters = 4.0;

/// Batas belok maksimum yang ditampilkan (radian, 0.6 ~= 34 derajat).
const double _egoMaxYawRad = 0.6;

/// Perubahan target < ini (radian, ~1.5 derajat) diabaikan -> mobil diam
/// saat lurus, tidak ikut jitter kecil dari planner.
const double _egoYawDeadbandRad = 0.026;

/// Faktor EMA per frame (0..1). Besar = responsif, kecil = halus.
const double _egoYawSmoothing = 0.35;

/// Durasi animasi antar-frame supaya rotasi mulus (bukan loncat).
const Duration _egoYawAnimDuration = Duration(milliseconds: 220);

/// Ukuran TETAP (px logis) WebView model 3D. Zoom = Transform.scale, bukan
/// resize WebView (resize = WebView2 render ulang + realokasi surface).
const double _egoWebViewPx = 260;

/// true = model difoto sekali lalu WebView2 dibuang (hemat memori).
/// Otomatis fallback ke WebView live kalau snapshot gagal.
const bool _egoUseSnapshot = true;

// ---------------------------------------------------------------------
// Data frame (immutable, sudah "siap gambar")
// ---------------------------------------------------------------------

/// Titik satu kelas: xyz berurutan (x,y,z,x,y,z,...).
class _PointGroup {
  final int classId;
  final Float32List xyz;
  final int count;
  int _filled = 0;

  _PointGroup(this.classId, this.count) : xyz = Float32List(count * 3);
}

class _BevFrameData {
  /// Titik sudah dikelompokkan per class_id (urut naik: Unknown dulu,
  /// Person terakhir -> Person/Vehicle tergambar di atas).
  final List<_PointGroup> groups;
  final int pointCount;
  final List<_BevObject> objects;

  /// x0,y0,x1,y1,... (ego-frame).
  final Float32List waypoints;
  final int? frameIdx;
  final double? timestamp;

  const _BevFrameData({
    required this.groups,
    required this.pointCount,
    required this.objects,
    required this.waypoints,
    required this.frameIdx,
    required this.timestamp,
  });
}

@immutable
class _CamState {
  final double azimuth, elevation, distance;
  const _CamState(this.azimuth, this.elevation, this.distance);

  _CamState copyWith({double? azimuth, double? elevation, double? distance}) =>
      _CamState(
        azimuth ?? this.azimuth,
        elevation ?? this.elevation,
        distance ?? this.distance,
      );

  @override
  bool operator ==(Object other) =>
      other is _CamState &&
      other.azimuth == azimuth &&
      other.elevation == elevation &&
      other.distance == distance;

  @override
  int get hashCode => Object.hash(azimuth, elevation, distance);
}

/// Cache yang dipakai ulang antar-paint (bukan state UI).
class _RenderCache {
  Float32List scratch = Float32List(8192);

  /// Titik layar 8 sudut box (x,y,x,y,...) -- dipakai ulang tiap objek.
  final Float64List boxXY = Float64List(16);

  /// TextPainter (ikon & label ID) yang sudah di-layout, supaya tidak
  /// layout ulang tiap paint.
  final Map<String, TextPainter> textCache = {};

  TextPainter text(String key, TextSpan span) {
    var tp = textCache[key];
    if (tp == null) {
      if (textCache.length > 96) textCache.clear(); // batasi ukuran cache
      tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
      textCache[key] = tp;
    }
    return tp;
  }

  Path? gridPath;
  _CamState? gridCam;
  Size? gridSize;

  Float32List scratchFor(int n) {
    if (scratch.length < n) scratch = Float32List(n + (n >> 2));
    return scratch;
  }
}

class _BevPointCloudViewState extends State<BevPointCloudView>
    with SingleTickerProviderStateMixin {
  StreamSubscription<Map<String, dynamic>>? _frameSub;
  StreamSubscription<Map<int, Color>>? _classColorSub;

  // Semua yang berubah tiap frame/gesture disimpan di notifier, BUKAN
  // setState -> pohon widget tidak di-rebuild, cuma painter yang repaint.
  final ValueNotifier<_BevFrameData?> _frame = ValueNotifier(null);
  final ValueNotifier<_CamState> _cam = ValueNotifier(
    // Default POV: sudut elevasi tinggi / top-down (~80.2 derajat dari atas)
    // agar mobil ego dan area sekitar tampak jelas dan proporsional.
    const _CamState(math.pi, 1.4, 29.5),
  );
  final ValueNotifier<double> _egoYaw = ValueNotifier(0);
  late final Listenable _egoListenable = Listenable.merge([_cam, _egoYaw]);

  final _RenderCache _cache = _RenderCache();
  Map<int, Color> _classColors = _fallbackClassColors;

  // Animasi arah hadap ego.
  late final AnimationController _yawAnim;
  double _yawFrom = 0;
  double _yawTo = 0; // nilai target yang sudah difilter (EMA + deadband)

  double _pinchStartDistance = 29.5;

  // Hasil snapshot model 3D ego (kalau berhasil, WebView dibuang).
  ui.Image? _egoImage;

  @override
  void initState() {
    super.initState();

    _yawAnim = AnimationController(vsync: this, duration: _egoYawAnimDuration)
      ..addListener(_tickYaw);

    final cached = RosService().bevClassColorMap;
    if (cached != null && cached.isNotEmpty) _classColors = cached;

    _frameSub = RosService().bevFrameStream.listen(_onFrame);
    _classColorSub = RosService().bevClassColorMapStream.listen((colors) {
      if (!mounted || colors.isEmpty) return;
      setState(() => _classColors = colors);
    });
  }

  @override
  void dispose() {
    _frameSub?.cancel();
    _classColorSub?.cancel();
    _yawAnim.dispose();
    _frame.dispose();
    _cam.dispose();
    _egoYaw.dispose();
    _egoImage?.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // Frame masuk
  // -------------------------------------------------------------------

  void _onFrame(Map<String, dynamic> frame) {
    if (!mounted) return;
    final data = _parseFrame(frame);
    if (data == null) return;
    _frame.value = data;
    if (_egoFollowWaypoint) _updateEgoHeading(data.waypoints);
  }

  /// Parse payload Fase 5 -> struktur siap gambar. Titik dikelompokkan per
  /// class_id di sini (2 lintasan: hitung, lalu isi) supaya paint() tidak
  /// perlu bikin list/map apa pun per frame.
  _BevFrameData? _parseFrame(Map<String, dynamic> frame) {
    try {
      final raw = frame['raw'];
      if (raw is! Map) return null;

      final ptsList = raw['pts'];
      if (ptsList is! List) return null;

      // --- Titik: lintasan 1 = hitung per kelas ---
      final n = ptsList.length;
      final counts = <int, int>{};
      for (int i = 0; i < n; i++) {
        final row = ptsList[i];
        if (row is List && row.length >= 4) {
          final c = (row[3] as num).toInt();
          counts[c] = (counts[c] ?? 0) + 1;
        }
      }

      final ids = counts.keys.toList()..sort();
      final byId = <int, _PointGroup>{};
      final groups = <_PointGroup>[];
      int total = 0;
      for (final id in ids) {
        final g = _PointGroup(id, counts[id]!);
        byId[id] = g;
        groups.add(g);
        total += g.count;
      }

      // --- Titik: lintasan 2 = isi langsung ke buffer kelasnya ---
      for (int i = 0; i < n; i++) {
        final row = ptsList[i];
        if (row is! List || row.length < 4) continue;
        final g = byId[(row[3] as num).toInt()]!;
        final o = g._filled * 3;
        g.xyz[o] = (row[0] as num).toDouble();
        g.xyz[o + 1] = (row[1] as num).toDouble();
        g.xyz[o + 2] = (row[2] as num).toDouble();
        g._filled++;
      }

      // --- Objek ---
      final objs = <_BevObject>[];
      final objList = raw['obj'];
      if (objList is List) {
        for (final o in objList) {
          if (o is! Map) continue;
          final cls = o['cls'] as String? ?? '?';
          objs.add(
            _BevObject(
              id: (o['id'] as num?)?.toInt(),
              className: cls,
              kind: _kindFromClass(cls),
              center: Offset3(
                (o['cx'] as num?)?.toDouble() ?? 0,
                (o['cy'] as num?)?.toDouble() ?? 0,
                (o['cz'] as num?)?.toDouble() ?? 0,
              ),
              length: (o['l'] as num?)?.toDouble() ?? 0,
              width: (o['w'] as num?)?.toDouble() ?? 0,
              height: (o['h'] as num?)?.toDouble() ?? 0,
              yaw: (o['yaw'] as num?)?.toDouble() ?? 0,
            ),
          );
        }
      }

      // --- Waypoint ---
      Float32List wp = Float32List(0);
      final wpList = raw['wp'];
      if (wpList is List) {
        final tmp = Float32List(wpList.length * 2);
        int k = 0;
        for (final p in wpList) {
          if (p is List && p.length >= 2) {
            tmp[k++] = (p[0] as num).toDouble();
            tmp[k++] = (p[1] as num).toDouble();
          }
        }
        wp = k == tmp.length ? tmp : Float32List.sublistView(tmp, 0, k);
      }

      return _BevFrameData(
        groups: groups,
        pointCount: total,
        objects: objs,
        waypoints: wp,
        frameIdx: (frame['frame_idx'] as num?)?.toInt(),
        timestamp: (frame['t'] as num?)?.toDouble(),
      );
    } catch (e) {
      debugPrint('BevPointCloudView: gagal parse frame: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------
  // Arah hadap ego dari waypoint
  // -------------------------------------------------------------------

  /// Sudut (radian, ego-frame: 0 = lurus +x, positif = kiri) menuju titik
  /// waypoint pada jarak lookahead. null = tidak ada waypoint yang layak.
  double? _headingFromWaypoints(Float32List wp) {
    final n = wp.length ~/ 2;
    if (n < 2) return null;

    const minForwardX = 0.3; // abaikan titik di samping/belakang ego
    const look2 = _egoLookaheadMeters * _egoLookaheadMeters;

    double? lastX, lastY;
    for (int i = 0; i < n; i++) {
      final x = wp[i * 2], y = wp[i * 2 + 1];
      if (x <= minForwardX) continue;
      if (x * x + y * y >= look2) return math.atan2(y, x);
      lastX = x;
      lastY = y;
    }
    // Semua waypoint lebih dekat dari lookahead -> pakai yang terjauh,
    // asal cukup jauh supaya arahnya bermakna.
    if (lastX != null && lastY != null && lastX * lastX + lastY * lastY > 1.0) {
      return math.atan2(lastY, lastX);
    }
    return null;
  }

  void _updateEgoHeading(Float32List wp) {
    final raw = _headingFromWaypoints(wp) ?? 0.0;
    final target = raw.clamp(-_egoMaxYawRad, _egoMaxYawRad);

    // Deadband: jitter kecil diabaikan -> mobil tidak "geol" saat lurus.
    if ((target - _yawTo).abs() < _egoYawDeadbandRad) return;

    // EMA: gerak sebagian menuju target tiap frame.
    _setYawTarget(_yawTo + _egoYawSmoothing * (target - _yawTo));
  }

  void _setYawTarget(double target) {
    if ((target - _yawTo).abs() < 1e-4) return;
    _yawFrom = _egoYaw.value;
    _yawTo = target;
    _yawAnim.forward(from: 0);
  }

  void _tickYaw() {
    final t = Curves.easeOutCubic.transform(_yawAnim.value);
    _egoYaw.value = _yawFrom + (_yawTo - _yawFrom) * t;
  }

  // -------------------------------------------------------------------
  // Ego 3D
  // -------------------------------------------------------------------

  Future<void> _onEgoSnapshot(Uint8List png) async {
    if (_egoImage != null) return;
    try {
      final codec = await ui.instantiateImageCodec(png);
      final fr = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        fr.image.dispose();
        return;
      }
      // Setelah setState ini, Car3DViewerWidget (WebView2) dilepas dari
      // pohon widget -> proses WebView2 ikut dibebaskan.
      setState(() => _egoImage = fr.image);
    } catch (e) {
      debugPrint('BevPointCloudView: snapshot ego gagal didecode: $e');
    }
  }

  /// Posisi, ukuran, dan sudut layar overlay ego. null = origin di belakang
  /// kamera (overlay disembunyikan, TAPI tidak dibuang dari pohon widget).
  ({Offset center, double sizePx, double angle})? _egoGeometry(
    Size size,
    _CamState cs,
    double yaw,
  ) {
    final cam = _Camera(
      azimuth: cs.azimuth,
      elevation: cs.elevation,
      distance: cs.distance,
    );
    const egoHeightCenter = 0.75; // separuh tinggi kanonik mobil
    final c = cam.project(0, 0, egoHeightCenter, size);
    final r = cam.project(1.0, 0, egoHeightCenter, size);
    if (c == null || r == null) return null;

    final pixelsPerMeter = (Offset(r.x, r.y) - Offset(c.x, c.y)).distance;
    final sizePx = (pixelsPerMeter * _egoLengthMeters).clamp(
      28.0,
      _egoWebViewPx,
    );

    // Sudut layar (searah jarum jam, dari "atas layar") vektor arah hadap
    // di tanah. Rumus sudah memperhitungkan azimuth kamera (drag-rotate)
    // dan pemendekan vertikal akibat elevasi (k), sehingga hidung mobil
    // sejajar dengan garis waypoint yang tergambar. k dibatasi >= 0.5
    // supaya tidak berputar liar saat kamera hampir horizontal.
    final k = math.sin(cs.elevation).abs().clamp(0.5, 1.0);
    final g = yaw - cs.azimuth + math.pi;
    final angle = math.atan2(-math.sin(g), math.cos(g) * k);

    return (center: Offset(c.x, c.y), sizePx: sizePx, angle: angle);
  }

  Widget _buildEgoBody(bool isLight) {
    final img = _egoImage;

    final Widget car = img != null
        ? RawImage(
            image: img,
            width: _egoWebViewPx,
            height: _egoWebViewPx,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          )
        : Car3DViewerWidget(
            key: const ValueKey('bev-ego-car'),
            speed: 0,
            steeringAngle: _bevEgoYawFixDeg,
            height: _egoWebViewPx,
            width: _egoWebViewPx,
            cameraOrbit: '0deg 20deg 105%', // hampir top-down
            captureSnapshot: _egoUseSnapshot,
            onSnapshot: _onEgoSnapshot,
          );

    // Mode terang: mobil ego berwarna putih, di atas latar putih hampir
    // tak kelihatan -> beri bayangan di belakangnya. Selalu dibungkus
    // Stack (slot bayangan kosong di mode gelap) supaya posisi `car` di
    // pohon widget tetap sama saat tema berganti -> WebView TIDAK
    // di-inisialisasi ulang.
    Widget shadow = const SizedBox.shrink();
    if (isLight) {
      shadow = img != null
          // Siluet mobil yang sebenarnya (dari alpha snapshot), di-blur.
          ? Transform.translate(
              offset: const Offset(0, 3),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0x8C000000),
                    BlendMode.srcIn,
                  ),
                  child: RawImage(
                    image: img,
                    width: _egoWebViewPx,
                    height: _egoWebViewPx,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.low,
                  ),
                ),
              ),
            )
          // Masih WebView: bayangan blob kira-kira seukuran badan mobil.
          : Center(
              child: Container(
                width: _egoWebViewPx * 0.42,
                height: _egoWebViewPx * 0.72,
                decoration: BoxDecoration(
                  color: const Color(0x22000000),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x59000000),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            );
    }

    return SizedBox(
      width: _egoWebViewPx,
      height: _egoWebViewPx,
      child: Stack(alignment: Alignment.center, children: [shadow, car]),
    );
  }

  Widget _buildEgoOverlay(Size size, bool isLight) {
    return AnimatedBuilder(
      animation: _egoListenable,
      // Body (WebView / gambar) dibuat sekali & dipakai ulang tiap tick
      // animasi -> yang di-rebuild cuma Positioned + Transform.
      child: IgnorePointer(child: _buildEgoBody(isLight)),
      builder: (context, body) {
        final g = _egoGeometry(size, _cam.value, _egoYaw.value);
        final visible = g != null;
        final geom = g ?? (center: Offset.zero, sizePx: 28.0, angle: 0.0);
        final scale = geom.sizePx / _egoWebViewPx;

        return Positioned(
          left: geom.center.dx - _egoWebViewPx / 2,
          top: geom.center.dy - _egoWebViewPx / 2,
          width: _egoWebViewPx,
          height: _egoWebViewPx,
          // Offstage (bukan `if`) -> WebView TIDAK dihancurkan saat ego
          // sesaat di belakang kamera.
          child: Offstage(
            offstage: !visible,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: Transform.rotate(angle: geom.angle, child: body),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Sama seperti camera_page.dart: terang = putih, gelap = tetap.
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      color: isLight ? Colors.white : const Color(0xFF05070C),
      child: Listener(
        // Scroll wheel mouse buat zoom.
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            final c = _cam.value;
            _cam.value = c.copyWith(
              distance: (c.distance * (1 + event.scrollDelta.dy * 0.001)).clamp(
                4.0,
                150.0,
              ),
            );
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (_) => _pinchStartDistance = _cam.value.distance,
          onScaleUpdate: (details) {
            final c = _cam.value;
            // details.scale bersifat KUMULATIF sejak gesture mulai, jadi
            // harus dibagi ke jarak awal gesture (bukan jarak saat ini).
            final dist = details.scale != 1.0
                ? (_pinchStartDistance / details.scale).clamp(4.0, 150.0)
                : c.distance;
            _cam.value = _CamState(
              c.azimuth - details.focalPointDelta.dx * 0.008,
              (c.elevation + details.focalPointDelta.dy * 0.008).clamp(
                -1.4,
                1.4,
              ),
              dist,
            );
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;

              return Stack(
                children: [
                  Positioned.fill(
                    // RepaintBoundary: animasi ego (rotasi/scale) tidak
                    // memaksa titik-titik digambar ulang, dan sebaliknya.
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _PointCloudPainter(
                          frame: _frame,
                          cam: _cam,
                          classColors: _classColors,
                          cache: _cache,
                          isLight: isLight,
                        ),
                      ),
                    ),
                  ),

                  _buildEgoOverlay(size, isLight),

                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isLight
                            ? const Color(0x14000000)
                            : Colors.black45,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ValueListenableBuilder<_BevFrameData?>(
                        valueListenable: _frame,
                        builder: (context, d, _) => Text(
                          d == null
                              ? 'BEV/SDC — menunggu /bev/frame...'
                              : 'frame_idx=${d.frameIdx}  t=${d.timestamp}\n'
                                    'titik=${d.pointCount} (semua, tanpa downsample)  '
                                    'objek=${d.objects.length}  waypoint=${d.waypoints.length ~/ 2}\n'
                                    'drag = rotate • scroll/pinch = zoom',
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF1B5E20)
                                : Colors.greenAccent,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: _ClassLegend(
                      classColors: _classColors,
                      isLight: isLight,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Legenda kecil di pojok kanan-atas.
class _ClassLegend extends StatelessWidget {
  final Map<int, Color> classColors;
  final bool isLight;
  const _ClassLegend({required this.classColors, required this.isLight});

  @override
  Widget build(BuildContext context) {
    final ids = classColors.keys.toList()..sort();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isLight ? const Color(0x14000000) : Colors.black45,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: ids.map((id) {
          final name = _fallbackClassNames[id] ?? 'class $id';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: classColors[id],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  name,
                  style: TextStyle(
                    color: isLight ? Colors.black87 : Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Vektor 3D minimal (gak pakai package vector_math biar gak nambah
/// dependency baru cuma buat ini).
class Offset3 {
  final double x, y, z;
  const Offset3(this.x, this.y, this.z);

  Offset3 operator -(Offset3 o) => Offset3(x - o.x, y - o.y, z - o.z);

  Offset3 cross(Offset3 o) =>
      Offset3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  double get length => math.sqrt(x * x + y * y + z * z);

  Offset3 normalized() {
    final l = length;
    if (l < 1e-9) return const Offset3(0, 0, 0);
    return Offset3(x / l, y / l, z / l);
  }
}

enum _ObjKind { vehicle, person, cyclist, other }

/// Petakan nama kelas dari payload (`cls`) ke jenis tampilan. Longgar
/// terhadap penamaan ("Car", "Vehicle", "Pedestrian", "Person", ...).
_ObjKind _kindFromClass(String cls) {
  final s = cls.toLowerCase();
  if (s.contains('cyc') || s.contains('bike') || s.contains('bicycle')) {
    return _ObjKind.cyclist;
  }
  if (s.contains('ped') || s.contains('person') || s.contains('human')) {
    return _ObjKind.person;
  }
  if (s.contains('car') ||
      s.contains('veh') ||
      s.contains('truck') ||
      s.contains('bus') ||
      s.contains('van')) {
    return _ObjKind.vehicle;
  }
  return _ObjKind.other;
}

class _BevObject {
  final int? id; // dari field "id" payload (null kalau tidak ada)
  final String className;
  final _ObjKind kind;
  final Offset3 center;
  final double length, width, height, yaw;
  _BevObject({
    required this.id,
    required this.className,
    required this.kind,
    required this.center,
    required this.length,
    required this.width,
    required this.height,
    required this.yaw,
  });
}

/// Objek + kedalamannya, buat sorting jauh -> dekat (painter's algorithm).
class _ObjItem {
  final _BevObject obj;
  final double depth;
  const _ObjItem(this.obj, this.depth);
}

class _Proj {
  final double x, y, depth;
  const _Proj(this.x, this.y, this.depth);
}

/// Kamera orbit sederhana (look-at ke origin/ego).
class _Camera {
  final Offset3 position;
  final Offset3 right;
  final Offset3 up;
  final Offset3 forward;

  factory _Camera({
    required double azimuth,
    required double elevation,
    required double distance,
    Offset3 target = const Offset3(0, 0, 0),
  }) {
    final cosE = math.cos(elevation), sinE = math.sin(elevation);
    final cosA = math.cos(azimuth), sinA = math.sin(azimuth);
    final position = Offset3(
      target.x + distance * cosE * cosA,
      target.y + distance * cosE * sinA,
      target.z + distance * sinE,
    );
    final forward = (target - position).normalized();
    const worldUp = Offset3(0, 0, 1); // ROS: z = atas
    var right = forward.cross(worldUp);
    right = right.length < 1e-6 ? const Offset3(1, 0, 0) : right.normalized();
    final up = right.cross(forward);
    return _Camera._(position, right, up, forward);
  }

  const _Camera._(this.position, this.right, this.up, this.forward);

  static const double _fovYRad = 0.9;
  static const double _near = 0.4;

  /// Proyeksi satu titik. null kalau di belakang kamera. Dipakai untuk
  /// jumlah kecil titik (grid, waypoint, box, ego) -- untuk ribuan titik
  /// LiDAR pakai [projectBatch] (tanpa alokasi objek per titik).
  _Proj? project(
    double x,
    double y,
    double z,
    Size size, {
    double fovYRad = _fovYRad,
    double near = _near,
  }) {
    final rx = x - position.x;
    final ry = y - position.y;
    final rz = z - position.z;
    final viewX = rx * right.x + ry * right.y + rz * right.z;
    final viewY = rx * up.x + ry * up.y + rz * up.z;
    final viewZ = rx * forward.x + ry * forward.y + rz * forward.z;
    if (viewZ <= near) return null;

    final f = (size.height / 2) / math.tan(fovYRad / 2);
    final sx = size.width / 2 + (viewX / viewZ) * f;
    final sy = size.height / 2 - (viewY / viewZ) * f;
    return _Proj(sx, sy, viewZ);
  }

  /// Proyeksi massal titik xyz (x,y,z,...) ke [out] (x,y,x,y,...), tanpa
  /// alokasi per titik. Titik di belakang kamera atau di luar layar
  /// (margin 24 px) dilewati. Return: jumlah float yang ditulis ke [out].
  int projectBatch(Float32List xyz, int count, Float32List out, Size size) {
    final f = (size.height / 2) / math.tan(_fovYRad / 2);
    final cx = size.width / 2, cy = size.height / 2;
    final minX = -24.0, maxX = size.width + 24.0;
    final minY = -24.0, maxY = size.height + 24.0;

    final px = position.x, py = position.y, pz = position.z;
    final rX = right.x, rY = right.y, rZ = right.z;
    final uX = up.x, uY = up.y, uZ = up.z;
    final fX = forward.x, fY = forward.y, fZ = forward.z;

    int w = 0;
    for (int i = 0, j = 0; i < count; i++, j += 3) {
      final dx = xyz[j] - px;
      final dy = xyz[j + 1] - py;
      final dz = xyz[j + 2] - pz;
      final vz = dx * fX + dy * fY + dz * fZ;
      if (vz <= _near) continue;
      final k = f / vz;
      final sx = cx + (dx * rX + dy * rY + dz * rZ) * k;
      final sy = cy - (dx * uX + dy * uY + dz * uZ) * k;
      if (sx < minX || sx > maxX || sy < minY || sy > maxY) continue;
      out[w++] = sx;
      out[w++] = sy;
    }
    return w;
  }
}

class _PointCloudPainter extends CustomPainter {
  final ValueListenable<_BevFrameData?> frame;
  final ValueListenable<_CamState> cam;
  final Map<int, Color> classColors;
  final _RenderCache cache;
  final bool isLight;

  // `repaint:` -> painter di-repaint langsung tiap frame/kamera berubah,
  // TANPA rebuild widget tree.
  _PointCloudPainter({
    required this.frame,
    required this.cam,
    required this.classColors,
    required this.cache,
    required this.isLight,
  }) : super(repaint: Listenable.merge([frame, cam]));

  static const _unknownColor = Color(0xFFBDBDBD);
  static const _waypointColor = Color(0xFFFFA726); // oranye, ala Open3D

  // Paint dibuat sekali, dipakai ulang (Paint disalin ke display list
  // saat draw, jadi aman diubah lagi sesudahnya).
  final Paint _gridPaint = Paint()
    ..color =
        const Color(0x14FFFFFF) // putih alpha ~0.08
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final Paint _wpLinePaint = Paint()
    ..color = _waypointColor
    ..strokeWidth = 2.4
    ..style = PaintingStyle.stroke;
  final Paint _wpDotPaint = Paint()
    ..color = _waypointColor
    ..strokeWidth = 4.4
    ..strokeCap = StrokeCap.round;
  final Paint _pointPaint = Paint()
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round;
  final Paint _facePaint = Paint()..style = PaintingStyle.fill;
  final Paint _edgePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0
    ..strokeJoin = StrokeJoin.round;

  /// Grid cincin jarak tanah. Path di-cache di [cache]; dibangun ulang
  /// HANYA kalau kamera / ukuran kanvas berubah.
  void _drawGroundGrid(Canvas canvas, Size size, _Camera camera, _CamState cs) {
    var path = cache.gridPath;
    if (path == null || cache.gridCam != cs || cache.gridSize != size) {
      path = Path();
      for (final r in const [10.0, 20.0, 30.0, 40.0, 50.0]) {
        bool pen = false;
        for (int i = 0; i <= 64; i++) {
          final a = (i / 64) * 2 * math.pi;
          final p = camera.project(r * math.cos(a), r * math.sin(a), 0, size);
          if (p == null) {
            pen = false;
            continue;
          }
          if (pen) {
            path.lineTo(p.x, p.y);
          } else {
            path.moveTo(p.x, p.y);
            pen = true;
          }
        }
      }
      cache.gridPath = path;
      cache.gridCam = cs;
      cache.gridSize = size;
    }
    _gridPaint.color = isLight
        ? const Color(0x1F000000) // hitam alpha ~0.12 di latar putih
        : const Color(0x14FFFFFF); // putih alpha ~0.08 di latar gelap
    canvas.drawPath(path, _gridPaint);
  }

  /// Garis trajectory (waypoint Fase 1b), z=0.05 supaya tidak tenggelam
  /// di grid. 1x drawPath + 1x drawRawPoints, bukan 1 draw per segmen.
  void _drawWaypointPath(
    Canvas canvas,
    Size size,
    _Camera camera,
    Float32List wp,
  ) {
    final n = wp.length ~/ 2;
    if (n < 2) return;

    final buf = cache.scratchFor(n * 2);
    final path = Path();
    bool pen = false;
    int w = 0;
    for (int i = 0; i < n; i++) {
      final p = camera.project(wp[i * 2], wp[i * 2 + 1], 0.05, size);
      if (p == null) {
        pen = false;
        continue;
      }
      if (pen) {
        path.lineTo(p.x, p.y);
      } else {
        path.moveTo(p.x, p.y);
        pen = true;
      }
      buf[w++] = p.x;
      buf[w++] = p.y;
    }
    canvas.drawPath(path, _wpLinePaint);
    if (w > 0) {
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(buf, 0, w),
        _wpDotPaint,
      );
    }
  }

  // ---------------------------------------------------------------
  // Objek terdeteksi: box padat + lencana ikon/ID (gaya streetscape.gl)
  // ---------------------------------------------------------------

  // Sisi box: 4 indeks sudut (bit0 = +x lokal, bit1 = +y, bit2 = +z) dan
  // normal lokalnya. Urutan sudut mengelilingi sisi, jadi bisa langsung
  // dijadikan Path.
  static const List<List<int>> _faceCorners = [
    [1, 3, 7, 5], // +x
    [0, 2, 6, 4], // -x
    [2, 3, 7, 6], // +y
    [0, 1, 5, 4], // -y
    [4, 5, 7, 6], // +z (atas)
    [0, 1, 3, 2], // -z (bawah)
  ];
  static const List<List<int>> _faceNormals = [
    [1, 0, 0],
    [-1, 0, 0],
    [0, 1, 0],
    [0, -1, 0],
    [0, 0, 1],
    [0, 0, -1],
  ];

  // Arah cahaya imajiner (kira-kira unit) dari atas-belakang-kiri.
  static const double _lx = -0.30, _ly = -0.35, _lz = 0.89;

  Color _baseColorFor(_BevObject o) {
    switch (o.kind) {
      case _ObjKind.vehicle:
        return classColors[4] ?? const Color(0xFF00E5FF);
      case _ObjKind.person:
        return classColors[5] ?? const Color(0xFFFF4D4D);
      case _ObjKind.cyclist:
        return const Color(0xFF9575FF);
      case _ObjKind.other:
        return const Color(0xFFFFC107);
    }
  }

  IconData _iconFor(_ObjKind k) {
    switch (k) {
      case _ObjKind.vehicle:
        return Icons.directions_car_filled_rounded;
      case _ObjKind.person:
        return Icons.directions_walk_rounded;
      case _ObjKind.cyclist:
        return Icons.pedal_bike_rounded;
      case _ObjKind.other:
        return Icons.help_outline_rounded;
    }
  }

  /// Box padat: hanya sisi yang menghadap kamera (back-face culling) yang
  /// digambar -- untuk box konveks sisi-sisi itu tidak saling menimpa,
  /// jadi alpha blending aman dan urutan antar-sisi tidak berpengaruh.
  void _drawSolidBox(
    Canvas canvas,
    Size size,
    _Camera camera,
    _BevObject o,
    Color base,
  ) {
    final hl = o.length / 2, hw = o.width / 2, hh = o.height / 2;
    final cosY = math.cos(o.yaw), sinY = math.sin(o.yaw);
    final xy = cache.boxXY;

    for (int i = 0; i < 8; i++) {
      final lx = (i & 1) != 0 ? hl : -hl;
      final ly = (i & 2) != 0 ? hw : -hw;
      final lz = (i & 4) != 0 ? hh : -hh;
      final p = camera.project(
        o.center.x + lx * cosY - ly * sinY,
        o.center.y + lx * sinY + ly * cosY,
        o.center.z + lz,
        size,
      );
      if (p == null) return; // ada sudut di belakang kamera, skip
      xy[i * 2] = p.x;
      xy[i * 2 + 1] = p.y;
    }

    final cp = camera.position;
    // Tepi: lebih terang dari badan di latar gelap, lebih gelap di latar
    // putih (tepi terang akan hilang di atas putih).
    final edge = isLight
        ? Color.lerp(base, Colors.black, 0.35)!
        : Color.lerp(base, Colors.white, 0.45)!;
    _facePaint.style = PaintingStyle.fill;
    _edgePaint.color = edge.withValues(alpha: 0.9);

    for (int f = 0; f < 6; f++) {
      final n = _faceNormals[f];
      // Normal & pusat sisi di dunia (yaw memutar bidang xy saja).
      final nwx = n[0] * cosY - n[1] * sinY;
      final nwy = n[0] * sinY + n[1] * cosY;
      final nwz = n[2].toDouble();
      final fcx = o.center.x + (n[0] * hl) * cosY - (n[1] * hw) * sinY;
      final fcy = o.center.y + (n[0] * hl) * sinY + (n[1] * hw) * cosY;
      final fcz = o.center.z + n[2] * hh;

      // Sisi membelakangi kamera -> lewati.
      if (nwx * (cp.x - fcx) + nwy * (cp.y - fcy) + nwz * (cp.z - fcz) <= 0) {
        continue;
      }

      final lambert = math.max(0.0, nwx * _lx + nwy * _ly + nwz * _lz);
      final shade = 0.55 + 0.55 * lambert; // sisi atas ~1.03, samping ~0.6-0.9
      final fill = Color.fromRGBO(
        (base.r * 255 * shade).round().clamp(0, 255),
        (base.g * 255 * shade).round().clamp(0, 255),
        (base.b * 255 * shade).round().clamp(0, 255),
        0.86,
      );

      final c = _faceCorners[f];
      final path = Path()
        ..moveTo(xy[c[0] * 2], xy[c[0] * 2 + 1])
        ..lineTo(xy[c[1] * 2], xy[c[1] * 2 + 1])
        ..lineTo(xy[c[2] * 2], xy[c[2] * 2 + 1])
        ..lineTo(xy[c[3] * 2], xy[c[3] * 2 + 1])
        ..close();
      _facePaint.color = fill;
      canvas.drawPath(path, _facePaint);
      canvas.drawPath(path, _edgePaint);
    }
  }

  /// Lencana di atas box: [ikon | #ID] dalam pill berekor kecil yang
  /// menunjuk ke box, seperti bubble di referensi.
  void _drawBadge(
    Canvas canvas,
    Size size,
    _Camera camera,
    _BevObject o,
    Color base,
  ) {
    final anchor = camera.project(
      o.center.x,
      o.center.y,
      o.center.z + o.height / 2 + 0.4,
      size,
    );
    if (anchor == null) return;
    final ax = anchor.x, ay = anchor.y;
    if (ax < -40 || ax > size.width + 40 || ay < -40 || ay > size.height + 40) {
      return;
    }

    final icon = _iconFor(o.kind);
    final iconTp = cache.text(
      'i:${o.kind.index}',
      TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 15,
          color: Colors.white,
        ),
      ),
    );
    final idTp = o.id == null
        ? null
        : cache.text(
            't:${o.id}',
            TextSpan(
              text: '#${o.id}',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.0,
              ),
            ),
          );

    const padH = 6.0, padV = 3.5, gap = 3.0, tail = 5.0;
    final double contentW =
        iconTp.width + (idTp == null ? 0.0 : gap + idTp.width);
    final double contentH = math.max(iconTp.height, idTp?.height ?? 0.0);
    final w = contentW + padH * 2;
    final h = contentH + padV * 2;

    final left = ax - w / 2;
    final top = ay - tail - h;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, w, h),
      const Radius.circular(8),
    );
    final tailPath = Path()
      ..moveTo(ax - 4, top + h - 0.5)
      ..lineTo(ax + 4, top + h - 0.5)
      ..lineTo(ax, ay)
      ..close();

    final bg = Color.lerp(base, Colors.black, 0.28)!;
    _facePaint
      ..style = PaintingStyle.fill
      ..color = bg.withValues(alpha: 0.95);
    canvas.drawRRect(rrect, _facePaint);
    canvas.drawPath(tailPath, _facePaint);

    _edgePaint.color = isLight
        ? Colors.black.withValues(alpha: 0.25)
        : Colors.white.withValues(alpha: 0.55);
    canvas.drawRRect(rrect, _edgePaint);

    iconTp.paint(canvas, Offset(left + padH, top + (h - iconTp.height) / 2));
    if (idTp != null) {
      idTp.paint(
        canvas,
        Offset(left + padH + iconTp.width + gap, top + (h - idTp.height) / 2),
      );
    }
  }

  void _drawObjects(
    Canvas canvas,
    Size size,
    _Camera camera,
    List<_BevObject> objects,
  ) {
    if (objects.isEmpty) return;

    // Urut jauh -> dekat supaya box/lencana yang dekat menimpa yang jauh.
    final items = <_ObjItem>[];
    for (final o in objects) {
      final p = camera.project(o.center.x, o.center.y, o.center.z, size);
      if (p != null) items.add(_ObjItem(o, p.depth));
    }
    items.sort((a, b) => b.depth.compareTo(a.depth));

    for (final it in items) {
      _drawSolidBox(canvas, size, camera, it.obj, _baseColorFor(it.obj));
    }
    // Lencana digambar setelah SEMUA box, supaya tidak tertutup box lain.
    for (final it in items) {
      _drawBadge(canvas, size, camera, it.obj, _baseColorFor(it.obj));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Latar sudah digambar oleh Container induk (tidak perlu drawRect
    // lagi -> hemat satu fill layar penuh per paint).
    final cs = cam.value;
    final camera = _Camera(
      azimuth: cs.azimuth,
      elevation: cs.elevation,
      distance: cs.distance,
    );

    _drawGroundGrid(canvas, size, camera, cs);

    final data = frame.value;
    if (data == null) return;

    _drawWaypointPath(canvas, size, camera, data.waypoints);

    // Titik: sudah dikelompokkan per kelas saat frame datang. Di sini
    // tinggal proyeksi ke buffer scratch yang dipakai ulang + 1 draw call
    // per kelas. Nol alokasi per titik.
    for (final g in data.groups) {
      final buf = cache.scratchFor(g.count * 2);
      final w = camera.projectBatch(g.xyz, g.count, buf, size);
      if (w == 0) continue;
      _pointPaint.color = classColors[g.classId] ?? _unknownColor;
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(buf, 0, w),
        _pointPaint,
      );
    }

    // Ego TIDAK digambar di sini -- overlay model 3D di
    // _BevPointCloudViewState._buildEgoOverlay().

    _drawObjects(canvas, size, camera, data.objects);
  }

  @override
  bool shouldRepaint(covariant _PointCloudPainter old) =>
      !identical(old.classColors, classColors) ||
      old.isLight != isLight ||
      !identical(old.frame, frame) ||
      !identical(old.cam, cam);
}
