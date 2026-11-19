import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinResult {
  final bool ok;
  final int attemptsLeft;
  final int lockedSeconds;
  const PinResult(this.ok, this.attemptsLeft, this.lockedSeconds);
}

/// Local security PIN that must be entered to approve an expense.
/// It lives only on this phone: stored as a salted SHA-256 hash, never sent to the server.
class PinService {
  PinService._();
  static final PinService instance = PinService._();

  static const maxAttempts = 3;
  static const lockSeconds = 30;

  String _key(String name, int userId) => 'pin_${name}_$userId';

  String _hash(String salt, String pin) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<bool> hasPin(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key('hash', userId)) != null;
  }

  Future<void> setPin(int userId, String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final random = Random.secure();
    final salt = base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
    await prefs.setString(_key('salt', userId), salt);
    await prefs.setString(_key('hash', userId), _hash(salt, pin));
    await prefs.remove(_key('fails', userId));
    await prefs.remove(_key('lock', userId));
  }

  Future<void> clear(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    for (final name in ['salt', 'hash', 'fails', 'lock']) {
      await prefs.remove(_key(name, userId));
    }
  }

  Future<int> lockedSecondsLeft(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(_key('lock', userId)) ?? 0;
    final left = ((until - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
    return left > 0 ? left : 0;
  }

  Future<PinResult> verify(int userId, String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final locked = await lockedSecondsLeft(userId);
    if (locked > 0) return PinResult(false, 0, locked);

    final salt = prefs.getString(_key('salt', userId));
    final stored = prefs.getString(_key('hash', userId));
    if (salt == null || stored == null) return const PinResult(false, 0, 0);

    if (_hash(salt, pin) == stored) {
      await prefs.remove(_key('fails', userId));
      return const PinResult(true, maxAttempts, 0);
    }
    final failCount = (prefs.getInt(_key('fails', userId)) ?? 0) + 1;
    if (failCount >= maxAttempts) {
      await prefs.setInt(_key('lock', userId), DateTime.now().millisecondsSinceEpoch + lockSeconds * 1000);
      await prefs.remove(_key('fails', userId));
      return const PinResult(false, 0, lockSeconds);
    }
    await prefs.setInt(_key('fails', userId), failCount);
    return PinResult(false, maxAttempts - failCount, 0);
  }
}
