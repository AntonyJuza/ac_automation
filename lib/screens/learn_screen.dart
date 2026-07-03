import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:ac_automation/models/ac_profile.dart';
import 'package:ac_automation/models/ir_button.dart';
import 'package:ac_automation/services/ac_provider.dart';
import 'package:ac_automation/services/ble_service.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:ac_automation/models/dynamic_config.dart';
import 'package:ac_automation/services/api_service.dart';

// Each button step definition
class _ButtonStep {
  final String key; // stored in profile, sent to ESP32
  final String label; // shown to user
  final IconData icon;
  final String? assetPath; // optional asset image path
  final bool optional;

  const _ButtonStep({
    required this.key,
    required this.label,
    required this.icon,
    this.assetPath,
    this.optional = false,
  });
}

const List<_ButtonStep> _steps = [
  _ButtonStep(
    key: 'power_off',
    label: 'Power OFF',
    icon: Icons.power_settings_new,
  ),
  _ButtonStep(
    key: 'power_on',
    label: 'Power ON',
    icon: Icons.power_settings_new,
  ),
  _ButtonStep(
    key: 'temp_up',
    label: 'Temp +',
    icon: Icons.add_circle_outline,
    optional: true,
  ),
  _ButtonStep(
    key: 'temp_down',
    label: 'Temp −',
    icon: Icons.remove_circle_outline,
    optional: true,
  ),
  _ButtonStep(
    key: 'temp_16',
    label: 'Temp 16°C',
    icon: Icons.thermostat_outlined,
    optional: true,
  ),
  _ButtonStep(
    key: 'temp_17',
    label: 'Temp 17°C',
    icon: Icons.thermostat_outlined,
    optional: true,
  ),
  _ButtonStep(
    key: 'temp_18',
    label: 'Temp 18°C',
    icon: Icons.thermostat_outlined,
    optional: true,
  ),
  _ButtonStep(
    key: 'temp_19',
    label: 'Temp 19°C',
    icon: Icons.thermostat_outlined,
    optional: true,
  ),
  _ButtonStep(
    key: 'temp_20',
    label: 'Temp 20°C',
    icon: Icons.thermostat_outlined,
    optional: true,
  ),
  _ButtonStep(
    key: 'temp_21',
    label: 'Temp 21°C',
    icon: Icons.thermostat_outlined,
    optional: true,
  ),
  _ButtonStep(
    key: 'temp_22',
    label: 'Temp 22°C',
    icon: Icons.thermostat_outlined,
    optional: true,
  ),
  _ButtonStep(
    key: 'temp_23',
    label: 'Temp 23°C',
    icon: Icons.thermostat_outlined,
    optional: true,
  ),
  _ButtonStep(
    key: 'temp_24',
    label: 'Temp 24°C',
    icon: Icons.thermostat_outlined,
    optional: true,
  ),
  _ButtonStep(
    key: 'temp_25',
    label: 'Temp 25°C',
    icon: Icons.thermostat_outlined,
    optional: true,
  ),
  _ButtonStep(
    key: 'temp_26',
    label: 'Temp 26°C',
    icon: Icons.thermostat_outlined,
    optional: true,
  ),
  _ButtonStep(
    key: 'temp_27',
    label: 'Temp 27°C',
    icon: Icons.thermostat_outlined,
    optional: true,
  ),
  _ButtonStep(
    key: 'temp_28',
    label: 'Temp 28°C',
    icon: Icons.thermostat_outlined,
    optional: true,
  ),
  _ButtonStep(
    key: 'temp_29',
    label: 'Temp 29°C',
    icon: Icons.thermostat_outlined,
    optional: true,
  ),
  _ButtonStep(
    key: 'temp_30',
    label: 'Temp 30°C',
    icon: Icons.thermostat_outlined,
    optional: true,
  ),
  _ButtonStep(
    key: 'mode',
    label: 'Mode',
    icon: Icons.ac_unit,
    assetPath: 'assets/20.png',
    optional: true,
  ),
  _ButtonStep(
    key: 'fan_speed',
    label: 'Fan Speed',
    icon: Icons.air,
    assetPath: 'assets/20.png',
    optional: true,
  ),
  _ButtonStep(
    key: 'swing',
    label: 'Swing',
    icon: Icons.swap_vert,
    optional: true,
  ),
  _ButtonStep(
    key: 'sleep',
    label: 'Sleep',
    icon: Icons.nightlight_round,
    optional: true,
  ),
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
  final Map<String, IRButton> _capturedData = {};

  // null = idle, true = waiting for hardware, false = captured/error
  bool _isCapturing = false;
  String? _captureError;
  bool _lastCaptureSuccess = false;

  // Upload progress state
  bool _isUploading = false;
  String _uploadStatus = '';
  double? _uploadProgress;

  Timer? _cloudPollTimer;

  bool get _isComplete => _currentStep >= _steps.length;

  @override
  void dispose() {
    _cloudPollTimer?.cancel();
    super.dispose();
  }

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
            child: _isComplete ? _buildReviewArea() : _buildCaptureArea(),
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
                : step.assetPath != null
                ? ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      AppColors.primaryBrand,
                      BlendMode.srcIn,
                    ),
                    child: Image.asset(
                      step.assetPath!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
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
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.statusRed,
                    size: 18,
                  ),
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
                  Icon(
                    Icons.check_circle,
                    color: AppColors.statusGreen,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Captured successfully!',
                    style: TextStyle(
                      color: AppColors.statusGreen,
                      fontWeight: FontWeight.w600,
                    ),
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
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Ready — Press the button now',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                    borderRadius: BorderRadius.circular(16),
                  ),
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
          const Icon(
            Icons.check_circle,
            color: AppColors.statusGreen,
            size: 48,
          ),
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
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
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
                    captured
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
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
                          _capturedData[step.key]!.isEncoded
                              ? 'encoded ${_capturedData[step.key]!.bits} bits'
                              : 'raw ${_capturedData[step.key]!.rawData?.length ?? 0} values',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        )
                      : const Text(
                          'Skipped',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                  trailing: captured
                      ? TextButton(
                          onPressed: () => _reRecordStep(index),
                          child: const Text(
                            'Re-record',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryBrand,
                            ),
                          ),
                        )
                      : null,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (_isUploading)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryBrand.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: AppColors.primaryBackground,
                      color: AppColors.primaryBrand,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _uploadStatus,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _capturedData.length >= 2 ? _saveProfile : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusGreen,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Save Profile to Device',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
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
    final acProvider = Provider.of<ACProvider>(context, listen: false);

    final isBleConnected = bleService.isConnected;
    final isCloudOnline =
        acProvider.selectedDevice?['online'] == true ||
        acProvider.isWifiConnected;

    if (!isBleConnected && !isCloudOnline) {
      setState(
        () => _captureError =
            'Device is offline. Connect via Bluetooth or check Cloud status.',
      );
      return;
    }

    setState(() {
      _isCapturing = true;
      _captureError = null;
      _lastCaptureSuccess = false;
    });

    if (isBleConnected) {
      final irButton = await bleService.captureIRButton(
        timeout: const Duration(seconds: 20),
      );

      if (!mounted) return;

      if (irButton != null && irButton.isValid) {
        final key = _steps[_currentStep].key;
        setState(() {
          _capturedData[key] = irButton;
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
          _captureError =
              'No signal received. Make sure the remote is pointing at the device and try again.';
        });
      }
    } else {
      final started = await acProvider.startCloudLearn();
      if (!started) {
        if (mounted) {
          setState(() {
            _isCapturing = false;
            _captureError = 'Failed to start learning mode via Cloud.';
          });
        }
        return;
      }

      int pollCount = 0;
      const maxPolls =
          15; // 15 * 1.5s = 22.5s timeout (similar to 20s BLE timeout)

      _cloudPollTimer?.cancel();
      _cloudPollTimer = Timer.periodic(const Duration(milliseconds: 1500), (
        timer,
      ) async {
        pollCount++;
        if (pollCount > maxPolls) {
          timer.cancel();
          await acProvider.stopCloudLearn();
          if (mounted) {
            setState(() {
              _isCapturing = false;
              _captureError = 'Capture timed out. No signal received.';
            });
          }
          return;
        }

        final res = await acProvider.fetchCapturedIr();
        if (res != null && res['success'] == true && res['captured'] == true) {
          timer.cancel();
          await acProvider.stopCloudLearn();

          final dataMap = res['data'] as Map<String, dynamic>;
          final method = dataMap['method'] as String;
          IRButton? button;
          if (method == 'encoded') {
            button = IRButton(
              name: '',
              method: IRMethod.encoded,
              hexData: (dataMap['data'] as List?)
                  ?.map((e) => e.toString())
                  .toList(),
              bits: dataMap['bits'] as int?,
              hdrMark: dataMap['hdr_mark'] as int?,
              hdrSpace: dataMap['hdr_space'] as int?,
              bitMark: dataMap['bit_mark'] as int?,
              oneSpace: dataMap['one_space'] as int?,
              zeroSpace: dataMap['zero_space'] as int?,
            );
          } else if (method == 'raw') {
            button = IRButton(
              name: '',
              method: IRMethod.raw,
              rawData: (dataMap['data'] as List?)
                  ?.map((e) => int.tryParse(e.toString()) ?? 0)
                  .toList(),
            );
          }

          if (mounted) {
            if (button != null && button.isValid) {
              final key = _steps[_currentStep].key;
              setState(() {
                _capturedData[key] = button!;
                _isCapturing = false;
                _lastCaptureSuccess = true;
                _captureError = null;
              });
              await Future.delayed(const Duration(milliseconds: 800));
              if (mounted) setState(() => _currentStep++);
            } else {
              setState(() {
                _isCapturing = false;
                _captureError = 'Received invalid IR signal format from Cloud.';
              });
            }
          }
        }
      });
    }
  }

  void _cancelCapture() async {
    final bleService = Provider.of<BLEService>(context, listen: false);
    final acProvider = Provider.of<ACProvider>(context, listen: false);

    _cloudPollTimer?.cancel();
    _cloudPollTimer = null;

    if (bleService.isConnected) {
      await bleService.stopLearnMode();
    } else {
      await acProvider.stopCloudLearn();
    }

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
    setState(() {
      _isUploading = true;
      _uploadStatus = 'Saving locally...';
      _uploadProgress = 0.05;
    });

    final bleService = Provider.of<BLEService>(context, listen: false);
    final acProvider = Provider.of<ACProvider>(context, listen: false);
    final router = GoRouter.of(context);

    final profile = ACProfile(
      id: const Uuid().v4(),
      name: widget.name,
      brand: widget.brand,
      model: widget.model,
      buttons: _capturedData.map(
        (key, value) => MapEntry(
          key,
          IRButton(
            name: key,
            method: value.method,
            hexData: value.hexData,
            bits: value.bits,
            hdrMark: value.hdrMark,
            hdrSpace: value.hdrSpace,
            bitMark: value.bitMark,
            oneSpace: value.oneSpace,
            zeroSpace: value.zeroSpace,
            rawData: value.rawData,
          ),
        ),
      ),
      createdAt: DateTime.now(),
    );

    // 1. Save locally on phone
    await acProvider.addProfile(profile);

    setState(() {
      _uploadStatus = 'Uploading to Device...';
      _uploadProgress = 0.1;
    });

    // 2. Upload to ESP32 via Dynamic Config (VAR_START/VAR_CHUNK/VAR_END)
    if (bleService.isConnected) {
      // Extract timing from the power_on button (the primary reference)
      final powerOn = _capturedData['power_on'];
      final powerOff = _capturedData['power_off'];

      if (powerOn != null && powerOn.isEncoded) {
        final configName = '${widget.brand}_${widget.model ?? "AC"}';

        final config = DynamicConfig(
          acOnData: powerOn.hexData ?? [],
          acOffData: powerOff?.hexData ?? powerOn.hexData ?? [],
          irFreqKhz: 38,
          hdrMark: powerOn.hdrMark ?? 0,
          hdrSpace: powerOn.hdrSpace ?? 0,
          bitMark: powerOn.bitMark ?? 0,
          oneSpace: powerOn.oneSpace ?? 0,
          zeroSpace: powerOn.zeroSpace ?? 0,
          stopMark: powerOn.bitMark ?? 0,
          bitLength: powerOn.bits ?? 0,
          sendRepeat: 3,
        );

        final saved = await bleService.sendDynamicConfig(
          config,
          name: configName,
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _uploadProgress =
                    0.1 + (progress * 0.7); // Progress from 0.1 to 0.8
                _uploadStatus =
                    'Uploading to Device... ${(progress * 100).toInt()}%';
              });
            }
          },
        );
        if (saved) {
          await bleService.sendCommand('USE_ENC');
          debugPrint('[App] Dynamic config "$configName" uploaded to ESP32');
        } else {
          debugPrint('[App] Warning: Dynamic config upload failed');
        }
      } else if (powerOn != null && !powerOn.isEncoded && powerOn.rawData != null) {
        debugPrint('[App] power_on button is RAW — Uploading raw pattern...');
        final onOk = await bleService.sendRawConfig('ON', powerOn.rawData!);
        
        if (onOk) {
            final pOff = powerOff ?? powerOn;
            if (pOff.rawData != null) {
                await bleService.sendRawConfig('OFF', pOff.rawData!);
            }
            await bleService.sendCommand('USE_RAW');
        }
      } else {
        debugPrint('[App] power_on button is missing or invalid — config not sent');
      }
    } else {
      debugPrint('[App] Not connected — profile saved locally only');
    }

    setState(() {
      _uploadStatus = 'Syncing to cloud...';
      _uploadProgress = 0.85;
    });

    // 3. Sync full profile to cloud
    if (acProvider.deviceId != 'UNKNOWN') {
      final configName = '${widget.brand}_${widget.model ?? "AC"}';
      debugPrint(
        '[App] Synchronizing full profile to cloud for ${acProvider.deviceId}',
      );
      try {
        await ApiService.syncDevice(
          deviceId: acProvider.deviceId,
          activeConfigName: configName,
          configData: profile.toJson(),
        );
      } catch (e) {
        debugPrint('[App] Cloud sync failed: $e');
      }
    }

    setState(() {
      _uploadStatus = 'Done!';
      _uploadProgress = 1.0;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) router.go('/');
  }
}
