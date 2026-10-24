/// Keadaan peliharaan Momo: statistik, mood, fisika kartun, partikel,
/// pencapaian, dan penyimpanan JSON lokal (tanpa plugin — dart:io murni).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

class Stats {
  int hits = 0, pats = 0, feeds = 0, hugs = 0, chats = 0, kos = 0, xp = 0;
  int mood = 72; // 0..100
  List<List<double>> bruises = []; // [x, y, rot] relatif badan
  List<String> achievements = [];
  List<Map<String, String>> chatLog = [];
  int get bondLv => math.sqrt(xp / 40).floor() + 1;

  Map<String, dynamic> toJson() => {
        'hits': hits, 'pats': pats, 'feeds': feeds, 'hugs': hugs,
        'chats': chats, 'kos': kos, 'xp': xp, 'mood': mood,
        'bruises': bruises, 'achievements': achievements, 'chatLog': chatLog,
      };

  static Stats fromJson(Map<String, dynamic> j) => Stats()
    ..hits = j['hits'] ?? 0
    ..pats = j['pats'] ?? 0
    ..feeds = j['feeds'] ?? 0
    ..hugs = j['hugs'] ?? 0
    ..chats = j['chats'] ?? 0
    ..kos = j['kos'] ?? 0
    ..xp = j['xp'] ?? 0
    ..mood = j['mood'] ?? 72
    ..bruises = ((j['bruises'] ?? []) as List)
        .map((b) => (b as List).map((v) => (v as num).toDouble()).toList())
        .toList()
    ..achievements = ((j['achievements'] ?? []) as List).cast<String>()
    ..chatLog = ((j['chatLog'] ?? []) as List)
        .map((m) => Map<String, String>.from(m as Map))
        .toList();
}

class PetState with ChangeNotifier {
  final Stats stats;
  PetState(this.stats);

  // ---- domain fisika & animasi ----
  double x = 0, y = 0, vx = 0, vy = 0, rot = 0, vrot = 0;
  double sx = 1, sy = 1, targetSx = 1, targetSy = 1;
  double breathe = 0, tailPhase = 0, dizzySpin = 0, shake = 0;
  int stateT = 0; // ms tersisa untuk state sementara
  String state = 'idle'; // idle/happy/hug/eat/dizzy/sulk/ko
  bool ko = false;
  double koT = 0, ghost = 0;
  int blink = 0, blinkT = 2000 + math.Random().nextInt(3000);
  String? bubble;
  int bubbleT = 0;
  double floorY = 0; // di-set oleh UI sesuai ukuran layar

  final List<Particle> particles = [];

  bool get isBusy => ko || ghost > 0;

  // ---- mood ----
  String get moodId {
    if (moodV >= 70) return 'senang';
    if (moodV >= 40) return 'biasa';
    if (moodV >= 15) return 'sedih';
    return 'ngambek';
  }

  String get moodLabel {
    switch (moodId) {
      case 'senang': return 'senang';
      case 'biasa': return 'biasa saja';
      case 'sedih': return 'sedih';
      default: return 'ngambek';
    }
  }

  int get moodV => stats.mood;
  void addMood(int d) {
    stats.mood = (stats.mood + d).clamp(0, 100);
    notifyListeners();
  }

  // ---- aksi ----
  void impact(double dir, double force) {
    vx += dir * force;
    vy -= force * (0.2 + math.Random().nextDouble() * 0.35);
    vrot += dir * force * 0.0022;
    targetSx = 1.32;
    targetSy = 0.68;
    shake = math.min(26, shake + force * 0.03);
  }

  void addBruise() {
    if (stats.bruises.length < 9) {
      stats.bruises.add([
        -0.7 + math.Random().nextDouble() * 1.4,
        -0.6 + math.Random().nextDouble() * 1.2,
        math.Random().nextDouble() * 6.28,
      ]);
    }
  }

