import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/pin_service.dart';
import '../theme/app_colors.dart';
import 'dialogs.dart';
import 'error_view.dart';

enum PinPurpose { confirmExpense, change }

/// Local security check. Returns true when the user entered the right PIN
/// (or just created one). The PIN never leaves the phone.
Future<bool> showPinSheet(
  BuildContext context, {
  required PinPurpose purpose,
  String? summaryTitle,
  String? summaryLine,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
    builder: (_) => _PinSheet(purpose: purpose, summaryTitle: summaryTitle, summaryLine: summaryLine),
  );
  return ok ?? false;
}

class _PinSheet extends StatefulWidget {
  final PinPurpose purpose;
  final String? summaryTitle;
  final String? summaryLine;
  const _PinSheet({required this.purpose, this.summaryTitle, this.summaryLine});

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  final _pins = PinService.instance;
  int? _userId;
  String _stage = 'loading'; // loading, verify, create, confirm
  String _entry = '';
  String _first = '';
  String? _message;
  bool _busy = false;
  int _locked = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final me = await ApiService.instance.getMe();
      final has = await _pins.hasPin(me.id);
      final locked = await _pins.lockedSecondsLeft(me.id);
      if (!mounted) return;
      setState(() {
        _userId = me.id;
        _stage = has ? 'verify' : 'create';
      });
      if (has && locked > 0) _startLock(locked);
    } catch (e) {
      if (!mounted) return;
      final nav = Navigator.of(context);
      showError(context, e);
      nav.pop(false);
    }
  }

  void _startLock(int seconds) {
    _timer?.cancel();
    setState(() {
      _locked = seconds;
      _message = 'Too many wrong attempts.';
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _locked -= 1;
        if (_locked <= 0) {
          _locked = 0;
          _message = null;
          t.cancel();
        }
      });
    });
  }

  void _digit(String d) {
    if (_busy || _locked > 0 || _entry.length >= 4 || _stage == 'loading') return;
    setState(() {
      _entry += d;
      _message = null;
    });
    if (_entry.length == 4) _submit();
  }

  void _backspace() {
    if (_entry.isEmpty || _busy) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _submit() async {
    final pin = _entry;
    setState(() => _busy = true);
    try {
      if (_stage == 'verify') {
        final r = await _pins.verify(_userId!, pin);
        if (!mounted) return;
        if (r.ok) {
          if (widget.purpose == PinPurpose.change) {
            setState(() {
              _stage = 'create';
              _entry = '';
            });
          } else {
            Navigator.pop(context, true);
          }
        } else if (r.lockedSeconds > 0) {
          setState(() => _entry = '');
          _startLock(r.lockedSeconds);
        } else {
          setState(() {
            _entry = '';
            _message = 'Wrong PIN. ${r.attemptsLeft} attempt(s) left.';
          });
        }
      } else if (_stage == 'create') {
        setState(() {
          _first = pin;
          _entry = '';
          _stage = 'confirm';
        });
      } else if (_stage == 'confirm') {
        if (pin == _first) {
          await _pins.setPin(_userId!, pin);
          if (mounted) Navigator.pop(context, true);
        } else {
          setState(() {
            _entry = '';
            _first = '';
            _stage = 'create';
            _message = 'The two PINs did not match. Try again.';
          });
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPin() async {
    final password = await askPassword(context, title: 'Enter your account password to reset the PIN');
    if (password == null || !mounted) return;
    try {
      final ok = await ApiService.instance.verifyPassword(password);
      if (!mounted) return;
      if (ok) {
        await _pins.clear(_userId!);
        _timer?.cancel();
        setState(() {
          _stage = 'create';
          _entry = '';
          _locked = 0;
          _message = 'Password confirmed. Create a new PIN.';
        });
      } else {
        setState(() => _message = 'Incorrect password.');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  String get _title {
    switch (_stage) {
      case 'create':
        return 'Create your security PIN';
      case 'confirm':
        return 'Confirm your PIN';
      default:
        return widget.purpose == PinPurpose.change ? 'Enter your current PIN' : 'Confirm this expense';
    }
  }

  String get _subtitle {
    switch (_stage) {
      case 'create':
        return 'Choose 4 digits. You will use this PIN to approve expenses on this phone.';
      case 'confirm':
        return 'Enter the same 4 digits again.';
      default:
        return widget.purpose == PinPurpose.change
            ? 'Enter your current PIN to continue.'
            : 'Enter your security PIN to approve this expense.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: _stage == 'loading'
            ? const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(height: 16),
                  const Icon(Icons.lock_outline, size: 34, color: AppColors.navy),
                  const SizedBox(height: 8),
                  Text(_title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 4),
                  Text(_subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.grey)),
                  if (widget.summaryTitle != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.expenseSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(widget.summaryTitle!,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.expense)),
                          if (widget.summaryLine != null)
                            Text(widget.summaryLine!, style: const TextStyle(color: AppColors.grey)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 4; i++)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 9),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < _entry.length ? AppColors.navy : Colors.transparent,
                            border: Border.all(color: AppColors.navy, width: 2),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(
                    height: 42,
                    child: Center(
                      child: Text(
                        _locked > 0 ? 'Try again in ${_locked}s' : (_message ?? ''),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.expense, fontSize: 14),
                      ),
                    ),
                  ),
                  _keypad(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      if (_stage == 'verify') TextButton(onPressed: _forgotPin, child: const Text('Forgot PIN?')),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _keypad() {
    Widget key(String label, {VoidCallback? onTap, IconData? icon}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Material(
            color: label.isEmpty && icon == null ? Colors.transparent : AppColors.paleBlue,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: SizedBox(
                height: 54,
                child: Center(
                  child: icon != null
                      ? Icon(icon, color: AppColors.navy)
                      : Text(label,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.navy)),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget row(List<String> digits) =>
        Row(children: [for (final d in digits) key(d, onTap: () => _digit(d))]);

    return Column(
      children: [
        row(['1', '2', '3']),
        row(['4', '5', '6']),
        row(['7', '8', '9']),
        Row(
          children: [
            key(''),
            key('0', onTap: () => _digit('0')),
            key('', icon: Icons.backspace_outlined, onTap: _backspace),
          ],
        ),
      ],
    );
  }
}
