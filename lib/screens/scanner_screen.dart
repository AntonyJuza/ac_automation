import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:ac_automation/services/ac_provider.dart';
import 'package:ac_automation/services/ble_service.dart';
import 'package:ac_automation/services/api_service.dart';
import 'package:ac_automation/utils/constants.dart';

enum PipelineStep {
  scanning,
  checkingCloud,
  offlineBleScan,
  bleConnecting,
  wifiProvisioning,
  sendingWifi,
  connectingInternet,
  initialSetupGuide,
  success,
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  final _manualIdController = TextEditingController();
  late AnimationController _laserController;

  PipelineStep _step = PipelineStep.scanning;
  String _targetDeviceId = '';
  String _pipelineStatus = '';
  String? _pipelineError;

  // Wi-Fi inputs
  String _selectedWifi = 'AVIO_Office_5G';
  final _wifiPasswordController = TextEditingController();

  // Brand options
  final List<String> _brands = [
    'Voltas',
    'Daikin',
    'Lloyd',
    'Blue Star',
    'Carrier',
    'Samsung',
    'LG',
  ];
  String _selectedBrand = 'Voltas';

  StreamSubscription? _bleStatusSub;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _manualIdController.dispose();
    _wifiPasswordController.dispose();
    _laserController.dispose();
    _bleStatusSub?.cancel();
    super.dispose();
  }

  // --- Start Smart Pipeline ---
  Future<void> _startSmartPipeline(String deviceId) async {
    setState(() {
      _targetDeviceId = deviceId.trim().toUpperCase();
      _step = PipelineStep.checkingCloud;
      _pipelineStatus = 'Checking cloud database for $_targetDeviceId...';
      _pipelineError = null;
    });

    try {
      // Step 1: Check if the device exists in the cloud database
      final deviceData = await ApiService.getDevice(_targetDeviceId);
      final acProvider = Provider.of<ACProvider>(context, listen: false);

      if (deviceData != null) {
        // Device exists in cloud! Check if it's currently online
        final isOnline = deviceData['online'] == true;
        if (isOnline) {
          setState(() {
            _pipelineStatus = 'Device found online! Claiming device...';
          });
          final claimed = await acProvider.claimCloudDevice(_targetDeviceId);
          if (claimed) {
            _completePipeline();
          } else {
            throw Exception('Failed to claim device in your profile.');
          }
        } else {
          // Device is offline, need BLE fallback
          _startBleFallback();
        }
      } else {
        // Brand new device (doesn't exist in database yet)
        _startBleFallback(isBrandNew: true);
      }
    } catch (e) {
      setState(() {
        _step = PipelineStep.scanning;
        _pipelineError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  // --- Step 2: BLE Fallback ---
  void _startBleFallback({bool isBrandNew = false}) async {
    setState(() {
      _step = PipelineStep.offlineBleScan;
      _pipelineStatus =
          'Device is offline. Scanning for local BLE broadcast...';
    });

    final bleService = Provider.of<BLEService>(context, listen: false);

    // Scan for nearby devices
    await bleService.startScan();

    Timer(const Duration(seconds: 4), () async {
      await bleService.stopScan();

      // Find device matching our target device ID in scan results
      dynamic matchingResult;
      for (final r in bleService.scanResults) {
        final name = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.advertisementData.advName;
        if (name.toUpperCase().contains(_targetDeviceId) ||
            r.device.remoteId.toString().toUpperCase().contains(
              _targetDeviceId,
            )) {
          matchingResult = r;
          break;
        }
      }

      if (matchingResult != null) {
        // Connect to BLE
        setState(() {
          _step = PipelineStep.bleConnecting;
          _pipelineStatus = 'Found device via BLE! Connecting...';
        });

        try {
          await bleService.connectTo(matchingResult.device);

          // Connected! Proceed to WiFi provisioning
          setState(() {
            _step = PipelineStep.wifiProvisioning;
            _pipelineStatus =
                'Connected over Bluetooth. Please configure Wi-Fi.';
          });
        } catch (e) {
          setState(() {
            _step = PipelineStep.scanning;
            _pipelineError = 'Bluetooth connection failed: $e';
          });
        }
      } else {
        setState(() {
          _step = PipelineStep.scanning;
          _pipelineError =
              'Could not find local BLE signal for $_targetDeviceId. Make sure it is powered on.';
        });
      }
    });
  }

  // --- Step 3: Wi-Fi Provisioning Dialog ---
  Future<void> _submitWifiProvisioning() async {
    final pass = _wifiPasswordController.text;

    setState(() {
      _step = PipelineStep.sendingWifi;
      _pipelineStatus = 'Sending Wi-Fi credentials via BLE...';
    });

    final bleService = Provider.of<BLEService>(context, listen: false);
    final success = await bleService.setWiFi(_selectedWifi, pass);

    if (success) {
      setState(() {
        _step = PipelineStep.connectingInternet;
        _pipelineStatus =
            'SSID credentials sent! Waiting for device to connect online...';
      });

      // Subscribe to status updates from BLE to verify connection
      _bleStatusSub = bleService.statusStream.listen((msg) {
        if (msg.contains('WIFI=CONNECTED') ||
            msg.contains('WS:con') ||
            msg.contains('CONNECTED')) {
          _bleStatusSub?.cancel();
          _checkIfDeviceClaimedSuccessfully();
        }
      });

      // Timeout fallback in case status isn't broadcasted
      Timer(const Duration(seconds: 10), () {
        _checkIfDeviceClaimedSuccessfully();
      });
    } else {
      setState(() {
        _step = PipelineStep.wifiProvisioning;
        _pipelineError = 'Failed to transmit Wi-Fi settings over Bluetooth.';
      });
    }
  }

  void _checkIfDeviceClaimedSuccessfully() async {
    final acProvider = Provider.of<ACProvider>(context, listen: false);
    // Claim it in backend profile
    final claimed = await acProvider.claimCloudDevice(_targetDeviceId);

    if (claimed) {
      // Check if it's a brand new device
      final deviceData = await ApiService.getDevice(_targetDeviceId);
      final isConfigured =
          deviceData != null && deviceData['activeConfigName'] != 'NONE';

      if (!isConfigured) {
        // Route to initial setup (brand preset or IR learning wizard)
        setState(() {
          _step = PipelineStep.initialSetupGuide;
          _pipelineStatus =
              'Device registered online! Let\'s setup the IR remote controls.';
        });
      } else {
        _completePipeline();
      }
    } else {
      setState(() {
        _step = PipelineStep.scanning;
        _pipelineError =
            'Wi-Fi connection verified but profile registration failed.';
      });
    }
  }

  // --- Step 4: Brand Setup / IR Selection ---
  Future<void> _setupBrandPreset() async {
    setState(() {
      _isLoading = true;
    });

    final acProvider = Provider.of<ACProvider>(context, listen: false);

    // Sync default profile with name & brand
    final success = await ApiService.syncDevice(
      deviceId: _targetDeviceId,
      deviceName: '$_selectedBrand AC',
      activeConfigName: _selectedBrand,
    );

    if (success) {
      await acProvider.fetchCloudDevices();
      _completePipeline();
    } else {
      setState(() {
        _isLoading = false;
        _pipelineError = 'Failed to sync brand config to cloud.';
      });
    }
  }

  bool _isLoading = false;

  void _startIrLearningWizard() {
    context.pushReplacement('/setup'); // Routes to setup screen
  }

  void _completePipeline() {
    setState(() {
      _step = PipelineStep.success;
      _pipelineStatus = 'Configuration complete!';
    });

    Timer(const Duration(seconds: 2), () {
      context.go('/');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      appBar: AppBar(
        title: const Text('Add Device'),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildStepLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildStepLayout() {
    switch (_step) {
      case PipelineStep.scanning:
        return _buildScanningUI();
      case PipelineStep.checkingCloud:
      case PipelineStep.offlineBleScan:
      case PipelineStep.bleConnecting:
      case PipelineStep.sendingWifi:
      case PipelineStep.connectingInternet:
        return _buildPipelineStatusUI();
      case PipelineStep.wifiProvisioning:
        return _buildWifiProvisioningUI();
      case PipelineStep.initialSetupGuide:
        return _buildInitialSetupUI();
      case PipelineStep.success:
        return _buildSuccessUI();
    }
  }

  // --- Step 1: Scanner View ---
  Widget _buildScanningUI() {
    return Column(
      key: const ValueKey('scanning_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_pipelineError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.statusRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.statusRed.withOpacity(0.2)),
            ),
            child: Text(
              _pipelineError!,
              style: const TextStyle(
                color: AppColors.statusRed,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],

        const Text(
          'Scan QR Code',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Point your camera at the QR code printed on the side of the ESP32 controller.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 24),

        // Glowing scanning box
        Center(
          child: Container(
            height: 260,
            width: 260,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.primaryBrand.withOpacity(0.4),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    size: 80,
                    color: AppColors.textSecondary,
                  ),

                  // Scanning reticle animation
                  AnimatedBuilder(
                    animation: _laserController,
                    builder: (context, child) {
                      final topOffset = _laserController.value * 220 + 20;
                      return Positioned(
                        top: topOffset,
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.statusGreen,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.statusGreen.withOpacity(0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // QR corners overlay
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: AppColors.primaryBrand,
                            width: 4,
                          ),
                          left: BorderSide(
                            color: AppColors.primaryBrand,
                            width: 4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: AppColors.primaryBrand,
                            width: 4,
                          ),
                          right: BorderSide(
                            color: AppColors.primaryBrand,
                            width: 4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.primaryBrand,
                            width: 4,
                          ),
                          left: BorderSide(
                            color: AppColors.primaryBrand,
                            width: 4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.primaryBrand,
                            width: 4,
                          ),
                          right: BorderSide(
                            color: AppColors.primaryBrand,
                            width: 4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Quick simulation shortcut buttons
        const Text(
          'Simulated Scanner Shortcuts:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () => _startSmartPipeline('AC_1CC3ABC25754'),
              child: const Text('AC_1CC3ABC25754'),
            ),
            ElevatedButton(
              onPressed: () => _startSmartPipeline('ESP_NEW_AC'),
              child: const Text('ESP_NEW_AC'),
            ),
          ],
        ),

        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 24),

        // Manual entry fallback
        const Text(
          'Or enter Device ID manually',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _manualIdController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Device Code',
                  hintText: 'e.g. AC_1CC3ABC25754',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.primaryBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                final text = _manualIdController.text.trim();
                if (text.isNotEmpty) {
                  _startSmartPipeline(text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBrand,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Submit',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Background Pipeline Status ---
  Widget _buildPipelineStatusUI() {
    return Column(
      key: const ValueKey('pipeline_status'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 80),
        const SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            color: AppColors.primaryBrand,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          _pipelineStatus,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Please keep your phone close to the device.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  // --- Step 3: Wi-Fi setup dropdown dialog ---
  Widget _buildWifiProvisioningUI() {
    return Column(
      key: const ValueKey('wifi_provisioning'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Configure AC Wi-Fi',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Connect the controller to your Wi-Fi network so it can communicate with the cloud server.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 24),

        // Dropdown scanned SSIDs
        const Text(
          'Select Wi-Fi Network',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.primaryBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.textSecondary.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedWifi,
              isExpanded: true,
              items:
                  [
                        'AVIO_Office_5G',
                        'Home_Network_Ext',
                        'MyPrivateWifi',
                        'Guest_Access_Open',
                      ]
                      .map(
                        (val) => DropdownMenuItem(value: val, child: Text(val)),
                      )
                      .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedWifi = val);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Password input
        const Text(
          'Enter Wi-Fi Password',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _wifiPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Password',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: AppColors.primaryBackground,
          ),
        ),
        const SizedBox(height: 40),

        ElevatedButton(
          onPressed: _submitWifiProvisioning,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBrand,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Provision Wi-Fi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // --- Step 4: Brand Preset vs IR learn ---
  Widget _buildInitialSetupUI() {
    return Column(
      key: const ValueKey('initial_setup'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Brand Presets Setup',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Configure remote signals. Select your AC brand from presets or record manually.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 32),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primaryBackground,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [AppStyles.softShadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select AC Brand Preset',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.secondaryBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedBrand,
                    isExpanded: true,
                    items: _brands
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedBrand = val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _setupBrandPreset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBrand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Apply Brand Preset',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // IR Learning trigger
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.primaryBackground,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [AppStyles.softShadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Option 2: IR Learning Wizard',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              const Text(
                'Point your AC remote at the TSOP component on the dongle and record each button step by step.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _startIrLearningWizard,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(
                    color: AppColors.primaryBrand,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Start Remote Learning Wizard',
                  style: TextStyle(
                    color: AppColors.primaryBrand,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Success confirmation ---
  Widget _buildSuccessUI() {
    return Column(
      key: const ValueKey('success_view'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 80),
        const CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.statusGreen,
          child: Icon(Icons.check, size: 40, color: Colors.white),
        ),
        const SizedBox(height: 24),
        const Text(
          'Device Set Up Successfully!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Adding $_targetDeviceId to your home dashboard...',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}
