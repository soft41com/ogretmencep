class SettingsModel {
  final int id;
  final String teacherName;
  final String schoolName;
  final String branch;
  final String academicYear;
  final String themeMode; // light, dark, system
  final int timetableDays; // 5 veya 7
  final int dailyPeriodsCount; // varsayılan 8
  final bool isOnboardingCompleted;
  final bool lessonNotifyEnabled;
  final bool lessonStartNotifyEnabled;
  final int lessonStartMinutes;
  final bool lessonEndNotifyEnabled;
  final int lessonEndMinutes;
  final String lessonNotifyType; // both, sound, vibrate

  SettingsModel({
    required this.id,
    required this.teacherName,
    required this.schoolName,
    required this.branch,
    required this.academicYear,
    required this.themeMode,
    this.timetableDays = 5,
    this.dailyPeriodsCount = 8,
    this.isOnboardingCompleted = false,
    this.lessonNotifyEnabled = true,
    this.lessonStartNotifyEnabled = true,
    this.lessonStartMinutes = 5,
    this.lessonEndNotifyEnabled = true,
    this.lessonEndMinutes = 5,
    this.lessonNotifyType = 'both',
  });

  /// Dinamik varsayılan eğitim öğretim yılı (içinde bulunulan yıl ve sonraki yıl, örn: 2026-2027)
  static String get defaultAcademicYear {
    final year = DateTime.now().year;
    return '$year-${year + 1}';
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      id: map['id'] as int,
      teacherName: (map['teacher_name'] as String?) ?? 'Öğretmen',
      schoolName: (map['school_name'] as String?) ?? '',
      branch: (map['branch'] as String?) ?? '',
      academicYear: (map['academic_year'] as String?) ?? defaultAcademicYear,
      themeMode: (map['theme_mode'] as String?) ?? 'system',
      timetableDays: (map['timetable_days'] as int?) ?? 5,
      dailyPeriodsCount: (map['daily_periods_count'] as int?) ?? 8,
      isOnboardingCompleted: (map['is_onboarding_completed'] as int? ?? 0) == 1,
      lessonNotifyEnabled: (map['lesson_notify_enabled'] as int? ?? 1) == 1,
      lessonStartNotifyEnabled: (map['lesson_start_notify_enabled'] as int? ?? 1) == 1,
      lessonStartMinutes: (map['lesson_start_minutes'] as int?) ?? 5,
      lessonEndNotifyEnabled: (map['lesson_end_notify_enabled'] as int? ?? 1) == 1,
      lessonEndMinutes: (map['lesson_end_minutes'] as int?) ?? 5,
      lessonNotifyType: (map['lesson_notify_type'] as String?) ?? 'both',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacher_name': teacherName,
      'school_name': schoolName,
      'branch': branch,
      'academic_year': academicYear,
      'theme_mode': themeMode,
      'timetable_days': timetableDays,
      'daily_periods_count': dailyPeriodsCount,
      'is_onboarding_completed': isOnboardingCompleted ? 1 : 0,
      'lesson_notify_enabled': lessonNotifyEnabled ? 1 : 0,
      'lesson_start_notify_enabled': lessonStartNotifyEnabled ? 1 : 0,
      'lesson_start_minutes': lessonStartMinutes,
      'lesson_end_notify_enabled': lessonEndNotifyEnabled ? 1 : 0,
      'lesson_end_minutes': lessonEndMinutes,
      'lesson_notify_type': lessonNotifyType,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  SettingsModel copyWith({
    String? teacherName,
    String? schoolName,
    String? branch,
    String? academicYear,
    String? themeMode,
    int? timetableDays,
    int? dailyPeriodsCount,
    bool? isOnboardingCompleted,
    bool? lessonNotifyEnabled,
    bool? lessonStartNotifyEnabled,
    int? lessonStartMinutes,
    bool? lessonEndNotifyEnabled,
    int? lessonEndMinutes,
    String? lessonNotifyType,
  }) {
    return SettingsModel(
      id: id,
      teacherName: teacherName ?? this.teacherName,
      schoolName: schoolName ?? this.schoolName,
      branch: branch ?? this.branch,
      academicYear: academicYear ?? this.academicYear,
      themeMode: themeMode ?? this.themeMode,
      timetableDays: timetableDays ?? this.timetableDays,
      dailyPeriodsCount: dailyPeriodsCount ?? this.dailyPeriodsCount,
      isOnboardingCompleted: isOnboardingCompleted ?? this.isOnboardingCompleted,
      lessonNotifyEnabled: lessonNotifyEnabled ?? this.lessonNotifyEnabled,
      lessonStartNotifyEnabled: lessonStartNotifyEnabled ?? this.lessonStartNotifyEnabled,
      lessonStartMinutes: lessonStartMinutes ?? this.lessonStartMinutes,
      lessonEndNotifyEnabled: lessonEndNotifyEnabled ?? this.lessonEndNotifyEnabled,
      lessonEndMinutes: lessonEndMinutes ?? this.lessonEndMinutes,
      lessonNotifyType: lessonNotifyType ?? this.lessonNotifyType,
    );
  }
}

class BellPeriodModel {
  final int id;
  final int periodNo;
  final String startTime;
  final String endTime;
  final String label;

  BellPeriodModel({
    required this.id,
    required this.periodNo,
    required this.startTime,
    required this.endTime,
    required this.label,
  });

  factory BellPeriodModel.fromMap(Map<String, dynamic> map) {
    return BellPeriodModel(
      id: map['id'] as int,
      periodNo: map['period_no'] as int,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      label: map['label'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'period_no': periodNo,
      'start_time': startTime,
      'end_time': endTime,
      'label': label,
    };
  }
}

class ClassModel {
  final int id;
  final String name;
  final String gradeLevel;
  final String? subject;
  final String academicYear;
  final String color;
  final int studentCount;

  ClassModel({
    required this.id,
    required this.name,
    required this.gradeLevel,
    this.subject,
    required this.academicYear,
    required this.color,
    this.studentCount = 0,
  });

  factory ClassModel.fromMap(Map<String, dynamic> map, {int studentCount = 0}) {
    return ClassModel(
      id: map['id'] as int,
      name: map['name'] as String,
      gradeLevel: map['grade_level'] as String,
      subject: map['subject'] as String?,
      academicYear: (map['academic_year'] as String?) ?? SettingsModel.defaultAcademicYear,
      color: (map['color'] as String?) ?? '#17433B',
      studentCount: studentCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'grade_level': gradeLevel,
      'subject': subject,
      'academic_year': academicYear,
      'color': color,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}

class StudentModel {
  final int id;
  final int classId;
  final String studentNo;
  final String firstName;
  final String lastName;
  final String gender;
  final String? photoPath;
  final String? birthDate;
  final String? guardianName;
  final String? guardianPhone;
  final String? healthNote;
  final String? club;
  final String? bloodType;
  final String? address;
  final String? specialNotes;
  final String? className;
  final String? classSubject;
  final int totalScore;
  final int noteCount;

  StudentModel({
    required this.id,
    required this.classId,
    required this.studentNo,
    required this.firstName,
    required this.lastName,
    required this.gender,
    this.photoPath,
    this.birthDate,
    this.guardianName,
    this.guardianPhone,
    this.healthNote,
    this.club,
    this.bloodType,
    this.address,
    this.specialNotes,
    this.className,
    this.classSubject,
    this.totalScore = 0,
    this.noteCount = 0,
  });

  String get fullName => '$firstName $lastName';

  StudentModel copyWith({
    int? id,
    int? classId,
    String? studentNo,
    String? firstName,
    String? lastName,
    String? gender,
    String? photoPath,
    String? birthDate,
    String? guardianName,
    String? guardianPhone,
    String? healthNote,
    String? club,
    String? bloodType,
    String? address,
    String? specialNotes,
    String? className,
    String? classSubject,
    int? totalScore,
    int? noteCount,
  }) {
    return StudentModel(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      studentNo: studentNo ?? this.studentNo,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      photoPath: photoPath ?? this.photoPath,
      birthDate: birthDate ?? this.birthDate,
      guardianName: guardianName ?? this.guardianName,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      healthNote: healthNote ?? this.healthNote,
      club: club ?? this.club,
      bloodType: bloodType ?? this.bloodType,
      address: address ?? this.address,
      specialNotes: specialNotes ?? this.specialNotes,
      className: className ?? this.className,
      classSubject: classSubject ?? this.classSubject,
      totalScore: totalScore ?? this.totalScore,
      noteCount: noteCount ?? this.noteCount,
    );
  }

  factory StudentModel.fromMap(Map<String, dynamic> map, {int totalScore = 0, int noteCount = 0}) {
    return StudentModel(
      id: map['id'] as int,
      classId: map['class_id'] as int,
      studentNo: map['student_no'] as String,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      gender: (map['gender'] as String?) ?? 'M',
      photoPath: map['photo_path'] as String?,
      birthDate: map['birth_date'] as String?,
      guardianName: map['guardian_name'] as String?,
      guardianPhone: map['guardian_phone'] as String?,
      healthNote: map['health_note'] as String?,
      club: map['club'] as String?,
      bloodType: map['blood_type'] as String?,
      address: map['address'] as String?,
      specialNotes: map['special_notes'] as String?,
      className: map['class_name'] as String?,
      classSubject: map['class_subject'] as String?,
      totalScore: totalScore != 0 ? totalScore : ((map['total_score'] as num?)?.toInt() ?? 0),
      noteCount: noteCount != 0 ? noteCount : ((map['note_count'] as num?)?.toInt() ?? 0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'class_id': classId,
      'student_no': studentNo,
      'first_name': firstName,
      'last_name': lastName,
      'gender': gender,
      'photo_path': photoPath,
      'birth_date': birthDate,
      'guardian_name': guardianName,
      'guardian_phone': guardianPhone,
      'health_note': healthNote,
      'club': club,
      'blood_type': bloodType,
      'address': address,
      'special_notes': specialNotes,
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}

class EvaluationModel {
  final int id;
  final int studentId;
  final int classId;
  final int value;
  final String category;
  final String? note;
  final String createdAt;

  EvaluationModel({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.value,
    required this.category,
    this.note,
    required this.createdAt,
  });

  factory EvaluationModel.fromMap(Map<String, dynamic> map) {
    return EvaluationModel(
      id: map['id'] as int,
      studentId: map['student_id'] as int,
      classId: map['class_id'] as int,
      value: map['value'] as int,
      category: (map['category'] as String?) ?? 'participation',
      note: map['note'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}

class StudentNoteModel {
  final int id;
  final int studentId;
  final String type;
  final String body;
  final String? tags;
  final bool isPrivate;
  final String? followUpAt;
  final String createdAt;

  StudentNoteModel({
    required this.id,
    required this.studentId,
    required this.type,
    required this.body,
    this.tags,
    required this.isPrivate,
    this.followUpAt,
    required this.createdAt,
  });

  factory StudentNoteModel.fromMap(Map<String, dynamic> map) {
    return StudentNoteModel(
      id: map['id'] as int,
      studentId: map['student_id'] as int,
      type: (map['type'] as String?) ?? 'observation',
      body: map['body'] as String,
      tags: map['tags'] as String?,
      isPrivate: (map['is_private'] as int? ?? 1) == 1,
      followUpAt: map['follow_up_at'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}

class AttendanceModel {
  final int id;
  final int studentId;
  final int classId;
  final String date;
  final int? periodId;
  final String status; // present, absent, late, excused, sick
  final String? note;

  AttendanceModel({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.date,
    this.periodId,
    required this.status,
    this.note,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      id: map['id'] as int,
      studentId: map['student_id'] as int,
      classId: map['class_id'] as int,
      date: map['date'] as String,
      periodId: map['period_id'] as int?,
      status: map['status'] as String,
      note: map['note'] as String?,
    );
  }
}

class TimetableEntryModel {
  final int id;
  final int classId;
  final int periodId;
  final int weekday; // 1: Pazartesi ... 5: Cuma
  final String subject;
  final String? classroom;
  final String? className;
  final String? classColor;
  final String? periodLabel;
  final String? startTime;
  final String? endTime;

  TimetableEntryModel({
    required this.id,
    required this.classId,
    required this.periodId,
    required this.weekday,
    required this.subject,
    this.classroom,
    this.className,
    this.classColor,
    this.periodLabel,
    this.startTime,
    this.endTime,
  });

  factory TimetableEntryModel.fromMap(Map<String, dynamic> map) {
    return TimetableEntryModel(
      id: map['id'] as int,
      classId: map['class_id'] as int,
      periodId: map['period_id'] as int,
      weekday: map['weekday'] as int,
      subject: map['subject'] as String,
      classroom: map['classroom'] as String?,
      className: map['class_name'] as String?,
      classColor: map['class_color'] as String?,
      periodLabel: map['period_label'] as String?,
      startTime: map['start_time'] as String?,
      endTime: map['end_time'] as String?,
    );
  }
}

class ExamModel {
  final int id;
  final int classId;
  final String title;
  final String type; // written, oral, project, performance
  final String examDate;
  final double weight;
  final double maxScore;
  final String? className;
  final String? subject;
  final double averageScore;

  ExamModel({
    required this.id,
    required this.classId,
    required this.title,
    required this.type,
    required this.examDate,
    required this.weight,
    required this.maxScore,
    this.className,
    this.subject,
    this.averageScore = 0.0,
  });

  factory ExamModel.fromMap(Map<String, dynamic> map, {double averageScore = 0.0}) {
    return ExamModel(
      id: map['id'] as int,
      classId: map['class_id'] as int,
      title: map['title'] as String,
      type: (map['type'] as String?) ?? 'written',
      examDate: map['exam_date'] as String,
      weight: (map['weight'] as num?)?.toDouble() ?? 100.0,
      maxScore: (map['max_score'] as num?)?.toDouble() ?? 100.0,
      className: map['class_name'] as String?,
      subject: map['subject'] as String?,
      averageScore: averageScore,
    );
  }
}

class LessonPlanModel {
  final int id;
  final int? classId;
  final int weekNo;
  final int term;
  final String subject;
  final String topic;
  final String? learningOutcomes;
  final String? activities;
  final String status; // pending, completed

  LessonPlanModel({
    required this.id,
    this.classId,
    required this.weekNo,
    required this.term,
    required this.subject,
    required this.topic,
    this.learningOutcomes,
    this.activities,
    required this.status,
  });

  factory LessonPlanModel.fromMap(Map<String, dynamic> map) {
    return LessonPlanModel(
      id: map['id'] as int,
      classId: map['class_id'] as int?,
      weekNo: map['week_no'] as int,
      term: (map['term'] as int?) ?? 1,
      subject: map['subject'] as String,
      topic: map['topic'] as String,
      learningOutcomes: map['learning_outcomes'] as String?,
      activities: map['activities'] as String?,
      status: (map['status'] as String?) ?? 'pending',
    );
  }
}
