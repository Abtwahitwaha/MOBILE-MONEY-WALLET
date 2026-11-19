import 'package:flutter/material.dart';

/// Every colour in the app lives here. The theme is blue only (the blues come from the XD design).
/// Green and red are used ONLY to tell income from expenses, and MTN yellow / Airtel red for provider cards.
class AppColors {
  // ----- Brand blues -----
  static const navy = Color(0xFF0E076A);
  static const navyDark = Color(0xFF122571);
  static const blue = Color(0xFF1F81CA);
  static const skyBlue = Color(0xFF6FAEE0);
  static const lightBlue = Color(0xFFA7CEED);
  static const softBlue = Color(0xFFD6E8F8);
  static const paleBlue = Color(0xFFEAF3FB);
  static const slate = Color(0xFFC3CAE5);

  // ----- Neutrals -----
  static const ink = Color(0xFF170B0B);
  static const grey = Color(0xFF707070);
  static const snow = Color(0xFFF2EAEA);
  static const border = Color(0xFFD0D8E4);
  static const shadow = Color(0x1F000000);

  // ----- Meaning: money in / money out -----
  static const income = Color(0xFF1B8A5A);
  static const incomeSoft = Color(0xFFE3F5EC);
  static const expense = Color(0xFFC0392B);
  static const expenseSoft = Color(0xFFFBE9E7);

  // ----- Mobile money providers -----
  static const mtnYellow = Color(0xFFFFCC00);
  static const mtnYellowDark = Color(0xFFF0A800);
  static const airtelRed = Color(0xFFE40000);
  static const airtelRedDark = Color(0xFFA80000);
}
