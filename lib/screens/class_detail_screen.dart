import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../providers/students_provider.dart';
import '../services/excel_export_service.dart';
import '../services/student_photo_service.dart';
import '../services/turkish_search_helper.dart';
import '../theme/app_theme.dart';
import 'dialogs/bulk_photo_import_dialog.dart';
import 'dialogs/bulk_student_import_dialog.dart';
import 'plans_screen.dart';
import 'student_profile_screen.dart';

class ClassDetailScreen extends StatefulWidget {
  final ClassModel classModel;

  const ClassDetailScreen({Key? key, required this.classModel}) : super(key: key);

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  String _searchQuery = '';
  final Set<int> _pickedStudentIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StudentsProvider>().fetchStudents(widget.classModel.id);
    });
  }

  void _openStudentProfile(BuildContext context, StudentModel student) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentProfileScreen(
          student: student,
          targetClass: widget.classModel,
        ),
      ),
    );
    if (mounted) {
      context.read<StudentsProvider>().fetchStudents(widget.classModel.id);
    }
  }

  void _showAddStudentSheet(BuildContext context, {StudentModel? editStudent}) async {
    final studentsProv = context.read<StudentsProvider>();
    final clubs = await studentsProv.getAvailableClubs();
    if (editStudent?.club != null &&
        editStudent!.club!.trim().isNotEmpty &&
        !clubs.contains(editStudent.club!.trim())) {
      clubs.add(editStudent.club!.trim());
    }
    if (!mounted) return;

    final noCtrl = TextEditingController(text: editStudent?.studentNo ?? '');
    final firstCtrl = TextEditingController(text: editStudent?.firstName ?? '');
    final lastCtrl = TextEditingController(text: editStudent?.lastName ?? '');
    final guardianCtrl = TextEditingController(text: editStudent?.guardianName ?? '');
    final phoneCtrl = TextEditingController(text: editStudent?.guardianPhone ?? '');
    final healthCtrl = TextEditingController(text: editStudent?.healthNote ?? '');
    final clubCtrl = TextEditingController(text: editStudent?.club ?? '');
    final bloodTypeCtrl = TextEditingController(text: editStudent?.bloodType ?? '');
    final addressCtrl = TextEditingController(text: editStudent?.address ?? '');
    final specialNotesCtrl = TextEditingController(text: editStudent?.specialNotes ?? '');
    String gender = editStudent?.gender ?? 'M';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 24,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          editStudent == null ? 'Yeni Öğrenci Ekle' : 'Öğrenciyi Düzenle',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (editStudent != null) ...[
                      Center(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(36),
                          onTap: () {
                            _openStudentPhotoActions(context, editStudent);
                          },
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              GestureAvatar(student: editStudent, radius: 32),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppTheme.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: noCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Öğrenci No *', hintText: '101'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: SegmentedButton<String>(
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                                if (states.contains(MaterialState.selected)) {
                                  return gender == 'F' ? const Color(0xFFD81B60) : const Color(0xFF1976D2);
                                }
                                return isDark ? AppTheme.bgDark : AppTheme.bgLight;
                              }),
                              foregroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                                if (states.contains(MaterialState.selected)) {
                                  return Colors.white;
                                }
                                return isDark ? AppTheme.inkDark : AppTheme.inkLight;
                              }),
                            ),
                            segments: const [
                              ButtonSegment(
                                value: 'M',
                                icon: Icon(Icons.male_rounded, size: 16),
                                label: Text('Erkek', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              ButtonSegment(
                                value: 'F',
                                icon: Icon(Icons.female_rounded, size: 16),
                                label: Text('Kız', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                            selected: {gender},
                            onSelectionChanged: (val) => setSheetState(() => gender = val.first),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: firstCtrl,
                            decoration: const InputDecoration(labelText: 'Adı *', hintText: 'Ali'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: lastCtrl,
                            decoration: const InputDecoration(labelText: 'Soyadı *', hintText: 'Yılmaz'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: guardianCtrl,
                            decoration: const InputDecoration(labelText: 'Veli Adı', hintText: 'Mehmet Yılmaz'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(labelText: 'Veli Telefonu', hintText: '0555...'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Autocomplete<String>(
                            initialValue: TextEditingValue(text: clubCtrl.text),
                            optionsBuilder: (textVal) {
                              if (textVal.text.trim().isEmpty) return clubs;
                              return clubs.where((c) =>
                                  TurkishSearchHelper.contains(c, textVal.text.trim()) ||
                                  c.toLowerCase().contains(textVal.text.trim().toLowerCase()));
                            },
                            onSelected: (val) => clubCtrl.text = val,
                            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                              textEditingController.addListener(() => clubCtrl.text = textEditingController.text);
                              return TextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Sosyal Kulübü',
                                  hintText: 'Örn: Kızılay Kulübü',
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: bloodTypeCtrl,
                            decoration: const InputDecoration(labelText: 'Kan Grubu', hintText: 'Örn: A Rh+'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: healthCtrl,
                      decoration: const InputDecoration(labelText: 'Sağlık / Alerji Bilgisi', hintText: 'Alerji, kronik durum vb.'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(labelText: 'Adres', hintText: 'İkametgah adresi...'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: specialNotesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Rehberlik / Özel Notlar', hintText: 'Özel yetenek, destek durumu vb.'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        if (noCtrl.text.trim().isEmpty || firstCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Numara ve Ad alanları zorunludur.')),
                          );
                          return;
                        }

                        final prov = context.read<StudentsProvider>();
                        if (editStudent == null) {
                          await prov.createStudent(
                            classId: widget.classModel.id,
                            studentNo: noCtrl.text.trim(),
                            firstName: firstCtrl.text.trim(),
                            lastName: lastCtrl.text.trim(),
                            gender: gender,
                            guardianName: guardianCtrl.text.trim(),
                            guardianPhone: phoneCtrl.text.trim(),
                            healthNote: healthCtrl.text.trim(),
                            club: clubCtrl.text.trim(),
                            bloodType: bloodTypeCtrl.text.trim(),
                            address: addressCtrl.text.trim(),
                            specialNotes: specialNotesCtrl.text.trim(),
                          );
                        } else {
                          await prov.updateStudent(
                            id: editStudent.id,
                            classId: widget.classModel.id,
                            studentNo: noCtrl.text.trim(),
                            firstName: firstCtrl.text.trim(),
                            lastName: lastCtrl.text.trim(),
                            gender: gender,
                            guardianName: guardianCtrl.text.trim(),
                            guardianPhone: phoneCtrl.text.trim(),
                            healthNote: healthCtrl.text.trim(),
                            club: clubCtrl.text.trim(),
                            bloodType: bloodTypeCtrl.text.trim(),
                            address: addressCtrl.text.trim(),
                            specialNotes: specialNotesCtrl.text.trim(),
                          );
                        }

                        if (mounted) Navigator.pop(ctx);
                      },
                      child: Text(editStudent == null ? 'Öğrenciyi Kaydet' : 'Bilgileri Güncelle'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 📷 Öğrenci Fotoğrafı Ekle / Değiştir / Kaldır Seçenekleri
  void _openStudentPhotoActions(BuildContext context, StudentModel student) {
    final hasExistingPhoto = student.photoPath != null &&
        student.photoPath!.isNotEmpty &&
        File(student.photoPath!).existsSync();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final messenger = ScaffoldMessenger.of(context);
        final studentsProv = context.read<StudentsProvider>();

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    GestureAvatar(student: student, radius: 26),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Okul No: #${student.studentNo} • ${student.gender == "F" ? "Kız" : "Erkek"}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.accent),
                  title: const Text('Kamera ile Çek', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Anında fotoğraf çek, optimize edilip minimum boyutta kaydedilir', style: TextStyle(fontSize: 11)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final newPath = await StudentPhotoService.pickAndSaveStudentPhoto(
                      source: ImageSource.camera,
                      classId: widget.classModel.id,
                      studentId: student.id,
                    );
                    if (newPath != null) {
                      await studentsProv.updatePhoto(student.id, widget.classModel.id, newPath);
                      messenger.showSnackBar(
                        SnackBar(
                          backgroundColor: AppTheme.posLight,
                          content: Text('${student.firstName} için fotoğraf kaydedildi.'),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Colors.blue),
                  title: const Text('Galeriden Seç', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Cihaz galerisinden görsel seç ve otomatik küçült', style: TextStyle(fontSize: 11)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final newPath = await StudentPhotoService.pickAndSaveStudentPhoto(
                      source: ImageSource.gallery,
                      classId: widget.classModel.id,
                      studentId: student.id,
                    );
                    if (newPath != null) {
                      await studentsProv.updatePhoto(student.id, widget.classModel.id, newPath);
                      messenger.showSnackBar(
                        SnackBar(
                          backgroundColor: AppTheme.posLight,
                          content: Text('${student.firstName} için fotoğraf kaydedildi.'),
                        ),
                      );
                    }
                  },
                ),
                if (hasExistingPhoto)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.negLight),
                    title: const Text('Fotoğrafı Kaldır', style: TextStyle(color: AppTheme.negLight, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Mevcut fotoğrafı sil ve varsayılan simgeye dön', style: TextStyle(fontSize: 11)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await studentsProv.removePhoto(student.id, widget.classModel.id);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('${student.firstName} öğrencisinin fotoğrafı silindi.'),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 🎲 "Kim Kalksın?" Rastgele Öğrenci Seçici (Daha önce gösterilenler tekrarlanmaz)
  void _openRandomPicker(BuildContext context, List<StudentModel> studentList) {
    if (studentList.isEmpty) return;

    // Henüz seçilmemiş öğrencileri belirle
    var availableStudents = studentList.where((s) => !_pickedStudentIds.contains(s.id)).toList();
    bool cycleReset = false;

    // Eğer sınıftaki tüm öğrenciler gösterilmişse listeyi sıfırla ve yeni tur başlat
    if (availableStudents.isEmpty) {
      _pickedStudentIds.clear();
      availableStudents = List.from(studentList);
      cycleReset = true;
    }

    // Bu tur için kesin olarak seçilen öğrenci
    final selectedStudent = (availableStudents..shuffle()).first;
    _pickedStudentIds.add(selectedStudent.id);

    showDialog(
      context: context,
      builder: (ctx) {
        StudentModel currentDisplay = studentList.first;
        bool isSpinning = true;
        int step = 0;
        Timer? timer;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            if (timer == null && isSpinning) {
              timer = Timer.periodic(const Duration(milliseconds: 70), (t) {
                step++;
                setDialogState(() {
                  // Döngü sırasında rastgele efekt göster
                  currentDisplay = (studentList..shuffle()).first;
                });
                if (step >= 16) {
                  t.cancel();
                  setDialogState(() {
                    // Nihai seçilen öğrenciyi göster
                    currentDisplay = selectedStudent;
                    isSpinning = false;
                  });
                }
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🎲 Kim Kalksın?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_pickedStudentIds.length} / ${studentList.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureAvatar(student: currentDisplay, radius: 36),
                  const SizedBox(height: 12),
                  Text(
                    '#${currentDisplay.studentNo}',
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    currentDisplay.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isSpinning ? 'Öğrenci seçiliyor...' : 'Sıradaki öğrenci tahtaya hazır! 🎯',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSpinning ? Colors.orange : AppTheme.posLight,
                    ),
                  ),
                  if (!isSpinning) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.negLight),
                            onPressed: () {
                              context.read<StudentsProvider>().giveEvaluation(
                                    studentId: currentDisplay.id,
                                    classId: widget.classModel.id,
                                    value: -1,
                                    note: 'Tahta performansı',
                                  );
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${currentDisplay.firstName} öğrencisine -1 verildi.')),
                              );
                            },
                            child: const Text('👎 -1 Eksi'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.posLight),
                            onPressed: () {
                              context.read<StudentsProvider>().giveEvaluation(
                                    studentId: currentDisplay.id,
                                    classId: widget.classModel.id,
                                    value: 1,
                                    note: 'Tahta performansı',
                                  );
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppTheme.posLight,
                                  content: Text('${currentDisplay.firstName} öğrencisine +1 verildi.'),
                                ),
                              );
                            },
                            child: const Text('👍 +1 Artı'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    timer?.cancel();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Kapat'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Öğrenci Zaman Çizelgesi & Notlar BottomSheet
  Future<void> _openStudentTimeline(BuildContext context, StudentModel student) async {
    final prov = context.read<StudentsProvider>();
    final noteCtrl = TextEditingController();
    String noteType = 'observation';

    String getNoteLabel(String type) {
      switch (type) {
        case 'observation':
          return '👁️ Ders İçi Gözlem';
        case 'parent':
        case 'guardian':
          return '👨‍👩‍👦 Veli Görüşmesi';
        case 'behavior':
          return '⭐ Davranış / Gelişim';
        case 'academic':
          return '📚 Akademik Takip';
        default:
          return 'Not';
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.8,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        GestureAvatar(student: student, radius: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                              Text('#${student.studentNo} • Toplam Puan: ${student.totalScore > 0 ? "+${student.totalScore}" : student.totalScore}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: student.totalScore > 0 ? AppTheme.posLight : (student.totalScore < 0 ? AppTheme.negLight : null),
                                    fontWeight: FontWeight.bold,
                                  )),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Yeni Not Ekleme Alanı
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: noteType,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 'observation', child: Text('👁️ Ders İçi Gözlem')),
                                DropdownMenuItem(value: 'parent', child: Text('👨‍👩‍👦 Veli Görüşmesi')),
                                DropdownMenuItem(value: 'behavior', child: Text('⭐ Davranış / Gelişim')),
                                DropdownMenuItem(value: 'academic', child: Text('📚 Akademik Takip')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setSheetState(() => noteType = v);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: noteCtrl,
                            decoration: InputDecoration(
                              hintText: '${getNoteLabel(noteType)} içeriğini yazın...',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(38)),
                          onPressed: () async {
                            if (noteCtrl.text.trim().isEmpty) return;
                            await prov.addStudentNote(
                              studentId: student.id,
                              type: noteType,
                              body: noteCtrl.text.trim(),
                            );
                            noteCtrl.clear();
                            setSheetState(() {});
                          },
                          child: const Text('Notu Kaydet', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Geçmiş Notlar & Gözlemler', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(height: 6),
                  Expanded(
                    child: FutureBuilder<List<StudentNoteModel>>(
                      future: prov.fetchStudentNotes(student.id),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final notes = snapshot.data!;
                        if (notes.isEmpty) {
                          return const Center(child: Text('Henüz kaydedilmiş bir not bulunmuyor.', style: TextStyle(fontSize: 12)));
                        }
                        return ListView.separated(
                          itemCount: notes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final n = notes[i];
                            return Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.brandLight.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            getNoteLabel(n.type),
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 16),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () async {
                                            await prov.deleteStudentNote(n.id);
                                            setSheetState(() {});
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(n.body, style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    final studentsProv = context.watch<StudentsProvider>();
    final appProv = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredStudents = studentsProv.students.where((s) {
      if (_searchQuery.isNotEmpty) {
        final q = TurkishSearchHelper.toLower(_searchQuery.trim());
        final isFemaleSearch = q == 'kız' || q == 'kiz';
        final isMaleSearch = q == 'erkek';

        if (isFemaleSearch) {
          return s.gender == 'F' || TurkishSearchHelper.contains(s.fullName, q);
        } else if (isMaleSearch) {
          return s.gender == 'M' || TurkishSearchHelper.contains(s.fullName, q);
        } else {
          return TurkishSearchHelper.contains(s.fullName, q) || s.studentNo.contains(q);
        }
      }
      return true;
    }).toList();

    final totalCount = studentsProv.students.length;
    final femaleCount = studentsProv.students.where((s) => s.gender == 'F').length;
    final maleCount = studentsProv.students.where((s) => s.gender == 'M').length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.classModel.name,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${widget.classModel.subject ?? "Ders"} • ${appProv.activeAcademicYear}',
              style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // 🎲 Kim Kalksın? (Hızlı Buton)
          IconButton(
            icon: const Text('🎲', style: TextStyle(fontSize: 18)),
            tooltip: 'Kim Kalksın? (Rastgele Seçici)',
            onPressed: () => _openRandomPicker(context, studentsProv.students),
          ),
          // 👤+ Yeni Öğrenci Ekle
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Öğrenci Ekle',
            onPressed: () => _showAddStudentSheet(context),
          ),
          // ⋮ Sınıf Araçları & Toplu İşlemler Menüsü
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Sınıf İşlemleri & Araçlar',
            constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
            onSelected: (val) async {
              if (val == 'score_report') {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 12),
                          Text('Puan raporu Excel olarak hazırlanıyor...'),
                        ],
                      ),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  await ExcelExportService.exportClassEvaluationsToExcel(widget.classModel);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: $e'), backgroundColor: AppTheme.negLight),
                    );
                  }
                }
              } else if (val == 'random') {
                _openRandomPicker(context, studentsProv.students);
              } else if (val == 'bulk_photo') {
                showDialog(
                  context: context,
                  builder: (_) => BulkPhotoImportDialog(targetClass: widget.classModel),
                ).then((_) {
                  studentsProv.fetchStudents(widget.classModel.id);
                });
              } else if (val == 'bulk_student') {
                showDialog(
                  context: context,
                  builder: (_) => BulkStudentImportDialog(targetClass: widget.classModel),
                ).then((_) {
                  studentsProv.fetchStudents(widget.classModel.id);
                });
              } else if (val == 'plans') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlansScreen(initialClassId: widget.classModel.id),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'score_report',
                child: Row(
                  children: [
                    Icon(Icons.assessment_outlined, size: 20, color: Colors.amber),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Puan Raporlama (Excel)', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'random',
                child: Row(
                  children: [
                    Text('🎲', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Kim Kalksın? (Rastgele)', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'bulk_student',
                child: Row(
                  children: [
                    Text('📊', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Toplu Öğrenci Aktar (Excel)', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'bulk_photo',
                child: Row(
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 20, color: AppTheme.accent),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Toplu Fotoğraf Yükle (ZIP)', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'plans',
                child: Row(
                  children: [
                    Icon(Icons.menu_book_rounded, size: 20, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Yıllık Plan & Kazanımlar', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // İstatistik Rozetleri (Toplam / Kız / Erkek)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
                    ),
                    child: Column(
                      children: [
                        const Text('Toplam', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        Text('$totalCount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
                    ),
                    child: Column(
                      children: [
                        const Text('Kız', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.pink)),
                        Text('$femaleCount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.pink)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
                    ),
                    child: Column(
                      children: [
                        const Text('Erkek', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                        Text('$maleCount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.blue)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Arama Kutusu (Tüm Satırı Kaplar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              height: 44,
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  hintText: 'İsim, numara veya "kız" / "erkek" ile ara...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ),
          ),

          // Öğrenci Kartları Listesi
          Expanded(
            child: studentsProv.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredStudents.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isNotEmpty ? 'Aramanıza uygun öğrenci bulunamadı.' : 'Bu sınıfta kayıtlı öğrenci yok.',
                          style: TextStyle(color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, i) {
                          final st = filteredStudents[i];
                          final isPos = st.totalScore > 0;
                          final isNeg = st.totalScore < 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      GestureAvatar(
                                        student: st,
                                        onTap: () => _openStudentPhotoActions(context, st),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _openStudentProfile(context, st),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    '#${st.studentNo}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontFamily: 'monospace',
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      st.fullName,
                                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                st.club != null && st.club!.isNotEmpty
                                                    ? 'Kulüp: ${st.club}'
                                                    : (st.guardianName != null && st.guardianName!.isNotEmpty
                                                        ? 'Veli: ${st.guardianName}'
                                                        : (st.gender == 'F' ? 'Kız Öğrenci' : 'Erkek Öğrenci')),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Toplam Puan Rozeti (Tıklanınca akış açılır)
                                      InkWell(
                                        onTap: () => _openStudentTimeline(context, st),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isPos
                                                ? AppTheme.posLight.withOpacity(0.15)
                                                : (isNeg ? AppTheme.negLight.withOpacity(0.15) : (isDark ? AppTheme.bgDark : AppTheme.bgLight)),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isPos
                                                  ? AppTheme.posLight.withOpacity(0.3)
                                                  : (isNeg ? AppTheme.negLight.withOpacity(0.3) : (isDark ? AppTheme.lineDark : AppTheme.lineLight)),
                                            ),
                                          ),
                                          child: Text(
                                            st.totalScore > 0 ? '+${st.totalScore}' : '${st.totalScore}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                              color: isPos
                                                  ? (isDark ? AppTheme.posDark : AppTheme.posLight)
                                                  : (isNeg ? (isDark ? AppTheme.negDark : AppTheme.negLight) : null),
                                            ),
                                          ),
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert, size: 18),
                                        constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
                                        onSelected: (val) {
                                          if (val == 'profile') {
                                            _openStudentProfile(context, st);
                                          } else if (val == 'photo') {
                                            _openStudentPhotoActions(context, st);
                                          } else if (val == 'timeline') {
                                            _openStudentTimeline(context, st).then((_) { if (mounted) studentsProv.fetchStudents(widget.classModel.id); });
                                          } else if (val == 'edit') {
                                            _showAddStudentSheet(context, editStudent: st);
                                          } else if (val == 'delete') {
                                            studentsProv.deleteStudent(st.id, widget.classModel.id);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'profile',
                                            child: Row(
                                              children: [
                                                Icon(Icons.badge_rounded, size: 18, color: AppTheme.accent),
                                                SizedBox(width: 10),
                                                Expanded(
                                                  child: Text('Öğrenci Profili & Notlar', overflow: TextOverflow.ellipsis),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'photo',
                                            child: Row(
                                              children: [
                                                Icon(Icons.camera_alt_outlined, size: 18),
                                                SizedBox(width: 10),
                                                Expanded(
                                                  child: Text('Fotoğraf Ekle / Değiştir', overflow: TextOverflow.ellipsis),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'timeline',
                                            child: Row(
                                              children: [
                                                Icon(Icons.timeline_rounded, size: 18),
                                                SizedBox(width: 10),
                                                Expanded(
                                                  child: Text('Hızlı Not Ekle', overflow: TextOverflow.ellipsis),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit_outlined, size: 18),
                                                SizedBox(width: 10),
                                                Expanded(
                                                  child: Text('Düzenle', overflow: TextOverflow.ellipsis),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete_outline, size: 18, color: AppTheme.negLight),
                                                SizedBox(width: 10),
                                                Expanded(
                                                  child: Text('Sil', style: TextStyle(color: AppTheme.negLight), overflow: TextOverflow.ellipsis),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // Hızlı Artı / Eksi Butonları
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.negLight,
                                            side: BorderSide(color: AppTheme.negLight.withOpacity(0.3)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            minimumSize: const Size.fromHeight(36),
                                          ),
                                          onPressed: () {
                                            studentsProv.giveEvaluation(
                                              studentId: st.id,
                                              classId: widget.classModel.id,
                                              value: -1,
                                            );
                                          },
                                          child: const Text('-1', style: TextStyle(fontWeight: FontWeight.w900)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.note_alt_outlined, size: 20),
                                            tooltip: 'Özel Notlar & Akış',
                                            onPressed: () async {
                                              await _openStudentTimeline(context, st);
                                              if (mounted) {
                                                context.read<StudentsProvider>().fetchStudents(widget.classModel.id);
                                              }
                                            },
                                          ),
                                          if (st.noteCount > 0)
                                            Positioned(
                                              right: 4,
                                              top: 4,
                                              child: Container(
                                                padding: const EdgeInsets.all(2),
                                                decoration: BoxDecoration(
                                                  color: Colors.purple.shade600,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                                                    width: 1.5,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.purple.withOpacity(0.35),
                                                      blurRadius: 3,
                                                      offset: const Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                                constraints: const BoxConstraints(
                                                  minWidth: 18,
                                                  minHeight: 18,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '${st.noteCount}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w900,
                                                      height: 1,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.posLight,
                                            side: BorderSide(color: AppTheme.posLight.withOpacity(0.3)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            minimumSize: const Size.fromHeight(36),
                                          ),
                                          onPressed: () {
                                            studentsProv.giveEvaluation(
                                              studentId: st.id,
                                              classId: widget.classModel.id,
                                              value: 1,
                                            );
                                          },
                                          child: const Text('+1', style: TextStyle(fontWeight: FontWeight.w900)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class GestureAvatar extends StatelessWidget {
  final StudentModel student;
  final double radius;
  final VoidCallback? onTap;

  const GestureAvatar({
    Key? key,
    required this.student,
    this.radius = 20,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isFemale = student.gender == 'F';
    final hasPhoto = student.photoPath != null &&
        student.photoPath!.isNotEmpty &&
        File(student.photoPath!).existsSync();

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: hasPhoto
          ? Colors.transparent
          : (isFemale ? Colors.pink.shade100 : Colors.blue.shade100),
      backgroundImage: hasPhoto ? FileImage(File(student.photoPath!)) : null,
      child: hasPhoto
          ? null
          : Text(
              student.firstName.isNotEmpty ? student.firstName[0] : '?',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isFemale ? Colors.pink.shade800 : Colors.blue.shade800,
                fontSize: radius * 0.8,
              ),
            ),
    );

    return GestureDetector(
      onTap: () {
        if (hasPhoto) {
          StudentPhotoService.showPhotoPreview(context, student);
        } else if (onTap != null) {
          onTap!();
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          if (onTap != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    hasPhoto ? Icons.zoom_in_rounded : Icons.camera_alt_rounded,
                    size: radius * 0.55,
                    color: AppTheme.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
