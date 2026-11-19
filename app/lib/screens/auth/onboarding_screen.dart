import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../theme/app_colors.dart';

class _OnboardingPage {
  final String image;
  final String title;
  final String text;
  const _OnboardingPage(this.image, this.title, this.text);
}

/// Screen 2 of the list: three intro slides shown only the first time.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pages = [
    _OnboardingPage('assets/images/ic_deposit.png', 'Record every shilling',
        'Log the money you receive and spend through your mobile money accounts.'),
    _OnboardingPage('assets/images/ic_card.png', 'All your accounts in one place',
        'Add your MTN or Airtel wallets and watch each balance update automatically.'),
    _OnboardingPage('assets/images/ic_withdraw.png', 'See where your money goes',
        'Review your history and track your spending by day and by category.'),
  ];

  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(ApiService.instance.isLoggedIn ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _finish, child: const Text('Skip', style: TextStyle(fontSize: 16))),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 220,
                          height: 220,
                          padding: const EdgeInsets.all(40),
                          decoration: const BoxDecoration(color: AppColors.paleBlue, shape: BoxShape.circle),
                          child: Image.asset(p.image, fit: BoxFit.contain),
                        ),
                        const SizedBox(height: 36),
                        Text(p.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.navy)),
                        const SizedBox(height: 12),
                        Text(p.text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 17, color: AppColors.grey)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.all(4),
                    width: i == _page ? 26 : 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: i == _page ? AppColors.navy : AppColors.softBlue,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
              child: FilledButton(
                onPressed: () {
                  if (last) {
                    _finish();
                  } else {
                    _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                  }
                },
                child: Text(last ? 'Get started' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
