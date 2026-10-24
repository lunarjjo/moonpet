/// Layar utama MoonPet: Momo + dock alat + chip statistik + panel curhat.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../brain/llama_ffi.dart';
import '../state/pet_state.dart';
import 'about_sheet.dart';
import 'chat_sheet.dart';
import 'pet_painter.dart';

class HomeScreen extends StatefulWidget {
  final MomoEngine engine;
  const HomeScreen({super.key, required this.engine});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  PetState pet = PetState(Stats());
  Timer? _tick;
  final _toasts = <_Toast>[];
  final Set<String> _shown = {};

  static const _lunarBg = Color(0xFF12101f);
  static const _lunarViolet = Color(0xFF8b5cf6);

  static const Map<String, (String, String)> _achievements = {
    'first_pat': ('Sapaan hangat', 'Elusan pertama untuk Momo'),
    'first_hit': ('Tangan pertama', 'Tamparan pertama tercatat'),
    'first_chat': ('Sahabat curhat', 'Percakapan pertama dengan Momo'),
    'hit_50': ('Petinang ×50', '50 pukulan terdaftar'),
    'hit_100': ('Diktator ×100', '100 pukulan… Momo tabah'),
    'ko_1': ('K.O. pertama', 'Momo pingsan… maaf ya 😔'),
    'ko_10': ('Legenda K.O. ×10', 'Momo kebal sakit hati'),
    'bond_5': ('Ikatan Kuat Lv5', 'Momo makin akrab denganmu'),
    'feed_10': ('Koki tercinta', '10 kali memberi makan'),
    'chat_50': ('50 Curhat', 'Momo pendengar setia'),
    'hug_5': ('Pelukan terapi', '5 pelukan erat'),
  };

