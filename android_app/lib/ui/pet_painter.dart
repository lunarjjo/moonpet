/// Pelukis Momo si kucing-bulan + langit malam lunar + partikel.
/// Port dari versi web (canvas 2D) ke CustomPainter Flutter.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/pet_state.dart';

class MomoPainter extends CustomPainter {
  final PetState pet;
  final double w, h;
  MomoPainter({required this.pet, required this.w, required this.h});

  @override
  bool shouldRepaint(MomoPainter oldDelegate) => true;

  @override
  void paint(Canvas canvas, Size size) {
    _sky(canvas);
    _floor(canvas);
    _particles(canvas);
    _momo(canvas);
    _bubble(canvas);
  }

  static final List<_Star> _stars = List.generate(
      90,
      (_) => _Star(math.Random().nextDouble(), math.Random().nextDouble(),
          0.4 + math.Random().nextDouble() * 1.2, math.Random().nextDouble() * 6.28));

  void _sky(Canvas canvas) {
    final rect = Offset.zero & Size(w, h);
    final g = uiGradient(rect, const [
      Color(0xFF141126),
      Color(0xFF1a1a2e),
      Color(0xFF2d2a44),
    ]);
    final paint = Paint()..shader = g;
    canvas.drawRect(rect, paint);

    final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
    for (final s in _stars) {
      final a = 0.35 +
          0.65 * math.sin((s.tw + t * (0.4 + s.s * 0.3)).abs()).abs();
      canvas.drawCircle(
          Offset(s.x * w, s.y * h * 0.7), s.s, Paint()..color = Colors.white.withOpacity(a));
    }

    // bulan sabit
    final mx = w * 0.84, my = h * 0.16, mr = (math.min(w, h) * 0.05).clamp(26.0, 44.0);
    canvas.drawCircle(Offset(mx, my), mr,
        Paint()..shader = uiRadial(Offset(mx - mr * .3, my - mr * .3), mr, const [Colors.white, Color(0xFFd9d0f0)]));
    canvas.drawCircle(
        Offset(mx + mr * 0.34, my - mr * 0.18), mr * 0.92, Paint()..color = const Color(0xFF1a1a2e).withOpacity(.92));
  }

