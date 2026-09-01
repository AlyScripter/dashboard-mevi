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
class SettingsPage extends StatefulWidget {
  final VoidCallback? onBack;

  const SettingsPage({super.key, this.onBack});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.settingsPageBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.glassTextPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 18),
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
