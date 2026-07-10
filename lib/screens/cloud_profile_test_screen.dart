import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:ac_automation/models/ac_profile.dart';
import 'package:ac_automation/models/ir_button.dart';
import 'package:ac_automation/services/cloud_ir_service.dart';
import 'package:ac_automation/services/ac_provider.dart';
import 'package:ac_automation/services/ble_service.dart';
import 'package:ac_automation/services/api_service.dart';
import 'package:ac_automation/models/dynamic_config.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class CloudProfileTestScreen extends StatefulWidget {
  final String brand;
  const CloudProfileTestScreen({super.key, required this.brand});

  @override
  State<CloudProfileTestScreen> createState() => _CloudProfileTestScreenState();
}

class _CloudProfileTestScreenState extends State<CloudProfileTestScreen>
    with TickerProviderStateMixin {
  List<CloudIRProfile> _profiles = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _error;

  CloudIRProfile? _detailedProfile;
  bool _isDetailLoading = false;

  // Simulated AC state for testing
  bool _isPowerOn = false;
  int _temperature = 24;
  int _fanSpeed = 0; // 0=auto, 1=low, 2=med, 3=high
  int _mode = 0; // 0=cool, 1=dry, 2=fan, 3=heat, 4=auto
  bool _isSending = false;

  // Device naming
  final _nameController = TextEditingController();
  bool _showNameInput = false;
  bool _isSaving = false;

  late AnimationController _pulseController;

  final _fanLabels = ['Auto', 'Low', 'Med', 'High'];
  final _modeLabels = ['Cool', 'Dry', 'Fan', 'Heat', 'Auto'];
  final _modeIcons = [
    Icons.ac_unit,
    Icons.water_drop,
    Icons.air,
    Icons.whatshot,
    Icons.autorenew,
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadProfiles();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final profiles = await CloudIRService.fetchProfilesForBrand(widget.brand);
    if (mounted) {
      setState(() {
        _profiles = profiles;
        _isLoading = false;
        if (profiles.isEmpty) {
          _error = 'No cloud profiles found for ${widget.brand}';
        }
      });
      if (profiles.isNotEmpty) {
        _loadProfileDetails();
      }
    }
  }

  CloudIRProfile? get _currentProfile =>
      _profiles.isNotEmpty ? _profiles[_currentIndex] : null;

  Future<void> _loadProfileDetails() async {
    final profile = _currentProfile;
    if (profile == null) return;

    if (profile.buttons.isNotEmpty) {
      setState(() {
        _detailedProfile = profile;
      });
      return;
    }

    setState(() {
      _isDetailLoading = true;
      _detailedProfile = null;
    });

    final detailed = await CloudIRService.fetchProfileDetails(profile.id);
    if (mounted && detailed != null) {
      setState(() {
        _profiles[_currentIndex] = detailed;
        _detailedProfile = detailed;
        _isDetailLoading = false;
      });
    } else if (mounted) {
      setState(() {
        _isDetailLoading = false;
      });
      _showSnack('Failed to load profile buttons');
    }
  }

  void _nextProfile() {
    if (_profiles.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _profiles.length;
      _isPowerOn = false;
      _temperature = 24;
    });
    _loadProfileDetails();
  }

  void _prevProfile() {
    if (_profiles.isEmpty) return;
    setState(() {
      _currentIndex =
          (_currentIndex - 1 + _profiles.length) % _profiles.length;
      _isPowerOn = false;
      _temperature = 24;
    });
    _loadProfileDetails();
  }

  Future<void> _sendButton(String key) async {
    final profile = _detailedProfile;
    if (profile == null) {
      _showSnack('Profile details not loaded yet');
      return;
    }
    final button = profile.buttons[key];
    if (button == null) {
      _showSnack('Button "$key" not available in this profile');
      return;
    }

    setState(() => _isSending = true);
    _pulseController.forward(from: 0);

    final bleService = Provider.of<BLEService>(context, listen: false);
    final acProvider = Provider.of<ACProvider>(context, listen: false);

    bool success = false;
    if (bleService.isConnected) {
      success = await bleService.transmitButton(key, button);
    } else if (acProvider.deviceId != 'UNKNOWN') {
      // Send via cloud MQTT
      success = await ApiService.sendIRCommand(
        deviceId: acProvider.deviceId,
        button: button,
        key: key,
      );
    }

    if (mounted) {
      setState(() => _isSending = false);
      if (!success) {
        _showSnack('Failed to send command. Check connection.');
      }
    }
  }

  String _resolveModeKey() {
    final profile = _detailedProfile;
    if (profile == null) return 'mode';
    
    final keysToTry = <String>[];
    switch (_mode) {
      case 0:
        keysToTry.addAll(['mode_->_cool', 'mode_cool', 'cool']);
        break;
      case 1:
        keysToTry.addAll(['mode_->_dehumidify', 'mode_->_dry', 'mode_dry', 'dry']);
        break;
      case 2:
        keysToTry.addAll(['mode_->_fan', 'mode_fan', 'fan']);
        break;
      case 3:
        keysToTry.addAll(['mode_->_heat', 'mode_heat', 'heat']);
        break;
      case 4:
        keysToTry.addAll(['mode_->_auto', 'mode_auto', 'auto']);
        break;
    }
    for (final k in keysToTry) {
      if (profile.buttons.containsKey(k)) return k;
    }
    return 'mode';
  }

  String _resolveFanKey() {
    final profile = _detailedProfile;
    if (profile == null) return 'fan_speed';
    
    final keysToTry = <String>[];
    switch (_fanSpeed) {
      case 1:
        keysToTry.addAll(['fan_low', 'fanLow', 'low']);
        break;
      case 2:
        keysToTry.addAll(['fan_medium', 'fan_med', 'medium', 'med']);
        break;
      case 3:
        keysToTry.addAll(['fan_high', 'fanHigh', 'high']);
        break;
      case 0:
      default:
        keysToTry.addAll(['fan_auto', 'fanAuto', 'auto']);
        break;
    }
    for (final k in keysToTry) {
      if (profile.buttons.containsKey(k)) return k;
    }
    return 'fan_speed';
  }

  String _resolveTempKey(int temp) {
    final profile = _detailedProfile;
    if (profile == null) return 'temp_up';
    
    final modeStr = _modeLabels[_mode].toLowerCase();
    final modeTempKey = '${modeStr}_temp_$temp';
    if (profile.buttons.containsKey(modeTempKey)) {
      return modeTempKey;
    }
    
    final generalTempKey = 'temp_$temp';
    if (profile.buttons.containsKey(generalTempKey)) {
      return generalTempKey;
    }
    
    return '';
  }

  void _onPowerTap() {
    setState(() => _isPowerOn = !_isPowerOn);
    _sendButton(_isPowerOn ? 'power_on' : 'power_off');
  }

  void _onTempUp() {
    if (_temperature < 30) {
      setState(() => _temperature++);
      final key = _resolveTempKey(_temperature);
      if (key.isNotEmpty) {
        _sendButton(key);
      } else {
        _sendButton('temp_up');
      }
    }
  }

  void _onTempDown() {
    if (_temperature > 16) {
      setState(() => _temperature--);
      final key = _resolveTempKey(_temperature);
      if (key.isNotEmpty) {
        _sendButton(key);
      } else {
        _sendButton('temp_down');
      }
    }
  }

  void _onFanTap() {
    setState(() => _fanSpeed = (_fanSpeed + 1) % _fanLabels.length);
    final key = _resolveFanKey();
    _sendButton(key);
  }

  void _onModeTap() {
    setState(() => _mode = (_mode + 1) % _modeLabels.length);
    final key = _resolveModeKey();
    _sendButton(key);
  }

  void _onConfirm() {
    setState(() => _showNameInput = true);
    _nameController.text = '${widget.brand} AC';
  }

  Future<void> _saveProfile() async {
    final profile = _detailedProfile;
    if (profile == null) {
      _showSnack('Profile details not loaded yet');
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Please enter a device name');
      return;
    }

    setState(() => _isSaving = true);

    final acProvider = Provider.of<ACProvider>(context, listen: false);
    final bleService = Provider.of<BLEService>(context, listen: false);
    final router = GoRouter.of(context);

    final acProfile = ACProfile(
      id: const Uuid().v4(),
      name: name,
      brand: widget.brand,
      model: profile.model,
      buttons: Map.from(profile.buttons),
      createdAt: DateTime.now(),
    );

    // Save locally
    await acProvider.addProfile(acProfile);

    // Upload to ESP32 if connected
    if (bleService.isConnected) {
      final powerOn = profile.buttons['power_on'];
      final powerOff = profile.buttons['power_off'];

      if (powerOn != null && powerOn.isEncoded) {
        final configName = '${widget.brand}_AC';
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
        final saved = await bleService.sendDynamicConfig(config, name: configName);
        if (saved) await bleService.sendCommand('USE_ENC');
      } else if (powerOn != null && !powerOn.isEncoded && powerOn.rawData != null) {
        final onOk = await bleService.sendRawConfig('ON', powerOn.rawData!);
        if (onOk) {
          final pOff = powerOff ?? powerOn;
          if (pOff.rawData != null) {
            await bleService.sendRawConfig('OFF', pOff.rawData!);
          }
          await bleService.sendCommand('USE_RAW');
        }
      }
    }

    // Sync to cloud
    if (acProvider.deviceId != 'UNKNOWN') {
      final configName = '${widget.brand}_AC';
      try {
        await ApiService.syncDevice(
          deviceId: acProvider.deviceId,
          deviceName: name,
          activeConfigName: configName,
          configData: acProfile.toJson(),
        );
      } catch (e) {
        debugPrint('[CloudTest] Cloud sync failed: $e');
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
      router.go('/');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showNameInput) return _buildNameInputPage();

    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBackground,
        title: Text(widget.brand),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_profiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBrand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${_profiles.length}',
                    style: const TextStyle(
                      color: AppColors.primaryBrand,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryBrand))
          : _error != null
              ? _buildErrorView()
              : _buildRemoteView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 56,
                color: AppColors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBrand,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Go Back',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteView() {
    return Column(
      children: [
        // Status Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          color: AppColors.primaryBackground,
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isDetailLoading
                      ? 'Loading cloud preset details...'
                      : 'Test each button. If your AC responds, tap ✓',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
              if (_isSending || _isDetailLoading)
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primaryBrand),
                ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Temperature Display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBackground,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [AppStyles.softShadow],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _isPowerOn ? 'ON' : 'OFF',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _isPowerOn
                              ? AppColors.statusGreen
                              : AppColors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_temperature',
                            style: const TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.w200,
                              color: AppColors.textPrimary,
                              height: 1,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              '°C',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w300,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _MiniChip(
                            icon: _modeIcons[_mode],
                            label: _modeLabels[_mode],
                          ),
                          const SizedBox(width: 8),
                          _MiniChip(
                            icon: Icons.air,
                            label: _fanLabels[_fanSpeed],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Control Grid
                Row(
                  children: [
                    // Temp Down
                    Expanded(
                      child: _RemoteButton(
                        icon: Icons.remove,
                        label: 'Temp −',
                        onTap: _onTempDown,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Power
                    Expanded(
                      child: _RemoteButton(
                        icon: Icons.power_settings_new,
                        label: 'Power',
                        isPrimary: true,
                        isActive: _isPowerOn,
                        onTap: _onPowerTap,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Temp Up
                    Expanded(
                      child: _RemoteButton(
                        icon: Icons.add,
                        label: 'Temp +',
                        onTap: _onTempUp,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _RemoteButton(
                        icon: Icons.air,
                        label: _fanLabels[_fanSpeed],
                        onTap: _onFanTap,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RemoteButton(
                        icon: _modeIcons[_mode],
                        label: _modeLabels[_mode],
                        onTap: _onModeTap,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Profile Navigation
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBackground,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [AppStyles.softShadow],
                  ),
                  child: Row(
                    children: [
                      _NavButton(
                        icon: Icons.skip_previous_rounded,
                        onTap: _prevProfile,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Profile ${_currentIndex + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 15,
                              ),
                            ),
                            if (_currentProfile?.model != null)
                              Text(
                                _currentProfile!.model!,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      _NavButton(
                        icon: Icons.skip_next_rounded,
                        onTap: _nextProfile,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Confirm Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _onConfirm,
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text(
                      'This Profile Works!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusGreen,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameInputPage() {
    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryBackground,
        title: const Text('Name Your Device'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _showNameInput = false),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryBackground,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [AppStyles.softShadow],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.statusGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.check_circle,
                            color: AppColors.statusGreen, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.brand,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: AppColors.textPrimary)),
                            Text(
                              'Profile ${_currentIndex + 1} selected',
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Device Name',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'e.g. Living Room, Bedroom',
                      hintStyle: TextStyle(
                          color:
                              AppColors.textSecondary.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: AppColors.secondaryBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBrand,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Done',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _RemoteButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final bool isActive;
  final VoidCallback onTap;

  const _RemoteButton({
    required this.icon,
    required this.label,
    this.isPrimary = false,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: isPrimary
              ? (isActive ? AppColors.statusGreen : AppColors.primaryBrand)
              : AppColors.primaryBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [AppStyles.softShadow],
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 28,
                color: isPrimary ? Colors.white : AppColors.textPrimary),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPrimary ? Colors.white : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryBrand.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primaryBrand, size: 24),
      ),
    );
  }
}
