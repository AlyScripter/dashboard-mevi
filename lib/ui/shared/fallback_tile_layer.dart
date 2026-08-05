// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import '../../config/map_config.dart';

// class FallbackTileLayer extends StatelessWidget {
//   const FallbackTileLayer({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return TileLayer(
//       urlTemplate: MapConfig.openStreetMapUrl,
//       // Use simple NetworkTileProvider for now
//       // TODO: Implement proper caching solution later
//       tileProvider: NetworkTileProvider(),
//       maxNativeZoom: 19,
//       maxZoom: MapConfig.maxZoom,
//       minZoom: MapConfig.minZoom,
//       tileSize: 256,
//       retinaMode: false,
//       keepBuffer: 4, // Increase buffer to reduce requests
//       panBuffer: 2, // Increase pan buffer
//       additionalOptions: const {
//         'User-Agent': 'MEVI-Dashboard/1.0 (contact@mevi.com)',
//         'Cache-Control': 'max-age=86400',
//         'Connection': 'keep-alive',
//         'Accept': 'image/png,image/jpeg,image/*,*/*;q=0.8',
//         'Accept-Encoding': 'gzip, deflate',
//       },
//       errorTileCallback: (tile, error, stackTrace) {
//         debugPrint('Tile load error: $error');
//       },
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../config/map_config.dart';

class FallbackTileLayer extends StatelessWidget {
  const FallbackTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: MapConfig.openStreetMapUrl,

      // Mengirimkan pengenal aplikasi kustom
      userAgentPackageName: 'com.mevi.dashboard',

      // HAPUS kata 'const' di depan Map headers agar bisa dimodifikasi oleh plugin
      tileProvider: NetworkTileProvider(
        headers: {
          'User-Agent': 'MEVI-Dashboard/1.0 (contact@mevi.com)',
          'Accept': 'image/png,image/jpeg,image/*,*/*;q=0.8',
        },
      ),
      maxNativeZoom: 19,
      maxZoom: MapConfig.maxZoom,
      minZoom: MapConfig.minZoom,
      tileSize: 256,
      retinaMode: false,
      keepBuffer: 4,
      panBuffer: 2,
      errorTileCallback: (tile, error, stackTrace) {
        debugPrint('Tile load error: $error');
      },
    );
  }
}
