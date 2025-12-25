import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/kbm_provider.dart';
import 'package:go_router/go_router.dart';

class SubjectModel {
  String id;
  String code;
  String name;
  List<SubSubjectModel> subSubjects;

  SubjectModel({
    required this.id,
    required this.code,
    required this.name,
    List<SubSubjectModel>? subSubjects,
  }) : subSubjects = subSubjects ?? [];
}

class SubSubjectModel {
  String id;
  String code;
  String name;

  SubSubjectModel({required this.id, required this.code, required this.name});
}

class EnrolledSubject {
  String subjectId;
  String subjectCode;
  String subjectName;
  List<String> subSubjectIds;

  EnrolledSubject({
    required this.subjectId,
    required this.subjectCode,
    required this.subjectName,
    List<String>? subSubjectIds,
  }) : subSubjectIds = subSubjectIds ?? [];
}

class EnrolledStudent {
  String studentId;
  String studentName;
  String studentNis;

  EnrolledStudent({
    required this.studentId,
    required this.studentName,
    required this.studentNis,
  });
}

class ClassModel {
  String id;
  String name;
  String gradeLevel;
  List<EnrolledSubject> subjects;
  List<EnrolledStudent> students;

  ClassModel({
    required this.id,
    required this.name,
    required this.gradeLevel,
    List<EnrolledSubject>? subjects,
    List<EnrolledStudent>? students,
  }) : subjects = subjects ?? [],
       students = students ?? [];
}

class KbmSetupScreen extends StatefulWidget {
  const KbmSetupScreen({super.key});

  @override
  State<KbmSetupScreen> createState() => _KbmSetupScreenState();
}

class _KbmSetupScreenState extends State<KbmSetupScreen> {
  // Subjects
  final TextEditingController _newSubjectCtrl = TextEditingController();
  final TextEditingController _newSubSubjectCtrl = TextEditingController();
  List<SubjectModel> subjects = [];
  String? selectedSubjectId;

  // Classes
  final TextEditingController _newClassCtrl = TextEditingController();
  String newGradeLevel = 'X';
  List<ClassModel> classes = [];
  String? selectedClassForRegistration;

  String activeTab = 'subjects';

  // Mock students
  final List<Map<String, String>> mockStudents = List.generate(
    12,
    (i) => {
      'id': 'stu${i + 1}',
      'name': 'Student ${i + 1}',
      'nis': 'NIS${1000 + i}',
    },
  );

