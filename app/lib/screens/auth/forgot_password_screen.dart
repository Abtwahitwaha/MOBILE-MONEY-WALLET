import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/square_button.dart';

/// Forgot password, in two steps: (1) ask for a reset code, (2) enter the code and a new password.
/// No database change is needed: the server keeps the code in memory for 10 minutes and, because this
/// project has no SMS or email service, prints it in the server window.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  int _step = 1;
  bool _busy = false;
  bool _hidden = true;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final api = ApiService.instance;
      if (_step == 1) {
        await api.forgotPassword(_email.text.trim());
        if (!mounted) return;
        setState(() => _step = 2);
        _toast('If that email is registered, a 6-digit code was generated.');
      } else {
        await api.resetPassword(
          email: _email.text.trim(),
          code: _code.text.trim(),
          newPassword: _password.text,
        );
        if (!mounted) return;
        _toast('Password updated. Please log in.');
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      }
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SquareIconButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                const SizedBox(height: 28),
                Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(color: AppColors.paleBlue, shape: BoxShape.circle),
                  child: const Icon(Icons.lock_reset, size: 36, color: AppColors.navy),
                ),
                const SizedBox(height: 18),
                Text(_step == 1 ? 'Forgot your password?' : 'Set a new password',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 8),
                Text(
                  _step == 1
                      ? 'Enter the email you registered with and we will generate a reset code.'
                      : 'Enter the 6-digit code and choose a new password. In this demo the code is shown in the server window.',
                  style: const TextStyle(color: AppColors.grey, fontSize: 15),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _email,
                  enabled: _step == 1,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                if (_step == 2) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(labelText: '6-digit code', prefixIcon: Icon(Icons.pin_outlined)),
                    validator: (v) => RegExp(r'^[0-9]{6}$').hasMatch(v ?? '') ? null : 'Enter the 6-digit code',
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _password,
                    obscureText: _hidden,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_hidden ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _hidden = !_hidden),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 8) return 'At least 8 characters';
                      if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'[0-9]').hasMatch(v)) {
                        return 'Use at least one letter and one digit';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirm,
                    obscureText: _hidden,
                    decoration: const InputDecoration(
                        labelText: 'Confirm new password', prefixIcon: Icon(Icons.lock_outline)),
                    validator: (v) => v != _password.text ? 'Passwords do not match' : null,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_step == 1 ? 'Send reset code' : 'Reset password'),
                ),
                if (_step == 2)
                  Center(
                    child: TextButton(
                      onPressed: _busy ? null : () => setState(() => _step = 1),
                      child: const Text('Use a different email / get a new code'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
