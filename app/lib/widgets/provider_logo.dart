import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/provider_brand.dart';

/// Provider logo. If you add official logo files to assets/images/providers/ (mtn.png, airtel.png)
/// they are used automatically; otherwise a branded badge is drawn: MTN yellow, Airtel red.
class ProviderLogo extends StatelessWidget {
  final String provider;
  final double size;
  const ProviderLogo({super.key, required this.provider, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final brand = brandFor(provider);
    final badge = _badge(brand);
    final asset = brand.logoAsset;
    if (asset == null) return badge;
    return SizedBox(
      width: size * 1.4,
      height: size,
      child: Image.asset(asset, fit: BoxFit.contain, errorBuilder: (_, __, ___) => badge),
    );
  }

  Widget _badge(ProviderBrand brand) {
    switch (brand.key) {
      case 'mtn':
        return Container(
          width: size * 1.4,
          height: size,
          alignment: Alignment.center,
          decoration: const ShapeDecoration(color: AppColors.mtnYellow, shape: StadiumBorder()),
          child: Text('MTN',
              style: TextStyle(
                  color: const Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  fontSize: size * 0.4)),
        );
      case 'airtel':
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.airtelRed, shape: BoxShape.circle),
          child: Text('airtel',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.27)),
        );
      default:
        final letter = brand.label.isEmpty ? '?' : brand.label.substring(0, 1).toUpperCase();
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.blue, shape: BoxShape.circle),
          child: Text(letter,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.45)),
        );
    }
  }
}