  void hurt(String kind, {required VoidCallback onKo, required void Function(String) onAchievement}) {
    if (isBusy) return;
    stats.hits++;
    stats.xp += 2;
    final dir = x < 0 ? 1.0 : -1.0; // x relatif pusat di-set UI
    const force = 260.0;
    switch (kind) {
      case 'tampar':
        impact(dir, force);
        bubble = pick(['aduh!! 😖', 'aaw!', 'kenapa sih!!', 'it hurts!!']);
        break;
      case 'jitak':
        vy = -force * 0.9;
        targetSx = 0.7;
        targetSy = 1.3;
        shake = math.min(26, shake + 10.0);
        state = 'dizzy';
        stateT = 2400;
        bubble = pick(['duh!! kepala…', 'bonk!! 💫', 'bintang…']);
        for (var i = 0; i < 12; i++) {
          particles.add(Particle('star', x, y - 60));
        }
        break;
      case 'cubit':
        targetSx = 1.25;
        targetSy = 0.75;
        vx = dir * 90;
        bubble = pick(['aaw aaw!', 'pinchnya sakit!!', 'pipiku!!']);
        break;
      case 'lempar':
        vx = dir * (700 + math.Random().nextDouble() * 350);
        vy = -(620 + math.Random().nextDouble() * 230);
        vrot = dir * (9 + math.Random().nextDouble() * 5);
        shake = math.min(26, shake + 8.0);
        bubble = pick(['waaa—!!', 'terbangggg', 'AAAAAAA!']);
        break;
    }
    addMood(kind == 'lempar' ? -9 : -6);
    addBruise();
    final koAt = (13 - stats.hits ~/ 40).clamp(6, 13);
    if (stats.hits % koAt == 0) {
      ko = true;
      koT = 3200;
      state = 'ko';
      stats.kos++;
      bubble = null;
      onKo();
      if (stats.kos == 1) onAchievement('ko_1');
      if (stats.kos >= 10) onAchievement('ko_10');
    }
    if (stats.hits >= 50) onAchievement('hit_50');
    if (stats.hits >= 100) onAchievement('hit_100');
    notifyListeners();
  }

  void love(String kind, {required void Function(String) onAchievement}) {
    if (isBusy) return;
    if (moodId == 'ngambek' && math.Random().nextDouble() < 0.5) {
      bubble = pick(['hmph! belum maaf!', '…belim!']);
      notifyListeners();
      return;
    }
    stats.xp += 4;
    switch (kind) {
      case 'elus':
        stats.pats++;
        state = 'happy';
        stateT = 1800;
        for (var i = 0; i < 5; i++) {
          particles.add(Particle('heart', x, y - 30));
        }
        addMood(4);
        bubble = pick(['mrrrp~ 💜', 'enak…', 'lagi lagi!']);
        if (stats.pats == 1) onAchievement('first_pat');
        break;
      case 'makan':
        stats.feeds++;
        state = 'eat';
        stateT = 2200;
        for (var i = 0; i < 7; i++) {
          particles.add(Particle('spark', x, y - 20));
        }
        addMood(6);
        bubble = pick(['nom nom~', 'enyak enyak!', 'makasih! 🍪']);
        if (stats.feeds >= 10) onAchievement('feed_10');
        break;
      case 'peluk':
        stats.hugs++;
        state = 'hug';
        stateT = 2400;
        for (var i = 0; i < 10; i++) {
          particles.add(Particle('heart', x, y - 40));
        }
        addMood(8);
        bubble = pick(['aku sayang kamu 🤗', 'hangat…', 'jangan pergi ya…']);
        if (stats.hugs >= 5) onAchievement('hug_5');
        break;
    }
    if (stats.bondLv >= 5) onAchievement('bond_5');
    notifyListeners();
  }

