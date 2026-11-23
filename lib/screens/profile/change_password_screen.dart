import 'dart:convert';

import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../../services/api_service.dart';
import 'profile_widgets.dart';

/// Change own password: the current one, the new one twice. See
/// docs/PROFILE_PASSWORD_API.md.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  static const minLength = 8;

  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _showCurrent = false, _showNew = false, _showConfirm = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The checklist follows what is typed.
    for (final c in [_current, _new, _confirm]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Widget _eye(bool shown, VoidCallback toggle) => IconButton(
        icon: Icon(
            shown ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        onPressed: toggle,
      );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService().changePassword(
        currentPassword: _current.text,
        newPassword: _new.text,
        confirmPassword: _confirm.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Password diubah.')));
      Navigator.of(context).pop();
    } catch (e) {
      // Not logged: the request carries the passwords.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = profileFailure(e, fallback: 'Password gagal diubah.');
      });
    }
  }

  /// One rule of the new password, ticked once it holds. [pending] while
  /// there is nothing to check yet.
  Widget _rule(String text, bool ok, {bool pending = false}) {
    final color = pending
        ? Lx.textMuted
        : ok
            ? Lx.success
            : Lx.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
              !pending && ok
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 16,
              color: color),
          const SizedBox(width: Lx.s8),
          Expanded(
              child: Text(text,
                  style: Lx.metadata.copyWith(
                      color: !pending && ok ? Lx.text : Lx.textSecondary))),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: Lx.s12),
        padding: const EdgeInsets.all(Lx.s16),
        decoration: Lx.card(),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children),
      );

  @override
  Widget build(BuildContext context) {
    final n = _new.text;
    final empty = n.isEmpty;
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Ubah Password')),
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(Lx.s16),
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: Lx.secondaryLight,
                          borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.lock_reset_rounded,
                          color: Lx.secondary),
                    ),
                    const SizedBox(width: Lx.s12),
                    Expanded(
                      child: Text(
                          'Masukkan password lama, lalu password baru dua '
                          'kali. Setelah diubah, gunakan password baru saat '
                          'masuk.',
                          style: Lx.body),
                    ),
                  ],
                ),
                const SizedBox(height: Lx.s16),
                _card([
                  Text('Password saat ini', style: Lx.cardHeading),
                  const SizedBox(height: Lx.s8),
                  TextFormField(
                    controller: _current,
                    enabled: !_saving,
                    obscureText: !_showCurrent,
                    autofillHints: const [AutofillHints.password],
                    decoration: profileDecoration('Password saat ini',
                        suffix: _eye(_showCurrent,
                            () => setState(() => _showCurrent = !_showCurrent))),
                    validator: (v) => (v ?? '').isEmpty
                        ? 'Password saat ini wajib diisi.'
                        : null,
                  ),
                ]),
                _card([
                  Text('Password baru', style: Lx.cardHeading),
                  const SizedBox(height: Lx.s8),
                  TextFormField(
                    controller: _new,
                    enabled: !_saving,
                    obscureText: !_showNew,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: profileDecoration('Password baru',
                        suffix: _eye(_showNew,
                            () => setState(() => _showNew = !_showNew))),
                    validator: (v) {
                      final t = v ?? '';
                      if (t.length < minLength) {
                        return 'Minimal $minLength karakter.';
                      }
                      if (!RegExp(r'[A-Za-z]').hasMatch(t) ||
                          !RegExp(r'[0-9]').hasMatch(t)) {
                        return 'Harus memuat huruf dan angka.';
                      }
                      if (utf8.encode(t).length > 72) {
                        return 'Password terlalu panjang (maksimal 72 byte).';
                      }
                      if (t == _current.text) {
                        return 'Tidak boleh sama dengan password saat ini.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: Lx.s12),
                  TextFormField(
                    controller: _confirm,
                    enabled: !_saving,
                    obscureText: !_showConfirm,
                    decoration: profileDecoration('Ulangi password baru',
                        suffix: _eye(_showConfirm,
                            () => setState(() => _showConfirm = !_showConfirm))),
                    validator: (v) =>
                        v == _new.text ? null : 'Password tidak sama.',
                  ),
                  const SizedBox(height: Lx.s12),
                  _rule('Minimal $minLength karakter', n.length >= minLength,
                      pending: empty),
                  _rule(
                      'Memuat huruf dan angka',
                      RegExp(r'[A-Za-z]').hasMatch(n) &&
                          RegExp(r'[0-9]').hasMatch(n),
                      pending: empty),
                  _rule('Berbeda dari password saat ini',
                      n != _current.text,
                      pending: empty || _current.text.isEmpty),
                  _rule('Kedua password baru sama', _confirm.text == n,
                      pending: _confirm.text.isEmpty),
                ]),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Material(
          color: Lx.surface,
          child: DecoratedBox(
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Lx.border))),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(Lx.s16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null) ProfileErrorBox(_error!),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Ubah Password'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
