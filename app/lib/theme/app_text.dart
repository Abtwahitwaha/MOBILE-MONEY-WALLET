import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Reusable text styles (the font itself is set once in app_theme.dart).
class AppText {
  static const h1 = TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.navy);
  static const h2 = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.navy);
  static const title = TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink);
  static const body = TextStyle(fontSize: 15, color: AppColors.ink);
  static const caption = TextStyle(fontSize: 12, color: AppColors.grey);
  static const onDark = TextStyle(color: AppColors.snow);
}
