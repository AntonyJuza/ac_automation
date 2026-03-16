import 'package:flutter/material.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:ac_automation/models/ac_profile.dart';
import 'package:ac_automation/models/ir_button.dart';
import 'package:ac_automation/services/ac_provider.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

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
  final List<String> _requiredButtons = [
    'Power OFF',
    'Power ON',
    'Temp +',
    'Temp -',
    'Mode',
    'Fan Speed',
  ];
  
  final Map<String, List<int>> _capturedData = {};
  bool _isCapturing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      appBar: AppBar(
        title: const Text('Teach Remote'),
      ),
      body: Column(
        children: [
          _buildProgressHeader(),
          Expanded(
            child: _currentStep < _requiredButtons.length
              ? _buildCaptureArea()
              : _buildReviewArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: AppColors.primaryBackground,
      child: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentStep + 1) / (_requiredButtons.length + 1),
            backgroundColor: AppColors.secondaryBackground,
            color: AppColors.primaryBrand,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 16),
          Text(
            'Step ${_currentStep + 1} of ${_requiredButtons.length}',
            style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureArea() {
    final buttonName = _requiredButtons[_currentStep];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.primaryBackground,
              shape: BoxShape.circle,
              boxShadow: [AppStyles.softShadow],
            ),
            child: Icon(
              _getIconForButton(buttonName),
              size: 80,
              color: AppColors.primaryBrand,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Press "$buttonName"',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Point your AC remote at the hardware\ndevice and press the button once.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 64),
          if (!_isCapturing)
            ElevatedButton(
              onPressed: _simulateCapture,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBrand,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'I pressed it',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            )
          else
            const CircularProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildReviewArea() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Setup Complete!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('All essential buttons have been learned.'),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _requiredButtons.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.check_circle, color: AppColors.statusGreen),
                  title: Text(_requiredButtons[index]),
                  trailing: const Icon(Icons.edit, size: 20),
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusGreen,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              'Save & Finish',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForButton(String name) {
    if (name.contains('Power')) return Icons.power_settings_new;
    if (name.contains('+')) return Icons.add_circle_outline;
    if (name.contains('-')) return Icons.remove_circle_outline;
    if (name.contains('Mode')) return Icons.ac_unit;
    return Icons.settings_remote;
  }

  void _simulateCapture() async {
    setState(() => _isCapturing = true);
    await Future.delayed(const Duration(seconds: 1));
    _capturedData[_requiredButtons[_currentStep]] = [100, 200, 300]; // Mock data
    setState(() {
      _isCapturing = false;
      _currentStep++;
    });
  }

  void _saveProfile() {
    final profile = ACProfile(
      id: Uuid().v4(),
      name: widget.name,
      brand: widget.brand,
      model: widget.model,
      buttons: _capturedData.map((key, value) => MapEntry(key, IRButton(name: key, rawData: value))),
      createdAt: DateTime.now(),
    );

    Provider.of<ACProvider>(context, listen: false).addProfile(profile);
    context.go('/');
  }
}
