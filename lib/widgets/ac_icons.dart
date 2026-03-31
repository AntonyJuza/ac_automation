import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ac_automation/utils/constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared AC icon painter helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Stroke style used by every AC icon painter.
Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..strokeWidth = width
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Paint _fill(Color color) => Paint()
  ..color = color
  ..style = PaintingStyle.fill;

/// Draws the base AC wall-unit body (body + divider + display bar).
/// [w], [h] are canvas dimensions.
void _drawACBase(Canvas canvas, double w, double h, Paint stroke, Paint fill) {
  // Outer body
  final body = RRect.fromRectAndRadius(
    Rect.fromLTWH(0, 0, w * 0.72, h * 0.52),
    const Radius.circular(9),
  );
  canvas.drawRRect(body, fill);
  canvas.drawRRect(body, stroke);

  // Divider
  final divY = h * 0.30;
  canvas.drawLine(Offset(0, divY), Offset(w * 0.72, divY), stroke);

  // Display bar
  final barW = w * 0.14;
  final barH = h * 0.055;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.29, divY - barH - h * 0.04, barW, barH),
      const Radius.circular(2),
    ),
    stroke,
  );

  // Air outlet grille (trapezoid)
  final gi = w * 0.04;
  final gt = divY + h * 0.03;
  final gb = h * 0.50;
  final grille = Path()
    ..moveTo(gi, gt)
    ..lineTo(w * 0.72 - gi, gt)
    ..lineTo(w * 0.72 - gi * 1.6, gb)
    ..lineTo(gi * 1.6, gb)
    ..close();
  canvas.drawPath(grille, fill);
  canvas.drawPath(grille, stroke);

  // Inner grille inset
  final ii = w * 0.03;
  final innerGrille = Path()
    ..moveTo(gi + ii, gt + h * 0.03)
    ..lineTo(w * 0.72 - gi - ii, gt + h * 0.03)
    ..lineTo(w * 0.72 - gi * 1.6 - ii * 0.5, gb - h * 0.025)
    ..lineTo(gi * 1.6 + ii * 0.5, gb - h * 0.025)
    ..close();
  canvas.drawPath(innerGrille, stroke);
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. AC + Cooling (snowflake) — used for Cool mode
// ─────────────────────────────────────────────────────────────────────────────

class AcCoolIcon extends StatelessWidget {
  final double size;
  final Color color;
  const AcCoolIcon({super.key, this.size = 80, this.color = AppColors.textPrimary});

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _AcCoolPainter(color)));
}

class _AcCoolPainter extends CustomPainter {
  final Color color;
  _AcCoolPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final s = _stroke(color, w * 0.028);
    final f = _fill(Colors.white);
    _drawACBase(canvas, w, h, s, f);

    // Snowflake to the right of the unit
    final cx = w * 0.88; final cy = h * 0.30;
    final r = w * 0.11;
    for (int i = 0; i < 6; i++) {
      final angle = i * math.pi / 3;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + r * math.cos(angle), cy + r * math.sin(angle)),
        s,
      );
      // Small branches
      for (final sign in [-1.0, 1.0]) {
        final bx = cx + r * 0.55 * math.cos(angle);
        final by = cy + r * 0.55 * math.sin(angle);
        final ba = angle + sign * math.pi / 4;
        canvas.drawLine(
          Offset(bx, by),
          Offset(bx + r * 0.28 * math.cos(ba), by + r * 0.28 * math.sin(ba)),
          s,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AcCoolPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. AC + Airflow lines (cool air blowing down) — used for Fan / running state
// ─────────────────────────────────────────────────────────────────────────────

class AcFanIcon extends StatelessWidget {
  final double size;
  final Color color;
  const AcFanIcon({super.key, this.size = 80, this.color = AppColors.textPrimary});

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _AcFanPainter(color)));
}

class _AcFanPainter extends CustomPainter {
  final Color color;
  _AcFanPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final s = _stroke(color, w * 0.028);
    final f = _fill(Colors.white);
    _drawACBase(canvas, w, h, s, f);

    // 5 downward airflow curves
    final airXs = [w * 0.08, w * 0.20, w * 0.32, w * 0.44, w * 0.56];
    for (final x in airXs) {
      final top = h * 0.54;
      final bot = h * 0.92;
      final ctrl = Offset(x + w * 0.04, (top + bot) / 2);
      final path = Path()
        ..moveTo(x, top)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, x, bot);
      canvas.drawPath(path, s);
    }
  }

  @override
  bool shouldRepaint(covariant _AcFanPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. AC + Heat airflow (wavy lines) — used for Heat mode
// ─────────────────────────────────────────────────────────────────────────────

class AcHeatIcon extends StatelessWidget {
  final double size;
  final Color color;
  const AcHeatIcon({super.key, this.size = 80, this.color = AppColors.textPrimary});

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _AcHeatPainter(color)));
}

