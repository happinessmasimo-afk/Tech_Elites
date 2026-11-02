import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import 'marketplace_screen.dart';

/// Matches the original app's app/(auth)/register.tsx: plain brand
/// background (no photo), pill inputs, brand-green button.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _notice;

  Future<void> _submit() async {
    if (_fullName.text.trim().isEmpty || _email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Fill in your name, email, and password.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });

    final result = await context.read<AuthProvider>().register(
          fullName: _fullName.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          password: _password.text,
        );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      setState(() => _error = result.message);
      return;
    }
    if (result.requiresEmailConfirmation) {
      setState(() => _notice = result.message);
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MarketplaceScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Create your account', style: AppFonts.heading()),
              const SizedBox(height: 4),
              Text('Sign up to browse listings and make offers on livestock', style: AppFonts.body(color: AppColors.muted)),
              const SizedBox(height: 24),
              _field('Full name', _fullName, hint: 'Jane Farmer'),
              _field('Email', _email, hint: 'you@example.com', keyboardType: TextInputType.emailAddress),
              _field('Phone', _phone, hint: '082 000 0000', keyboardType: TextInputType.phone),
              _field('Password', _password, hint: 'At least 6 characters', obscure: true),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: AppFonts.bodyMedium(color: AppColors.danger, size: 13)),
              ],
              if (_notice != null) ...[
                const SizedBox(height: 12),
                Text(_notice!, style: AppFonts.bodyMedium(color: AppColors.accent, size: 13)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Create account'),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Already have an account? Log in', style: AppFonts.bodyMedium(color: AppColors.accent)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {String? hint, bool obscure = false, TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppFonts.bodyMedium(color: AppColors.muted, size: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }
}
