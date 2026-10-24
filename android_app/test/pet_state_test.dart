import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:moonpet/state/pet_state.dart';

void main() {
  group('Stats', () {
    test('bond level naik dengan akar XP', () {
      final s = Stats();
      expect(s.bondLv, 1);
      s.xp = 40; // sqrt(40/40) = 1 -> Lv 2
      expect(s.bondLv, 2);
      s.xp = 160; // sqrt(160/40) = 2 -> Lv 3
      expect(s.bondLv, 3);
      s.xp = 360; // sqrt(360/40) = 3 -> Lv 4
      expect(s.bondLv, 4);
    });

    test('serialisasi JSON pulih-pergi', () {
      final s = Stats()
        ..hits = 13
        ..xp = 200
        ..mood = 45
        ..bruises = [
          [0.1, -0.2, 1.5]
        ]
        ..achievements = ['ko_1']
        ..chatLog = [
          {'role': 'user', 'content': 'hai'}
        ];
      final s2 = Stats.fromJson(s.toJson());
      expect(s2.hits, 13);
      expect(s2.mood, 45);
      expect(s2.bruises.first, [0.1, -0.2, 1.5]);
      expect(s2.achievements, ['ko_1']);
      expect(s2.chatLog.first['content'], 'hai');
    });
  });

  group('PetState mood', () {
    test('ambang mood', () {
      final p = PetState(Stats()..mood = 75);
      expect(p.moodId, 'senang');
      p.stats.mood = 50;
      expect(p.moodId, 'biasa');
      p.stats.mood = 20;
      expect(p.moodId, 'sedih');
      p.stats.mood = 5;
      expect(p.moodId, 'ngambek');
    });
  });

  group('PetState aksi', () {
    test('hurt menambah hit, memar, dan turunkan mood', () {
      final p = PetState(Stats());
      var ko = 0;
      p.hurt('tampar', onKo: () => ko++, onAchievement: (_) {});
      expect(p.stats.hits, 1);
      expect(p.stats.bruises.length, 1);
      expect(p.stats.mood, lessThan(72));
      expect(p.vx, isNot(0));
    });

    test('hitung-K.O.: setiap N hit memicu KO', () {
      final p = PetState(Stats());
      var ko = 0;
      for (var i = 0; i < 13; i++) {
        p.hurt('cubit', onKo: () => ko++, onAchievement: (_) {});
      }
      expect(ko, greaterThanOrEqualTo(1));
      expect(p.ko, isTrue);
      expect(p.stats.kos, greaterThanOrEqualTo(1));
    });

    test('love menaikkan mood dan xp', () {
      final p = PetState(Stats()..mood = 50);
      p.love('elus', onAchievement: (_) {});
      expect(p.stats.pats, 1);
      expect(p.stats.xp, 4);
      expect(p.stats.mood, 54);
      expect(p.particles, isNotEmpty);
    });

    test('ngambek: kadang menolak kasih sayang', () {
      final p = PetState(Stats()..mood = 3);
      p.love('peluk', onAchievement: (_) {});
      // bisa ditolak (bubble hmph) atau diterima; asal tidak crash
      expect(p.stats.hugs, anyOf(0, 1));
    });
  });

  group('PetState fisika', () {
    test('gravitasi + lantai memantul lalu diam', () {
      final p = PetState(Stats());
      p.vy = -900;
      p.love('elus', onAchievement: (_) {}); // no-op fisika
      for (var i = 0; i < 400; i++) {
        p.tick(33,
            size: const Size(400, 800), floorY: 0);
      }
      expect(p.vy, 0);
      expect(p.y, 0);
    });

    test('KO respawn memulihkan mood', () {
      final p = PetState(Stats()..mood = 10);
      p.hurt('tampar', onKo: () {}, onAchievement: (_) {});
      p.hurt('cubit', onKo: () {}, onAchievement: (_) {});
      p.hurt('jitak', onKo: () {}, onAchievement: (_) {});
      p.hurt('lempar', onKo: () {}, onAchievement: (_) {});
      p.hurt('tampar', onKo: () {}, onAchievement: (_) {});
      p.hurt('cubit', onKo: () {}, onAchievement: (_) {});
      if (p.ko) {
        // jalankan waktu respawn
        for (var i = 0; i < 300; i++) {
          p.tick(33, size: const Size(400, 800), floorY: 0);
        }
        expect(p.ko, isFalse);
        expect(p.ghost, greaterThan(-1));
        expect(p.stats.mood, greaterThan(10));
      }
    });
  });
}