  void _floor(Canvas canvas) {
    final R = (math.min(w, h) * 0.11).clamp(46.0, 92.0);
    final cy = h * 0.62 + R * 0.95;
    final p = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(w / 2, cy), width: w * 0.6, height: 52));
    canvas.drawPath(p, Paint()..color = const Color(0xFF232038));
  }

  void _particles(Canvas canvas) {
    for (final p in pet.particles) {
      final alpha = (1 - p.t / p.life).clamp(0.0, 1.0);
      final color = HSLColor.fromAHSL(alpha, p.hue.toDouble(), 0.85, 0.72).toColor();
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rot);
      if (p.kind == 'heart') {
        _heart(canvas, p.size, color);
      } else if (p.kind == 'star') {
        _star5(canvas, p.size, color);
      } else {
        canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: 3),
            Paint()..color = color);
      }
      canvas.restore();
    }
  }

  void _heart(Canvas canvas, double s, Color color) {
    final p = Path()
      ..moveTo(0, s * 0.3)
      ..cubicTo(-s * 0.7, -s * 0.4, -s * 0.28, -s * 0.85, 0, -s * 0.42)
      ..cubicTo(s * 0.28, -s * 0.85, s * 0.7, -s * 0.4, 0, s * 0.3)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  void _star5(Canvas canvas, double s, Color color) {
    final p = Path();
    for (var i = 0; i < 5; i++) {
      final a = (i / 5) * math.pi * 2 - math.pi / 2;
      final a2 = a + math.pi / 5;
      p.lineTo(math.cos(a) * s, math.sin(a) * s);
      p.lineTo(math.cos(a2) * s * 0.45, math.sin(a2) * s * 0.45);
    }
    p.close();
    canvas.drawPath(p, Paint()..color = color);
  }

  void _momo(Canvas canvas) {
    final R = (math.min(w, h) * 0.11).clamp(46.0, 92.0);
    final cx = w / 2 + pet.x;
    final cy = h * 0.62 + pet.y;
    final shakeJitter = pet.shake > 0 ? pet.shake * 0.3 : 0.0;
    final jx = shakeJitter * (math.Random().nextDouble() * 2 - 1);
    final jy = shakeJitter * (math.Random().nextDouble() * 2 - 1);

    canvas.save();
    canvas.translate(cx + jx, cy + jy);
    canvas.rotate(pet.rot);
    canvas.scale(pet.sx, pet.sy);
    if (pet.ghost > 0) {
      canvas.saveLayer(null, Paint()..color = Colors.white.withOpacity(0.5));
    }
    if (pet.ko) {
      canvas.scale(1, 0.55);
      canvas.translate(0, R * 0.45);
    }

    final breathe = 1 + 0.018 * math.sin(pet.breathe);

    // ekor
    final tailPaint = Paint()
      ..color = const Color(0xFFC9C0E4)
      ..strokeWidth = R * 0.16
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final sway = math.sin(pet.tailPhase) * R * 0.28;
    final tail = Path()
      ..moveTo(R * 0.55, R * 0.25)
      ..quadraticBezierTo(R * 1.3, -R * 0.25 + sway, R * 1.2, -R * 0.7 + sway * 0.6);
    canvas.drawPath(tail, tailPaint);

    // badan
    final body = Path()
      ..addOval(Rect.fromCenter(
          center: Offset.zero,
          width: 2 * R * breathe,
          height: 2 * R * 0.92 * breathe));
    canvas.drawPath(
        body,
        Paint()
          ..shader = uiRadial(
              Offset(-R * .3, -R * .35), R * 1.15, const [
            Color(0xFFF4F0FB),
            Color(0xFFE8E3F5),
            Color(0xFFC9C0E4),
          ]));
    canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFb9b0d8));

    // telinga
    for (final side in [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(side * R * 0.52, -R * 0.62)
        ..lineTo(side * R * 0.78, -R * 1.42)
        ..lineTo(side * R * 0.95, -R * 0.55)
        ..close();
      canvas.drawPath(ear, Paint()..color = const Color(0xFFE8E3F5));
      canvas.drawPath(
          ear,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFb9b0d8));
      final inner = Path()
        ..moveTo(side * R * 0.63, -R * 0.74)
        ..lineTo(side * R * 0.76, -R * 1.2)
        ..lineTo(side * R * 0.85, -R * 0.68)
        ..close();
      canvas.drawPath(inner, Paint()..color = const Color(0xFFf2b8cf));
    }

    // memar kartun
    for (final b in pet.stats.bruises) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(b[0] * R, b[1] * R),
              width: R * 0.26,
              height: R * 0.18),
          Paint()..color = const Color(0xFF785AAA).withOpacity(0.45));
    }
    // plester
    if (pet.stats.bruises.length >= 3) {
      canvas.save();
      canvas.translate(-R * 0.45, -R * 0.78);
      canvas.rotate(-0.5);
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: R * 0.6, height: R * 0.18),
          Paint()..color = const Color(0xFFf5e6c8));
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(-R * 0.2, 0), width: R * 0.1, height: R * 0.18),
          Paint()..color = const Color(0xFFe8d5b0));
      canvas.restore();
    }

    // mata
    _eyes(canvas, R);

    // mulut
    _mouth(canvas, R);

    // rona pipi
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(side * R * 0.52, R * 0.12),
              width: R * 0.2,
              height: R * 0.12),
          Paint()..color = const Color(0xFFf2b8cf).withOpacity(0.75));
    }

    // kumis
    final wPaint = Paint()
      ..color = const Color(0xFFb9b0d8)
      ..strokeWidth = 1.5;
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
            Offset(side * R * 0.55, -R * 0.05 + i * R * 0.09),
            Offset(side * R * 0.95, -R * 0.12 + i * R * 0.13),
            wPaint);
      }
    }

    if (pet.ghost > 0) {
      canvas.restore();
    }
    canvas.restore();
  }

  void _eyes(Canvas canvas, double R) {
    final eyeY = -R * 0.1, eyeX = R * 0.3;
    final dark = Paint()
      ..color = const Color(0xFF2d2a44)
      ..strokeWidth = math.max(3.0, R * 0.07)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    if (pet.ko || pet.state == 'ko') {
      for (final side in [-1.0, 1.0]) {
        final ex = side * eyeX;
        canvas.drawLine(Offset(ex - R * .12, eyeY - R * .12),
            Offset(ex + R * .12, eyeY + R * .12), dark);
        canvas.drawLine(Offset(ex + R * .12, eyeY - R * .12),
            Offset(ex - R * .12, eyeY + R * .12), dark);
      }
    } else if (pet.state == 'dizzy') {
      pet.dizzySpin += 0.25;
      for (final side in [-1.0, 1.0]) {
        final ex = side * eyeX;
        final p = Path();
        for (double a = 0; a < math.pi * 3.6; a += 0.25) {
          final rr = a * R * 0.035;
          final px = ex + math.cos(a + pet.dizzySpin) * rr;
          final py = eyeY + math.sin(a + pet.dizzySpin) * rr;
          if (a == 0) {
            p.moveTo(px, py);
          } else {
            p.lineTo(px, py);
          }
        }
        canvas.drawPath(p, dark);
      }
    } else if (pet.state == 'happy' || pet.state == 'hug' || pet.state == 'eat') {
      for (final side in [-1.0, 1.0]) {
        final rect = Rect.fromCircle(
            center: Offset(side * eyeX, eyeY + R * .05), radius: R * .14);
        canvas.drawArc(rect, math.pi * 1.15, math.pi * 0.7, false, dark);
      }
    } else if (pet.state == 'sulk') {
      for (final side in [-1.0, 1.0]) {
        final ex = side * eyeX;
        canvas.drawLine(Offset(ex - R * .13, eyeY - R * .16),
            Offset(ex + R * .13, eyeY - R * .04), dark);
        canvas.drawCircle(
            Offset(ex, eyeY + R * .06), R * .1, Paint()..color = const Color(0xFF2d2a44));
      }
    } else if (pet.blink > 0) {
      for (final side in [-1.0, 1.0]) {
        canvas.drawLine(Offset(side * eyeX - R * .13, eyeY),
            Offset(side * eyeX + R * .13, eyeY), dark);
      }
    } else {
      for (final side in [-1.0, 1.0]) {
        final ex = side * eyeX;
        canvas.drawCircle(Offset(ex, eyeY), R * .13,
            Paint()..color = const Color(0xFF2d2a44));
        canvas.drawCircle(Offset(ex + R * .04, eyeY - R * .05), R * .035,
            Paint()..color = Colors.white);
      }
    }
  }

  void _mouth(Canvas canvas, double R) {
    final my = R * 0.22;
    final paint = Paint()
      ..color = const Color(0xFF2d2a44)
      ..strokeWidth = math.max(2.0, R * 0.05)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (pet.state == 'happy' || pet.state == 'hug') {
      canvas.drawArc(Rect.fromCircle(center: Offset(0, my - R * .06), radius: R * .12),
          0.15, math.pi - 0.3, false, paint);
    } else if (pet.state == 'sulk' || pet.state == 'dizzy') {
      canvas.drawArc(Rect.fromCircle(center: Offset(0, my + R * .1), radius: R * .09),
          math.pi + 0.2, math.pi - 0.4, false, paint);
    } else {
      final p = Path()
        ..moveTo(-R * 0.1, my)
        ..quadraticBezierTo(-R * 0.04, my + R * 0.07, 0, my)
        ..quadraticBezierTo(R * 0.04, my + R * 0.07, R * 0.1, my);
      canvas.drawPath(p, paint);
    }
  }

  void _bubble(Canvas canvas) {
    final b = pet.bubble;
    if (b == null || pet.bubbleT <= 0) return;
    final R = (math.min(w, h) * 0.11).clamp(46.0, 92.0);
    final tp = TextPainter(
      text: TextSpan(
          text: b,
          style: TextStyle(
              color: const Color(0xFFE8E3F5),
              fontSize: (R * 0.18).clamp(12.0, 18.0))),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w * 0.5);
    final cx = (w / 2 + pet.x).clamp(tp.width / 2 + 12, w - tp.width / 2 - 12);
    final cy = h * 0.62 + pet.y - R * 1.9 - 16;
    final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, cy),
            width: tp.width + 24,
            height: tp.height + 16),
        const Radius.circular(10));
    canvas.drawRRect(
        rrect, Paint()..color = const Color(0xFF1d1a30).withOpacity(.95));
    canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFF8b5cf6));
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }
}

class _Star {
  final double x, y, s, tw;
  const _Star(this.x, this.y, this.s, this.tw);
}

// util gradient (tanpa perlu ui.dart panjang)
Shader uiGradient(Rect rect, List<Color> colors) =>
    LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors)
        .createShader(rect);

Shader uiRadial(Offset center, double radius, List<Color> colors) =>
    RadialGradient(center: Alignment(-0.3, -0.35), radius: 1.0, colors: colors)
        .createShader(Rect.fromCircle(center: center, radius: radius));

