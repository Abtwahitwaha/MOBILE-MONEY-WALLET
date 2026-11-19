import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account.dart';
import '../models/user_profile.dart';
import '../models/wallet_category.dart';
import '../models/wallet_transaction.dart';

/// Where the backend lives.
///  * Real phone plugged in by USB:  run `adb reverse tcp:8000 tcp:8000`, keep the value below.
///  * Real phone over Wi-Fi:         use your PC's address, e.g. 'http://192.168.1.50:8000'
///  * Android emulator:              set to '' (empty) and 10.0.2.2 is used automatically.
const String serverUrlOverride = 'http://127.0.0.1:8000';

String get baseUrl {
  if (serverUrlOverride.isNotEmpty) return serverUrlOverride;
  if (kIsWeb) return 'http://127.0.0.1:8000';
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000';
  return 'http://127.0.0.1:8000';
}

/// Every error the screens show comes through this class.
class ApiException implements Exception {
  final String message;
  final bool unauthorized; // true when the token is missing/expired -> go to login
  ApiException(this.message, {this.unauthorized = false});

  @override
  String toString() => message;
}

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const _tokenKey = 'token';
  String? _token;
  UserProfile? _me;

  bool get isLoggedIn => _token != null;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<void> _saveToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  /// One place that sends every request, adds the token, and turns failures into ApiException.
  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (auth && _token != null) 'Authorization': 'Bearer $_token',
    };
    final encoded = body == null ? null : jsonEncode(body);

    late http.Response res;
    try {
      final Future<http.Response> call;
      switch (method) {
        case 'POST':
          call = http.post(uri, headers: headers, body: encoded);
          break;
        case 'PUT':
          call = http.put(uri, headers: headers, body: encoded);
          break;
        case 'DELETE':
          call = http.delete(uri, headers: headers);
          break;
        default:
          call = http.get(uri, headers: headers);
      }
      res = await call.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw ApiException('The server took too long to answer. Check your connection.');
    } catch (_) {
      // Server switched off, wrong address, no network...
      throw ApiException('Cannot reach the server at $baseUrl. Is it running?');
    }

    if (res.statusCode == 401 && auth) {
      await _saveToken(null); // token is no good: clear it
      _me = null;
      throw ApiException('Session expired. Please log in again.', unauthorized: true);
    }

    dynamic data;
    final text = utf8.decode(res.bodyBytes);
    if (text.isNotEmpty) {
      try {
        data = jsonDecode(text);
      } catch (_) {}
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw ApiException(_errorMessage(data, res.statusCode));
  }

  String _errorMessage(dynamic data, int status) {
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      if (detail is String) return detail; // 400 / 401 / 404 style
      if (detail is List) {
        // 422 style: a list of {loc, msg, ...}
        return detail.map((e) => e is Map ? '${e['msg']}'.replaceFirst('Value error, ', '') : '$e').join('\n');
      }
    }
    return 'Request failed (HTTP $status)';
  }

  // ---------- auth ----------
  Future<void> register({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) async {
    await _request('POST', '/auth/register',
        body: {'full_name': fullName, 'phone_number': phone, 'email': email, 'password': password},
        auth: false);
  }

  Future<void> login(String email, String password) async {
    final data = await _request('POST', '/auth/login',
        body: {'email': email, 'password': password}, auth: false);
    await _saveToken(data['access_token'] as String);
    _me = UserProfile.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Step 1 of "forgot password": the server prints a 6-digit code in its console.
  Future<void> forgotPassword(String email) async {
    await _request('POST', '/auth/forgot-password', body: {'email': email}, auth: false);
  }

  /// Step 2: the code plus a new password.
  Future<void> resetPassword({required String email, required String code, required String newPassword}) async {
    await _request('POST', '/auth/reset-password',
        body: {'email': email, 'code': code, 'new_password': newPassword}, auth: false);
  }

  /// Checks the logged-in user's password without changing the saved login.
  Future<bool> verifyPassword(String password) async {
    final me = await getMe();
    try {
      await _request('POST', '/auth/login', body: {'email': me.email, 'password': password}, auth: false);
      return true;
    } on ApiException catch (e) {
      if (e.message.toLowerCase().contains('incorrect')) return false;
      rethrow;
    }
  }

  Future<UserProfile> getMe({bool refresh = false}) async {
    if (_me != null && !refresh) return _me!;
    final data = await _request('GET', '/auth/me');
    _me = UserProfile.fromJson(data as Map<String, dynamic>);
    return _me!;
  }

  /// Logging out = deleting the token from the phone.
  Future<void> logout() async {
    _me = null;
    await _saveToken(null);
  }

  // ---------- accounts ----------
  Future<List<Account>> getAccounts() async {
    final data = await _request('GET', '/accounts/') as List;
    return data.map((e) => Account.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Account> getAccount(int id) async {
    final data = await _request('GET', '/accounts/$id');
    return Account.fromJson(data as Map<String, dynamic>);
  }

  /// New accounts always start at 0: money only enters through Income transactions.
  Future<void> createAccount({
    required String provider,
    required String phone,
    required String name,
  }) async {
    await _request('POST', '/accounts/', body: {
      'provider': provider,
      'phone_number': phone,
      'account_name': name,
    });
  }

  Future<void> updateAccount(int id, {required String provider, required String phone, required String name}) async {
    await _request('PUT', '/accounts/$id',
        body: {'provider': provider, 'phone_number': phone, 'account_name': name});
  }

  Future<void> deleteAccount(int id) async {
    await _request('DELETE', '/accounts/$id');
  }

  // ---------- categories ----------
  Future<List<WalletCategory>> _fetchCategories() async {
    final data = await _request('GET', '/categories/') as List;
    return data.map((e) => WalletCategory.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// With [ensureOther] the app makes sure the user has an "Other" category
  /// (it is created through the normal categories endpoint if missing).
  Future<List<WalletCategory>> getCategories({bool ensureOther = false}) async {
    var list = await _fetchCategories();
    if (ensureOther && !list.any((c) => c.name.trim().toLowerCase() == 'other')) {
      try {
        await createCategory('Other', icon: 'more_horiz');
      } on ApiException catch (e) {
        if (e.unauthorized) rethrow; // a duplicate-name error just means it already exists
      }
      list = await _fetchCategories();
    }
    return list;
  }

  Future<void> createCategory(String name, {String? icon}) async {
    await _request('POST', '/categories/', body: {'name': name, 'icon': icon});
  }

  // ---------- transactions ----------
  Future<List<WalletTransaction>> getTransactions() async {
    final data = await _request('GET', '/transactions/', query: {'limit': '500'}) as List;
    return data.map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createTransaction({
    required int accountId,
    required int categoryId,
    required String type,
    required double amount,
    String? description,
  }) async {
    await _request('POST', '/transactions/', body: {
      'account_id': accountId,
      'category_id': categoryId,
      'type': type,
      'amount': amount,
      'description': description,
    });
  }

  Future<void> updateTransaction(
    int id, {
    required int accountId,
    required int categoryId,
    required String type,
    required double amount,
    String? description,
  }) async {
    await _request('PUT', '/transactions/$id', body: {
      'account_id': accountId,
      'category_id': categoryId,
      'type': type,
      'amount': amount,
      'description': description,
    });
  }

  Future<void> deleteTransaction(int id) async {
    await _request('DELETE', '/transactions/$id');
  }
}
