/// MoonPet — peliharaan AI offline.
/// Entry point: muat model LFM2.5-350M dari penyimpanan lokal lalu tampilkan Momo.
library;

import 'package:flutter/material.dart';

import 'brain/llama_ffi.dart';
import 'ui/home_screen.dart';

void main() {
  runApp(const MoonPetApp());
}

class MoonPetApp extends StatelessWidget {
  const MoonPetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoonPet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF12101f),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8b5cf6),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      home: const BootScreen(),
    );
  }
}

/// Layar pemuatan: inisialisasi otak (model 229 MB) dengan status hidup.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  final _engine = MomoEngine();
  String _status = 'mencari otak Momo…';
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      setState(() => _status = 'mencari berkas model…');
      final modelPath = await resolveModelPath();
      if (modelPath == null) {
        throw Exception(
            'berkas model (libmoonpetmodel.so) tidak ditemukan di penyimpanan aplikasi');
      }
      setState(() => _status = 'membangunkan Momo (memuat 229 MB model)…');
      final msg = await _engine.load(modelPath, nCtx: 2048, nThreads: 4);
      setState(() => _status = msg);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(engine: _engine)),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    // engine dimiliki oleh HomeScreen setelah navigasi; jangan dispose di sini
    // bila sukses. dispose hanya bila gagal boot.
    if (_error != null) _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12101f),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // bulan kecil berdenyut
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.9, end: 1.05),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeInOut,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment(-0.3, -0.3),
                      colors: [Colors.white, Color(0xFFd9d0f0)],
                    ),
                    boxShadow: [
                      BoxShadow(color: Color(0x668b5cf6), blurRadius: 30),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text('MoonPet',
                  style: TextStyle(
                      color: Color(0xFFE8E3F5),
                      fontSize: 30,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1)),
              const SizedBox(height: 8),
              const Text('peliharaan AI offline — 100% di perangkatmu',
                  style: TextStyle(color: Color(0xFF776f99), fontSize: 12)),
              const SizedBox(height: 36),
              if (_error == null) ...[
                const CircularProgressIndicator(
                    strokeWidth: 2.4, color: Color(0xFF8b5cf6)),
                const SizedBox(height: 18),
                Text(_status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFFc9c2e4), fontSize: 13)),
              ] else ...[
                const Text('😭', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text('Momo gagal bangun:\n$_error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFFff8888), fontSize: 13, height: 1.5)),
                const SizedBox(height: 8),
                const Text(
                    'Coba pasang ulang aplikasi. Bila tetap gagal, laporkan ke '
                    'github.com/lunarjjo/moonpet/issues',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF776f99), fontSize: 11)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
