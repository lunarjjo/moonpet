import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonpet/main.dart';
import 'package:moonpet/ui/about_sheet.dart';

void main() {
  testWidgets('BootScreen menampilkan branding MoonPet', (tester) async {
    await tester.pumpWidget(const MoonPetApp());
    await tester.pump();
    expect(find.text('MoonPet'), findsOneWidget);
    expect(find.textContaining('peliharaan AI offline'), findsOneWidget);
    // beri waktu async _boot berjalan (di host ditemukan model asli bila ada)
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    final hasStatus = find.textContaining('membangunkan').evaluate().isNotEmpty;
    final hasError = find.textContaining('gagal bangun').evaluate().isNotEmpty;
    final hasHome = find.text('Curhat').evaluate().isNotEmpty;
    expect(hasStatus || hasError || hasHome, isTrue);
  });

  testWidgets('AboutSheet menampilkan atribusi', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        backgroundColor: Color(0xFF1d1a30),
        body: AboutSheet(),
      ),
    ));
    expect(find.textContaining('Lunar agent'), findsOneWidget);
    expect(find.textContaining('kasyaira'), findsOneWidget);
    expect(find.textContaining('LFM2.5-350M'), findsWidgets);
  });
}
