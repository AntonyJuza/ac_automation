import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:ac_automation/services/ac_provider.dart';
import 'package:ac_automation/services/api_service.dart';
import 'package:ac_automation/models/ac_profile.dart';
import 'dart:math' as math;
import 'dart:async';

class ControlScreen extends StatefulWidget {
  final ACProfile profile;
  const ControlScreen({super.key, required this.profile});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _activeDeviceIndex = 0;
  String? _activeDeviceId;
  Timer? _pollTimer;

  // AC States
  double _temperature = 22.0;
  String _mode = 'Cool';
  bool _isPowerOn = true;
  bool _presenceAutomation = true;

  // Animation controllers
  late AnimationController _breathController;
  late Animation<double> _breathAnimation;
  late AnimationController _airflowController;
  late Animation<double> _airflowYAnimation;
  late Animation<double> _airflowAlphaAnimation;

  @override
  void initState() {
    super.initState();
    _isPowerOn = widget.profile.buttons.containsKey('power_on');

    _pageController = PageController();

    // Breathing animation for AC running status
    _breathController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _breathAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );
    _breathController.repeat(reverse: true);

    // Airflow animation for active fan flow
    _airflowController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _airflowYAnimation = Tween<double>(begin: 0.0, end: 24.0).animate(
      CurvedAnimation(parent: _airflowController, curve: Curves.linear),
    );
    _airflowAlphaAnimation =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.8, end: 0.2),
            weight: 50.0,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.2, end: 0.8),
            weight: 50.0,
          ),
        ]).animate(
          CurvedAnimation(parent: _airflowController, curve: Curves.linear),
        );

    if (_isPowerOn) {
      _airflowController.repeat();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final acProvider = Provider.of<ACProvider>(context, listen: false);
      final index = acProvider.cloudDevices.indexWhere(
        (d) => d['deviceId'] == widget.profile.id,
      );
      if (index >= 0) {
        setState(() {
          _activeDeviceIndex = index;
          _activeDeviceId = widget.profile.id;
        });
        _pageController.jumpToPage(index);
      }
      setState(() {
        _presenceAutomation = !acProvider.radarBypassed;
      });

      // Poll cloud devices status every 5 seconds while on this screen
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted && acProvider.cloudDevices.isNotEmpty) {
          acProvider.fetchCloudDevices();
        }
      });
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pageController.dispose();
    _breathController.dispose();
    _airflowController.dispose();
    super.dispose();
  }

  void _onDeviceChanged(int index, ACProvider acProvider) {
    setState(() {
      _activeDeviceIndex = index;
      if (acProvider.cloudDevices.length > index) {
        _activeDeviceId = acProvider.cloudDevices[index]['deviceId'];
      }
    });
    final dev = acProvider.cloudDevices[index];
    acProvider.selectDevice(dev);

    // Sync local state with active device
    setState(() {
      _isPowerOn = dev['powerState'] ?? false;
      _temperature = 22.0; // default template or last set
      _mode = 'Cool';
      _presenceAutomation = !(dev['radarBypassed'] ?? false);
    });

    if (_isPowerOn) {
      _airflowController.repeat();
    } else {
      _airflowController.stop();
    }
  }

  void _cycleMode(String mode) {
    setState(() {
      _mode = mode;
    });
  }

  Future<void> _updateTemperature(String deviceId, double temp) async {
    final success = await ApiService.changeTemperature(
      deviceId: deviceId,
      temp: temp.toInt(),
    );
    if (success) {
      debugPrint('[ControlScreen] Temperature updated to ${temp.toInt()}°C');
    } else {
      debugPrint('[ControlScreen] Failed to update temperature');
    }
  }

  // --- Show Premium Settings Dialog ---
  void _openSettingsMenu(
    BuildContext context,
    Map<String, dynamic> device,
    ACProvider acProvider,
  ) {
    final nameController = TextEditingController(
      text: device['deviceName'] ?? 'Smart AC Node',
    );
    bool isPresenceOn = _presenceAutomation;
    int selectedDefaultTemp = device['configData']?['defaultTurnOnTemp'] ?? 0;
    // Get delays in seconds
    double onTimeSec = (acProvider.onTimeMs / 1000.0).clamp(5.0, 120.0);
    double offTimeSec = (acProvider.offTimeMs / 1000.0).clamp(10.0, 600.0);
    String configBrand = device['activeConfigName'] ?? 'Voltas';
    final brands = [
      'Voltas',
      'Daikin',
      'Lloyd',
      'Blue Star',
      'Carrier',
      'LG',
      'Samsung',
    ];
    if (!brands.contains(configBrand)) {
      brands.add(configBrand);
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.primaryBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              'Controller Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontSize: 18,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // RENAME FIELD
                  const Text(
                    'Custom Name',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.black.withOpacity(0.12),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primaryBrand,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // PRESENCE AUTOMATION RADAR SWITCH
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LD2410 Radar Sensor',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Automate AC power based on presence',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isPresenceOn,
                        onChanged: (val) {
                          setDialogState(() {
                            isPresenceOn = val;
                          });
                        },
                        activeColor: AppColors.primaryBrand,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (isPresenceOn) ...[
                    // PRESENCE ON TIME CONFIG SLIDER
                    Text(
                      'Presence On Time: ${onTimeSec.toInt()}s',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryBrand,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Time required to trigger Power-On',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Slider(
                      value: onTimeSec,
                      min: 5,
                      max: 120,
                      activeColor: AppColors.primaryBrand,
                      inactiveColor: Colors.black.withOpacity(0.12),
                      onChanged: (val) {
                        setDialogState(() {
                          onTimeSec = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // PRESENCE OFF TIME CONFIG SLIDER
                    Text(
                      'Absence Off Time: ${offTimeSec.toInt()}s',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryBrand,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Time empty room triggers Power-Off',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Slider(
                      value: offTimeSec,
                      min: 10,
                      max: 600,
                      activeColor: AppColors.primaryBrand,
                      inactiveColor: Colors.black.withOpacity(0.12),
                      onChanged: (val) {
                        setDialogState(() {
                          offTimeSec = val;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Brand selection dropdown
                  const Text(
                    'Active Brand Preset',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withOpacity(0.12)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: configBrand,
                        dropdownColor: AppColors.primaryBackground,
                        style: const TextStyle(color: AppColors.textPrimary),
                        items: brands
                            .map(
                              (b) => DropdownMenuItem(
                                value: b,
                                child: Text(
                                  b,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              configBrand = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Default Turn-On Temperature dropdown
                  const Text(
                    'Default Turn-On Temperature',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withOpacity(0.12)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedDefaultTemp,
                        dropdownColor: AppColors.primaryBackground,
                        style: const TextStyle(color: AppColors.textPrimary),
                        items: [
                          const DropdownMenuItem<int>(
                            value: 0,
                            child: Text(
                              'Standard (Power ON button)',
                              style: TextStyle(color: AppColors.textPrimary),
                            ),
                          ),
                          ...List.generate(15, (index) {
                            final temp = 16 + index;
                            // Check if this temp button exists in the learned buttons
                            final hasTempPattern = device['configData']?['buttons']?['temp_$temp'] != null;
                            return DropdownMenuItem<int>(
                              value: temp,
                              child: Text(
                                '$temp°C${hasTempPattern ? "" : " (Not Learned)"}',
                                style: TextStyle(
                                  color: hasTempPattern
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedDefaultTemp = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      context.push('/setup');
                    },
                    icon: const Icon(
                      Icons.settings_remote_outlined,
                      size: 18,
                      color: AppColors.primaryBrand,
                    ),
                    label: const Text(
                      'Re-launch IR Learning Wizard',
                      style: TextStyle(color: AppColors.primaryBrand),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.primaryBrand),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newName = nameController.text.trim();
                  final onMs = (onTimeSec * 1000).round();
                  final offMs = (offTimeSec * 1000).round();

                  Navigator.pop(dialogCtx);

                  // Sync parameters to Cloud
                  await ApiService.syncDevice(
                    deviceId: device['deviceId'],
                    deviceName: newName,
                    activeConfigName: configBrand,
                    defaultTurnOnTemp: selectedDefaultTemp,
                  );
                  await acProvider.setCloudTiming(onMs, offMs);
                  await acProvider.setRadarBypass(!isPresenceOn);
                  await acProvider.fetchCloudDevices();

                  setState(() {
                    _presenceAutomation = isPresenceOn;
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Settings saved successfully!'),
                        backgroundColor: AppColors.statusGreen,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBrand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final acProvider = Provider.of<ACProvider>(context);
    final deviceList = acProvider.cloudDevices;

    // Keep _activeDeviceIndex synchronized with _activeDeviceId if the list changes/shuffles
    if (_activeDeviceId != null && deviceList.isNotEmpty) {
      final idx = deviceList.indexWhere((d) => d['deviceId'] == _activeDeviceId);
      if (idx >= 0 && idx != _activeDeviceIndex) {
        _activeDeviceIndex = idx;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients) {
            _pageController.jumpToPage(idx);
          }
        });
      }
    }

    final activeDevice = deviceList.isNotEmpty
        ? deviceList[_activeDeviceIndex]
        : null;

    if (activeDevice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Device Control')),
        body: const Center(child: Text('No active device selected.')),
      );
    }

    // Sync local state when backend state changes (e.g. from sensor turning AC on/off)
    final serverPower = activeDevice['powerState'] ?? false;
    if (serverPower != _isPowerOn) {
      _isPowerOn = serverPower;
      if (_isPowerOn) {
        _airflowController.repeat();
      } else {
        _airflowController.stop();
      }
    }

    final config = activeDevice['configData'];
    if (config != null && config['temperature'] != null) {
      final serverTemp = (config['temperature'] as num).toDouble();
      if (serverTemp != _temperature) {
        _temperature = serverTemp;
      }
    }

    final isOnline = activeDevice['online'] ?? false;
    final room =
        activeDevice['roomName'] ?? activeDevice['deviceName'] ?? 'Room';

    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      body: Container(
        decoration: const BoxDecoration(color: AppColors.secondaryBackground),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Custom Header Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button
                    GestureDetector(
                      onTap: () => context.go('/'),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),

                    // Device Switching Tabs
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: List.generate(
                            math.min(2, deviceList.length),
                            (index) {
                              final dev = deviceList[index];
                              final isCurrent = index == _activeDeviceIndex;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: GestureDetector(
                                    onTap: () {
                                      _pageController.animateToPage(
                                        index,
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeInOut,
                                      );
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isCurrent
                                            ? AppColors.primaryBrand
                                            : Colors.white.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Center(
                                        child: Text(
                                          dev['deviceName'] ?? 'Room AC',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isCurrent
                                                ? Colors.white
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // Settings Button
                    GestureDetector(
                      onTap: () =>
                          _openSettingsMenu(context, activeDevice, acProvider),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.settings,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Scrollable content area for active device
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (idx) => _onDeviceChanged(idx, acProvider),
                  itemCount: deviceList.length,
                  itemBuilder: (context, index) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          // CENTER AC ILLUSTRATION & AIRFLOW ANIMATION
                          SizedBox(
                            width: double.infinity,
                            height: 180,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Glow Background
                                if (isOnline && _isPowerOn)
                                  Container(
                                    width: 160,
                                    height: 160,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          AppColors.primaryBrand.withOpacity(
                                            0.3,
                                          ),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),

                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // AC Vector drawing container
                                    Container(
                                      width: 210,
                                      height: 65,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.06,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: _isPowerOn
                                              ? AppColors.primaryBrand
                                                    .withOpacity(0.2)
                                              : Colors.black.withOpacity(0.08),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
                                          // Subtle horizontal grill line near top
                                          Positioned(
                                            top: 8,
                                            left: 15,
                                            right: 15,
                                            child: Container(
                                              height: 2,
                                              color: Colors.black.withOpacity(
                                                0.05,
                                              ),
                                            ),
                                          ),
                                          // Main AC Display & Icons
                                          Align(
                                            alignment: Alignment.center,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                  ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  // Left side brand/status
                                                  Row(
                                                    children: [
                                                      ColorFiltered(
                                                        colorFilter: ColorFilter.mode(
                                                          _isPowerOn
                                                              ? AppColors
                                                                    .primaryBrand
                                                              : AppColors
                                                                    .textSecondary
                                                                    .withOpacity(
                                                                      0.5,
                                                                    ),
                                                          BlendMode.srcIn,
                                                        ),
                                                        child: Image.asset(
                                                          'assets/20.png',
                                                          width: 16,
                                                          height: 16,
                                                          fit: BoxFit.contain,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      // Mini status LED indicator
                                                      Container(
                                                        width: 6,
                                                        height: 6,
                                                        decoration: BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color: _isPowerOn
                                                              ? AppColors
                                                                    .statusGreen
                                                              : Colors.black
                                                                    .withOpacity(
                                                                      0.1,
                                                                    ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  // Right side LED Temperature display
                                                  if (_isPowerOn)
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors
                                                            .primaryBrand
                                                            .withOpacity(0.08),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        "${_temperature.toInt()}°C",
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: AppColors
                                                              .primaryBrand,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    )
                                                  else
                                                    Text(
                                                      "OFF",
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: AppColors
                                                            .textSecondary
                                                            .withOpacity(0.6),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          // Bottom swing flap line
                                          Positioned(
                                            bottom: 6,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              height: 3,
                                              color: _isPowerOn
                                                  ? AppColors.primaryBrand
                                                        .withOpacity(0.25)
                                                  : Colors.black.withOpacity(
                                                      0.06,
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 14),

                                    // Airflow animation waves
                                    AnimatedBuilder(
                                      animation: _airflowController,
                                      builder: (context, child) {
                                        return Opacity(
                                          opacity: _isPowerOn
                                              ? _airflowAlphaAnimation.value
                                              : 0.0,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: List.generate(3, (idx) {
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                    ),
                                                child: Transform.translate(
                                                  offset: Offset(
                                                    0,
                                                    _airflowYAnimation.value,
                                                  ),
                                                  child: Transform.rotate(
                                                    angle: math.pi / 2,
                                                    child: ColorFiltered(
                                                      colorFilter:
                                                          const ColorFilter.mode(
                                                            AppColors
                                                                .primaryBrand,
                                                            BlendMode.srcIn,
                                                          ),
                                                      child: Image.asset(
                                                        'assets/20.png',
                                                        width: 24,
                                                        height: 24,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // SUBTITLE DEVICE NAME
                          Text(
                            activeDevice['deviceName'] ?? 'Bedroom AC',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.primaryBrand,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "$room Comfort",
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          if (isOnline && _isPowerOn && !(activeDevice['presence'] ?? false) && (activeDevice['radarBypassed'] ?? false))
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.statusRed.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.statusRed.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: AppColors.statusRed,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Radar is bypassed, AC is ON, but no one is in the room.',
                                      style: TextStyle(
                                        color: AppColors.statusRed.withOpacity(0.9),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 24),

                          // TEMPERATURE CIRCULAR SLIDER
                          _CircularTempSlider(
                            temperature: _temperature,
                            isPowerOn: _isPowerOn,
                            onTemperatureChanged: (temp) {
                              setState(() {
                                _temperature = temp;
                              });
                            },
                            onTemperatureChangeEnd: (temp) {
                              _updateTemperature(activeDevice['deviceId'], temp);
                            },
                          ),

                          const SizedBox(height: 24),

                          // POWER & OPERATION MODES ROW
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Mode selector
                              GestureDetector(
                                onTap: () {
                                  if (isOnline && _isPowerOn) {
                                    final modes = [
                                      'Cool',
                                      'Heat',
                                      'Eco',
                                      'Auto',
                                    ];
                                    int currentIdx = modes.indexOf(_mode);
                                    String nextMode =
                                        modes[(currentIdx + 1) % modes.length];
                                    _cycleMode(nextMode);
                                  }
                                },
                                child: Column(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: (isOnline && _isPowerOn)
                                            ? AppColors.primaryBrand
                                                  .withOpacity(0.08)
                                            : Colors.white.withOpacity(0.06),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.15),
                                        ),
                                      ),
                                      child: _mode == 'Cool'
                                          ? ColorFiltered(
                                              colorFilter: ColorFilter.mode(
                                                (isOnline && _isPowerOn)
                                                    ? AppColors.primaryBrand
                                                    : AppColors.textSecondary,
                                                BlendMode.srcIn,
                                              ),
                                              child: Image.asset(
                                                'assets/20.png',
                                                width: 24,
                                                height: 24,
                                                fit: BoxFit.contain,
                                              ),
                                            )
                                          : Icon(
                                              _mode == 'Heat'
                                                  ? Icons.wb_sunny_rounded
                                                  : _mode == 'Eco'
                                                  ? Icons.eco_rounded
                                                  : Icons.hdr_auto_rounded,
                                              color: (isOnline && _isPowerOn)
                                                  ? AppColors.primaryBrand
                                                  : AppColors.textSecondary,
                                              size: 24,
                                            ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      (isOnline && _isPowerOn) ? _mode : "Mode",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: (isOnline && _isPowerOn)
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Power button
                              GestureDetector(
                                onTap: () async {
                                  if (!isOnline) return;
                                  final nextState = !_isPowerOn;
                                  final success =
                                      await ApiService.toggleDevicePower(
                                        activeDevice['deviceId'],
                                        nextState,
                                      );
                                  if (success) {
                                    setState(() {
                                      _isPowerOn = nextState;
                                    });
                                    if (nextState) {
                                      _airflowController.repeat();
                                    } else {
                                      _airflowController.stop();
                                    }
                                  }
                                },
                                child: Column(
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: _isPowerOn
                                            ? AppColors.primaryBrand
                                            : Colors.white.withOpacity(0.08),
                                        shape: BoxShape.circle,
                                        boxShadow: _isPowerOn
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.primaryBrand
                                                      .withOpacity(0.3),
                                                  blurRadius: 12,
                                                  spreadRadius: 2,
                                                ),
                                              ]
                                            : [],
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.power_settings_new,
                                        color: _isPowerOn
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _isPowerOn ? "Turn Off" : "Turn On",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Presence automation status
                              GestureDetector(
                                onTap: () async {
                                  final nextState = !_presenceAutomation;
                                  final success = await acProvider.setRadarBypass(!nextState);
                                  if (success) {
                                    setState(() {
                                      _presenceAutomation = nextState;
                                    });
                                  } else {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Failed to update Radar Bypass state.'),
                                          backgroundColor: AppColors.statusRed,
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: Column(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.06),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.15),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.sensor_occupied,
                                        color: _presenceAutomation
                                            ? AppColors.statusGreen
                                            : AppColors.statusRed,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _presenceAutomation
                                          ? "Radar On"
                                          : "Radar Off",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _presenceAutomation
                                            ? AppColors.statusGreen
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Premium Circular Temperature Slider ---
class _CircularTempSlider extends StatefulWidget {
  final double temperature;
  final bool isPowerOn;
  final ValueChanged<double> onTemperatureChanged;
  final ValueChanged<double>? onTemperatureChangeEnd;

  const _CircularTempSlider({
    required this.temperature,
    required this.isPowerOn,
    required this.onTemperatureChanged,
    this.onTemperatureChangeEnd,
  });

  @override
  State<_CircularTempSlider> createState() => _CircularTempSliderState();
}

class _CircularTempSliderState extends State<_CircularTempSlider> {
  late double _currentTemp;

  @override
  void initState() {
    super.initState();
    _currentTemp = widget.temperature;
  }

  @override
  void didUpdateWidget(covariant _CircularTempSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.temperature != widget.temperature) {
      _currentTemp = widget.temperature;
    }
  }

  void _handleDrag(Offset localPosition, Size size) {
    if (!widget.isPowerOn) return;

    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;

    // Calculate angle in radians
    double angleRad = math.atan2(dy, dx);
    double angleDeg = angleRad * 180 / math.pi;

    if (angleDeg < 0) {
      angleDeg += 360;
    }

    // Split bottom gap (40 to 140) at 90 degrees to prevent sudden jumping:
    // Left of 90 degrees snaps to 140 (16.0°C), right of 90 degrees snaps to 400 (30.0°C).
    double normalizedAngle = angleDeg;
    if (normalizedAngle < 90.0) {
      if (normalizedAngle >= 40.0) {
        normalizedAngle = 400.0;
      } else {
        normalizedAngle += 360;
      }
    } else {
      if (normalizedAngle < 140.0) {
        normalizedAngle = 140.0;
      }
    }

    final clampedAngle = normalizedAngle.clamp(140.0, 400.0);
    final fraction = (clampedAngle - 140.0) / 260.0;
    final resolvedTemp = 16.0 + (fraction * 14.0);

    setState(() {
      _currentTemp = resolvedTemp.clamp(16.0, 30.0);
    });
    widget.onTemperatureChanged(_currentTemp);
  }

  @override
  Widget build(BuildContext context) {
    const size = Size(240, 240);
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanUpdate: (details) => _handleDrag(details.localPosition, size),
          onPanStart: (details) => _handleDrag(details.localPosition, size),
          onPanEnd: (_) {
            if (widget.isPowerOn && widget.onTemperatureChangeEnd != null) {
              widget.onTemperatureChangeEnd!(_currentTemp);
            }
          },
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: size,
                  painter: _CircularSliderPainter(
                    temperature: _currentTemp,
                    isPowerOn: widget.isPowerOn,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.isPowerOn)
                          GestureDetector(
                            onTap: () {
                              if (_currentTemp > 16.0) {
                                final newTemp = (_currentTemp - 1.0).clamp(16.0, 30.0);
                                setState(() {
                                  _currentTemp = newTemp;
                                });
                                widget.onTemperatureChanged(_currentTemp);
                                if (widget.onTemperatureChangeEnd != null) {
                                  widget.onTemperatureChangeEnd!(_currentTemp);
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.05),
                              ),
                              child: const Icon(
                                Icons.remove,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                            ),
                          ),
                        const SizedBox(width: 14),
                        Text(
                          widget.isPowerOn ? _currentTemp.toStringAsFixed(0) : "--",
                          style: const TextStyle(
                            fontSize: 58,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 14),
                        if (widget.isPowerOn)
                          GestureDetector(
                            onTap: () {
                              if (_currentTemp < 30.0) {
                                final newTemp = (_currentTemp + 1.0).clamp(16.0, 30.0);
                                setState(() {
                                  _currentTemp = newTemp;
                                });
                                widget.onTemperatureChanged(_currentTemp);
                                if (widget.onTemperatureChangeEnd != null) {
                                  widget.onTemperatureChangeEnd!(_currentTemp);
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.05),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.isPowerOn ? "TARGET TEMPERATURE" : "STANDBY MODE",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: widget.isPowerOn
                            ? AppColors.primaryBrand
                            : AppColors.textSecondary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CircularSliderPainter extends CustomPainter {
  final double temperature;
  final bool isPowerOn;

  _CircularSliderPainter({required this.temperature, required this.isPowerOn});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.5;

    const sweepAngleStart = 140.0;
    const sweepAngleMax = 260.0;

    final proportion = (temperature - 16.0) / 14.0;
    final activeAngle = sweepAngleStart + (proportion * sweepAngleMax);

    // Convert degrees to radians for drawing
    double startAngleRad = sweepAngleStart * math.pi / 180;
    double sweepAngleMaxRad = sweepAngleMax * math.pi / 180;
    double activeSweepAngleRad =
        (activeAngle - sweepAngleStart) * math.pi / 180;

    // 1. Draw Background Inactive Gauge Arc
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngleRad,
      sweepAngleMaxRad,
      false,
      trackPaint,
    );

    // 2. Draw Active Temperature Accent Arc
    if (isPowerOn) {
      final activePaint = Paint()
        ..shader = const LinearGradient(
          colors: [AppColors.secondaryAccent, AppColors.primaryBrand],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngleRad,
        activeSweepAngleRad,
        false,
        activePaint,
      );

      // 3. Draw Slider Handle (Thumb)
      final handleAngleRad = activeAngle * math.pi / 180;
      final handleX = center.dx + radius * math.cos(handleAngleRad);
      final handleY = center.dy + radius * math.sin(handleAngleRad);

      final handlePaintOuter = Paint()..color = Colors.white;
      final handlePaintInner = Paint()..color = AppColors.primaryBrand;

      canvas.drawCircle(Offset(handleX, handleY), 12, handlePaintOuter);
      canvas.drawCircle(Offset(handleX, handleY), 6, handlePaintInner);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularSliderPainter oldDelegate) {
    return oldDelegate.temperature != temperature ||
        oldDelegate.isPowerOn != isPowerOn;
  }
}
