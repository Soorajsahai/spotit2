import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'app_theme.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final SupabaseService service = SupabaseService();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  final TextEditingController confirmCtrl = TextEditingController();

  bool _isEmailFound = false;
  bool _isLoading = false;
  String? _foundEmail;

  Future<void> _lookupEmail() async {
    final email = emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your email')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final rows = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('email', email)
          .limit(1);
      if ((rows as List).isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email not found')));
        setState(() => _isEmailFound = false);
      } else {
        setState(() {
          _isEmailFound = true;
          _foundEmail = email;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lookup error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final newPass = passCtrl.text.trim();
    final confirm = confirmCtrl.text.trim();
    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
      return;
    }
    if (newPass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final ok = await service.resetPasswordByEmail(_foundEmail!, newPass);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully')));
        Future.delayed(const Duration(milliseconds: 800), () => Navigator.pop(context));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update password')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Header text
                Text('Forgot Password', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
                const SizedBox(height: 8),
                Text('Enter your registered email to reset your password', style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant)),

                const SizedBox(height: 32),

                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: colorScheme.shadow.withOpacity(0.05), blurRadius: 20, spreadRadius: 2)],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Email
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your registered email',
                          prefixIcon: Icon(Icons.email_rounded),
                        ),
                      ),

                      const SizedBox(height: 16),

                      if (!_isEmailFound)
                        ElevatedButton(
                          onPressed: _isLoading ? null : _lookupEmail,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.aquaBlue),
                          child: _isLoading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Continue'),
                        ),

                      if (_isEmailFound) ...[
                        Text('Email found: $_foundEmail', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: passCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'New Password', prefixIcon: Icon(Icons.lock_rounded)),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: confirmCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Confirm Password', prefixIcon: Icon(Icons.lock_rounded)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _resetPassword,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.aquaBlue),
                          child: _isLoading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Reset Password'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(() => _isEmailFound = false),
                          child: const Text('Use a different email'),
                        ),
                      ]
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
