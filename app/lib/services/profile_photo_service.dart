import 'dart:io';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Profile picture kept ONLY on this phone (a file in the app's private folder).
/// Nothing is uploaded and nothing is stored in the database.
class ProfilePhotoService {
  /// Screens listen to this to refresh their avatar after the photo changes.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static String _key(int userId) => 'profile_photo_$userId';

  static Future<File?> load(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_key(userId));
    if (path == null) return null;
    final file = File(path);
    return await file.exists() ? file : null;
  }

  /// Returns true if a new photo was saved (false if the user cancelled).
  static Future<bool> pick(int userId, ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) return false;

    final dir = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await File(picked.path).copy(dest.path);

    await _deleteCurrent(userId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId), dest.path);
    changes.value++;
    return true;
  }

  static Future<void> remove(int userId) async {
    await _deleteCurrent(userId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
    changes.value++;
  }

  static Future<void> _deleteCurrent(int userId) async {
    final current = await load(userId);
    if (current != null) {
      try {
        await current.delete();
      } catch (_) {}
    }
  }
}
