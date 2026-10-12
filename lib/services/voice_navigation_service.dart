import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

/// Data model untuk instruksi pemandu navigasi suara & HUD banner.
class NavigationInstruction {
  final String text;
  final String spokenText;
  final String distanceText;
  final IconData icon;
  final Color bannerColor;
  final bool isWarning;

  const NavigationInstruction({
    required this.text,
    required this.spokenText,
    this.distanceText = '',
    required this.icon,
    this.bannerColor = const Color(0xFF0288D1),
    this.isWarning = false,
  });
}

/// Service pemandu navigasi berbasis suara (Google Maps style) untuk BEV Dashboard.
/// Menggunakan Windows Native SAPI Speech Synthesizer yang super ringan (<50ms startup),
/// bebas lag, dan dilengkapi atomic cancellation token agar tidak terjadi penumpukan proses
/// atau suara berulang-ulang yang menyebabkan freeze/not responding.
class VoiceNavigationService {
  VoiceNavigationService._internal();
  static final VoiceNavigationService _instance =
      VoiceNavigationService._internal();
  factory VoiceNavigationService() => _instance;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  final StreamController<bool> _muteController =
      StreamController<bool>.broadcast();
  Stream<bool> get muteStream => _muteController.stream;

  final StreamController<NavigationInstruction?> _instructionController =
      StreamController<NavigationInstruction?>.broadcast();
  Stream<NavigationInstruction?> get instructionStream =>
      _instructionController.stream;

  NavigationInstruction? _currentInstruction;
  NavigationInstruction? get currentInstruction => _currentInstruction;

  Process? _activeSpeechProcess;
  int _speechGeneration = 0;
  String? _lastSpokenText;
  DateTime? _lastSpokenTimestamp;

  void toggleMute() {
    _isMuted = !_isMuted;
    _muteController.add(_isMuted);
    if (_isMuted) {
      stop();
    }
  }

  void setMute(bool muted) {
    _isMuted = muted;
    _muteController.add(_isMuted);
    if (_isMuted) {
      stop();
    }
  }

  /// Memperbarui visual HUD banner instruksi navigasi di layar secara realtime.
  /// Secara default TIDAK membunyikan suara (playVoice = false) agar tidak memicu
  /// pemanggilan proses TTS pada setiap frame websocket frekuensi tinggi.
  void announce(NavigationInstruction instruction, {bool playVoice = false}) {
    _currentInstruction = instruction;
    _instructionController.add(instruction);

    if (playVoice && !_isMuted) {
      speak(instruction.spokenText);
    }
  }

  /// Membunyikan suara navigasi menggunakan Native Windows SAPI Speech Synthesizer.
  /// Dilengkapi debouncing dan pembatalan atomic agar suara lama langsung terputus
  /// dan tidak menumpuk di latar belakang OS.
  void speak(String text) {
    final cleanText = text.trim();
    if (_isMuted || cleanText.isEmpty) return;

    // Cegah duplikasi audio kalimat yang persis sama dalam jeda singkat (< 3.5 detik)
    final now = DateTime.now();
    if (_lastSpokenText == cleanText &&
        _lastSpokenTimestamp != null &&
        now.difference(_lastSpokenTimestamp!).inMilliseconds < 3500) {
      return;
    }

    _lastSpokenText = cleanText;
    _lastSpokenTimestamp = now;

    // Increment generation ID untuk membatalkan proses sebelumnya yang masih antre
    final generation = ++_speechGeneration;

    // Hentikan proses suara aktif saat ini
    _killActiveProcess();

    try {
      if (Platform.isWindows) {
        final escaped = cleanText.replaceAll("'", "''").replaceAll('"', '`"');
        // Gunakan COM SAPI.SpVoice native Windows (super ringan, tidak compile .NET CLR)
        Process.start(
          'powershell',
          [
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            "\$s = New-Object -ComObject SAPI.SpVoice; \$s.Rate = 1; \$s.Speak('$escaped');",
          ],
        ).then((process) {
          // Jika generation telah berubah (misal user pindah halaman atau ada instruksi baru),
          // bunuh proses seketika tanpa membunyikan suara!
          if (generation != _speechGeneration) {
            _killProcessInstance(process);
            return;
          }
          _activeSpeechProcess = process;
          process.exitCode.then((_) {
            if (_activeSpeechProcess == process) {
              _activeSpeechProcess = null;
            }
          });
        }).catchError((e) {
          debugPrint('VoiceNavigationService speak error: $e');
        });
      }
    } catch (e) {
      debugPrint('VoiceNavigationService failed: $e');
    }
  }

  void _killProcessInstance(Process process) {
    try {
      final pid = process.pid;
      process.kill();
      if (Platform.isWindows && pid > 0) {
        Process.run('taskkill', ['/F', '/T', '/PID', '$pid'])
            .catchError((_) => ProcessResult(pid, -1, '', ''));
      }
    } catch (_) {}
  }

  void _killActiveProcess() {
    if (_activeSpeechProcess != null) {
      _killProcessInstance(_activeSpeechProcess!);
      _activeSpeechProcess = null;
    }
  }

  /// Menghentikan seluruh proses suara yang sedang berjalan seketika
  void stop() {
    _speechGeneration++; // Invalidasi semua pending speech callback
    _lastSpokenText = null;
    _killActiveProcess();
  }

  /// Membersihkan tampilan HUD visual dan mematikan seluruh audio navigasi
  void clearInstruction() {
    _currentInstruction = null;
    _instructionController.add(null);
    stop();
  }
}
