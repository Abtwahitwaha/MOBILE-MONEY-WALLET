import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The rounded square button used for menu / back / add in the XD design.
class SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color iconColor;

  const SquareIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.background = AppColors.slate,
    this.iconColor = AppColors.navy,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(width: 52, height: 48, child: Icon(icon, color: iconColor)),
      ),
    );
  }
}
