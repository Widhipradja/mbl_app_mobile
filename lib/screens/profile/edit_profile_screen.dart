import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/launcher_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'profile_widgets.dart';

/// Edit own profile: name, email, phone and gender. The login id (`user_id`)
/// is shown but cannot be changed. See docs/PROFILE_PASSWORD_API.md.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;

  /// What the server last said about the profile: the baseline for "changed".
  Map<String, String> _orig = {};
  String _userId = '';

  /// M / F; null when the account is not linked to a member (read-only then).
  String? _sex;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _s(dynamic v) => v?.toString().trim() ?? '';

  void _fill(Map<dynamic, dynamic> p) {
    final first = _s(p['first_name'] ?? p['firstname']);
    final last = _s(p['last_name'] ?? p['lastname']);
    _orig = {
      'first_name': first,
      'last_name': last,
      'email': _s(p['email']).toLowerCase(),
      'phone': _s(p['phone']),
    };
    _first.text = first;
    _last.text = last;
    _email.text = _s(p['email']);
    _phone.text = _s(p['phone']);
    _password.clear();
    final sex = _s(p['sex']).toUpperCase();
    _sex = sex == 'M' || sex == 'F' ? sex : null;
    _sexOrig = _sex;
    _userId = _s(p['user_id']);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final resp = await ApiService().getProfile();
      if (!mounted) return;
      final data = resp.data;
      if (data is! Map) throw const FormatException('profile');
      setState(() => _fill(data));
    } catch (e) {
      debugPrint('EditProfileScreen load error: $e');
      if (mounted) {
        setState(() =>
            _loadError = profileFailure(e, fallback: 'Profil gagal dimuat.'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _emailChanged =>
      _email.text.trim().toLowerCase() != (_orig['email'] ?? '');

  /// Only what differs from the server's profile.
  Map<String, dynamic> _changes() {
    final now = {
      'first_name': _first.text.trim(),
      'last_name': _last.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
    };
    return {
      for (final e in now.entries)
        if (e.key == 'email' ? _emailChanged : e.value != (_orig[e.key] ?? ''))
          e.key: e.value,
    };
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final changes = _changes();
    if (_sexChanged) changes['sex'] = _sex;
    if (changes.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    if (_emailChanged) changes['current_password'] = _password.text;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().updateProfile(changes);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profil diperbarui.')));
      Navigator.of(context).pop();
    } catch (e) {
      // Not logged: the request may carry the password.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = profileFailure(e, fallback: 'Profil gagal disimpan.');
      });
    }
  }

  String? _sexOrig;
  bool get _sexChanged => _sex != null && _sex != _sexOrig;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Ubah Profil')),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(Lx.s24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_loadError!,
                                textAlign: TextAlign.center, style: Lx.body),
                            TextButton(
                                onPressed: _load,
                                child: const Text('Coba lagi')),
                          ],
                        ),
                      ),
                    )
                  : _body(),
        ),
      ),
    );
  }

  Widget _body() {
    // No `sex` in the profile: the account is not linked to one member, so
    // the server would refuse to save.
    final readOnly = _sex == null;
    final enabled = !_saving && !readOnly;
    return Form(
      key: _form,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(Lx.s16),
        children: [
          if (readOnly)
            Container(
              margin: const EdgeInsets.only(bottom: Lx.s12),
              padding: const EdgeInsets.all(Lx.s12),
              decoration: BoxDecoration(
                color: Lx.primaryLight,
                borderRadius: BorderRadius.circular(Lx.rButton),
              ),
              child: Text(
                  'Akun Anda belum terhubung ke data anggota, jadi profil '
                  'belum bisa diubah. Hubungi admin.',
                  style: Lx.metadata.copyWith(color: Lx.primaryDark)),
            ),
          TextFormField(
            key: ValueKey('uid$_userId'),
            initialValue: _userId,
            enabled: false,
            decoration: profileDecoration('User ID (tidak bisa diubah)'),
          ),
          const SizedBox(height: Lx.s12),
          TextFormField(
            controller: _first,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            decoration: profileDecoration('Nama depan'),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return 'Nama depan wajib diisi.';
              return t.length > 100 ? 'Maksimal 100 karakter.' : null;
            },
          ),
          const SizedBox(height: Lx.s12),
          TextFormField(
            controller: _last,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            decoration: profileDecoration('Nama belakang'),
            validator: (v) =>
                (v ?? '').trim().length > 100 ? 'Maksimal 100 karakter.' : null,
          ),
          const SizedBox(height: Lx.s12),
          TextFormField(
            controller: _email,
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
            decoration: profileDecoration('Email'),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return 'Email wajib diisi.';
              if (t.length > 254) return 'Email terlalu panjang.';
              return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                  ? null
                  : 'Format email tidak valid.';
            },
          ),
          if (_emailChanged) ...[
            const SizedBox(height: Lx.s12),
            TextFormField(
              controller: _password,
              enabled: enabled,
              obscureText: !_showPassword,
              decoration: profileDecoration('Password saat ini',
                  suffix: IconButton(
                    icon: Icon(_showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  )),
              validator: (v) => _emailChanged && (v ?? '').isEmpty
                  ? 'Isi password saat ini untuk mengubah email.'
                  : null,
            ),
            const SizedBox(height: Lx.s8),
            Text('Mengubah email memerlukan password saat ini.',
                style: Lx.metadata),
          ],
          const SizedBox(height: Lx.s12),
          TextFormField(
            controller: _phone,
            enabled: enabled,
            keyboardType: TextInputType.phone,
            decoration: profileDecoration('No. HP'),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return null;
              final digits = t.replaceAll(RegExp(r'[\s-]'), '');
              return RegExp(r'^\+?[0-9]{8,16}$').hasMatch(digits)
                  ? null
                  : 'Nomor telepon harus 8-16 digit.';
            },
          ),
          if (!readOnly) ...[
            const SizedBox(height: Lx.s12),
            DropdownButtonFormField<String>(
              value: _sex,
              decoration: profileDecoration('Jenis kelamin'),
              items: const [
                DropdownMenuItem(value: 'M', child: Text('Laki-laki')),
                DropdownMenuItem(value: 'F', child: Text('Perempuan')),
              ],
              onChanged: _saving ? null : (v) => setState(() => _sex = v),
            ),
          ],
          const SizedBox(height: Lx.s24),
          if (_error != null) ProfileErrorBox(_error!),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: enabled ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan'),
            ),
          ),
        ],
      ),
    );
  }
}
