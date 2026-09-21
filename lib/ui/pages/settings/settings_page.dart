import 'package:flutter/material.dart';
import 'widgets/data_source_section.dart';
import 'widgets/about_section.dart';
import '../../../core/theme/colors.dart';

/// Settings Page - Dedicated page for all app settings
///
/// REVISI: dihapus bar/app-bar-nya sepenuhnya (tidak ada lagi ikon panah
/// kembali atau ikon gerigi) — hanya menyisakan judul teks "Settings"
/// polos langsung di atas konten, tanpa kotak/background terpisah.
/// Data Source & About sekarang disusun berdampingan (kiri-kanan) alih-
/// alih ditumpuk atas-bawah, supaya semuanya muat tanpa perlu scroll
/// halaman. Latar halaman dibuat gelap pekat, sementara kedua kartu
/// section diberi warna navy-biru yang jelas lebih terang supaya
/// kontras dengan latar dan tidak menyatu — senada dengan referensi
/// panel "CONTROL".
///
/// REVISI #2: judul teks "Settings" beserta jarak di atasnya dihapus
/// total — kartu "Data Source" / "About" sekarang langsung menempel ke
/// tepi atas halaman (hanya dibatasi SafeArea + padding halaman) supaya
/// tidak perlu discroll untuk melihat bagian atas kartu.
///
/// REVISI #3: light mode sekarang punya style sendiri — background
/// halaman berubah jadi biru solid (bukan lagi navy gelap), sementara
/// kartu "Data Source" / "About" berubah jadi putih bersih. Semua
/// konten di dalam kedua kartu (`DataSourceSection` / `AboutSection`)
/// menyesuaikan warna teks/ikon/border masing-masing. Dark mode tidak
/// berubah sama sekali.
class SettingsPage extends StatefulWidget {
  final VoidCallback? onBack;

  const SettingsPage({super.key, this.onBack});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      color: isLight ? AppColors.settingsPageBgLight : AppColors.settingsPageBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Two side-by-side panels instead of a single scrolling
              // column — Data Source on the left, About on the right —
              // so both are visible together without scrolling the page.
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Expanded(
                      child: SingleChildScrollView(child: DataSourceSection()),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: SingleChildScrollView(child: AboutSection()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