  /// Satu tick fisika/animasi (ms).
  void tick(int dtMs, {required Size size, required double floorY}) {
    final dt = dtMs / 1000.0;
    breathe += dt * (state == 'happy' ? 9 : 3.2);
    tailPhase += dt * (state == 'happy' ? 7 : 2.6);
    if (stateT > 0) {
      stateT -= dtMs;
      if (stateT <= 0 && !ko && ghost <= 0) {
        state = moodId == 'ngambek' ? 'sulk' : 'idle';
      }
    }
    if (bubbleT > 0) {
      bubbleT -= dtMs;
      if (bubbleT <= 0) bubble = null;
    }
    blinkT -= dtMs;
    if (blinkT <= 0) {
      blink = 120;
      blinkT = 2200 + math.Random().nextInt(3300);
    }
    if (blink > 0) blink -= dtMs;

    // fisika
    if (!ko && ghost <= 0) {
      x += vx * dt;
      y += vy * dt;
      rot += vrot * dt;
      vrot *= (1 - dt * 2.2);
      final R = (size.shortestSide * 0.11).clamp(46.0, 92.0);
      if (y > floorY) {
        if (vy > 200) {
          for (var i = 0; i < 6; i++) {
            particles.add(Particle('spark', x, y + 40));
          }
        }
        y = floorY;
        vy = -vy.abs() * 0.45;
        if (vy.abs() < 60) vy = 0;
      } else if (y < floorY - 2 && vy != 0) {
        vy += 1500 * dt;
      }
      if (vx != 0 && y >= floorY - 1) vx *= (1 - dt * 3);
      if (x < -size.width / 2 + R) {
        x = -size.width / 2 + R;
        vx = vx.abs() * 0.5;
      }
      if (x > size.width / 2 - R) {
        x = size.width / 2 - R;
        vx = -vx.abs() * 0.5;
      }
    }
    sx += (targetSx - sx) * dt * 9;
    sy += (targetSy - sy) * dt * 9;
    if ((targetSx - sx).abs() < 0.01) {
      targetSx = 1;
      targetSy = 1;
    }
    shake *= (1 - dt * 7);
    if (shake < 0.15) shake = 0;

    // KO -> respawn
    if (ko) {
      koT -= dtMs;
      if (koT <= 0) {
        ko = false;
        ghost = 2200;
        bubble = pick(['aku kembali~', 'maafkan kamu…', 'halo lagi! 💫', 'miss me?']);
        bubbleT = 2400;
        for (var i = 0; i < 8; i++) {
          particles.add(Particle('heart', x, y - 60));
        }
        addMood(12);
      }
    }
    if (ghost > 0) {
      ghost -= dtMs;
      y = floorY - (2200 - ghost).abs() * math.sin((2.2 - ghost / 1000.0) * 3) * 0.012;
      if (ghost <= 0) {
        state = 'idle';
        y = floorY;
        notifyListeners();
      }
    }

    // partikel
    for (var i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.t += dt;
      p.vy += 280 * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      if (p.t > p.life) particles.removeAt(i);
    }
  }

  // ---- persistensi ----
  File? _file;

  void attachStore(File file) => _file = file;

  Future<void> save() async {
    final f = _file;
    if (f == null) return;
    try {
      await f.writeAsString(jsonEncode(stats.toJson()));
    } catch (e) {
      debugPrint('gagal menyimpan: $e');
    }
  }

  Future<void> reset() async {
    stats.hits = stats.pats = stats.feeds = stats.hugs = stats.chats = 0;
    stats.kos = stats.xp = 0;
    stats.mood = 72;
    stats.bruises = [];
    stats.achievements = [];
    stats.chatLog = [];
    notifyListeners();
    await save();
  }
}

class Particle {
  final String kind; // heart | star | spark
  double x, y, vx, vy, t = 0, life, size, rot;
  final int hue;
  Particle(this.kind, this.x, this.y)
      : vx = (math.Random().nextDouble() * 2 - 1) * 320,
        vy = -60 - math.Random().nextDouble() * 260,
        life = 0.5 + math.Random().nextDouble() * 0.6,
        size = 6 + math.Random().nextDouble() * 10,
        rot = math.Random().nextDouble() * 6.28,
        hue = kind == 'heart'
            ? 320 + math.Random().nextInt(25)
            : kind == 'star'
                ? 45 + math.Random().nextInt(15)
                : 260 + math.Random().nextInt(25);
}

// util kecil (tanpa dependensi)
T pick<T>(List<T> list) => list[math.Random().nextInt(list.length)];
