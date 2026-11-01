import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _location;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile;
    _name = TextEditingController(text: profile?.fullName ?? '');
    _phone = TextEditingController(text: profile?.phone ?? '');
    _location = TextEditingController(text: profile?.location ?? '');
  }

  Future<void> _save() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await context.read<AuthProvider>().updateProfile(
          fullName: _name.text.trim(),
          phone: _phone.text.trim(),
          location: _location.text.trim(),
        );
    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _loading = false;
        _error = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(controller: _name, label: 'Full name'),
              AppTextField(controller: _phone, label: 'Phone', keyboardType: TextInputType.phone),
              AppTextField(controller: _location, label: 'Location (e.g. town / area — set it however you like)'),
              if (_error != null) ...[
                Text(_error!, style: AppFonts.bodyMedium(color: AppColors.danger, size: 13)),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              PrimaryButton(label: 'Save changes', onPressed: _save, loading: _loading),
            ],
          ),
        ),
      ),
    );
  }
}
