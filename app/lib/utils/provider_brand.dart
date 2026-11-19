import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Look of a mobile money provider: MTN is yellow, Airtel is red, anything else is blue.
class ProviderBrand {
  final String key; // 'mtn', 'airtel' or 'other'
  final String label;
  final List<Color> gradient;
  final Color onColor; // text colour on top of the gradient
  final String? logoAsset; // optional official logo file

  const ProviderBrand({
    required this.key,
    required this.label,
    required this.gradient,
    required this.onColor,
    this.logoAsset,
  });
}

const _mtn = ProviderBrand(
  key: 'mtn',
  label: 'MTN Mobile Money',
  gradient: [AppColors.mtnYellow, AppColors.mtnYellowDark],
  onColor: Color(0xFF1A1A1A),
  logoAsset: 'assets/images/providers/mtn.png',
);

const _airtel = ProviderBrand(
  key: 'airtel',
  label: 'Airtel Money',
  gradient: [AppColors.airtelRed, AppColors.airtelRedDark],
  onColor: Colors.white,
  logoAsset: 'assets/images/providers/airtel.png',
);

ProviderBrand brandFor(String provider) {
  final p = provider.toLowerCase();
  if (p.contains('mtn')) return _mtn;
  if (p.contains('airtel')) return _airtel;
  return ProviderBrand(
    key: 'other',
    label: provider,
    gradient: const [AppColors.navy, AppColors.blue],
    onColor: Colors.white,
  );
}
