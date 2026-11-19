import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';

/// Shown instead of content when loading failed (for example: the server is off).
class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const ErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final e = error;
    if (e is ApiException && e.unauthorized) {
      // Token expired: send the user back to the login screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        }
      });
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.navy),
            const SizedBox(height: 12),
            Text('$error', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.ink)),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pop-up message for failed actions (save, delete...).
void showError(BuildContext context, Object error) {
  if (error is ApiException && error.unauthorized) {
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$error')));
}
