/// Panel "Tentang" MoonPet: info, atribusi, dan reset statistik.
library;

import 'package:flutter/material.dart';

class AboutSheet extends StatelessWidget {
  final VoidCallback? onReset;
  const AboutSheet({super.key, this.onReset});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('MoonPet v0.1.0',
                    style: TextStyle(
                        color: Color(0xFFE8E3F5),
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF8d84ad)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Peliharaan AI offline: menemani kesepian, diajak curhat, '
              'dan… boleh dipukul untuk melepas penat. Semua berjalan 100% '
              'lokal di perangkatmu — tanpa internet, tanpa server luar, '
              'tanpa data yang dikirim ke mana pun.',
              style: TextStyle(color: Color(0xFFc9c2e4), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 12),
            const Text('Otak',
                style: TextStyle(
                    color: Color(0xFFb9a5ff),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Model LFM2.5-350M (Q4_K_M, 229 MB) berjalan lokal lewat llama.cpp. '
              'Balasan chat bahasa Inggris sederhana — model kecil ini tidak '
              'dilatih untuk bahasa Indonesia, jadi aplikasi menerjemahkan '
              'curhatmu kata-per-kata (kamus kurang lebih 300 kata) sebelum '
              'dikirim ke Momo. Kualitas khas model 350M: kadang nyambung, '
              'kadang melantur 💜',
              style: TextStyle(color: Color(0xFFc9c2e4), fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: 12),
            const Text('Kredit & lisensi',
                style: TextStyle(
                    color: Color(0xFFb9a5ff),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Dibuat oleh Lunar agent (github.com/lunarjjo) atas framework '
              'algoritma AI yang dikembangkan oleh @kasyaira. Model: LiquidAI '
              'LFM2.5-350M — LFM Open License v1.0. Runtime: llama.cpp (MIT). '
              'Karakter Momo digambar prosedural — tanpa aset pihak ketiga.',
              style: TextStyle(color: Color(0xFFc9c2e4), fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2d2a44),
                    foregroundColor: const Color(0xFFff6b81)),
                onPressed: () {
                  final ctx = context;
                  showDialog<void>(
                    context: ctx,
                    builder: (dctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1d1a30),
                      title: const Text('Reset statistik?',
                          style: TextStyle(color: Color(0xFFE8E3F5), fontSize: 16)),
                      content: const Text(
                          'Pukulan, level ikatan, mood, dan riwayat curhat akan dihapus.',
                          style: TextStyle(color: Color(0xFFc9c2e4), fontSize: 13)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(dctx),
                            child: const Text('Batal')),
                        FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFff6b81)),
                            onPressed: () {
                              Navigator.pop(dctx);
                              Navigator.pop(ctx);
                              onReset?.call();
                            },
                            child: const Text('Reset')),
                      ],
                    ),
                  );
                },
                child: const Text('Reset statistik'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
