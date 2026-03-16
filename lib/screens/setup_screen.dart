import 'package:flutter/material.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:go_router/go_router.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _brand = '';
  String _model = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: AppBar(
        title: const Text('Add New AC'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tell us about your AC',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This helps in naming your profile and matching with existing IR codes.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              _buildTextField(
                label: 'Device Name (e.g. Living Room)',
                onSaved: (v) => _name = v!,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                label: 'Brand (e.g. Voltas, Daikin)',
                onSaved: (v) => _brand = v!,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                label: 'Model Number (optional)',
                optional: true,
                onSaved: (v) => _model = v!,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBrand,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text(
                  'Start Learning IR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label, 
    required FormFieldSetter<String> onSaved,
    bool optional = false,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.secondaryBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (v) => !optional && (v == null || v.isEmpty) ? 'Required' : null,
      onSaved: onSaved,
    );
  }

  void _onNext() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      // Navigate to Learn Screen with data
      context.push('/learn', extra: {
        'name': _name,
        'brand': _brand,
        'model': _model,
      });
    }
  }
}
