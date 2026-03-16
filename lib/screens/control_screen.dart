import 'package:flutter/material.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:ac_automation/widgets/ac_button.dart';
import 'dart:math' as math;

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  double _temperature = 22.0;
  bool _isPowerOn = true;
  String _mode = 'Cool';
  String _fanSpeed = 'Auto';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      appBar: AppBar(
        title: const Text('Living Room'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Temperature Hero Section
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(260, 260),
                    painter: _TempDialPainter(),
                  ),
                  _buildTemperatureDisplay(),
                ],
              ),
            ),
            const SizedBox(height: 60),
            // Primary Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ACButton(
                    icon: Icons.power_settings_new,
                    label: 'Power',
                    isActive: _isPowerOn,
                    activeColor: _isPowerOn ? AppColors.primaryBrand : null,
                    onTap: () => setState(() => _isPowerOn = !_isPowerOn),
                  ),
                  ACButton(
                    icon: _getModeIcon(),
                    label: _mode,
                    isActive: true,
                    onTap: _cycleMode,
                  ),
                  ACButton(
                    icon: Icons.air,
                    label: 'Fan: $_fanSpeed',
                    isActive: true,
                    onTap: _cycleFanSpeed,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Secondary Controls Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryBackground,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [AppStyles.softShadow],
              ),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  ACButton(icon: Icons.swap_vert, label: 'Swing', onTap: () {}),
                  ACButton(icon: Icons.bolt, label: 'Turbo', onTap: () {}),
                  ACButton(icon: Icons.timer_outlined, label: 'Timer', onTap: () {}),
                  ACButton(icon: Icons.nightlight_round, label: 'Sleep', onTap: () {}),
                  ACButton(icon: Icons.eco_outlined, label: 'Eco', onTap: () {}),
                  ACButton(icon: Icons.cleaning_services, label: 'Clean', onTap: () {}),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemperatureDisplay() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_temperature.toInt()}°',
          style: const TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const Text(
          'Target Temp',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => setState(() => _temperature--),
              icon: const Icon(Icons.remove_circle_outline),
              color: AppColors.primaryBrand,
            ),
            const SizedBox(width: 16),
            IconButton(
              onPressed: () => setState(() => _temperature++),
              icon: const Icon(Icons.add_circle_outline),
              color: AppColors.primaryBrand,
            ),
          ],
        ),
      ],
    );
  }

  IconData _getModeIcon() {
    switch (_mode) {
      case 'Cool': return Icons.ac_unit;
      case 'Heat': return Icons.wb_sunny;
      case 'Dry': return Icons.water_drop;
      case 'Fan': return Icons.air;
      default: return Icons.ac_unit;
    }
  }

  void _cycleMode() {
    final modes = ['Cool', 'Heat', 'Dry', 'Fan'];
    setState(() {
      _mode = modes[(modes.indexOf(_mode) + 1) % modes.length];
    });
  }

  void _cycleFanSpeed() {
    final speeds = ['Low', 'Med', 'High', 'Auto'];
    setState(() {
      _fanSpeed = speeds[(speeds.indexOf(_fanSpeed) + 1) % speeds.length];
    });
  }
}

class _TempDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background track
    final trackPaint = Paint()
      ..color = AppColors.secondaryBackground
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    
    canvas.drawCircle(center, radius - 6, trackPaint);

    // Gradient progress (mockup static for now, can be adjusted)
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.primaryBrand, AppColors.secondaryAccent],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 12;

    const startAngle = -math.pi * 0.5;
    const sweepAngle = math.pi * 1.5; // Represents progress
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 6),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
