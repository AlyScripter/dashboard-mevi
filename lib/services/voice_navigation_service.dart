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
/// Menggunakan Windows Native Speech Synthesizer untuk ucapan suara berbahasa Indonesia/Inggris
/// yang jernih, responsif, dan bebas lag.
class VoiceNavigationService {
  VoiceNavigationService._internal();
  static final VoiceNavigationService _instance = VoiceNavigationService._internal();
  factory VoiceNavigationService() => _instance;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  final StreamController<bool> _muteController = StreamController<bool>.broadcast();
  Stream<bool> get muteStream => _muteController.stream;

  final StreamController<NavigationInstruction?> _instructionController =
      StreamController<NavigationInstruction?>.broadcast();
  Stream<NavigationInstruction?> get instructionStream =>
      _instructionController.stream;

  NavigationInstruction? _currentInstruction;
  NavigationInstruction? get currentInstruction => _currentInstruction;

  Process? _activeSpeechProcess;

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

  /// Menampilkan banner instruksi visual dan menyuarakan instruksi via suara
  void announce(NavigationInstruction instruction) {
    _currentInstruction = instruction;
    _instructionController.add(instruction);

    if (!_isMuted) {
      speak(instruction.spokenText);
    }
  }

  /// Membunyikan suara navigasi menggunakan Native Windows Speech Synthesizer
  void speak(String text) {
    if (_isMuted || text.trim().isEmpty) return;

    try {
      if (Platform.isWindows) {
        // Hentikan proses suara sebelumnya jika ada
        _activeSpeechProcess?.kill();

        final escaped = text.replaceAll("'", "''").replaceAll('"', '`"');
        // Jalankan PowerShell SpeechSynthesizer non-blocking
        Process.start(
          'powershell',
          [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            'Add-Type -AssemblyName System.Speech; '
                '\$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer; '
                '\$synth.Rate = 1; '
                '\$synth.Speak(\'$escaped\');',
          ],
        ).then((process) {
          _activeSpeechProcess = process;
        }).catchError((e) {
          debugPrint('VoiceNavigationService speak error: $e');
        });
      }
    } catch (e) {
      debugPrint('VoiceNavigationService failed: $e');
    }
  }

  void stop() {
    try {
      _activeSpeechProcess?.kill();
      _activeSpeechProcess = null;
    } catch (_) {}
  }

  void clearInstruction() {
    _currentInstruction = null;
    _instructionController.add(null);
    stop();
  }
}
