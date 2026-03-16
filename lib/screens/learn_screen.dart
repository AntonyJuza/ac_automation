import 'package:flutter/material.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:ac_automation/models/ac_profile.dart';
import 'package:ac_automation/models/ir_button.dart';
import 'package:ac_automation/services/ac_provider.dart';
import 'package:ac_automation/services/ble_service.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

// Each button step definition
class _ButtonStep {
  final String key;        // stored in profile, sent to ESP32
  final String label;      // shown to user
  final IconData icon;
  final bool optional;

  const _ButtonStep({
    required this.key,
    required this.label,
    required this.icon,
    this.optional = false,
  });
}

const List<_ButtonStep> _steps = [
  _ButtonStep(key: 'power_off',  label: 'Power OFF',   icon: Icons.power_settings_new),
  _ButtonStep(key: 'power_on',   label: 'Power ON',    icon: Icons.power_settings_new),
  _ButtonStep(key: 'temp_up',    label: 'Temp +',      icon: Icons.add_circle_outline),
  _ButtonStep(key: 'temp_down',  label: 'Temp −',      icon: Icons.remove_circle_outline),
  _ButtonStep(key: 'mode',       label: 'Mode',        icon: Icons.ac_unit),
  _ButtonStep(key: 'fan_speed',  label: 'Fan Speed',   icon: Icons.air),
  _ButtonStep(key: 'swing',      label: 'Swing',       icon: Icons.swap_vert,    optional: true),
  _ButtonStep(key: 'sleep',      label: 'Sleep',       icon: Icons.nightlight_round, optional: true),
];

class LearnScreen extends StatefulWidget {
  final String name;
  final String brand;
  final String? model;

  const LearnScreen({
    super.key,
    required this.name,
    required this.brand,
    this.model,
  });

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  int _currentStep = 0;
  final Map<String, List<int>> _capturedData = {};
  
  // null = idle, true = waiting for hardware, false = captured/error
  bool _isCapturing = false;
  String? _captureError;
  bool _lastCaptureSuccess = false;