  @override
  void dispose() {
    _newSubjectCtrl.dispose();
    _newSubSubjectCtrl.dispose();
    _newClassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;

          // Header
          final header = Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.settings, color: Colors.purple),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kelola mata pelajaran, kelas, dan pendaftaran siswa dalam satu halaman',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          if (isWide) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  header,
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildSubjectsSection()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildClassesSection()),
                    ],
                  ),
                ],
              ),
            );
          }

          // Narrow layout: tabs
          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Padding(padding: const EdgeInsets.all(16), child: header),
                TabBar(
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: Theme.of(context).primaryColor,
                  tabs: const [
                    Tab(text: 'Mata Pelajaran'),
                    Tab(text: 'Kelas & Pendaftaran'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Wrap sections in scroll views so each tab scrolls independently
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildSubjectsSection(),
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildClassesSection(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String getNextSubjectCode() {
    if (subjects.isEmpty) return 'A';
    final last = subjects.last.code;
    return String.fromCharCode(last.codeUnitAt(0) + 1);
  }

  String getNextSubSubjectCode(SubjectModel subject) {
    final subCount = subject.subSubjects.length;
    return '${subject.code}.${subCount + 1}';
  }

  void handleAddSubject() {
    final name = _newSubjectCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama mata pelajaran tidak boleh kosong')),
      );
      return;
    }
    final code = getNextSubjectCode();
    subjects.add(
      SubjectModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        code: code,
        name: name,
      ),
    );
    _newSubjectCtrl.clear();
    setState(() {});
  }

  void handleAddSubSubject() {
    if (selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih mata pelajaran terlebih dahulu')),
      );
      return;
    }
    final name = _newSubSubjectCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama sub mata pelajaran tidak boleh kosong'),
        ),
      );
      return;
    }
    final subject = subjects.firstWhere((s) => s.id == selectedSubjectId);
    final code = getNextSubSubjectCode(subject);
    subject.subSubjects.add(
      SubSubjectModel(
        id: '${subject.id}-${DateTime.now().millisecondsSinceEpoch}',
        code: code,
        name: name,
      ),
    );
    _newSubSubjectCtrl.clear();
    setState(() {});
  }

  void handleDeleteSubject(String subjectId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus mata pelajaran ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      subjects.removeWhere((s) => s.id == subjectId);
      setState(() {});
    }
  }

  void handleDeleteSubSubject(String subjectId, String subId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus sub mata pelajaran ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final subject = subjects.firstWhere((s) => s.id == subjectId);
      subject.subSubjects.removeWhere((ss) => ss.id == subId);
      setState(() {});
    }
  }

  void handleAddClass() {
    final name = _newClassCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama kelas tidak boleh kosong')),
      );
      return;
    }
    final cls = ClassModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      gradeLevel: newGradeLevel,
    );
    classes.add(cls);
    _newClassCtrl.clear();
    setState(() {});
  }

  void handleDeleteClass(String classId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Apakah Anda yakin ingin menghapus kelas ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      classes.removeWhere((c) => c.id == classId);
      if (selectedClassForRegistration == classId) {
        selectedClassForRegistration = null;
      }
      setState(() {});
    }
  }

  void handleToggleSubject(String classId, String subjectId) {
    final subject = subjects.firstWhere((s) => s.id == subjectId);
    classes = classes.map((cls) {
      if (cls.id != classId) return cls;
      final enrolled = cls.subjects.any((es) => es.subjectId == subjectId);
      if (enrolled) {
        cls.subjects.removeWhere((es) => es.subjectId == subjectId);
      } else {
        cls.subjects.add(
          EnrolledSubject(
            subjectId: subject.id,
            subjectCode: subject.code,
            subjectName: subject.name,
          ),
        );
      }
      return cls;
    }).toList();
    setState(() {});
  }

  void handleToggleSubSubject(
    String classId,
    String subjectId,
    String subSubjectId,
  ) {
    classes = classes.map((cls) {
      if (cls.id != classId) return cls;
      cls.subjects = cls.subjects.map((es) {
        if (es.subjectId != subjectId) return es;
        final exists = es.subSubjectIds.contains(subSubjectId);
        if (exists) {
          es.subSubjectIds.removeWhere((id) => id == subSubjectId);
        } else {
          es.subSubjectIds.add(subSubjectId);
        }
        return es;
      }).toList();
      return cls;
    }).toList();
    setState(() {});
  }

  void handleToggleStudent(String classId, String studentId) {
    final student = mockStudents.firstWhere((s) => s['id'] == studentId);
    classes = classes.map((cls) {
      if (cls.id != classId) return cls;
      final enrolled = cls.students.any((es) => es.studentId == studentId);
      if (enrolled) {
        cls.students.removeWhere((es) => es.studentId == studentId);
      } else {
        cls.students.add(
          EnrolledStudent(
            studentId: student['id']!,
            studentName: student['name']!,
            studentNis: student['nis']!,
          ),
        );
      }
      return cls;
    }).toList();
    setState(() {});
  }

  bool isSubjectEnrolled(String classId, String subjectId) {
    final cls = classes.firstWhere(
      (c) => c.id == classId,
      orElse: () => ClassModel(id: '', name: '', gradeLevel: ''),
    );
    return cls.subjects.any((s) => s.subjectId == subjectId);
  }

  bool isSubSubjectEnrolled(
    String classId,
    String subjectId,
    String subSubjectId,
  ) {
    final cls = classes.firstWhere(
      (c) => c.id == classId,
      orElse: () => ClassModel(id: '', name: '', gradeLevel: ''),
    );
    final subj = cls.subjects.firstWhere(
      (s) => s.subjectId == subjectId,
      orElse: () =>
          EnrolledSubject(subjectId: '', subjectCode: '', subjectName: ''),
    );
    return subj.subSubjectIds.contains(subSubjectId);
  }

  bool isStudentEnrolled(String classId, String studentId) {
    final cls = classes.firstWhere(
      (c) => c.id == classId,
      orElse: () => ClassModel(id: '', name: '', gradeLevel: ''),
    );
    return cls.students.any((s) => s.studentId == studentId);
  }

  int getEnrolledSubSubjectsCount(String classId, String subjectId) {
    final cls = classes.firstWhere(
      (c) => c.id == classId,
      orElse: () => ClassModel(id: '', name: '', gradeLevel: ''),
    );
    final subj = cls.subjects.firstWhere(
      (s) => s.subjectId == subjectId,
      orElse: () =>
          EnrolledSubject(subjectId: '', subjectCode: '', subjectName: ''),
    );
    return subj.subSubjectIds.length;
  }

  List<ClassModel> getStudentEnrolledClasses(String studentId) {
    return classes
        .where((cls) => cls.students.any((s) => s.studentId == studentId))
        .toList();
  }

  ClassModel? get selectedClass => classes.firstWhere(
    (c) => c.id == selectedClassForRegistration,
    orElse: () => ClassModel(id: '', name: '', gradeLevel: ''),
  );

  Widget _buildSubjectsSection() {
    return Card(
      child: Column(
        children: [
          // Subjects header (modern)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withOpacity(0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.book, color: Colors.blue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mata Pelajaran',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  backgroundColor: Colors.blue.shade50,
                  label: Text('${subjects.length}'),
                ),
                // always show subjects section
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;
                final leftColumn = Column(
                  children: [
                    // Add Subject
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Tambah Mata Pelajaran',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _newSubjectCtrl,
                              decoration: InputDecoration(
                                hintText: 'Nama mata pelajaran',
                                isDense: true,
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).inputDecorationTheme.fillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Kode otomatis: ${getNextSubjectCode()}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: handleAddSubject,
                                child: const Text('Tambah Mata Pelajaran'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    // Add SubSubject
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Tambah Sub Mata Pelajaran',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: selectedSubjectId,
                              decoration: InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).inputDecorationTheme.fillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              hint: const Text('-- Pilih Mata Pelajaran --'),
                              items: subjects
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text('${s.code}. ${s.name}'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => selectedSubjectId = v),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _newSubSubjectCtrl,
                              decoration: InputDecoration(
                                hintText: 'Nama sub mata pelajaran',
                                isDense: true,
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).inputDecorationTheme.fillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              enabled: selectedSubjectId != null,
                            ),
                            const SizedBox(height: 8),
                            if (selectedSubjectId != null)
                              Text(
                                'Kode otomatis: ${getNextSubSubjectCode(subjects.firstWhere((s) => s.id == selectedSubjectId))}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: selectedSubjectId != null
                                    ? handleAddSubSubject
                                    : null,
                                child: const Text('Tambah Sub Mata Pelajaran'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );

                final rightList = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Daftar Mata Pelajaran',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 340),
                          child: subjects.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.menu_book_outlined,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 8),
                                      Text('Belum ada mata pelajaran'),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: subjects.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final s = subjects[index];
                                    return Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.blue.shade50,
                                          child: Text(
                                            s.code,
                                            style: const TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          s.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: s.subSubjects.isNotEmpty
                                            ? Text(
                                                '${s.subSubjects.length} sub-mata pelajaran',
                                              )
                                            : null,
                                        trailing: IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              handleDeleteSubject(s.id),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 1, child: leftColumn),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: rightList),
                    ],
                  );
                }

                // Narrow layout: stack vertically
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [leftColumn, const SizedBox(height: 12), rightList],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassesSection() {
    return Card(
      child: Column(
        children: [
          // Classes header (modern)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.purple.shade50.withOpacity(0.12),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.class_, color: Colors.purple),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Kelas & Pendaftaran',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  backgroundColor: Colors.purple.shade50,
                  label: Text('${classes.length}'),
                ),
                // always show classes section
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;

                final leftColumn = Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Tambah Kelas',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: newGradeLevel,
                              decoration: InputDecoration(
                                isDense: true,
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).inputDecorationTheme.fillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'X',
                                  child: Text('Tingkat X'),
                                ),
                                DropdownMenuItem(
                                  value: 'XI',
                                  child: Text('Tingkat XI'),
                                ),
                                DropdownMenuItem(
                                  value: 'XII',
                                  child: Text('Tingkat XII'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => newGradeLevel = v!),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _newClassCtrl,
                              decoration: InputDecoration(
                                hintText: 'Contoh: X-A',
                                isDense: true,
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).inputDecorationTheme.fillColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: handleAddClass,
                                child: const Text('Tambah Kelas'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Daftar Kelas',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 340),
                              child: classes.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            Icons.class_,
                                            size: 40,
                                            color: Colors.grey,
                                          ),
                                          SizedBox(height: 8),
                                          Text('Belum ada kelas'),
                                        ],
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: classes.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 8),
                                      itemBuilder: (context, index) {
                                        final cls = classes[index];
                                        final selected =
                                            selectedClassForRegistration ==
                                            cls.id;
                                        return GestureDetector(
                                          onTap: () => setState(
                                            () => selectedClassForRegistration =
                                                cls.id,
                                          ),
                                          child: Card(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            color: selected
                                                ? Colors.purple.shade50
                                                : null,
                                            child: ListTile(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              title: Text(
                                                cls.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              subtitle: Text(
                                                '${cls.subjects.length} mapel • ${cls.students.length} siswa',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Chip(
                                                    label: Text(cls.gradeLevel),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                    ),
                                                    onPressed: () =>
                                                        handleDeleteClass(
                                                          cls.id,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );

                final rightPanel = Card(
                  child: Column(
                    children: [
                      // Tabs
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: activeTab == 'subjects'
                                    ? Colors.white
                                    : Colors.grey.shade100,
                              ),
                              onPressed: () =>
                                  setState(() => activeTab = 'subjects'),
                              child: const Text('Daftarkan Mata Pelajaran'),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: activeTab == 'students'
                                    ? Colors.white
                                    : Colors.grey.shade100,
                              ),
                              onPressed: () =>
                                  setState(() => activeTab = 'students'),
                              child: const Text('Daftarkan Siswa'),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 1),
                      if (selectedClassForRegistration == null)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: const [
                              Icon(
                                Icons.info_outline,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Pilih kelas di sebelah kiri untuk mendaftarkan mata pelajaran dan siswa',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      if (selectedClassForRegistration != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: activeTab == 'subjects'
                              ? _buildClassSubjectsTab()
                              : _buildClassStudentsTab(),
                        ),
                    ],
                  ),
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 1, child: leftColumn),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: rightPanel),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    leftColumn,
                    const SizedBox(height: 12),
                    rightPanel,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassSubjectsTab() {
    final cls = classes.firstWhere((c) => c.id == selectedClassForRegistration);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mata Pelajaran untuk ${cls.name}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: ListView.builder(
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                final subject = subjects[index];
                final enrolled = isSubjectEnrolled(cls.id, subject.id);
                final enrolledSubCount = getEnrolledSubSubjectsCount(
                  cls.id,
                  subject.id,
                );
                return Column(
                  children: [
                    CheckboxListTile(
                      value: enrolled,
                      onChanged: (_) => handleToggleSubject(cls.id, subject.id),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${subject.code}. ${subject.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (enrolled && subject.subSubjects.isNotEmpty)
                            Text(
                              '($enrolledSubCount/${subject.subSubjects.length} sub)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                        ],
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      secondary: enrolled
                          ? const Icon(Icons.check_circle, color: Colors.blue)
                          : const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.grey,
                            ),
                    ),
                    if (enrolled && subject.subSubjects.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 56,
                          right: 12,
                          bottom: 6,
                        ),
                        child: Column(
                          children: subject.subSubjects
                              .map(
                                (sub) => Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: isSubSubjectEnrolled(
                                            cls.id,
                                            subject.id,
                                            sub.id,
                                          ),
                                          onChanged: (_) =>
                                              handleToggleSubSubject(
                                                cls.id,
                                                subject.id,
                                                sub.id,
                                              ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            '${sub.code} ${sub.name}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    isSubSubjectEnrolled(
                                          cls.id,
                                          subject.id,
                                          sub.id,
                                        )
                                        ? const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                          )
                                        : const SizedBox.shrink(),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Mata pelajaran terdaftar: ${cls.subjects.length} dari ${subjects.length}',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildClassStudentsTab() {
    final cls = classes.firstWhere((c) => c.id == selectedClassForRegistration);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Siswa untuk ${cls.name}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: ListView.builder(
              itemCount: mockStudents.length,
              itemBuilder: (context, index) {
                final student = mockStudents[index];
                final enrolled = isStudentEnrolled(cls.id, student['id']!);
                final enrolledClasses = getStudentEnrolledClasses(
                  student['id']!,
                );
                final otherEnrolled = enrolledClasses
                    .where((c) => c.id != cls.id)
                    .toList();
                return CheckboxListTile(
                  value: enrolled,
                  onChanged: (_) => handleToggleStudent(cls.id, student['id']!),
                  title: Row(
                    children: [
                      Text(student['nis']!),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          student['name']!,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (otherEnrolled.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          children: otherEnrolled
                              .map(
                                (c) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    c.name,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  secondary: enrolled
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Terdaftar: ${cls.students.length} dari ${mockStudents.length}',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}
