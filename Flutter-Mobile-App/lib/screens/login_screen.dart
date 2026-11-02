import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import 'farmer_dashboard_screen.dart';
import 'marketplace_screen.dart';
import 'register_screen.dart';

/// Matches the original app's app/(auth)/login.tsx: login-bg.jpg behind a
/// centered form, pill-shaped inputs, brand-green submit button.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await context.read<AuthProvider>().login(_email.text.trim(), _password.text);

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      final isFarmer = context.read<AuthProvider>().isFarmer;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => isFarmer ? const FarmerDashboardScreen() : const MarketplaceScreen()),
        (route) => false,
      );
    } else {
      setState(() => _error = context.read<AuthProvider>().lastError ?? 'Login failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/login-bg.jpg', fit: BoxFit.cover),
          SafeArea(
            child: KeyboardAvoidingBody(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Agricast Livestock', style: AppFonts.heading()),
                    const SizedBox(height: 4),
                    Text('Log in with your Agricast account', style: AppFonts.body(color: AppColors.muted)),
                    const SizedBox(height: 32),
                    Text('Email', style: AppFonts.bodyMedium(color: AppColors.muted, size: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(hintText: 'you@example.com'),
                    ),
                    const SizedBox(height: 16),
                    Text('Password', style: AppFonts.bodyMedium(color: AppColors.muted, size: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(hintText: '••••••••'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: AppFonts.bodyMedium(color: AppColors.danger, size: 13)),
                    ],
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Log in'),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                        child: Text('New farmer? Create an account', style: AppFonts.bodyMedium(color: AppColors.accent)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small helper so the form shifts up above the keyboard, same as the
/// original's KeyboardAvoidingView.
class KeyboardAvoidingBody extends StatelessWidget {
  final Widget child;
  const KeyboardAvoidingBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      reverse: true,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
        child: child,
      ),
    );
  }
}
