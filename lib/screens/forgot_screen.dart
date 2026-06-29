import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key});

  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  final _emailController = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_emailController.text.isNotEmpty) {
      setState(() {
        _sent = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color inputFillColor = Color(0xFFEEF2F6);
    const Color textColorBrand = Color(0xFF0E1A2B);
    const Color textMutedColor = Color(0xFF64748B);
    const Color accentBlue = Color(0xFF1763D6);
    const Color successColor = Color(0xFF16A34A);
    const Color successBgColor = Color(0xFFDCFCE7);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/login');
                        }
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back,
                            color: textMutedColor,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Back to sign in',
                            style: TextStyle(
                              color: textMutedColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Reset your password',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: textColorBrand,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "We'll email you a reset link.",
                    style: TextStyle(
                      fontSize: 16,
                      color: textMutedColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_sent)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: successBgColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: successColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Check your inbox',
                                  style: TextStyle(
                                    color: successColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'If an account exists for ${_emailController.text}, a reset link is on its way.',
                                  style: TextStyle(
                                    color: successColor.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          style: const TextStyle(
                            color: textColorBrand,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Email',
                            hintStyle: const TextStyle(
                              color: textMutedColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                            filled: true,
                            fillColor: inputFillColor,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: accentBlue,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Send reset link',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
