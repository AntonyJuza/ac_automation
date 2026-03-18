import 'package:flutter/material.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:ac_automation/services/ble_service.dart';
import 'package:ac_automation/models/dynamic_config.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

class DynamicConfigScreen extends StatefulWidget {
  const DynamicConfigScreen({super.key});

  @override
  State<DynamicConfigScreen> createState() => _DynamicConfigScreenState();
}

class _DynamicConfigScreenState extends State<DynamicConfigScreen> {
  final _formKey = GlobalKey<FormState>();

  final _acOnDataController = TextEditingController(text: "0x6408BF836, 0x7480000000A800");
  final _acOffDataController = TextEditingController(text: "0x6400BF836, 0x7400000000A800");
  final _irFreqController = TextEditingController(text: "38");
  final _hdrMarkController = TextEditingController(text: "1050");
  final _hdrSpaceController = TextEditingController(text: "550");
  final _bitMarkController = TextEditingController(text: "1000");
  final _oneSpaceController = TextEditingController(text: "2550");
  final _zeroSpaceController = TextEditingController(text: "1000");
  final _stopMarkController = TextEditingController(text: "600");
  final _bitLengthController = TextEditingController(text: "119");
  final _sendRepeatController = TextEditingController(text: "3");

  bool _isUploading = false;

  @override
  void dispose() {
    _acOnDataController.dispose();
    _acOffDataController.dispose();
    _irFreqController.dispose();
    _hdrMarkController.dispose();
    _hdrSpaceController.dispose();
    _bitMarkController.dispose();
    _oneSpaceController.dispose();
    _zeroSpaceController.dispose();
    _stopMarkController.dispose();
    _bitLengthController.dispose();
    _sendRepeatController.dispose();
    super.dispose();
  }

  void _uploadConfig() async {
    if (!_formKey.currentState!.validate()) return;

    final bleService = Provider.of<BLEService>(context, listen: false);
    if (!bleService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to BLE device', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.statusRed),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final config = DynamicConfig(
        acOnData: _parseHexArray(_acOnDataController.text),
        acOffData: _parseHexArray(_acOffDataController.text),
        irFreqKhz: int.parse(_irFreqController.text),
        hdrMark: int.parse(_hdrMarkController.text),
        hdrSpace: int.parse(_hdrSpaceController.text),
        bitMark: int.parse(_bitMarkController.text),
        oneSpace: int.parse(_oneSpaceController.text),
        zeroSpace: int.parse(_zeroSpaceController.text),
        stopMark: int.parse(_stopMarkController.text),
        bitLength: int.parse(_bitLengthController.text),
        sendRepeat: int.parse(_sendRepeatController.text),
      );

      final success = await bleService.sendDynamicConfig(config);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration uploaded successfully!'), backgroundColor: AppColors.statusGreen),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload configuration.', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.statusRed),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e', style: const TextStyle(color: Colors.white)), backgroundColor: AppColors.statusRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  List<String> _parseHexArray(String input) {
    return input.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.primaryBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter a value';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondaryBackground,
      appBar: AppBar(
        title: const Text('Dynamic Config'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Upload raw AC configuration variables directly to the ESP32.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 24),
              _buildTextField('AC ON Hex Data (comma separated)', _acOnDataController, isNumber: false),
              _buildTextField('AC OFF Hex Data (comma separated)', _acOffDataController, isNumber: false),
              Row(
                children: [
                  Expanded(child: _buildTextField('Freq (kHz)', _irFreqController)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField('Repeat', _sendRepeatController)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildTextField('Hdr Mark', _hdrMarkController)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField('Hdr Space', _hdrSpaceController)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildTextField('Bit Mark', _bitMarkController)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField('Bit Length', _bitLengthController)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildTextField('One Space', _oneSpaceController)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField('Zero Space', _zeroSpaceController)),
                ],
              ),
              _buildTextField('Stop Mark', _stopMarkController),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isUploading ? null : _uploadConfig,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBrand,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Upload to ESP32',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
