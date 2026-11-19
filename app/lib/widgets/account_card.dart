import 'package:flutter/material.dart';

import '../models/account.dart';
import '../utils/format.dart';
import '../utils/provider_brand.dart';
import 'provider_logo.dart';

/// Account card in the provider's colours: yellow for MTN, red for Airtel, blue for others.
class AccountCard extends StatelessWidget {
  final Account account;
  const AccountCard({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    final brand = brandFor(account.provider);
    final on = brand.onColor;
    final soft = on.withAlpha(190);
    return Container(
      height: 190,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(colors: brand.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            // soft decorative circles
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(color: Color(0x22FFFFFF), shape: BoxShape.circle),
              ),
            ),
            Positioned(
              right: 40,
              bottom: -60,
              child: Container(
                width: 130,
                height: 130,
                decoration: const BoxDecoration(color: Color(0x18FFFFFF), shape: BoxShape.circle),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: ProviderLogo(provider: account.provider, size: 30),
                      ),
                      const Spacer(),
                      Text(maskPhone(account.phoneNumber),
                          style: TextStyle(color: on, fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Spacer(),
                  Text(account.accountName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: on, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(brand.label, style: TextStyle(color: soft, fontSize: 12)),
                  const SizedBox(height: 10),
                  Text('Available balance', style: TextStyle(color: soft, fontSize: 12)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(formatUgx(account.balance),
                        style: TextStyle(color: on, fontSize: 26, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
