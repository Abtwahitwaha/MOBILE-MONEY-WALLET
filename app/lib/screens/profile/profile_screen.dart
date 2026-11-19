import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/profile_photo_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/format.dart';
import '../../widgets/app_notification.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/error_view.dart';
import '../../widgets/pin_sheet.dart';
import '../../widgets/user_avatar.dart';

/// Profile: photo (kept on this phone only), account details, security PIN and log out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<UserProfile> _future = ApiService.instance.getMe(refresh: true);

  void _reload() {
    setState(() {
      _future = ApiService.instance.getMe(refresh: true);
    });
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _changePhoto(UserProfile user) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text('Profile photo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Text('Your photo stays on this phone. It is not uploaded or saved in the database.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.grey)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.blue),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.blue),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.expense),
              title: const Text('Remove photo'),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null) return;
    try {
      if (choice == 'remove') {
        await ProfilePhotoService.remove(user.id);
      } else {
        await ProfilePhotoService.pick(user.id, choice == 'camera' ? ImageSource.camera : ImageSource.gallery);
      }
    } catch (_) {
      if (mounted) _toast('Could not open the camera or gallery. Check the app permissions.');
    }
  }

  Future<void> _changePin() async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final ok = await showPinSheet(context, purpose: PinPurpose.change);
    if (ok) {
      AppNotification.show(overlay,
          title: 'Security PIN saved', message: 'You will use it to approve expenses.', kind: NotificationKind.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<UserProfile>(
          future: _future,
          builder: (context, snap) {
            final u = snap.data;
            return Column(
              children: [
                const SizedBox(height: 18),
                Stack(
                  children: [
                    UserAvatar(size: 112, onTap: u == null ? null : () => _changePhoto(u)),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: u == null ? null : () => _changePhoto(u),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.photo_camera, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(u?.fullName ?? '...',
                    style: const TextStyle(color: AppColors.snow, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Tap the photo to change it', style: TextStyle(color: AppColors.slate, fontSize: 12)),
                const SizedBox(height: 18),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
                    ),
                    child: _buildDetails(snap),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetails(AsyncSnapshot<UserProfile> snap) {
    if (snap.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
    final u = snap.data!;
    final since = u.createdAt == null ? null : DateTime.tryParse(u.createdAt!);
    return ListView(
      children: [
        _tile(Icons.person_outline, 'Full name', u.fullName),
        _tile(Icons.email_outlined, 'Email', u.email),
        _tile(Icons.phone_outlined, 'Phone', u.phoneNumber),
        _tile(Icons.event_outlined, 'Member since', formatDateTime(since)),
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 4),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _changePin,
          child: _tile(Icons.lock_outline, 'Security PIN', 'Required to approve expenses - tap to set or change',
              trailing: const Icon(Icons.chevron_right, color: AppColors.grey)),
        ),
        _tile(Icons.dns_outlined, 'Server', baseUrl),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.blue),
          onPressed: () => confirmLogout(context),
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _tile(IconData icon, String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: AppColors.paleBlue, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: AppColors.navy),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                Text(value, style: const TextStyle(color: AppColors.ink, fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
