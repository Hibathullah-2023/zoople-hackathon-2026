import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';

/// Standalone Terms & Conditions screen (accessible from profile/settings).
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Text(
          _termsText,
          style: TextStyle(
            fontSize: 14,
            height: 1.7,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
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
• Immediate account suspension
• Permanent ban after 3 false reports
• Potential legal action under applicable laws
• Prosecution under IPC Section 182 (false information to public servant)

5. PRIVACY & DATA PROTECTION
• Your Aadhaar number is hashed using SHA-512 with 100,000 PBKDF2 iterations
• Location data is used solely for incident mapping
• Photos are stripped of metadata before upload
• Admin and authorities cannot see your personal identity unless you opt out

6. ANONYMOUS MODE
By default, your identity is masked. You may reveal your identity through Profile Settings.

7. ACCOUNT SUSPENSION
Your account may be suspended if:
• You submit 3 or more reports marked as fake
• You violate these terms
• Suspicious activity is detected

8. DATA RETENTION
Reports and associated data are retained for investigation and legal proceedings.

9. DISCLAIMER
Nizhal is a reporting platform only. We do not guarantee specific outcomes.

10. GOVERNING LAW
These terms are governed by the laws of India.
''';
}
