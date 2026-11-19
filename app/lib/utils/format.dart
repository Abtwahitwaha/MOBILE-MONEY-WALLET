import 'package:flutter/material.dart';

/// 1500000 -> "UGX 1,500,000"
String formatUgx(double value, {bool prefix = true}) {
  final digits = value.abs().toStringAsFixed(0);
  final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  final sign = value < 0 ? '-' : '';
  return prefix ? 'UGX $sign$grouped' : '$sign$grouped';
}

/// 1500000 -> "1.5M"
String formatCompact(double value) {
  final a = value.abs();
  String s;
  if (a >= 1000000000) {
    s = '${(a / 1000000000).toStringAsFixed(1)}B';
  } else if (a >= 1000000) {
    s = '${(a / 1000000).toStringAsFixed(1)}M';
  } else if (a >= 1000) {
    s = '${(a / 1000).toStringAsFixed(1)}K';
  } else {
    s = a.toStringAsFixed(0);
  }
  return value < 0 ? '-$s' : s;
}

/// "0771234567" -> "077*****67"
String maskPhone(String phone) {
  if (phone.length < 6) return phone;
  final stars = '*' * (phone.length - 5);
  return '${phone.substring(0, 3)}$stars${phone.substring(phone.length - 2)}';
}

String greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good Morning';
  if (h < 17) return 'Good Afternoon';
  return 'Good Evening';
}

String two(int n) => n.toString().padLeft(2, '0');

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String monthShort(int month) => _months[month - 1];
String dayShort(DateTime d) => _days[d.weekday - 1];

/// "06.09.26-06.13.26" style range used in the design.
String rangeLabel(DateTime a, DateTime b) =>
    '${two(a.day)}.${two(a.month)}.${two(a.year % 100)} - ${two(b.day)}.${two(b.month)}.${two(b.year % 100)}';

String formatDateTime(DateTime? d) {
  if (d == null) return '-';
  return '${two(d.day)} ${monthShort(d.month)} ${d.year}, ${two(d.hour)}:${two(d.minute)}';
}

/// The backend stores an icon NAME for each category; this turns it into a Flutter icon.
IconData categoryIcon(String? name) {
  switch (name) {
    case 'restaurant':
      return Icons.restaurant;
    case 'directions_bus':
      return Icons.directions_bus;
    case 'home':
      return Icons.home;
    case 'phone_android':
      return Icons.phone_android;
    case 'shopping_bag':
      return Icons.shopping_bag;
    case 'payments':
      return Icons.payments;
    case 'store':
      return Icons.store;
    case 'card_giftcard':
      return Icons.card_giftcard;
    case 'more_horiz':
      return Icons.more_horiz;
    default:
      return Icons.label;
  }
}
