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

  @override
  Widget build(BuildContext context) {
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
                const SizedBox(height: Lx.s12),
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
                const SizedBox(height: Lx.s8),
                Text('Minimal $minLength karakter, memuat huruf dan angka.',
                    style: Lx.metadata),
                const SizedBox(height: Lx.s24),
                if (_error != null) ProfileErrorBox(_error!),
                SizedBox(
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
    );
  }
}
