import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

Future<bool> confirmDialog(BuildContext context, String message, {String confirmLabel = 'Delete'}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Are you sure?'),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44), backgroundColor: AppColors.expense),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Asks the user to type their account password (used to reset the local PIN).
Future<String?> askPassword(BuildContext context, {String title = 'Enter your account password'}) {
  return showDialog<String>(context: context, builder: (_) => _PasswordPrompt(title: title));
}

class _PasswordPrompt extends StatefulWidget {
  final String title;
  const _PasswordPrompt({required this.title});

  @override
  State<_PasswordPrompt> createState() => _PasswordPromptState();
}

class _PasswordPromptState extends State<_PasswordPrompt> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Password'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          onPressed: () {
            if (_controller.text.isNotEmpty) Navigator.pop(context, _controller.text);
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

/// The logout pop-up from the XD design ("Oh no! You're leaving... Are you sure?").
Future<void> confirmLogout(BuildContext context) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logout_art.png', height: 130),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              "Oh no! You're leaving...\nAre you sure?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: AppColors.ink),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.blue, shape: const StadiumBorder()),
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep me logged in!'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.paleBlue,
                  foregroundColor: AppColors.blue,
                  minimumSize: const Size.fromHeight(54),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes, Log Me Out'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (yes != true) return;
  await ApiService.instance.logout(); // clears the token from the phone
  if (!context.mounted) return;
  Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
}
