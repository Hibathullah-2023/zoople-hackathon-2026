import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';

/// Registration screen with email, password, Aadhaar, and Terms acceptance.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _aadhaarController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _termsAccepted = false;
  bool _isLoading = false;
  String? _errorMessage;

  int _currentStep = 0; // 0: credentials, 1: aadhaar, 2: terms

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _aadhaarController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = context.read<AuthService>();
      await authService.registerUser(
        email: _emailController.text,
        password: _passwordController.text,
        aadhaarNumber: _aadhaarController.text,
        displayName: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : null,
      );

      if (!mounted) return;

      // Show success and navigate
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created! Please verify your email.',
          ),
          backgroundColor: AppColors.secondaryContainer,
        ),
      );

      context.go('/home');
    } catch (e) {
      setState(() {
        _errorMessage = _formatError(e.toString());
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatError(String error) {
    if (error.contains('email-already-in-use')) {
      return 'An account with this email already exists.';
    }
    if (error.contains('weak-password')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    if (error.contains('identity already exists')) {
      return error;
    }
    if (error.contains('Invalid Aadhaar')) {
      return error;
    }
    return 'Registration failed. Please try again.';
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_emailController.text.trim().isEmpty ||
            _passwordController.text.isEmpty) {
          setState(() => _errorMessage = 'Please fill all required fields.');
          return false;
        }
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
            .hasMatch(_emailController.text.trim())) {
          setState(() => _errorMessage = 'Enter a valid email address.');
          return false;
        }
        if (_passwordController.text.length < 8) {
          setState(
              () => _errorMessage = 'Password must be at least 8 characters.');
          return false;
        }
        if (_passwordController.text != _confirmPasswordController.text) {
          setState(() => _errorMessage = 'Passwords do not match.');
          return false;
        }
        setState(() => _errorMessage = null);
        return true;
      case 1:
        final clean =
            _aadhaarController.text.replaceAll(RegExp(r'[\s\-]'), '');
        if (clean.length != 12 || !RegExp(r'^\d{12}$').hasMatch(clean)) {
          setState(
              () => _errorMessage = 'Aadhaar must be exactly 12 digits.');
          return false;
        }
        setState(() => _errorMessage = null);
        return true;
      case 2:
        if (!_termsAccepted) {
          setState(() =>
              _errorMessage = 'You must accept the Terms & Conditions.');
          return false;
        }
        setState(() => _errorMessage = null);
        return true;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_validateCurrentStep()) {
      if (_currentStep < 2) {
        setState(() => _currentStep++);
      } else {
        _handleRegister();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _prevStep,
              )
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.go('/login'),
              ),
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Progress Bar ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) / 3,
                        backgroundColor: AppColors.surfaceContainerHighest,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.tertiary),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'STEP ${_currentStep + 1}/3',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildCurrentStep(),
                  ),
                ),
              ),
            ),

            // ─── Bottom Button ───
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Error message
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color:
                            AppColors.errorContainer.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentStep == 2
                            ? AppColors.tertiary
                            : AppColors.secondary,
                        foregroundColor: AppColors.onSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.onSecondary,
                              ),
                            )
                          : Text(
                              _currentStep == 2
                                  ? 'Create Account'
                                  : 'Continue',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildCredentialsStep();
      case 1:
        return _buildAadhaarStep();
      case 2:
        return _buildTermsStep();
      default:
        return const SizedBox.shrink();
    }
  }

  /// Step 1: Email, Password, Name
  Widget _buildCredentialsStep() {
    return Column(
      key: const ValueKey('step_0'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Credentials',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Create a secure account to report incidents anonymously.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 32),

        // Name (optional)
        TextFormField(
          controller: _nameController,
          style: const TextStyle(color: AppColors.onSurface),
          decoration: InputDecoration(
            labelText: 'Display Name (optional)',
            labelStyle: TextStyle(
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            prefixIcon: const Icon(Icons.person_outline,
                color: AppColors.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 16),

        // Email
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppColors.onSurface),
          decoration: InputDecoration(
            labelText: 'Email *',
            labelStyle: TextStyle(
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            prefixIcon: const Icon(Icons.email_outlined,
                color: AppColors.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 16),

        // Password
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: AppColors.onSurface),
          decoration: InputDecoration(
            labelText: 'Password *',
            labelStyle: TextStyle(
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            prefixIcon: const Icon(Icons.lock_outline,
                color: AppColors.onSurfaceVariant),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.onSurfaceVariant,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            helperText: 'Minimum 8 characters',
            helperStyle: TextStyle(
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Confirm Password
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          style: const TextStyle(color: AppColors.onSurface),
          decoration: InputDecoration(
            labelText: 'Confirm Password *',
            labelStyle: TextStyle(
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            prefixIcon: const Icon(Icons.lock_outline,
                color: AppColors.onSurfaceVariant),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.onSurfaceVariant,
              ),
              onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
        ),
      ],
    );
  }

  /// Step 2: Aadhaar Number
  Widget _buildAadhaarStep() {
    return Column(
      key: const ValueKey('step_1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Identity Verification',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your Aadhaar number is encrypted and used only to prevent duplicate accounts.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 32),

        // Aadhaar Number
        TextFormField(
          controller: _aadhaarController,
          keyboardType: TextInputType.number,
          maxLength: 14, // 12 digits + 2 spaces
          style: const TextStyle(
            color: AppColors.onSurface,
            fontSize: 20,
            letterSpacing: 4,
          ),
          decoration: InputDecoration(
            labelText: 'Aadhaar Number',
            labelStyle: TextStyle(
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            prefixIcon: const Icon(Icons.credit_card,
                color: AppColors.onSurfaceVariant),
            hintText: 'XXXX XXXX XXXX',
            hintStyle: TextStyle(
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
              letterSpacing: 4,
            ),
            counterText: '',
          ),
        ),
        const SizedBox(height: 24),

        // Security info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.security,
                    color: AppColors.secondary.withValues(alpha: 0.8),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'How we protect your data',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildSecurityPoint(
                'Your Aadhaar number is never stored in plain text',
              ),
              _buildSecurityPoint(
                'SHA-512 hashing with 100,000 iterations protects your data',
              ),
              _buildSecurityPoint(
                'Used only for duplicate account prevention',
              ),
              _buildSecurityPoint(
                'Admin and authorities cannot see your Aadhaar',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppColors.secondary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Step 3: Terms & Conditions
  Widget _buildTermsStep() {
    return Column(
      key: const ValueKey('step_2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Terms & Conditions',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 16),

        Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: Text(
              _termsText,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Accept checkbox
        InkWell(
          onTap: () => setState(() => _termsAccepted = !_termsAccepted),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _termsAccepted
                  ? AppColors.secondary.withValues(alpha: 0.1)
                  : AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _termsAccepted
                    ? AppColors.secondary.withValues(alpha: 0.3)
                    : AppColors.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _termsAccepted
                        ? AppColors.secondary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _termsAccepted
                          ? AppColors.secondary
                          : AppColors.outline,
                      width: 2,
                    ),
                  ),
                  child: _termsAccepted
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'I have read and agree to the Terms & Conditions and Privacy Policy',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.onSurface,
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

  static const String _termsText = '''
NIZHAL - TERMS AND CONDITIONS

Last Updated: July 2026

1. ACCEPTANCE OF TERMS
By creating an account on Nizhal, you agree to be bound by these Terms and Conditions.

2. ANONYMOUS REPORTING
Nizhal provides a platform for anonymous reporting of drug-related incidents. Your identity is encrypted and protected by default.

3. TRUTHFUL REPORTING
You agree to submit only truthful and accurate reports. Filing false or misleading reports is a serious offense.

4. LEGAL CONSEQUENCES FOR FALSE REPORTS
WARNING: Submitting fake reports may result in:
- Immediate account suspension
- Permanent ban after 3 false reports
- Potential legal action under applicable laws
- Prosecution under IPC Section 182 (false information to public servant)

5. PRIVACY & DATA PROTECTION
- Your Aadhaar number is hashed using SHA-512 with 100,000 PBKDF2 iterations and is never stored in plain text
- Location data is used solely for incident mapping
- Photos are stripped of metadata before upload
- Admin and authorities cannot see your personal identity unless you explicitly opt out of anonymous mode

6. ANONYMOUS MODE
By default, your identity is masked. You may choose to reveal your identity through Profile Settings. This choice can be changed at any time.

7. ACCOUNT SUSPENSION
Your account may be suspended if:
- You submit 3 or more reports marked as fake by authorities
- You violate these terms
- Suspicious activity is detected

8. DATA RETENTION
Reports and associated data are retained for the purpose of investigation and legal proceedings.

9. DISCLAIMER
Nizhal is a reporting platform only. We do not guarantee specific outcomes for submitted reports.

10. GOVERNING LAW
These terms are governed by the laws of India.

By proceeding, you acknowledge that you have read, understood, and agree to these terms.
''';
}
