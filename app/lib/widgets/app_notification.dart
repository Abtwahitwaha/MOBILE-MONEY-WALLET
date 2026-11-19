import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum NotificationKind { income, expense, info }

/// A banner that slides down from the top of the screen and disappears by itself.
/// It is drawn on the app's root overlay, so it stays visible while screens close.
class AppNotification {
  static void show(
    OverlayState overlay, {
    required String title,
    required String message,
    NotificationKind kind = NotificationKind.info,
  }) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Banner(title: title, message: message, kind: kind, onDone: () => entry.remove()),
    );
    overlay.insert(entry);
  }
}

class _Banner extends StatefulWidget {
  final String title;
  final String message;
  final NotificationKind kind;
  final VoidCallback onDone;
  const _Banner({required this.title, required this.message, required this.kind, required this.onDone});

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(const Duration(milliseconds: 3800), _close);
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (mounted) await _controller.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    late final Color accent;
    late final IconData icon;
    switch (widget.kind) {
      case NotificationKind.income:
        accent = AppColors.income;
        icon = Icons.south_west;
        break;
      case NotificationKind.expense:
        accent = AppColors.expense;
        icon = Icons.north_east;
        break;
      case NotificationKind.info:
        accent = AppColors.blue;
        icon = Icons.notifications_active;
        break;
    }
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -1.4), end: Offset.zero)
              .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: _close,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent, width: 2),
                    boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 6))],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                        child: Icon(icon, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.title,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink)),
                            const SizedBox(height: 2),
                            Text(widget.message, style: const TextStyle(fontSize: 14, color: AppColors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
