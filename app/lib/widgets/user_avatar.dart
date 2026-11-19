import 'dart:io';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/profile_photo_service.dart';

/// Round profile picture: the photo saved on this phone, or the default avatar.
class UserAvatar extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;
  const UserAvatar({super.key, this.size = 52, this.onTap});

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  File? _photo;

  @override
  void initState() {
    super.initState();
    ProfilePhotoService.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    ProfilePhotoService.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final me = await ApiService.instance.getMe();
      final file = await ProfilePhotoService.load(me.id);
      if (mounted) setState(() => _photo = file);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipOval(
        child: Container(
          width: widget.size,
          height: widget.size,
          color: Colors.white,
          child: _photo != null
              ? Image.file(_photo!, fit: BoxFit.cover)
              : Image.asset('assets/images/avatar.png', fit: BoxFit.cover),
        ),
      ),
    );
  }
}
