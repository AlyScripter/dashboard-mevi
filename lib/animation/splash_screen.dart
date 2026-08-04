import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true); // Mengulang animasi secara bolak-balik

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0), // Mulai dari bawah layar
      end: const Offset(0.0, 0.0), // Berhenti di tengah layar
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Warna latar belakang splash screen
      body: Center(
        child: SlideTransition(
          position: _offsetAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Image.asset(
              'assets/images/mevicar.png', // Pastikan Anda menambahkan logo ke folder assets
              width: 150, // Sesuaikan ukuran gambar
              height: 150,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.directions_car, size: 100, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
