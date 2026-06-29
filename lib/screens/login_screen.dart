import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:ac_automation/services/auth_service.dart';
import 'package:ac_automation/utils/constants.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _emailChecked = false;
  bool _emailExists = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email';
      });
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _errorMessage = 'Please enter a valid email address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final exists = await authService.checkEmail(email);
      setState(() {
        _emailChecked = true;
        _emailExists = exists;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to verify email. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitAuth() async {
    if (_isLoading) return;

    if (!_emailChecked) {
      await _checkEmail();
      return;
    }

    if (_emailExists) {
      // Login flow
      if (_passwordController.text.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter your password';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final success = await authService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
        if (success && mounted) {
          context.go('/');
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      // Signup flow
      if (_usernameController.text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Please enter a username';
        });
        return;
      }
      if (_passwordController.text.isEmpty) {
        setState(() {
          _errorMessage = 'Please enter a password';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final success = await authService.register(
          _usernameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
        );
        if (success && mounted) {
          context.go('/');
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _resetEmailCheck() {
    setState(() {
      _emailChecked = false;
      _emailExists = false;
      _usernameController.clear();
      _passwordController.clear();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color inputFillColor = Color(0xFFEEF2F6);
    const Color textColorBrand = Color(0xFF0E1A2B);
    const Color textMutedColor = Color(0xFF64748B);
    const Color accentBlue = Color(0xFF1763D6);

    const String avioSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="-10 -10 48 48">
  <rect x="-3" y="-3" width="30" height="30" rx="5" fill="#FFFFFF" stroke="#E5E7EB" stroke-width="0.5" />
  <g fill="none" stroke="#0066FF" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">
    <path d="m10 20-1.25-2.5L6 18"/>
    <path d="M10 4 8.75 6.5 6 6"/>
    <path d="m14 20 1.25-2.5L18 18"/>
    <path d="m14 4 1.25 2.5L18 6"/>
    <path d="m17 21-3-6h-4"/>
    <path d="m17 3-3 6 1.5 3"/>
    <path d="M2 12h6.5L10 9"/>
    <path d="m20 10-1.5 2 1.5 2"/>
    <path d="M22 12h-6.5L14 15"/>
    <path d="m4 10 1.5 2L4 14"/>
    <path d="m7 21 3-6-1.5-3"/>
    <path d="m7 3 3 6h4"/>
  </g>
</svg>
''';

    const String googleSvg = '''
<svg width="18" height="18" viewBox="0 0 18 18" xmlns="http://www.w3.org/2000/svg">
  <path fill="#4285F4" d="M17.64 9.2c0-.64-.06-1.25-.17-1.84H9v3.48h4.84a4.14 4.14 0 0 1-1.8 2.72v2.26h2.92c1.71-1.57 2.68-3.88 2.68-6.62z"/>
  <path fill="#34A853" d="M9 18c2.43 0 4.47-.8 5.96-2.18l-2.92-2.26c-.8.54-1.84.86-3.04.86-2.34 0-4.32-1.58-5.03-3.7H.97v2.32A9 9 0 0 0 9 18z"/>
  <path fill="#FBBC05" d="M3.97 10.72A5.4 5.4 0 0 1 3.68 9c0-.6.1-1.18.29-1.72V4.96H.97A9 9 0 0 0 0 9c0 1.45.35 2.82.97 4.04l3-2.32z"/>
  <path fill="#EA4335" d="M9 3.58c1.32 0 2.5.45 3.44 1.35l2.58-2.58C13.46.89 11.43 0 9 0A9 9 0 0 0 .97 4.96l3 2.32C4.68 5.16 6.66 3.58 9 3.58z"/>
</svg>
''';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 64.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // AVIO Logo (Left aligned as original)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: SvgPicture.string(avioSvg),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'AVIO',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textColorBrand,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),

                    // Greeting Header (Left aligned)
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 300),
                      crossFadeState: _emailChecked
                          ? (_emailExists
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond)
                          : CrossFadeState.showFirst,
                      firstChild: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: textColorBrand,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Sign in to manage your AC devices.',
                            style: TextStyle(
                              fontSize: 16,
                              color: textMutedColor,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      secondChild: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: textColorBrand,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Sign up to manage your AC devices.',
                            style: TextStyle(
                              fontSize: 16,
                              color: textMutedColor,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Error Message
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.statusRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.statusRed.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.statusRed,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_emailChecked,
                      textInputAction: _emailChecked
                          ? TextInputAction.none
                          : TextInputAction.next,
                      onFieldSubmitted: (_) =>
                          _emailChecked ? null : _submitAuth(),
                      style: TextStyle(
                        color: _emailChecked ? textMutedColor : textColorBrand,
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
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: _emailChecked
                            ? IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: accentBlue,
                                  size: 18,
                                ),
                                onPressed: _resetEmailCheck,
                              )
                            : null,
                      ),
                    ),

                    // Elegant Compose-style Animated Height Expansion
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: Container(
                        child: _emailChecked
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 12),
                                  if (!_emailExists) ...[
                                    // Username field for signup
                                    TextFormField(
                                      controller: _usernameController,
                                      keyboardType: TextInputType.text,
                                      textInputAction: TextInputAction.next,
                                      style: const TextStyle(
                                        color: textColorBrand,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Username',
                                        hintStyle: const TextStyle(
                                          color: textMutedColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        filled: true,
                                        fillColor: inputFillColor,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 16,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: const BorderSide(
                                            color: accentBlue,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  // Password field
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: true,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submitAuth(),
                                    style: const TextStyle(
                                      color: textColorBrand,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Password',
                                      hintStyle: const TextStyle(
                                        color: textMutedColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      filled: true,
                                      fillColor: inputFillColor,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                                  if (_emailExists) ...[
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () =>
                                            context.push('/forgot'),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'Forgot password?',
                                          style: TextStyle(
                                            color: accentBlue,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              !_emailChecked
                                  ? 'Next'
                                  : (_emailExists ? 'Sign in' : 'Sign up'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),

                    if (_emailChecked) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _resetEmailCheck,
                        child: const Text(
                          'Use a different email address',
                          style: TextStyle(
                            color: accentBlue,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // OR Divider (from original page)
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(
                            color: Color(0xFFE2E8F0),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: textMutedColor.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(
                            color: Color(0xFFE2E8F0),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Continue with Google (from original page)
                    OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Google Authentication is not supported yet.',
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.string(googleSvg, width: 18, height: 18),
                          const SizedBox(width: 12),
                          const Text(
                            'Continue with Google',
                            style: TextStyle(
                              color: textColorBrand,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Footer Row (from original page)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: textMutedColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            // If they tap here, reset checker to let them start registration or auto-fill
                            _resetEmailCheck();
                            context.push('/register');
                          },
                          child: const Text(
                            'Sign up',
                            style: TextStyle(
                              color: accentBlue,
                              fontSize: 14,
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
      ),
    );
  }
}