class _AcHeatPainter extends CustomPainter {
  final Color color;
  _AcHeatPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final s = _stroke(color, w * 0.028);
    final f = _fill(Colors.white);
    _drawACBase(canvas, w, h, s, f);

    // Wavy heat lines
    final xs = [w * 0.08, w * 0.22, w * 0.36, w * 0.50];
    for (final x in xs) {
      final path = Path();
      path.moveTo(x, h * 0.56);
      double y = h * 0.56;
      bool right = true;
      while (y < h * 0.92) {
        final seg = h * 0.09;
        path.quadraticBezierTo(
          x + (right ? w * 0.04 : -w * 0.04), y + seg / 2,
          x, y + seg,
        );
        y += seg;
        right = !right;
      }
      canvas.drawPath(path, s);
    }
  }

  @override
  bool shouldRepaint(covariant _AcHeatPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. AC + Thermometer — used for temperature / heat mode indicator
// ─────────────────────────────────────────────────────────────────────────────

class AcTempIcon extends StatelessWidget {
  final double size;
  final Color color;
  const AcTempIcon({super.key, this.size = 80, this.color = AppColors.textPrimary});

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _AcTempPainter(color)));
}

class _AcTempPainter extends CustomPainter {
  final Color color;
  _AcTempPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final s = _stroke(color, w * 0.028);
    final f = _fill(Colors.white);
    _drawACBase(canvas, w, h, s, f);

    // Thermometer body
    final tx = w * 0.84; final ty = h * 0.08;
    final tr = w * 0.04; final th = h * 0.30;
    // Tube
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(tx - tr, ty, tr * 2, th), Radius.circular(tr)),
      s,
    );
    // Bulb
    canvas.drawCircle(Offset(tx, ty + th + tr * 1.2), tr * 1.8, s);
    // Fill line inside tube
    canvas.drawLine(Offset(tx, ty + th * 0.4), Offset(tx, ty + th), _stroke(color, w * 0.022));
    // Tick marks
    for (int i = 1; i <= 3; i++) {
      final tickY = ty + th * (i / 4.0);
      canvas.drawLine(Offset(tx + tr, tickY), Offset(tx + tr * 1.8, tickY), _stroke(color, w * 0.02));
    }
  }

  @override
  bool shouldRepaint(covariant _AcTempPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. AC + Remote — used for BLE / remote control
// ─────────────────────────────────────────────────────────────────────────────

class AcRemoteIcon extends StatelessWidget {
  final double size;
  final Color color;
  const AcRemoteIcon({super.key, this.size = 80, this.color = AppColors.textPrimary});

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _AcRemotePainter(color)));
}

class _AcRemotePainter extends CustomPainter {
  final Color color;
  _AcRemotePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final s = _stroke(color, w * 0.028);
    final f = _fill(Colors.white);
    _drawACBase(canvas, w, h, s, f);

    // Remote body
    final rx = w * 0.78; final ry = h * 0.04;
    final rw = w * 0.18; final rh = h * 0.44;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(rx, ry, rw, rh), Radius.circular(rw * 0.35)),
      f,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(rx, ry, rw, rh), Radius.circular(rw * 0.35)),
      s,
    );
    // Power button on remote
    canvas.drawCircle(Offset(rx + rw / 2, ry + rh * 0.22), rw * 0.22, s);
    // Small dots (buttons)
    for (int row = 0; row < 2; row++) {
      for (int col = 0; col < 2; col++) {
        canvas.drawCircle(
          Offset(rx + rw * (0.28 + col * 0.44), ry + rh * (0.52 + row * 0.22)),
          rw * 0.1,
          _fill(color),
        );
      }
    }
    // Wireless signal arcs from remote
    for (int i = 1; i <= 2; i++) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(rx - w * 0.02, ry + rh * 0.22), width: w * i * 0.12, height: h * i * 0.12),
        -math.pi * 0.75, math.pi * 0.5,
        false, s,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AcRemotePainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. AC + Warning triangle — used for error states
// ─────────────────────────────────────────────────────────────────────────────

class AcWarningIcon extends StatelessWidget {
  final double size;
  final Color color;
  const AcWarningIcon({super.key, this.size = 80, this.color = AppColors.statusRed});

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _AcWarningPainter(color)));
}

class _AcWarningPainter extends CustomPainter {
  final Color color;
  _AcWarningPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final s = _stroke(color, w * 0.028);
    final f = _fill(Colors.white);
    _drawACBase(canvas, w, h, s, f);