  bool get _isComplete => _currentStep >= _steps.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      appBar: AppBar(
        title: const Text('Teach Remote'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          _buildProgressHeader(),
          Expanded(
            child: _isComplete
                ? _buildReviewArea()
                : _buildCaptureArea(),
          ),
        ],
      ),
    );
  }

  // ---------- Progress Header ----------

  Widget _buildProgressHeader() {
    final total = _steps.length;
    return Container(
      padding: const EdgeInsets.all(24),
      color: AppColors.primaryBackground,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep) / total,
              backgroundColor: AppColors.secondaryBackground,
              color: AppColors.primaryBrand,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Button ${_currentStep + 1} of $total',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_capturedData.length} captured',
                style: const TextStyle(
                  color: AppColors.statusGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Capture Area ----------

  Widget _buildCaptureArea() {
    final step = _steps[_currentStep];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Icon circle
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _isCapturing
                  ? AppColors.primaryBrand.withValues(alpha: 0.1)
                  : AppColors.primaryBackground,
              shape: BoxShape.circle,
              boxShadow: [AppStyles.softShadow],
              border: _isCapturing
                  ? Border.all(color: AppColors.primaryBrand, width: 2)
                  : null,
            ),
            child: _isCapturing
                ? const SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      color: AppColors.primaryBrand,
                    ),
                  )
                : Icon(step.icon, size: 80, color: AppColors.primaryBrand),
          ),
          const SizedBox(height: 32),
          // Instruction text
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Press  ',
                style: const TextStyle(
                  fontSize: 22,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryBrand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${step.label}"',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBrand,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isCapturing
                ? 'Waiting for signal from your remote...'
                : 'Point your AC remote at the hardware device\nand press the button once.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          // Error message
          if (_captureError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.statusRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.statusRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _captureError!,
                      style: const TextStyle(
                        color: AppColors.statusRed,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Success flash
          if (_lastCaptureSuccess && !_isCapturing) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.statusGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle,
                      color: AppColors.statusGreen, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Captured successfully!',
                    style: TextStyle(
                        color: AppColors.statusGreen,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 48),
          // Action buttons
          if (!_isCapturing) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startCapture,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBrand,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text(
                  'Ready — Press the button now',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (step.optional)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _skipStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppColors.textSecondary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'Skip (optional)',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _cancelCapture,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.statusRed),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.statusRed),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------- Review Area (all done) ----------

  Widget _buildReviewArea() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle,
              color: AppColors.statusGreen, size: 48),
          const SizedBox(height: 16),
          const Text(
            'All Done!',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Profile for ${widget.brand} is ready.\n${_capturedData.length} buttons captured.',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: _steps.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final step = _steps[index];
                final captured = _capturedData.containsKey(step.key);
                return ListTile(
                  leading: Icon(
                    captured ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: captured
                        ? AppColors.statusGreen
                        : AppColors.textSecondary,
                  ),
                  title: Text(
                    step.label,
                    style: TextStyle(
                      color: captured
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: captured
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: captured
                      ? Text(
                          '${_capturedData[step.key]!.length} bytes',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        )
                      : const Text('Skipped',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                  trailing: captured
                      ? TextButton(
                          onPressed: () => _reRecordStep(index),
                          child: const Text('Re-record',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primaryBrand)),
                        )
                      : null,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _capturedData.length >= 2 ? _saveProfile : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusGreen,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                'Save Profile to Device',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Actions ----------

  void _startCapture() async {
    final bleService = Provider.of<BLEService>(context, listen: false);

    if (!bleService.isConnected) {
      setState(() => _captureError = 'Not connected to device. Go back and connect first.');
      return;
    }

    setState(() {
      _isCapturing = true;
      _captureError = null;
      _lastCaptureSuccess = false;
    });

    final rawData = await bleService.captureIRButton(
      timeout: const Duration(seconds: 15),
    );

    if (!mounted) return;

    if (rawData != null && rawData.isNotEmpty) {
      final key = _steps[_currentStep].key;
      setState(() {
        _capturedData[key] = rawData;
        _isCapturing = false;
        _lastCaptureSuccess = true;
        _captureError = null;
      });
      // Auto-advance after short delay so user sees success message
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) setState(() => _currentStep++);
    } else {
      setState(() {
        _isCapturing = false;
        _captureError = 'No signal received. Make sure the remote is pointing at the device and try again.';
      });
    }
  }

  void _cancelCapture() {
    final bleService = Provider.of<BLEService>(context, listen: false);
    bleService.stopLearnMode();
    setState(() {
      _isCapturing = false;
      _captureError = null;
    });
  }

  void _skipStep() {
    setState(() {
      _currentStep++;
      _captureError = null;
      _lastCaptureSuccess = false;
    });
  }

  void _reRecordStep(int stepIndex) {
    setState(() {
      _currentStep = stepIndex;
      _lastCaptureSuccess = false;
      _captureError = null;
    });
  }

  void _saveProfile() async {
    final bleService = Provider.of<BLEService>(context, listen: false);
    final acProvider = Provider.of<ACProvider>(context, listen: false);

    final profile = ACProfile(
      id: Uuid().v4(),
      name: widget.name,
      brand: widget.brand,
      model: widget.model,
      buttons: _capturedData.map(
        (key, value) => MapEntry(key, IRButton(name: key, rawData: value)),
      ),
      createdAt: DateTime.now(),
    );

    // 1. Save locally on phone
    await acProvider.addProfile(profile);

    // 2. Send profile JSON to ESP32 for NVS storage
    if (bleService.isConnected) {
      final buttonsMap = _capturedData.map(
        (key, value) => MapEntry(key, value),
      );
      final profileJson = json.encode({
        'id':      profile.id,
        'name':    profile.name,
        'brand':   profile.brand,
        'model':   profile.model ?? '',
        'buttons': buttonsMap,
      });

      final saved = await bleService.saveProfileToDevice(profileJson);
      if (saved) {
        // 3. Tell ESP32 to use this profile for automation
        await bleService.setActiveProfile(profile.id);
        debugPrint('[App] Profile saved to ESP32 and set as active');
      } else {
        debugPrint('[App] Warning: Profile saved locally but ESP32 send failed');
      }
    } else {
      debugPrint('[App] Not connected — profile saved locally only');
    }

    if (mounted) context.go('/');
  }
}