import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../providers/classes_provider.dart';
import '../providers/exams_provider.dart';
import '../providers/students_provider.dart';
import '../services/student_photo_service.dart';
import '../services/turkish_search_helper.dart';
import '../theme/app_theme.dart';

class StudentProfileScreen extends StatefulWidget {
  final StudentModel student;
  final ClassModel? targetClass;

  const StudentProfileScreen({
    Key? key,
    required this.student,
    this.targetClass,
  }) : super(key: key);

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> with SingleTickerProviderStateMixin {
  late StudentModel _currentStudent;
  late TabController _tabController;

  bool _isLoading = true;
  List<Map<String, dynamic>> _examDetails = [];
  List<EvaluationModel> _evaluations = [];
  List<StudentNoteModel> _notes = [];
  Map<String, int> _attendanceSummary = {
    'present': 0,
    'absent': 0,
    'late': 0,
    'excused': 0,
  };

  @override
  void initState() {
    super.initState();
    _currentStudent = widget.student;
    _tabController = TabController(length: 5, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final prov = context.read<StudentsProvider>();
    final sId = _currentStudent.id;
    final cId = _currentStudent.classId;

    try {
      final exams = await prov.fetchStudentExamDetails(sId, cId);
      final evals = await prov.fetchStudentEvaluations(sId);
      final notes = await prov.fetchStudentNotes(sId);
      final att = await prov.fetchStudentAttendanceSummary(sId);

      // Öğrenci güncel bilgilerini de tazele
      final allStudents = prov.students;
      final match = allStudents.firstWhere((s) => s.id == sId, orElse: () => _currentStudent);

      if (mounted) {
        setState(() {
          _currentStudent = match;
          _examDetails = exams;
          _evaluations = evals;
          _notes = notes;
          _attendanceSummary = att;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 📞 Veli Arama
  Future<void> _callGuardian() async {
    final phone = _currentStudent.guardianPhone?.replaceAll(RegExp(r'\s+'), '');
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veli telefon numarası kayıtlı değil.')),
      );
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Telefon araması başlatılamadı: $phone')),
      );
    }
  }

  // 💬 Mesaj Gönderme (SMS veya WhatsApp Seçeneği)
  Future<void> _messageGuardian() async {
    final rawPhone = _currentStudent.guardianPhone?.trim();
    if (rawPhone == null || rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veli telefon numarası kayıtlı değil.')),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanDigits = rawPhone.replaceAll(RegExp(r'\D'), '');

    // WhatsApp uluslararası telefon formatı (Türkiye varsayılan 90)
    String waPhone = cleanDigits;
    if (waPhone.startsWith('0')) {
      waPhone = '90${waPhone.substring(1)}';
    } else if (!waPhone.startsWith('90')) {
      waPhone = '90$waPhone';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.brandLight.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.message_rounded, color: AppTheme.brandLight, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Veliye Mesaj Gönder',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        Text(
                          '${_currentStudent.guardianName != null && _currentStudent.guardianName!.isNotEmpty ? "${_currentStudent.guardianName} • " : ""}$rawPhone',
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
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // WhatsApp Seçeneği
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  Navigator.pop(ctx);
                  final waUri = Uri.parse('https://wa.me/$waPhone');
                  try {
                    await launchUrl(waUri, mode: LaunchMode.externalApplication);
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('WhatsApp uygulaması başlatılamadı.')),
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF25D366).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF25D366),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chat_bubble, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WhatsApp ile Gönder',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E7E34)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'WhatsApp sohbet ekranına yönlendir',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF1E7E34)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // SMS Seçeneği
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  Navigator.pop(ctx);
                  final smsUri = Uri.parse('sms:$cleanDigits');
                  try {
                    await launchUrl(smsUri);
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('SMS uygulaması başlatılamadı.')),
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.sms_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Normal SMS ile Gönder',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.blue),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Telefonun SMS mesajlaşma uygulamasını aç',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.blue),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 📷 Fotoğraf Değiştir / Çek / Kaldır
  void _openPhotoOptions() {
    final hasPhoto = _currentStudent.photoPath != null &&
        _currentStudent.photoPath!.isNotEmpty &&
        File(_currentStudent.photoPath!).existsSync();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
              ),
              Text(
                '${_currentStudent.fullName} Fotoğrafı',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.accent),
                title: const Text('Kamera ile Çek', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Yeni fotoğraf çek ve optimize ederek kaydet', style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final path = await StudentPhotoService.pickAndSaveStudentPhoto(
                    source: ImageSource.camera,
                    classId: _currentStudent.classId,
                    studentId: _currentStudent.id,
                  );
                  if (path != null) {
                    if (!mounted) return;
                    await context.read<StudentsProvider>().updatePhoto(_currentStudent.id, _currentStudent.classId, path);
                    if (!mounted) return;
                    setState(() {
                      _currentStudent = _currentStudent.copyWith(photoPath: path);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(backgroundColor: AppTheme.posLight, content: Text('Fotoğraf güncellendi.')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Colors.blue),
                title: const Text('Galeriden Seç', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Cihaz galerisinden görsel seç ve boyutunu küçült', style: TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final path = await StudentPhotoService.pickAndSaveStudentPhoto(
                    source: ImageSource.gallery,
                    classId: _currentStudent.classId,
                    studentId: _currentStudent.id,
                  );
                  if (path != null) {
                    if (!mounted) return;
                    await context.read<StudentsProvider>().updatePhoto(_currentStudent.id, _currentStudent.classId, path);
                    if (!mounted) return;
                    setState(() {
                      _currentStudent = _currentStudent.copyWith(photoPath: path);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(backgroundColor: AppTheme.posLight, content: Text('Fotoğraf güncellendi.')),
                    );
                  }
                },
              ),
              if (hasPhoto)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.negLight),
                  title: const Text('Fotoğrafı Kaldır', style: TextStyle(color: AppTheme.negLight, fontWeight: FontWeight.w600)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (!mounted) return;
                    await context.read<StudentsProvider>().removePhoto(_currentStudent.id, _currentStudent.classId);
                    if (!mounted) return;
                    setState(() {
                      _currentStudent = _currentStudent.copyWith(photoPath: '');
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Öğrenci fotoğrafı silindi.')),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ✏️ Tüm Öğrenci Bilgilerini Düzenle
  void _openEditStudentSheet() async {
    final studentsProv = context.read<StudentsProvider>();
    final clubs = await studentsProv.getAvailableClubs();
    if (_currentStudent.club != null &&
        _currentStudent.club!.trim().isNotEmpty &&
        !clubs.contains(_currentStudent.club!.trim())) {
      clubs.add(_currentStudent.club!.trim());
    }
    if (!mounted) return;

    final noCtrl = TextEditingController(text: _currentStudent.studentNo);
    final firstCtrl = TextEditingController(text: _currentStudent.firstName);
    final lastCtrl = TextEditingController(text: _currentStudent.lastName);
    final guardianCtrl = TextEditingController(text: _currentStudent.guardianName ?? '');
    final phoneCtrl = TextEditingController(text: _currentStudent.guardianPhone ?? '');
    final healthCtrl = TextEditingController(text: _currentStudent.healthNote ?? '');
    final clubCtrl = TextEditingController(text: _currentStudent.club ?? '');
    final addressCtrl = TextEditingController(text: _currentStudent.address ?? '');
    final notesCtrl = TextEditingController(text: _currentStudent.specialNotes ?? '');

    String gender = _currentStudent.gender;
    String? bloodType = _currentStudent.bloodType;
    String? birthDate = _currentStudent.birthDate;

    final bloodTypes = ['A Rh+', 'A Rh-', 'B Rh+', 'B Rh-', '0 Rh+', '0 Rh-', 'AB Rh+', 'AB Rh-'];

    showModalBottomSheet(
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
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
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
                          const Text('Öğrenci Profilini Düzenle', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Okul No & Cinsiyet
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: noCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Öğrenci No *'),
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
                      // Ad & Soyad
                      Row(
                        children: [
                          Expanded(
                            child: TextField(controller: firstCtrl, decoration: const InputDecoration(labelText: 'Adı *')),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(controller: lastCtrl, decoration: const InputDecoration(labelText: 'Soyadı *')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Sosyal Kulüp
                      Autocomplete<String>(
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
                              labelText: 'Sosyal Kulüp',
                              hintText: 'Örn: Kızılay Kulübü',
                              prefixIcon: Icon(Icons.diversity_3_rounded, size: 20),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      // Kan Grubu & Doğum Tarihi
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: bloodType != null && bloodTypes.contains(bloodType) ? bloodType : null,
                              decoration: const InputDecoration(labelText: 'Kan Grubu'),
                              items: bloodTypes.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                              onChanged: (val) => setSheetState(() => bloodType = val),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.cake_outlined, size: 16),
                              label: Text(
                                birthDate != null ? DateFormat('dd.MM.yyyy').format(DateTime.parse(birthDate!)) : 'Doğum Tarihi',
                                style: const TextStyle(fontSize: 11),
                              ),
                              onPressed: () async {
                                final initial = birthDate != null ? DateTime.tryParse(birthDate!) ?? DateTime(2010) : DateTime(2010);
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: initial,
                                  firstDate: DateTime(1995),
                                  lastDate: DateTime.now(),
                                  locale: const Locale('tr', 'TR'),
                                );
                                if (picked != null) {
                                  setSheetState(() => birthDate = DateFormat('yyyy-MM-dd').format(picked));
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Veli Adı & Veli Telefonu
                      Row(
                        children: [
                          Expanded(
                            child: TextField(controller: guardianCtrl, decoration: const InputDecoration(labelText: 'Veli Adı Soyadı')),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(labelText: 'Veli Telefonu', hintText: '05...'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Ev Adresi
                      TextField(
                        controller: addressCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Ev / İkametgah Adresi', hintText: 'Mahalle, Cadde, No...'),
                      ),
                      const SizedBox(height: 12),
                      // Sağlık Notu
                      TextField(
                        controller: healthCtrl,
                        decoration: const InputDecoration(labelText: 'Sağlık / Alerji Durumu', hintText: 'Astım, gözlük, alerji vb.'),
                      ),
                      const SizedBox(height: 12),
                      // Özel Rehberlik Notu
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Özel / Rehberlik Notu', hintText: 'Öğrenciye dair özel gözlem...'),
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

                          await context.read<StudentsProvider>().updateStudent(
                                id: _currentStudent.id,
                                classId: _currentStudent.classId,
                                studentNo: noCtrl.text.trim(),
                                firstName: firstCtrl.text.trim(),
                                lastName: lastCtrl.text.trim(),
                                gender: gender,
                                birthDate: birthDate,
                                guardianName: guardianCtrl.text.trim(),
                                guardianPhone: phoneCtrl.text.trim(),
                                healthNote: healthCtrl.text.trim(),
                                club: clubCtrl.text.trim(),
                                bloodType: bloodType,
                                address: addressCtrl.text.trim(),
                                specialNotes: notesCtrl.text.trim(),
                              );

                          setState(() {
                            _currentStudent = _currentStudent.copyWith(
                              studentNo: noCtrl.text.trim(),
                              firstName: firstCtrl.text.trim(),
                              lastName: lastCtrl.text.trim(),
                              gender: gender,
                              birthDate: birthDate,
                              guardianName: guardianCtrl.text.trim(),
                              guardianPhone: phoneCtrl.text.trim(),
                              healthNote: healthCtrl.text.trim(),
                              club: clubCtrl.text.trim(),
                              bloodType: bloodType,
                              address: addressCtrl.text.trim(),
                              specialNotes: notesCtrl.text.trim(),
                            );
                          });

                          if (mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Bilgileri Kaydet'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 📝 Yeni Öğretmen Notu Ekle Modalı
  void _showAddNoteDialog() {
    final noteCtrl = TextEditingController();
    String noteType = 'observation';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Not & Gözlem Ekle', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: noteType,
                    decoration: const InputDecoration(labelText: 'Not Türü'),
                    items: const [
                      DropdownMenuItem(value: 'observation', child: Text('👁️ Ders İçi Gözlem')),
                      DropdownMenuItem(value: 'guardian', child: Text('👨‍👩‍👦 Veli Görüşmesi')),
                      DropdownMenuItem(value: 'behavior', child: Text('⭐ Davranış / Gelişim')),
                      DropdownMenuItem(value: 'academic', child: Text('📚 Akademik Takip')),
                    ],
                    onChanged: (val) => setDialogState(() => noteType = val ?? 'observation'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: '${_getNoteTypeName(noteType)} içeriğini buraya yazın...',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (noteCtrl.text.trim().isEmpty) return;
                      await context.read<StudentsProvider>().addStudentNote(
                            studentId: _currentStudent.id,
                            body: noteCtrl.text.trim(),
                            type: noteType,
                          );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadProfileData();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(backgroundColor: AppTheme.posLight, content: Text('Not kaydedildi.')),
                      );
                    },
                    child: const Text('Notu Kaydet'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 🗑️ Değerlendirme Puanı Silme Onayı (Uzun Basınca veya İkona Tıklayınca)
  Future<void> _confirmDeleteEvaluation(EvaluationModel ev) async {
    final isPos = ev.value > 0;
    final valStr = isPos ? '+${ev.value}' : '${ev.value}';
    final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.tryParse(ev.createdAt) ?? DateTime.now());

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Puan Kaydını Sil'),
        content: Text(
          '$valStr puan ($dateStr - ${ev.note ?? (isPos ? 'Artı Puan' : 'Eksi Puan')}) kaydını silmek istediğinize emin misiniz?\n\nÖğrencinin toplam puanı otomatik olarak güncellenecektir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.negLight),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<StudentsProvider>().deleteEvaluation(
            evaluationId: ev.id,
            studentId: _currentStudent.id,
            value: ev.value,
          );
      if (!mounted) return;
      setState(() {
        _currentStudent = _currentStudent.copyWith(totalScore: _currentStudent.totalScore - ev.value);
      });
      _loadProfileData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.posLight,
          content: Text('Değerlendirme puanı silindi.'),
        ),
      );
    }
  }

  // 🗑️ Öğretmen Notu Silme Onayı
  Future<void> _confirmDeleteNote(StudentNoteModel note) async {
    final dateStr = DateFormat('dd.MM.yyyy').format(DateTime.tryParse(note.createdAt) ?? DateTime.now());
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notu Sil'),
        content: Text(
          '${_getNoteTypeName(note.type)} ($dateStr) notunu silmek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.negLight),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<StudentsProvider>().deleteStudentNote(note.id);
      if (!mounted) return;
      _loadProfileData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.posLight,
          content: Text('Öğretmen notu silindi.'),
        ),
      );
    }
  }

  // Hızlı Değerlendirme (+1 / -1 verme)
  Future<void> _giveScore(int value, String note) async {
    await context.read<StudentsProvider>().giveEvaluation(
          studentId: _currentStudent.id,
          classId: _currentStudent.classId,
          value: value,
          note: note,
        );
    if (!mounted) return;
    setState(() {
      _currentStudent = _currentStudent.copyWith(totalScore: _currentStudent.totalScore + value);
    });
    _loadProfileData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: value > 0 ? AppTheme.posLight : AppTheme.negLight,
        content: Text('${_currentStudent.firstName} için $value puan kaydedildi ($note).'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classes = context.watch<ClassesProvider>().classes;
    final cls = widget.targetClass ?? classes.firstWhere((c) => c.id == _currentStudent.classId, orElse: () => ClassModel(
      id: _currentStudent.classId,
      name: _currentStudent.className ?? 'Sınıf',
      gradeLevel: '9',
      academicYear: SettingsModel.defaultAcademicYear,
      color: '#17433B',
      subject: _currentStudent.classSubject,
    ));

    final hasPhoto = _currentStudent.photoPath != null &&
        _currentStudent.photoPath!.isNotEmpty &&
        File(_currentStudent.photoPath!).existsSync();

    // Sınav notları dönem ortalaması hesapla
    final scoredExams = _examDetails.where((e) => e['score'] != null && (e['score'] as num) > 0).toList();
    final double examAverage = scoredExams.isNotEmpty
        ? scoredExams.map((e) => (e['score'] as num).toDouble()).reduce((a, b) => a + b) / scoredExams.length
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentStudent.fullName, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Profili Düzenle',
            onPressed: _openEditStudentSheet,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // -------------------------------------------------------------
                // 🌟 ÖĞRENCİ KARTI & HERO BAŞLIK BÖLÜMÜ
                // -------------------------------------------------------------
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                    border: Border(bottom: BorderSide(color: isDark ? AppTheme.lineDark : AppTheme.lineLight)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Fotoğraf & Kamera Badge
                          GestureDetector(
                            onTap: () {
                              if (hasPhoto) {
                                StudentPhotoService.showPhotoPreview(context, _currentStudent);
                              } else {
                                _openPhotoOptions();
                              }
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: hasPhoto
                                      ? Colors.transparent
                                      : (_currentStudent.gender == 'F' ? Colors.pink.shade100 : Colors.blue.shade100),
                                  backgroundImage: hasPhoto ? FileImage(File(_currentStudent.photoPath!)) : null,
                                  child: hasPhoto
                                      ? null
                                      : Text(
                                          _currentStudent.firstName.isNotEmpty ? _currentStudent.firstName[0] : '?',
                                          style: TextStyle(
                                            fontSize: 30,
                                            fontWeight: FontWeight.w900,
                                            color: _currentStudent.gender == 'F' ? Colors.pink.shade800 : Colors.blue.shade800,
                                          ),
                                        ),
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: GestureDetector(
                                    onTap: _openPhotoOptions,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accent,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Theme.of(context).cardColor, width: 2),
                                      ),
                                      child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Öğrenci Adı, No, Sınıf ve Kulüp
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '#${_currentStudent.studentNo}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _currentStudent.totalScore >= 0
                                            ? AppTheme.posLight.withOpacity(0.15)
                                            : AppTheme.negLight.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _currentStudent.totalScore >= 0 ? '+${_currentStudent.totalScore} Puan' : '${_currentStudent.totalScore} Puan',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                          color: _currentStudent.totalScore >= 0 ? AppTheme.posLight : AppTheme.negLight,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _currentStudent.fullName,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.brandLight.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${cls.name}${cls.subject != null ? " • ${cls.subject}" : ""}',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.accent : AppTheme.brandLight),
                                      ),
                                    ),
                                    if (_currentStudent.club != null && _currentStudent.club!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '🎭 ${_currentStudent.club}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Hızlı Aksiyon Butonları (Veli Ara, WhatsApp, +1, -1)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.phone_in_talk, size: 16, color: Colors.blue),
                              label: const Text('Veli Ara', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: _callGuardian,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.green),
                              label: const Text('Mesaj', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: _messageGuardian,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.remove, size: 16),
                            style: IconButton.styleFrom(backgroundColor: AppTheme.negLight.withOpacity(0.15), foregroundColor: AppTheme.negLight),
                            tooltip: '-1 Eksi Puan',
                            onPressed: () => _giveScore(-1, 'Derse katılım'),
                          ),
                          const SizedBox(width: 4),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.add, size: 16),
                            style: IconButton.styleFrom(backgroundColor: AppTheme.posLight.withOpacity(0.15), foregroundColor: AppTheme.posLight),
                            tooltip: '+1 Artı Puan',
                            onPressed: () => _giveScore(1, 'Derse katılım'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // -------------------------------------------------------------
                // 📑 SEKME BAŞLIKLARI (TABS)
                // -------------------------------------------------------------
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: isDark ? AppTheme.accent : AppTheme.brandLight,
                  unselectedLabelColor: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                  indicatorColor: isDark ? AppTheme.accent : AppTheme.brandLight,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(icon: Icon(Icons.person_outline, size: 18), text: 'Genel Bilgiler'),
                    Tab(icon: Icon(Icons.grading_rounded, size: 18), text: 'Notlar & Sınavlar'),
                    Tab(icon: Icon(Icons.thumb_up_alt_outlined, size: 18), text: 'Puan Geçmişi'),
                    Tab(icon: Icon(Icons.note_alt_outlined, size: 18), text: 'Öğretmen Notları'),
                    Tab(icon: Icon(Icons.calendar_month_outlined, size: 18), text: 'Devamsızlık'),
                  ],
                ),

                // -------------------------------------------------------------
                // 📋 SEKME İÇERİKLERİ
                // -------------------------------------------------------------
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: GENEL BİLGİLER
                      _buildGeneralInfoTab(cls, isDark),

                      // TAB 2: NOTLAR & SINAVLAR
                      _buildGradesTab(examAverage, isDark),

                      // TAB 3: PUAN GEÇMİŞİ (+/-)
                      _buildEvaluationsTab(isDark),

                      // TAB 4: ÖĞRETMEN NOTLARI
                      _buildNotesTab(isDark),

                      // TAB 5: DEVAMSIZLIK
                      _buildAttendanceTab(isDark),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // 1. GENEL BİLGİLER SEKMESİ
  Widget _buildGeneralInfoTab(ClassModel cls, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoSectionTitle('Kimlik & Okul Bilgileri'),
        _buildInfoCard(isDark, [
          _buildInfoRow(Icons.pin, 'Okul Numarası', '#${_currentStudent.studentNo}'),
          _buildInfoRow(Icons.school_outlined, 'Sınıf / Şube', cls.name),
          _buildInfoRow(Icons.diversity_3_outlined, 'Sosyal Kulübü', _currentStudent.club?.isNotEmpty == true ? _currentStudent.club! : 'Belirtilmedi'),
          _buildInfoRow(Icons.transgender, 'Cinsiyet', _currentStudent.gender == 'F' ? 'Kız Öğrenci' : 'Erkek Öğrenci'),
          _buildInfoRow(Icons.cake_outlined, 'Doğum Tarihi', _currentStudent.birthDate != null && _currentStudent.birthDate!.isNotEmpty
              ? DateFormat('dd.MM.yyyy').format(DateTime.parse(_currentStudent.birthDate!))
              : 'Belirtilmedi'),
        ]),
        const SizedBox(height: 16),

        _buildInfoSectionTitle('Sağlık & Özel Durum'),
        _buildInfoCard(isDark, [
          _buildInfoRow(Icons.bloodtype_outlined, 'Kan Grubu', _currentStudent.bloodType?.isNotEmpty == true ? _currentStudent.bloodType! : 'Belirtilmedi', iconColor: Colors.red),
          _buildInfoRow(Icons.medical_information_outlined, 'Sağlık / Alerji Durumu', _currentStudent.healthNote?.isNotEmpty == true ? _currentStudent.healthNote! : 'Özel durum belirtilmedi', iconColor: Colors.orange),
          _buildInfoRow(Icons.psychology_outlined, 'Özel Rehberlik Notu', _currentStudent.specialNotes?.isNotEmpty == true ? _currentStudent.specialNotes! : 'Not yok', iconColor: Colors.purple),
        ]),
        const SizedBox(height: 16),

        _buildInfoSectionTitle('Veli & İletişim Bilgileri'),
        _buildInfoCard(isDark, [
          _buildInfoRow(Icons.person_outline, 'Veli Adı Soyadı', _currentStudent.guardianName?.isNotEmpty == true ? _currentStudent.guardianName! : 'Kayıtlı değil'),
          _buildInfoRow(
            Icons.phone_outlined,
            'Veli Telefonu',
            _currentStudent.guardianPhone?.isNotEmpty == true ? _currentStudent.guardianPhone! : 'Kayıtlı değil',
            onTap: _currentStudent.guardianPhone?.isNotEmpty == true ? _callGuardian : null,
            trailing: _currentStudent.guardianPhone?.isNotEmpty == true
                ? IconButton(icon: const Icon(Icons.phone, size: 18, color: Colors.blue), onPressed: _callGuardian)
                : null,
          ),
          _buildInfoRow(Icons.home_outlined, 'Ev / İkametgah Adresi', _currentStudent.address?.isNotEmpty == true ? _currentStudent.address! : 'Adres bilgisi girilmedi'),
        ]),
        const SizedBox(height: 24),
      ],
    );
  }

  // 2. NOTLAR & SINAVLAR SEKMESİ
  Widget _buildGradesTab(double examAverage, bool isDark) {
    if (_examDetails.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.grading_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Bu sınıfa ait sınav kaydı bulunmuyor.', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Sınavlar sayfasından bu sınıfa değerlendirme ekleyebilirsiniz.',
                style: TextStyle(fontSize: 12, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Dönem Not Ortalaması Gösterge Kartı
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: examAverage >= 85
                  ? [const Color(0xFF1F8A5B), const Color(0xFF17433B)]
                  : (examAverage >= 70
                      ? [const Color(0xFF2563EB), const Color(0xFF1D4ED8)]
                      : [const Color(0xFFD97706), const Color(0xFFB45309)]),
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ders Not Ortalaması', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    examAverage > 0 ? examAverage.toStringAsFixed(1) : '-',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    examAverage >= 85
                        ? '🌟 Takdir Belgesi Seviyesi'
                        : (examAverage >= 70 ? '🎖️ Teşekkür Belgesi Seviyesi' : (examAverage >= 50 ? '✅ Başarılı' : '⚠️ Geliştirilmeli')),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 36),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoSectionTitle('Sınav & Değerlendirme Notları'),

        // Sınav Notları Listesi
        ..._examDetails.map((ex) {
          final score = (ex['score'] as num?)?.toDouble();
          final classAvg = (ex['class_average'] as num?)?.toDouble() ?? 0.0;
          final title = ex['title'] as String;
          final type = ex['type'] as String;
          final rawDate = ex['exam_date'] as String?;
          String formattedDate = '-';
          if (rawDate != null && rawDate.isNotEmpty) {
            final parsedDate = DateTime.tryParse(rawDate);
            formattedDate = parsedDate != null ? DateFormat('dd.MM.yyyy').format(parsedDate) : rawDate;
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
            ),
            child: InkWell(
              onTap: () => _showEditStudentScoreDialog(ex),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          _getExamIcon(type),
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(
                            'Tarih: $formattedDate • Sınıf Ortalaması: ${classAvg > 0 ? classAvg.toStringAsFixed(1) : "-"}',
                            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: score != null && score > 0
                            ? (score >= 50 ? AppTheme.posLight.withOpacity(0.15) : AppTheme.negLight.withOpacity(0.15))
                            : (isDark ? AppTheme.bgDark : AppTheme.bgLight),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: score != null && score > 0
                              ? (score >= 50 ? AppTheme.posLight.withOpacity(0.3) : AppTheme.negLight.withOpacity(0.3))
                              : (isDark ? AppTheme.lineDark : AppTheme.lineLight),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            score != null && score > 0
                                ? (score == score.roundToDouble() ? score.toInt().toString() : score.toStringAsFixed(1))
                                : 'Girilmedi',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: score != null && score > 0
                                  ? (score >= 50 ? AppTheme.posLight : AppTheme.negLight)
                                  : (isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: score != null && score > 0
                                ? (score >= 50 ? AppTheme.posLight : AppTheme.negLight)
                                : (isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Future<void> _showEditStudentScoreDialog(Map<String, dynamic> ex) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final examId = ex['exam_id'] as int;
    final title = ex['title'] as String;
    final maxScore = (ex['max_score'] as num?)?.toDouble() ?? 100.0;
    final currentScore = (ex['score'] as num?)?.toDouble();

    final scoreCtrl = TextEditingController(
      text: (currentScore != null && currentScore > 0)
          ? (currentScore == currentScore.roundToDouble()
              ? currentScore.toInt().toString()
              : currentScore.toString())
          : '',
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            final viewInsets = MediaQuery.of(sheetCtx).viewInsets;
            return Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, viewInsets.bottom + 20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_currentStudent.fullName} (${_currentStudent.studentNo})',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: scoreCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                    decoration: InputDecoration(
                      hintText: 'Not girin (0 - ${maxScore.toInt()})',
                      hintStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
                      suffixText: '/ ${maxScore.toInt()}',
                      suffixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Hızlı Not Butonları
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [100, 90, 85, 70, 50].map((val) {
                      return ActionChip(
                        label: Text('$val'),
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        onPressed: () {
                          scoreCtrl.text = '$val';
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (currentScore != null && currentScore > 0) ...[
                        Expanded(
                          flex: 1,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.negLight,
                              side: const BorderSide(color: AppTheme.negLight),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            label: const Text('Sil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await context.read<ExamsProvider>().saveExamScores(examId, {_currentStudent.id: 0.0});
                              await _loadProfileData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Not silindi.')),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                          label: const Text('Notu Kaydet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          onPressed: () async {
                            final text = scoreCtrl.text.trim().replaceAll(',', '.');
                            final val = double.tryParse(text);
                            if (val == null && text.isNotEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppTheme.negLight,
                                  content: Text('Lütfen geçerli bir sayısal not giriniz.'),
                                ),
                              );
                              return;
                            }
                            final scoreToSave = val ?? 0.0;
                            if (scoreToSave > maxScore) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppTheme.negLight,
                                  content: Text('Girilen not maksimum puandan ($maxScore) büyük olamaz.'),
                                ),
                              );
                              return;
                            }

                            Navigator.pop(ctx);
                            await context.read<ExamsProvider>().saveExamScores(examId, {_currentStudent.id: scoreToSave});
                            await _loadProfileData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppTheme.posLight,
                                  content: Text('Öğrenci sınav notu başarıyla güncellendi.'),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 3. PUAN & DEĞERLENDİRME GEÇMİŞİ SEKMESİ
  Widget _buildEvaluationsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hızlı Puan Butonları
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.posLight),
                icon: const Icon(Icons.thumb_up_alt_rounded, size: 16),
                label: const Text('+1 Puan Ver'),
                onPressed: () => _giveScore(1, 'Ders içi katılım'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.negLight),
                icon: const Icon(Icons.thumb_down_alt_rounded, size: 16),
                label: const Text('-1 Puan Ver'),
                onPressed: () => _giveScore(-1, 'Ders düzeni / ödev eksiği'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildInfoSectionTitle('Değerlendirme Akışı (${_evaluations.length})'),

        if (_evaluations.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Henüz değerlendirme puanı girilmedi.',
                  style: TextStyle(color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight)),
            ),
          )
        else
          ..._evaluations.map((ev) {
            final isPos = ev.value > 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onLongPress: () => _confirmDeleteEvaluation(ev),
                leading: CircleAvatar(
                  backgroundColor: isPos ? AppTheme.posLight.withOpacity(0.15) : AppTheme.negLight.withOpacity(0.15),
                  child: Text(
                    isPos ? '+${ev.value}' : '${ev.value}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: isPos ? AppTheme.posLight : AppTheme.negLight,
                    ),
                  ),
                ),
                title: Text(ev.note ?? (isPos ? 'Artı Puan' : 'Eksi Puan'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(DateFormat('dd.MM.yyyy HH:mm').format(DateTime.tryParse(ev.createdAt) ?? DateTime.now()),
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.negLight),
                  tooltip: 'Puanı Sil (veya uzun basın)',
                  onPressed: () => _confirmDeleteEvaluation(ev),
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  // 4. ÖĞRETMEN NOTLARI SEKMESİ
  Widget _buildNotesTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElevatedButton.icon(
          onPressed: _showAddNoteDialog,
          icon: const Icon(Icons.note_add_rounded),
          label: const Text('Yeni Öğretmen Notu Ekle'),
        ),
        const SizedBox(height: 16),
        _buildInfoSectionTitle('Kayıtlı Notlar (${_notes.length})'),

        if (_notes.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Öğrenciye ait öğretmen notu bulunmuyor.',
                  style: TextStyle(color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight)),
            ),
          )
        else
          ..._notes.map((n) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onLongPress: () => _confirmDeleteNote(n),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getNoteTypeName(n.type),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accent),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                DateFormat('dd.MM.yyyy').format(DateTime.tryParse(n.createdAt) ?? DateTime.now()),
                                style: TextStyle(fontSize: 10, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Notu Sil (veya uzun basın)',
                                onPressed: () => _confirmDeleteNote(n),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(n.body, style: const TextStyle(fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  // 5. DEVAMSIZLIK SEKMESİ
  Widget _buildAttendanceTab(bool isDark) {
    final absent = _attendanceSummary['absent'] ?? 0;
    final lateCount = _attendanceSummary['late'] ?? 0;
    final excused = _attendanceSummary['excused'] ?? 0;
    final present = _attendanceSummary['present'] ?? 0;
    final totalDays = absent + lateCount + excused + present;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoSectionTitle('Genel Devamsızlık Durumu'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildAttendanceStatCard('Toplam Özürsüz', '$absent Gün', Colors.red, isDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildAttendanceStatCard('Toplam Özürlü', '$excused Gün', Colors.orange, isDark),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildAttendanceStatCard('Geç Kalma', '$lateCount Ders', Colors.amber.shade800, isDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildAttendanceStatCard('Katılım Sağlanan', '$present Gün', Colors.green, isDark),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildInfoCard(isDark, [
          _buildInfoRow(Icons.calendar_today, 'Toplam İşlenen Gün', '$totalDays Gün'),
          _buildInfoRow(
            Icons.warning_amber_rounded,
            'Yasal Özürsüz Sınırı',
            '10 Gün (Kalan: ${10 - absent > 0 ? 10 - absent : 0} Gün)',
            iconColor: Colors.red,
          ),
        ]),
      ],
    );
  }

  // Yardımcı UI Widget'ları
  Widget _buildAttendanceStatCard(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildInfoSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.3)),
    );
  }

  Widget _buildInfoCard(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? iconColor, VoidCallback? onTap, Widget? trailing}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? AppTheme.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  String _getExamIcon(String type) {
    switch (type) {
      case 'written':
        return '📝';
      case 'oral':
        return '🗣️';
      case 'performance':
        return '⭐';
      case 'project':
        return '🎨';
      default:
        return '📄';
    }
  }

  String _getNoteTypeName(String type) {
    switch (type) {
      case 'observation':
        return '👁️ Ders İçi Gözlem';
      case 'guardian':
        return '👨‍👩‍👦 Veli Görüşmesi';
      case 'behavior':
        return '⭐ Davranış / Gelişim';
      case 'academic':
        return '📚 Akademik Takip';
      default:
        return '📌 Not';
    }
  }
}