    // Warning triangle
    final cx = w * 0.87; final cy = h * 0.28;
    final tr = w * 0.13;
    final tri = Path()
      ..moveTo(cx, cy - tr)
      ..lineTo(cx + tr, cy + tr * 0.6)
      ..lineTo(cx - tr, cy + tr * 0.6)
      ..close();
    canvas.drawPath(tri, f);
    canvas.drawPath(tri, s);
    // Exclamation
    canvas.drawLine(Offset(cx, cy - tr * 0.4), Offset(cx, cy + tr * 0.1), s);
    canvas.drawCircle(Offset(cx, cy + tr * 0.38), w * 0.018, _fill(color));
  }

  @override
  bool shouldRepaint(covariant _AcWarningPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. AC + Humidity drop — used for Dry mode
// ─────────────────────────────────────────────────────────────────────────────

class AcDryIcon extends StatelessWidget {
  final double size;
  final Color color;
  const AcDryIcon({super.key, this.size = 80, this.color = AppColors.textPrimary});

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _AcDryPainter(color)));
}

class _AcDryPainter extends CustomPainter {
  final Color color;
  _AcDryPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final s = _stroke(color, w * 0.028);
    final f = _fill(Colors.white);
    _drawACBase(canvas, w, h, s, f);

    // Water drop
    final dx = w * 0.87; final dtop = h * 0.06;
    final dr = w * 0.09;
    final drop = Path()
      ..moveTo(dx, dtop)
      ..cubicTo(dx + dr * 1.2, dtop + dr * 1.4, dx + dr, dtop + dr * 2.6, dx, dtop + dr * 2.8)
      ..cubicTo(dx - dr, dtop + dr * 2.6, dx - dr * 1.2, dtop + dr * 1.4, dx, dtop)
      ..close();
    canvas.drawPath(drop, f);
    canvas.drawPath(drop, s);
  }

  @override
  bool shouldRepaint(covariant _AcDryPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. AC + Snowflake + airflow — used for active cooling (home hero)
// ─────────────────────────────────────────────────────────────────────────────

class AcActiveCoolIcon extends StatelessWidget {
  final double size;
  final Color color;
  const AcActiveCoolIcon({super.key, this.size = 160, this.color = AppColors.textPrimary});

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size * 0.7, child: CustomPaint(painter: _AcActiveCoolPainter(color)));
}

class _AcActiveCoolPainter extends CustomPainter {
  final Color color;
  _AcActiveCoolPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final s = _stroke(color, w * 0.018);
    final f = _fill(Colors.white);

    // Larger base for hero use
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h * 0.60),
      const Radius.circular(14),
    );
    canvas.drawRRect(body, f);
    canvas.drawRRect(body, s);

    final divY = h * 0.34;
    canvas.drawLine(Offset(0, divY), Offset(w, divY), s);

    // Display bar
    final barW = w * 0.18;
    final barH = h * 0.055;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH((w - barW) / 2, divY - barH - h * 0.05, barW, barH),
        const Radius.circular(2.5),
      ),
      s,
    );

    // Two indicator dots
    final dotY = h * 0.12;
    final dotPaint = _fill(color.withValues(alpha: 0.7));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.74, dotY - 2, 8, 4.5), const Radius.circular(2)), dotPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.84, dotY - 2, 8, 4.5), const Radius.circular(2)), dotPaint);

    // Grille
    final gi = w * 0.05;
    final gt = divY + h * 0.03;
    final gb = h * 0.58;
    final grille = Path()
      ..moveTo(gi, gt)
      ..lineTo(w - gi, gt)
      ..lineTo(w - gi * 1.7, gb)
      ..lineTo(gi * 1.7, gb)
      ..close();
    canvas.drawPath(grille, f);
    canvas.drawPath(grille, s);
    final ii = w * 0.035;
    final inner = Path()
      ..moveTo(gi + ii, gt + h * 0.03)
      ..lineTo(w - gi - ii, gt + h * 0.03)
      ..lineTo(w - gi * 1.7 - ii * 0.5, gb - h * 0.025)
      ..lineTo(gi * 1.7 + ii * 0.5, gb - h * 0.025)
      ..close();
    canvas.drawPath(inner, s);

    // Airflow lines below grille
    final airXs = [w * 0.12, w * 0.26, w * 0.40, w * 0.54, w * 0.68];
    for (final x in airXs) {
      final top = h * 0.62;
      final bot = h * 0.96;
      final path = Path()
        ..moveTo(x, top)
        ..quadraticBezierTo(x + w * 0.03, (top + bot) / 2, x, bot);
      canvas.drawPath(path, s);
    }
  }

  @override
  bool shouldRepaint(covariant _AcActiveCoolPainter old) => old.color != color;
}
