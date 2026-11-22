import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import 'event_data.dart';

const _statuses = {
  'Scheduled': 'Terjadwal',
  'Ongoing': 'Berlangsung',
  'Completed': 'Selesai',
  'Cancelled': 'Dibatalkan',
};
const _levels = ['', 'Kelompok', 'Desa', 'Daerah', 'Pusat'];
const _maxMaterials = 50;

class _MaterialRow {
  _MaterialRow({String title = '', String speaker = ''})
      : title = TextEditingController(text: title),
        speaker = TextEditingController(text: speaker);

  final key = UniqueKey();
  final TextEditingController title, speaker;

  void dispose() {
    title.dispose();
    speaker.dispose();
  }
}

/// Create (no [event]) or edit one. Pops `true` after a saved change, and
/// `false` when the account turned out not to be allowed to write.
class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, this.event});

  final MobileEvent? event;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.event?.title);
  late final _location = TextEditingController(text: widget.event?.location);
  late final _description =
      TextEditingController(text: widget.event?.description);

  late bool _announcement = widget.event?.isAnnouncement ?? false;
  late String _category = widget.event?.category ?? 'Umum';
  late String _level = _levels.contains(widget.event?.level)
      ? widget.event!.level
      : '';
  late String _status = _statuses.containsKey(widget.event?.status)
      ? widget.event!.status
      : 'Scheduled';
  late bool _multiDay = widget.event?.isMultiDay ?? false;
  late DateTime? _start = widget.event?.start ?? DateTime.now();
  late DateTime? _end = widget.event?.isMultiDay == true
      ? widget.event!.end
      : null;
  TimeOfDay? _from, _to;
  final List<_MaterialRow> _materials = [];

  bool _saving = false;
  String? _error;

  bool get _editing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    if (e != null) {
      _from = _parseTime(e.startTime);
      _to = _parseTime(e.endTime);
      _materials.addAll(e.materials
          .map((m) => _MaterialRow(title: m.title, speaker: m.speaker)));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    for (final m in _materials) {
      m.dispose();
    }
    super.dispose();
  }

  static TimeOfDay? _parseTime(String s) {
    final p = s.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
    return h == null || m == null ? null : TimeOfDay(hour: h, minute: m);
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _dateLabel(DateTime? d) => d == null
      ? 'Pilih tanggal'
      : '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  Future<void> _pickDate({required bool end}) async {
    final initial = (end ? _end : _start) ?? _start ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (end) {
        _end = picked;
      } else {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) _end = picked;
      }
    });
  }

  Future<void> _pickTime({required bool to}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (to ? _to : _from) ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => to ? _to = picked : _from = picked);
  }

  /// Quick feedback; the server stays the judge.
  String? _validate() {
    if (_start == null) return 'Tanggal mulai wajib diisi.';
    if (_multiDay) {
      if (_end == null) return 'Tanggal selesai wajib diisi.';
      if (_end!.isBefore(_start!)) {
        return 'Tanggal selesai tidak boleh sebelum tanggal mulai.';
      }
    } else if (!_announcement) {
      if ((_from == null) != (_to == null)) {
        return 'Jam mulai dan jam selesai harus diisi bersamaan.';
      }
      if (_from != null &&
          _to!.hour * 60 + _to!.minute <= _from!.hour * 60 + _from!.minute) {
        return 'Jam selesai harus setelah jam mulai.';
      }
    }
    if (!_announcement) {
      for (final m in _materials) {
        if (m.title.text.trim().isEmpty) return 'Judul materi wajib diisi.';
        if (m.title.text.trim().length > 255 ||
            m.speaker.text.trim().length > 255) {
          return 'Materi dan pemateri maksimal 255 karakter.';
        }
      }
    }
    return null;
  }

  Map<String, dynamic> _body() {
    final multi = _multiDay;
    final timed = !multi && !_announcement && _from != null && _to != null;
    return {
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'location': _location.text.trim(),
      'category': _category,
      'level': _level,
      'kind': _announcement ? 'announcement' : 'event',
      if (_editing) 'status': _status,
      'start_date': eventDay(_start!),
      if (multi) 'end_date': eventDay(_end!),
      if (timed) 'start_time': _fmt(_from!),
      if (timed) 'end_time': _fmt(_to!),
      // Editing replaces the list; an empty one clears it.
      if (!_announcement && (_editing || _materials.isNotEmpty))
        'materials': [
          for (final m in _materials)
            EventMaterial(
                    title: m.title.text.trim(), speaker: m.speaker.text.trim())
                .toJson()
        ],
    };
  }

  Future<void> _save() async {
    if (_saving) return;
    final formOk = _formKey.currentState?.validate() ?? false;
    final problem = _validate();
    if (!formOk || problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final body = _body();
      if (_editing) {
        await eventRepo.update(widget.event!.id, body);
      } else {
        await eventRepo.create(body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Event save error: $e');
      if (!mounted) return;
      final failure = eventFailure(e);
      if (failure == EventFailure.notWriter ||
          failure == EventFailure.notProvisioned) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(eventError(e))));
        Navigator.of(context).pop(false);
        return;
      }
      // Stay on the form with everything typed so far.
      setState(() {
        _saving = false;
        _error = eventError(e);
      });
    }
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Lx.rButton)),
        filled: true,
        fillColor: Lx.surface,
      );

  Widget _gap([double h = Lx.s12]) => SizedBox(height: h);

  @override
  Widget build(BuildContext context) {
    final kindWord = _announcement ? 'Pengumuman' : 'Kegiatan';
    return Scaffold(
      backgroundColor: Lx.background,
      appBar: AppBar(
        title: Text(_editing ? 'Ubah $kindWord' : 'Tambah $kindWord'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Lx.s16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: Lx.primary,
              foregroundColor: Colors.white,
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Simpan'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(Lx.s16),
          children: [
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: Lx.s12),
                padding: const EdgeInsets.all(Lx.s12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(Lx.rButton),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: Color(0xFFB91C1C))),
              ),
            // Type is fixed once saved: event-reminder refuses a change.
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Kegiatan')),
                ButtonSegment(value: true, label: Text('Pengumuman')),
              ],
              selected: {_announcement},
              onSelectionChanged: _editing
                  ? null
                  : (s) => setState(() {
                        _announcement = s.first;
                        if (_announcement) {
                          _from = _to = null;
                          _materials
                            ..forEach((m) => m.dispose())
                            ..clear();
                        }
                      }),
            ),
            _gap(),
            TextFormField(
              controller: _title,
              decoration: _dec('Judul *'),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 255,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Judul wajib diisi.' : null,
            ),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: _dec('Kategori *'),
              items: const [
                DropdownMenuItem(value: 'Umum', child: Text('Umum')),
                DropdownMenuItem(value: 'Generus', child: Text('Generus')),
              ],
              onChanged: (v) => setState(() => _category = v ?? 'Umum'),
            ),
            _gap(),
            DropdownButtonFormField<String>(
              value: _level,
              decoration: _dec('Tingkat'),
              items: [
                for (final l in _levels)
                  DropdownMenuItem(
                      value: l, child: Text(l.isEmpty ? 'Tanpa tingkat' : l)),
              ],
              onChanged: (v) => setState(() => _level = v ?? ''),
            ),
            _gap(),
            TextFormField(
              controller: _location,
              decoration: _dec('Lokasi'),
              textCapitalization: TextCapitalization.sentences,
            ),
            _gap(),
            TextFormField(
              controller: _description,
              decoration: _dec('Keterangan'),
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: 6,
            ),
            if (_editing) ...[
              _gap(),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: _dec('Status'),
                items: [
                  for (final s in _statuses.entries)
                    DropdownMenuItem(value: s.key, child: Text(s.value)),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'Scheduled'),
              ),
            ],
            _gap(Lx.s20),
            Text('Waktu', style: Lx.cardHeading),
            _gap(Lx.s8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Satu hari')),
                ButtonSegment(value: true, label: Text('Beberapa hari')),
              ],
              selected: {_multiDay},
              onSelectionChanged: (s) => setState(() {
                _multiDay = s.first;
                if (_multiDay) {
                  _from = _to = null;
                  _end ??= _start;
                }
              }),
            ),
            _gap(),
            Row(children: [
              Expanded(
                child: _pickerField(
                    'Tanggal mulai', _dateLabel(_start), () => _pickDate(end: false)),
              ),
              if (_multiDay) ...[
                const SizedBox(width: Lx.s12),
                Expanded(
                  child: _pickerField(
                      'Tanggal selesai', _dateLabel(_end), () => _pickDate(end: true)),
                ),
              ],
            ]),
            if (!_multiDay && !_announcement) ...[
              _gap(),
              Row(children: [
                Expanded(
                  child: _pickerField('Jam mulai',
                      _from == null ? 'Seluruh hari' : _fmt(_from!), () => _pickTime(to: false)),
                ),
                const SizedBox(width: Lx.s12),
                Expanded(
                  child: _pickerField('Jam selesai',
                      _to == null ? 'Seluruh hari' : _fmt(_to!), () => _pickTime(to: true)),
                ),
              ]),
              if (_from != null || _to != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _from = _to = null),
                    child: const Text('Hapus jam (seluruh hari)'),
                  ),
                ),
            ],
            if (!_announcement) ..._materialSection(),
            const SizedBox(height: Lx.s32),
          ],
        ),
      ),
    );
  }

  Widget _pickerField(String label, String value, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Lx.rButton),
        child: InputDecorator(
          decoration: _dec(label),
          child: Text(value),
        ),
      );

  List<Widget> _materialSection() => [
        _gap(Lx.s20),
        Row(children: [
          Expanded(child: Text('Materi', style: Lx.cardHeading)),
          TextButton.icon(
            onPressed: _materials.length >= _maxMaterials
                ? null
                : () => setState(() => _materials.add(_MaterialRow())),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah materi'),
          ),
        ]),
        // The order here is the order stored.
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: (from, to) => setState(() {
            if (to > from) to -= 1;
            _materials.insert(to, _materials.removeAt(from));
          }),
          children: [
            for (var i = 0; i < _materials.length; i++)
              Padding(
                key: _materials[i].key,
                padding: const EdgeInsets.only(bottom: Lx.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.only(top: 16, right: 8),
                        child: Icon(Icons.drag_handle, color: Lx.textMuted),
                      ),
                    ),
                    Expanded(
                      child: Column(children: [
                        TextField(
                            controller: _materials[i].title,
                            decoration: _dec('Materi *')),
                        const SizedBox(height: Lx.s8),
                        TextField(
                            controller: _materials[i].speaker,
                            decoration: _dec('Pemateri')),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Hapus materi',
                      onPressed: () => setState(() => _materials.removeAt(i).dispose()),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (_materials.isEmpty)
          Text(_editing ? 'Tanpa materi (daftar lama dikosongkan).' : 'Belum ada materi.',
              style: Lx.sectionSubtitle),
      ];
}
