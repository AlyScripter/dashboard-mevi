import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

/// Serves the app's own bundled assets (the `data/flutter_assets` folder
/// that sits next to the .exe on a Windows desktop build) over
/// `http://127.0.0.1:<port>/...` instead of `file://`.
///
/// WHY THIS EXISTS
/// ----------------
/// `model_viewer_plus` (and the `<model-viewer>` web component it wraps)
/// downloads the `.glb` with the browser's `fetch()` API. Chromium's
/// `fetch()` refuses `file://` URLs outright, which is what made the
/// desktop build hang forever on a spinner before this fix (WebView2 *is*
/// Chromium, so it inherits the exact same restriction).
///
/// SAME-ORIGIN NOTE (important — this is the part that was missing before)
/// ---------------------------------------------------------------------
/// An earlier version of the Windows viewer loaded its HTML via
/// `controller.loadStringContent(...)`. That gives the page a null/opaque
/// origin, so `<model-viewer>`'s internal `fetch()` to
/// `http://127.0.0.1:<port>/assets/3d/....glb` was cross-origin from a
/// null origin — silently blocked, with `<model-viewer>` swallowing the
/// failure instead of throwing anywhere Dart could catch it. That's why
/// everything could log "ready" with zero errors, yet nothing ever
/// appeared, no matter which .glb file was used.
///
/// Fix: this server now also serves the viewer HTML itself (at
/// [viewerPath]), so the page and the `.glb` are on the exact same
/// `http://127.0.0.1:<port>` origin — there is no cross-origin request
/// left to block, exactly like the web build (one origin, `index.html` +
/// assets together). See `car_3d_viewer_windows.dart`, which now calls
/// `controller.loadUrl(...)` against [viewerPath] instead of
/// `loadStringContent`.
///
/// Only wired up for Windows right now.
class LocalAssetServerService {
  LocalAssetServerService._();

  static final LocalAssetServerService instance = LocalAssetServerService._();

  /// Path (relative to [baseUrl]) of the generated viewer page.
  static const viewerPath = '/__viewer.html';

  static const _modelViewerJsAssetPath =
      'packages/model_viewer_plus/assets/model-viewer.min.js';

  HttpServer? _server;
  int? _port;

  bool get isRunning => _server != null;

  int? get port => _port;

  /// Base URL to prefix any bundled-asset path with, e.g.:
  ///   '$baseUrl/assets/3d/car_model.glb'
  ///   '$baseUrl$viewerPath'
  String get baseUrl {
    final port = _port;
    if (port == null) {
      throw StateError(
        'LocalAssetServerService.start() has not completed yet — call '
        'and await start() before reading baseUrl.',
      );
    }
    return 'http://127.0.0.1:$port';
  }

  Directory _flutterAssetsDir() {
    final exeDir = File(Platform.resolvedExecutable).parent;
    final dir = Directory(
      '${exeDir.path}${Platform.pathSeparator}data'
      '${Platform.pathSeparator}flutter_assets',
    );
    if (!dir.existsSync()) {
      throw StateError(
        'flutter_assets directory not found at "${dir.path}". This '
        'service only works inside a built/launched Windows desktop app '
        '(flutter run -d windows / flutter build windows), where Flutter '
        'unpacks assets next to the .exe.',
      );
    }
    return dir;
  }