  @override
  void initState() {
    super.initState();
    _loadState();
    _tick = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted) return;
      final mq = MediaQuery.of(context).size;
      pet.tick(33, size: mq, floorY: 0);
      setState(() {});
    });
  }

  Future<void> _loadState() async {
    late File f;
    try {
      final docs = Platform.isAndroid
          ? '/data/data/com.lunarjjo.moonpet/files'
          : '/tmp/moonpet_home';
      Directory(docs).createSync(recursive: true);
      f = File('$docs/state.json');
    } catch (_) {
      f = File('/tmp/moonpet_home/state.json');
    }
    Stats stats;
    if (f.existsSync()) {
      try {
        stats = Stats.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
      } catch (_) {
        stats = Stats();
      }
    } else {
      stats = Stats();
    }
    pet = PetState(stats);
    pet.attachStore(f);
    pet.stats.achievements.forEach(_shown.add);
    setState(() {});
  }

  void _achieve(String id) {
    if (_shown.contains(id)) return;
    final def = _achievements[id];
    if (def == null) return;
    _shown.add(id);
    pet.stats.achievements.add(id);
    pet.save();
    HapticFeedback.lightImpact();
    setState(() => _toasts.add(_Toast('🏆', def.$1, def.$2)));
    Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _toasts.removeWhere((t) => t.title == def.$1));
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _tool(String tool) {
    if (['tampar', 'jitak', 'cubit', 'lempar'].contains(tool)) {
      _achieve('first_hit');
      pet.hurt(tool, onKo: _showKo, onAchievement: _achieve);
    } else {
      pet.love(tool, onAchievement: _achieve);
    }
    pet.save();
    HapticFeedback.lightImpact();
  }

  void _showKo() {
    HapticFeedback.vibrate();
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _KoDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lunarBg,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, cons) {
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) {
                    final R = (cons.biggest.shortestSide * 0.11).clamp(46.0, 92.0);
                    final px = d.localPosition.dx - cons.biggest.width / 2 - pet.x;
                    final py = d.localPosition.dy - cons.biggest.height * 0.62 - pet.y;
                    final hit = (px / (R * 1.35)) * (px / (R * 1.35)) +
                            (py / (R * 1.25)) * (py / (R * 1.25)) <=
                        1;
                    if (hit) _tool('elus');
                  },
                  child: CustomPaint(
                    painter: MomoPainter(pet: pet, w: cons.biggest.width, h: cons.biggest.height),
                    size: Size.infinite,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    const Text('Moon',
                        style: TextStyle(
                            color: Color(0xFFE8E3F5),
                            fontSize: 20,
                            fontWeight: FontWeight.w300)),
                    const Text('Pet',
                        style: TextStyle(
                            color: Color(0xFFb9a5ff),
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    _chip('❤ Lv ${pet.stats.bondLv}'),
                    const SizedBox(width: 6),
                    _chip('💥 ${pet.stats.hits}'),
                    const SizedBox(width: 6),
                    _chip('🐾 ${pet.moodLabel}'),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.info_outline, color: Color(0xFFb9a5ff)),
                      onPressed: _showAbout,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      _dockGroup('SAYANG', [
                        _toolBtn('🖐 Elus', 'elus'),
                        _toolBtn('🍪 Makan', 'makan'),
                        _toolBtn('🤗 Peluk', 'peluk'),
                      ]),
                      const SizedBox(width: 8),
                      _dockGroup('SIKSA', [
                        _toolBtn('✋ Tampar', 'tampar', hurt: true),
                        _toolBtn('🔨 Jitak', 'jitak', hurt: true),
                        _toolBtn('🤏 Cubit', 'cubit', hurt: true),
                        _toolBtn('🗑 Lempar', 'lempar', hurt: true),
                      ]),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 56,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [for (final t in _toasts.take(3)) _toastWidget(t)],
                ),
              ),
              Positioned(
                right: 12,
                bottom: 84,
                child: FloatingActionButton.extended(
                  backgroundColor: _lunarViolet,
                  onPressed: () => _openChat(context),
                  icon: const Icon(Icons.chat_bubble, color: Colors.white),
                  label: const Text('Curhat', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2d2a44).withOpacity(.8),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x558b5cf6)),
        ),
        child: Text(text,
            style: const TextStyle(color: Color(0xFFd9ccff), fontSize: 13)),
      );

  Widget _dockGroup(String label, List<Widget> children) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2d2a44).withOpacity(.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: label == 'SIKSA'
                  ? const Color(0x44ff6b81)
                  : const Color(0x448b5cf6)),
        ),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF9c93bd), fontSize: 9, letterSpacing: 2)),
            const SizedBox(width: 6),
            ...children,
          ],
        ),
      );

  Widget _toolBtn(String label, String tool, {bool hurt = false}) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Material(
          color: const Color(0xFF1f1c33),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _tool(tool),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: hurt
                        ? const Color(0x66ff6b81)
                        : const Color(0x668b5cf6)),
              ),
              child: Text(label,
                  style: const TextStyle(color: Color(0xFFE8E3F5), fontSize: 13)),
            ),
          ),
        ),
      );

  Widget _toastWidget(_Toast t) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2d2a44), Color(0xFF1f1c33)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _lunarViolet),
        ),
        constraints: const BoxConstraints(maxWidth: 280),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title,
                      style: const TextStyle(
                          color: Color(0xFFd9ccff),
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                  Text(t.desc,
                      style:
                              const TextStyle(color: Color(0xFFc9c2e4), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );

  void _openChat(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatSheet(
        engine: widget.engine,
        pet: pet,
        onAchievement: _achieve,
      ),
    );
  }

  void _showAbout() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1d1a30),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => AboutSheet(onReset: () => pet.reset()),
    );
  }
}

class _KoDialog extends StatelessWidget {
  const _KoDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.75),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('MOMO K.O.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6)),
            SizedBox(height: 8),
            Text('dia akan kembali… selalu kembali 💫',
                style: TextStyle(color: Color(0xFFb9a5ff), fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _Toast {
  final String icon, title, desc;
  const _Toast(this.icon, this.title, this.desc);
}
