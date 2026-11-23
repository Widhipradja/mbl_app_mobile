import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/launcher_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_ui.dart' show RetryState;
import 'profile_widgets.dart';

/// Edit own profile: name, date of birth, email, phone and gender. The login id (`user_id`)
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

  /// A photo upload is running: the form is not sent meanwhile, so the two
  /// requests never overlap.
  bool _photoBusy = false;
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
    _birthOrig = _birth = parseBirthDate(_s(p['birth_date']));
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
      // A date is `YYYY-MM-DD`; "" removes it.
      if (_birthChanged)
        'birth_date': _birth == null ? '' : birthDateParam(_birth!),
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

  /// Date of birth as the server last said it, and as it is now; null for none.
  DateTime? _birthOrig, _birth;

  bool get _birthChanged => _birth != _birthOrig;

  Future<void> _pickBirth() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900, 1, 1),
      lastDate: today,
      helpText: 'Tanggal lahir',
    );
    if (picked != null) {
      setState(() => _birth = DateTime(picked.year, picked.month, picked.day));
    }
  }

  /// A tap opens the picker; "Hapus" clears it (the server then stores none).
  Widget _birthField(bool enabled) {
    final d = _birth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tanggal lahir', style: Lx.metadata),
        const SizedBox(height: 6),
        InkWell(
          onTap: enabled ? _pickBirth : null,
          borderRadius: BorderRadius.circular(Lx.rButton),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: Lx.s12),
            decoration: BoxDecoration(
              color: Lx.surface,
              borderRadius: BorderRadius.circular(Lx.rButton),
              border: Border.all(color: Lx.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.cake_outlined, size: 20, color: Lx.textMuted),
                const SizedBox(width: Lx.s12),
                Expanded(
                  child: Text(
                    d == null ? 'Belum diisi' : longDate(d),
                    style: Lx.body.copyWith(
                        color: d == null ? Lx.textMuted : Lx.text,
                        fontWeight:
                            d == null ? FontWeight.w400 : FontWeight.w600),
                  ),
                ),
                const Icon(Icons.calendar_today_outlined,
                    size: 18, color: Lx.textSecondary),
              ],
            ),
          ),
        ),
        if (d != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: enabled ? () => setState(() => _birth = null) : null,
              style: TextButton.styleFrom(
                  foregroundColor: Lx.danger,
                  visualDensity: VisualDensity.compact),
              child: const Text('Hapus tanggal lahir'),
            ),
          ),
      ],
    );
  }

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
                  ? Center(child: RetryState(_loadError!, onRetry: _load))
                  : _body(),
        ),
        bottomNavigationBar:
            _loading || _loadError != null ? null : _bottomBar(),
      ),
    );
  }

  /// Error and the save button, kept above the keyboard.
  Widget _bottomBar() {
    final readOnly = _sex == null;
    final enabled = !_saving && !_photoBusy && !readOnly;
    return Material(
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
                    onPressed: enabled ? _save : null,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Simpan Perubahan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) =>
      Container(
        margin: const EdgeInsets.only(bottom: Lx.s12),
        padding: const EdgeInsets.all(Lx.s16),
        decoration: Lx.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Lx.primary),
                const SizedBox(width: Lx.s8),
                Text(title, style: Lx.cardHeading),
              ],
            ),
            const SizedBox(height: Lx.s12),
            ...children,
          ],
        ),
      );

  /// Laki-laki | Perempuan as two choices instead of a dropdown.
  Widget _sexChoice() {
    Widget option(String value, String label, IconData icon) {
      final on = _sex == value;
      return Expanded(
        child: InkWell(
          onTap: _saving ? null : () => setState(() => _sex = value),
          borderRadius: BorderRadius.circular(Lx.rButton),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 48,
            decoration: BoxDecoration(
              color: on ? Lx.primaryLight : Lx.surface,
              borderRadius: BorderRadius.circular(Lx.rButton),
              border: Border.all(
                  color: on ? Lx.primary : Lx.border, width: on ? 2 : 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: on ? Lx.primary : Lx.textMuted),
                const SizedBox(width: 6),
                Text(label,
                    style: Lx.button
                        .copyWith(color: on ? Lx.primary : Lx.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option('M', 'Laki-laki', Icons.male_rounded),
        const SizedBox(width: Lx.s8),
        option('F', 'Perempuan', Icons.female_rounded),
      ],
    );
  }

  Widget _body() {
    // No `sex` in the profile: the account is not linked to one member, so
    // the server would refuse to save.
    final readOnly = _sex == null;
    final enabled = !_saving && !_photoBusy && !readOnly;
    return Form(
      key: _form,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(Lx.s16),
        children: [
          // The server refuses photo changes for an account without a member.
          ProfilePhotoEditor(
            enabled: !readOnly && !_saving,
            onBusyChanged: (b) => setState(() => _photoBusy = b),
          ),
          const SizedBox(height: Lx.s4),
          if (!readOnly)
            Center(child: Text('Ketuk untuk ganti foto', style: Lx.metadata)),
          const SizedBox(height: Lx.s16),
          if (readOnly)
            Container(
              margin: const EdgeInsets.only(bottom: Lx.s12),
              padding: const EdgeInsets.all(Lx.s12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(Lx.rButton),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 18, color: Color(0xFFEA580C)),
                  const SizedBox(width: Lx.s8),
                  Expanded(
                    child: Text(
                        'Akun Anda belum terhubung ke data anggota, jadi '
                        'profil belum bisa diubah. Hubungi admin.',
                        style: Lx.metadata.copyWith(
                            color: const Color(0xFF9A3412), height: 1.4)),
                  ),
                ],
              ),
            ),
          _section('Data diri', Icons.person_outline_rounded, [
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
              validator: (v) => (v ?? '').trim().length > 100
                  ? 'Maksimal 100 karakter.'
                  : null,
            ),
            if (!readOnly) ...[
              const SizedBox(height: Lx.s16),
              _birthField(enabled),
            ],
            if (!readOnly) ...[
              const SizedBox(height: Lx.s16),
              Text('Jenis kelamin', style: Lx.metadata),
              const SizedBox(height: 6),
              _sexChoice(),
            ],
          ]),
          _section('Kontak', Icons.contact_mail_outlined, [
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
          ]),
          _section('Akun', Icons.badge_outlined, [
            Row(
              children: [
                Text('User ID', style: Lx.body),
                const Spacer(),
                Text(_userId.isEmpty ? '—' : _userId,
                    style: Lx.body
                        .copyWith(color: Lx.text, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Dipakai untuk masuk dan tidak bisa diubah.',
                style: Lx.metadata),
          ]),
        ],
      ),
    );
  }
}