  /// The HTML page served at [viewerPath].
  ///
  /// Which `.glb` to load is **not** hardcoded here — it's read from the
  /// `?glb=` query param at page-load time (see `car_3d_viewer_windows.dart`,
  /// which is where you actually switch between `car_model.glb`,
  /// `vino.glb`, `mevi3d.glb`, etc. for testing). This file never needs to
  /// change just to test a different model.
  ///
  /// REVISI (BEV/SDC top-down car overlay): also reads an optional
  /// `?orbit=` query param (e.g. `0deg%2015deg%20105%25`) and applies it
  /// as `<model-viewer camera-orbit="...">` once at page load — this is
  /// what lets `Car3DViewerWindows` request a near-top-down view for the
  /// BEV ego-car overlay without touching this file's HTML again for
  /// every new angle. No `orbit` param (every OTHER existing call site,
  /// e.g. VehicleStageWidget) means the attribute is never set, so
  /// model-viewer keeps using its own default auto-framed view — exactly
  /// the previous behavior, unchanged.
  ///
  /// REVISI ke-3 (AKAR MASALAH SEBENARNYA — "kursor tangan" & mobil
  /// "geol-geol"): keduanya BUKAN kursor mouse & bukan bug Flutter. Itu
  /// *interaction prompt* bawaan `<model-viewer>`: ikon tangan + animasi
  /// "wiggle" (kamera bergoyang kanan-kiri) yang sengaja ditampilkan untuk
  /// memberi tahu user bahwa model bisa di-drag.
  ///
  /// Kenapa prompt itu muncul: elemen sebelumnya memakai
  /// `camera-controls="false"`. Di HTML, atribut boolean cukup ADA saja
  /// sudah berarti TRUE (nilai "false" tidak dibaca) -> kontrol kamera
  /// sebenarnya AKTIF, dan `interaction-prompt` default ("auto") ikut
  /// jalan. Di BEV widget ini dibungkus `IgnorePointer`, jadi user tak
  /// pernah bisa "berinteraksi" -> prompt tidak pernah dianggap selesai:
  /// ikon tangan muncul terus + model goyang terus. Itu juga sebabnya
  /// perbaikan kursor di revisi ke-2 tidak berpengaruh apa-apa: yang
  /// tampak adalah PIKSEL yang digambar di canvas WebGL, bukan kursor OS.
  ///
  /// Perbaikan:
  ///  - atribut `camera-controls` dibuang sama sekali;
  ///  - `interaction-prompt="none"`, `disable-zoom/pan/tap`,
  ///    `pointer-events: none`;
  ///  - lapis pengaman: style penyembunyi slot prompt disuntik ke Shadow
  ///    DOM begitu model selesai dimuat.
  /// Bonus: tanpa animasi terus-menerus, `<model-viewer>` hanya merender
  /// saat ada yang berubah -> WebView2 idle (CPU/GPU jauh lebih ringan).
  /// Berlaku juga untuk VehicleStageWidget (memang tidak butuh drag).
  ///
  /// SNAPSHOT (opsional, `?snap=1`): setelah model selesai dimuat, halaman
  /// memotret dirinya lewat `<model-viewer>.toBlob()` (PNG), memastikan
  /// latar benar-benar transparan (cek alpha 4 sudut), lalu mengirim PNG
  /// base64 ke Dart (`{type:'snapshot', png:...}`). Dart bisa lalu
  /// membuang WebView2 sepenuhnya dan menampilkan gambar biasa — dipakai
  /// BEV karena ego-nya statis (rotasi dilakukan Flutter, bukan WebView).
  /// Gagal/opak -> dikirim `snapshot-failed`/`snapshot-opaque` dan WebView
  /// tetap dipakai apa adanya.
  ///
  /// DIAGNOSTICS: any in-page JS error, plus `<model-viewer>`'s own
  /// `error`/`load` events, are forwarded to Dart via
  /// `window.chrome.webview.postMessage(...)`. Listen for these on
  /// `WebviewController.webMessage` — this is what turns "silently blank"
  /// failures into a readable log line instead of a guessing game.
  String buildViewerHtml() {
    return '''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <script type="module" src="/$_modelViewerJsAssetPath"></script>
    <style>
      html, body {
        margin: 0;
        padding: 0;
        height: 100%;
        background: transparent;
        cursor: default;
        overflow: hidden;
      }
      model-viewer {
        width: 100%;
        height: 100%;
        background-color: transparent;
        --poster-color: transparent;
        cursor: default !important;
        pointer-events: none;
      }
    </style>
  </head>
  <body>
    <!-- SENGAJA tanpa atribut camera-controls (atribut boolean: ada = true,
         bahkan camera-controls="false" tetap AKTIF). interaction-prompt
         "none" mematikan ikon tangan + animasi wiggle. -->
    <model-viewer
      id="car"
      alt="Model 3D Mobil MEVI"
      interaction-prompt="none"
      disable-zoom
      disable-pan
      disable-tap
      touch-action="none"
    ></model-viewer>
    <script>
      function post(payload) {
        try {
          window.chrome.webview.postMessage(JSON.stringify(payload));
        } catch (e) {
          // Not running inside WebView2 — ignore.
        }
      }

      window.onerror = function (msg, url, line, col, error) {
        post({ type: 'js-error', msg: String(msg), url: url, line: line, col: col });
      };

      const car = document.getElementById('car');
      var wantSnapshot = false;

      // Lapis pengaman: sembunyikan slot interaction-prompt di Shadow DOM.
      function hidePromptSlots() {
        try {
          var root = car.shadowRoot;
          if (!root || root.getElementById('mevi-no-prompt')) return;
          var st = document.createElement('style');
          st.id = 'mevi-no-prompt';
          st.textContent =
            '.interaction-prompt, #default-interaction-prompt, ' +
            '[slot="interaction-prompt"] { display: none !important; ' +
            'visibility: hidden !important; }';
          root.appendChild(st);
        } catch (e) {
          post({ type: 'js-error', msg: 'hidePromptSlots: ' + e });
        }
      }

      // --- SNAPSHOT (lihat doc comment buildViewerHtml() di atas) ---
      var snapTries = 0;
      function scheduleSnapshot() {
        setTimeout(function () {
          // Tunggu model benar-benar tampil (reveal) sebelum difoto.
          if (car.modelIsVisible === false && snapTries < 20) {
            snapTries++;
            scheduleSnapshot();
            return;
          }
          takeSnapshot();
        }, 300);
      }

      async function takeSnapshot() {
        try {
          await car.updateComplete;
          var blob = await car.toBlob({ mimeType: 'image/png' });

          // Pastikan latar transparan: cek alpha 4 sudut.
          var url = URL.createObjectURL(blob);
          var img = new Image();
          await new Promise(function (res, rej) {
            img.onload = res;
            img.onerror = rej;
            img.src = url;
          });
          var c = document.createElement('canvas');
          c.width = img.naturalWidth;
          c.height = img.naturalHeight;
          var ctx = c.getContext('2d');
          ctx.drawImage(img, 0, 0);
          URL.revokeObjectURL(url);

          var w = c.width, h = c.height;
          var corners = [[0, 0], [w - 1, 0], [0, h - 1], [w - 1, h - 1]];
          for (var i = 0; i < corners.length; i++) {
            var a = ctx.getImageData(corners[i][0], corners[i][1], 1, 1).data[3];
            if (a > 8) {
              post({ type: 'snapshot-opaque' });
              return;
            }
          }

          var dataUrl = await new Promise(function (res, rej) {
            var fr = new FileReader();
            fr.onloadend = function () { res(fr.result); };
            fr.onerror = rej;
            fr.readAsDataURL(blob);
          });
          var b64 = String(dataUrl).substring(String(dataUrl).indexOf(',') + 1);
          post({ type: 'snapshot', png: b64, w: w, h: h });
        } catch (e) {
          post({ type: 'snapshot-failed', reason: String(e) });
        }
      }

      car.addEventListener('error', function (e) {
        post({
          type: 'model-viewer-error',
          detail: e && e.detail ? JSON.stringify(e.detail) : String(e),
        });
      });

      car.addEventListener('load', function () {
        post({ type: 'model-viewer-loaded', src: car.getAttribute('src') });
        hidePromptSlots();
        if (wantSnapshot) scheduleSnapshot();
      });

      // Called from Dart via controller.executeScript() whenever
      // steeringAngle changes.
      function setOrientation(value) {
        car.setAttribute('orientation', value);
      }

      // Everything the page needs (which .glb, initial orientation,
      // optional camera-orbit, optional snapshot) comes in as query params
      // so switching test assets / angles never requires touching this
      // HTML/service file — only car_3d_viewer_windows.dart.
      try {
        const params = new URLSearchParams(window.location.search);
        const glb = params.get('glb');
        const initialOrientation = params.get('ori');
        const orbit = params.get('orbit');
        wantSnapshot = params.get('snap') === '1';
        post({ type: 'debug-params', glb: glb, ori: initialOrientation, orbit: orbit, snap: wantSnapshot });
        if (initialOrientation) setOrientation(initialOrientation);
        if (orbit) car.setAttribute('camera-orbit', orbit);
        // src terakhir: orientation & orbit sudah terpasang sebelum load.
        if (glb) car.setAttribute('src', glb);
      } catch (e) {
        post({ type: 'js-error', msg: 'failed to read query params: ' + e });
      }
    </script>
  </body>
</html>
''';
  }

  /// Starts the loopback server once. Safe to call repeatedly — later
  /// calls are no-ops while a server is already running.
  Future<void> start() async {
    if (isRunning) return;

    final assetsDir = _flutterAssetsDir();
    final staticHandler = createStaticHandler(
      assetsDir.path,
      defaultDocument: null,
      serveFilesOutsidePath: false,
    );

    Future<shelf.Response> router(shelf.Request request) async {
      if (request.url.path == viewerPath.substring(1)) {
        return shelf.Response.ok(
          buildViewerHtml(),
          headers: {'content-type': 'text/html; charset=utf-8'},
        );
      }
      return staticHandler(request);
    }

    final server = await shelf_io.serve(
      router,
      InternetAddress.loopbackIPv4,
      0,
    );
    _server = server;
    _port = server.port;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
  }
}
