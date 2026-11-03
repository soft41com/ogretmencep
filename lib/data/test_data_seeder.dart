import '../data/database_helper.dart';

class TestDataSeeder {
  static Future<Map<String, int>> seedAllData() async {
    final db = await DatabaseHelper.instance.database;

    // Temizlik: Mevcut sınıflar, öğrenciler, ders programı ve planları temizle
    await db.delete('student_evaluations');
    await db.delete('student_notes');
    await db.delete('attendances');
    await db.delete('exam_scores');
    await db.delete('exams');
    await db.delete('students');
    await db.delete('timetable_entries');
    await db.delete('lesson_plans');
    await db.delete('classes');

    final now = DateTime.now().toIso8601String();

    // 1. ZİL SAATLERİNİ KONTROL ET / OLUŞTUR
    final existingPeriods = await db.query('bell_periods', orderBy: 'period_no ASC');
    if (existingPeriods.isEmpty) {
      final defaultPeriods = [
        {'period_no': 1, 'start_time': '08:40', 'end_time': '09:20', 'label': '1. Ders'},
        {'period_no': 2, 'start_time': '09:30', 'end_time': '10:10', 'label': '2. Ders'},
        {'period_no': 3, 'start_time': '10:20', 'end_time': '11:00', 'label': '3. Ders'},
        {'period_no': 4, 'start_time': '11:10', 'end_time': '11:50', 'label': '4. Ders'},
        {'period_no': 5, 'start_time': '12:40', 'end_time': '13:20', 'label': '5. Ders'},
        {'period_no': 6, 'start_time': '13:30', 'end_time': '14:10', 'label': '6. Ders'},
        {'period_no': 7, 'start_time': '14:20', 'end_time': '15:00', 'label': '7. Ders'},
        {'period_no': 8, 'start_time': '15:10', 'end_time': '15:50', 'label': '8. Ders'},
      ];
      for (var p in defaultPeriods) {
        await db.insert('bell_periods', p);
      }
    }
    final periods = await db.query('bell_periods', orderBy: 'period_no ASC');
    final pMap = {for (var p in periods) p['period_no'] as int: p['id'] as int};

    // 2. 6 ADET SINIF OLUŞTUR
    final classConfigs = [
      {'name': '9-A', 'grade': '9', 'subject': 'Matematik', 'color': '#17433B', 'base_no': 100},
      {'name': '9-B', 'grade': '9', 'subject': 'Matematik', 'color': '#1F8A5B', 'base_no': 200},
      {'name': '10-A', 'grade': '10', 'subject': 'Geometri', 'color': '#2563EB', 'base_no': 300},
      {'name': '10-B', 'grade': '10', 'subject': 'Geometri', 'color': '#7C3AED', 'base_no': 400},
      {'name': '11-A', 'grade': '11', 'subject': 'İleri Matematik', 'color': '#D97706', 'base_no': 500},
      {'name': '12-A', 'grade': '12', 'subject': 'Matematik Uygulamaları', 'color': '#E11D48', 'base_no': 600},
    ];

    final Map<String, int> classIds = {};

    for (var cfg in classConfigs) {
      final cid = await db.insert('classes', {
        'name': cfg['name'],
        'grade_level': cfg['grade'],
        'subject': cfg['subject'],
        'academic_year': DatabaseHelper.defaultAcademicYear,
        'color': cfg['color'],
        'created_at': now,
      });
      classIds[cfg['name'] as String] = cid;
    }

    // 3. HER SINIF İÇİN 30 ÖĞRENCİ OLUŞTUR (TOPLAM 180 ÖĞRENCİ)
    final maleNames = [
      'Ali', 'Burak', 'Can', 'Deniz', 'Emre', 'Furkan', 'Görkem', 'Hakan', 'Kerem', 'Mert',
      'Murat', 'Oğuz', 'Onur', 'Ömer', 'Serkan', 'Tolga', 'Umut', 'Yiğit', 'Kaan', 'Arda',
      'Batuhan', 'Berk', 'Doruk', 'Ege', 'Eren', 'Mehmet', 'Mustafa', 'Rüzgar', 'Tarık', 'Yaman'
    ];

    final femaleNames = [
      'Ayşe', 'Buse', 'Ceren', 'Derya', 'Ece', 'Elif', 'Gamze', 'Gizem', 'İrem', 'Melis',
      'Merve', 'Nazlı', 'Pelin', 'Selin', 'Şevval', 'Tuğba', 'Yağmur', 'Zeynep', 'Aslı', 'Begüm',
      'Beyza', 'Cansu', 'Damla', 'Defne', 'Duru', 'Eylül', 'Irmak', 'Lara', 'Nil', 'Simge'
    ];

    final lastNames = [
      'Yılmaz', 'Kaya', 'Demir', 'Çelik', 'Şahin', 'Yıldız', 'Yıldırım', 'Öztürk', 'Aydın', 'Özdemir',
      'Arslan', 'Doğan', 'Kılıç', 'Aslan', 'Çetin', 'Kara', 'Koç', 'Kurt', 'Özkan', 'Şimşek',
      'Polat', 'Korkmaz', 'Erdoğan', 'Yavuz', 'Güneş', 'Aksoy', 'Acar', 'Bulut', 'Keskin', 'Ünal'
    ];

    int totalStudentsCreated = 0;

    for (var cfg in classConfigs) {
      final cid = classIds[cfg['name']]!;
      final baseNo = cfg['base_no'] as int;

      for (int i = 0; i < 30; i++) {
        final isFemale = i % 2 == 1;
        final firstName = isFemale ? femaleNames[i] : maleNames[i];
        final lastName = lastNames[(i * 3 + baseNo) % lastNames.length];
        final studentNo = (baseNo + i + 1).toString();
        final guardianName = isFemale ? 'Ahmet $lastName' : 'Fatma $lastName';
        final guardianPhone = '053${(baseNo ~/ 100)} ${100 + i} ${20 + i}';

        String healthNote = '';
        if (i == 2) healthNote = 'Gözlük kullanıyor (Ön sıra)';
        if (i == 7) healthNote = 'Alerji: Fıstık ve Polen';
        if (i == 14) healthNote = 'Hafif işitme hassasiyeti';

        final stId = await db.insert('students', {
          'class_id': cid,
          'student_no': studentNo,
          'first_name': firstName,
          'last_name': lastName,
          'gender': isFemale ? 'F' : 'M',
          'guardian_name': guardianName,
          'guardian_phone': guardianPhone,
          'health_note': healthNote,
          'created_at': now,
        });

        totalStudentsCreated++;

        // Bazı öğrencilere başlangıç değerlendirme puanları ekle
        if (i % 3 == 0) {
          await db.insert('student_evaluations', {
            'student_id': stId,
            'class_id': cid,
            'value': 1,
            'category': 'participation',
            'note': 'Derse hazırlıklı ve aktif katılım sağladı',
            'created_at': now,
          });
        }
      }
    }

    // 4. HAFTALIK DERS PROGRAMI (TIMETABLE)
    // 5 Günlük dolu haftalık program
    final schedulePlan = [
      // Pazartesi (1)
      {'day': 1, 'p': 1, 'cls': '9-A', 'sub': 'Matematik', 'room': 'Derslik 101'},
      {'day': 1, 'p': 2, 'cls': '9-A', 'sub': 'Matematik', 'room': 'Derslik 101'},
      {'day': 1, 'p': 3, 'cls': '10-A', 'sub': 'Geometri', 'room': 'Derslik 201'},
      {'day': 1, 'p': 4, 'cls': '10-A', 'sub': 'Geometri', 'room': 'Derslik 201'},
      {'day': 1, 'p': 5, 'cls': '11-A', 'sub': 'İleri Matematik', 'room': 'Derslik 301'},
      {'day': 1, 'p': 6, 'cls': '11-A', 'sub': 'İleri Matematik', 'room': 'Derslik 301'},

      // Salı (2)
      {'day': 2, 'p': 1, 'cls': '9-B', 'sub': 'Matematik', 'room': 'Derslik 102'},
      {'day': 2, 'p': 2, 'cls': '9-B', 'sub': 'Matematik', 'room': 'Derslik 102'},
      {'day': 2, 'p': 3, 'cls': '12-A', 'sub': 'Matematik Uygulamaları', 'room': 'Derslik 401'},
      {'day': 2, 'p': 4, 'cls': '12-A', 'sub': 'Matematik Uygulamaları', 'room': 'Derslik 401'},
      {'day': 2, 'p': 5, 'cls': '10-B', 'sub': 'Geometri', 'room': 'Derslik 202'},
      {'day': 2, 'p': 6, 'cls': '10-B', 'sub': 'Geometri', 'room': 'Derslik 202'},

      // Çarşamba (3)
      {'day': 3, 'p': 1, 'cls': '9-A', 'sub': 'Matematik', 'room': 'Derslik 101'},
      {'day': 3, 'p': 2, 'cls': '9-A', 'sub': 'Matematik', 'room': 'Derslik 101'},
      {'day': 3, 'p': 3, 'cls': '11-A', 'sub': 'İleri Matematik', 'room': 'Derslik 301'},
      {'day': 3, 'p': 4, 'cls': '11-A', 'sub': 'İleri Matematik', 'room': 'Derslik 301'},
      {'day': 3, 'p': 5, 'cls': '9-B', 'sub': 'Matematik', 'room': 'Derslik 102'},
      {'day': 3, 'p': 6, 'cls': '9-B', 'sub': 'Matematik', 'room': 'Derslik 102'},

      // Perşembe (4)
      {'day': 4, 'p': 1, 'cls': '10-A', 'sub': 'Geometri', 'room': 'Derslik 201'},
      {'day': 4, 'p': 2, 'cls': '10-A', 'sub': 'Geometri', 'room': 'Derslik 201'},
      {'day': 4, 'p': 3, 'cls': '10-B', 'sub': 'Geometri', 'room': 'Derslik 202'},
      {'day': 4, 'p': 4, 'cls': '10-B', 'sub': 'Geometri', 'room': 'Derslik 202'},
      {'day': 4, 'p': 5, 'cls': '12-A', 'sub': 'Matematik Uygulamaları', 'room': 'Derslik 401'},
      {'day': 4, 'p': 6, 'cls': '12-A', 'sub': 'Matematik Uygulamaları', 'room': 'Derslik 401'},

      // Cuma (5)
      {'day': 5, 'p': 1, 'cls': '9-B', 'sub': 'Matematik', 'room': 'Derslik 102'},
      {'day': 5, 'p': 2, 'cls': '9-B', 'sub': 'Matematik', 'room': 'Derslik 102'},
      {'day': 5, 'p': 3, 'cls': '9-A', 'sub': 'Matematik', 'room': 'Derslik 101'},
      {'day': 5, 'p': 4, 'cls': '9-A', 'sub': 'Matematik', 'room': 'Derslik 101'},
      {'day': 5, 'p': 5, 'cls': '11-A', 'sub': 'İleri Matematik', 'room': 'Derslik 301'},
      {'day': 5, 'p': 6, 'cls': '11-A', 'sub': 'İleri Matematik', 'room': 'Derslik 301'},
    ];

    int timetableEntriesCreated = 0;
    for (var item in schedulePlan) {
      final cid = classIds[item['cls']]!;
      final periodId = pMap[item['p'] as int] ?? periods.first['id'] as int;

      await db.insert('timetable_entries', {
        'class_id': cid,
        'period_id': periodId,
        'weekday': item['day'],
        'subject': item['sub'],
        'classroom': item['room'],
        'created_at': now,
      });
      timetableEntriesCreated++;
    }

    // 5. YILLIK DERS PLANLARI (HER BİRİ İÇİN 36 HAFTA = TOPLAM 216 PLAN SATIRI)
    final math9Plan = _generate36WeekPlan(
      subject: 'Matematik',
      topics1: [
        'Tanışma ve Hedefler', 'Önermeler ve Doğruluk Değerleri', 'Mantık Bağlaçları (Ve, Veya)',
        'Koşullu Önerme (İse)', 'Açık Önermeler ve Niceleyiciler', 'Kümelerde Temel Kavramlar',
        'Kümelerde İşlemler ve Venn Şeması', '1. Yazılı Öncesi Tekrar', '1. Ortak Yazılı Sınavı',
        'Sınav Analizi ve Geri Bildirim', 'Kartezyen Çarpım', 'Sayı Kümeleri ve Aralıklar',
        '1. Dereceden Denklemler', '1. Dereceden Eşitsizlikler', 'Mutlak Değer Kavramı',
        '2. Yazılı Öncesi Tekrar', '2. Ortak Yazılı Sınavı', '1. Dönem Değerlendirmesi',
      ],
      topics2: [
        'Üslü İfadeler ve Kuralları', 'Köklü İfadeler ve Eşlenik', 'Oran ve Orantı',
        'Sayı ve Kesir Problemleri', 'Yaş Problemleri', 'İşçi ve Havuz Problemleri',
        'Yüzde ve Kâr-Zarar Problemleri', '2. Dönem 1. Yazılı Tekrar', '2. Dönem 1. Yazılı Sınavı',
        'Sınav Geri Bildirimi', 'Karışım ve Hareket Problemleri', 'Üçgende Açı Özellikleri',
        'Açı-Kenar Bağıntıları', 'Üçgenlerin Benzerliği', 'Dik Üçgen ve Pisagor Teoremi',
        'Yıllık Genel Tekrar', '2. Dönem 2. Yazılı Sınavı', 'Yıl Sonu Kapanış ve Başarı Analizi',
      ],
    );

    final geo10Plan = _generate36WeekPlan(
      subject: 'Geometri',
      topics1: [
        'Sayma Yöntemleri ve Çarpma Kuralı', 'Permütasyon Hesaplamaları', 'Kombinasyon Kavramı',
        'Binom Açılımı', 'Basit Olayların Olasılığı', 'Fonksiyon Tanımı ve Tanım Kümesi',
        'Fonksiyon Türleri (Birebir, Örten)', '1. Yazılı Öncesi Tekrar', '1. Ortak Yazılı Sınavı',
        'Sınav Çözümü ve Analiz', 'Fonksiyonların Grafikleri', 'Bileşke Fonksiyon',
        'Fonksiyonun Tersi', 'Polinom Kavramı ve Derecesi', 'Polinomlarda İşlemler',
        '2. Yazılı Öncesi Tekrar', '2. Ortak Yazılı Sınavı', '1. Dönem Kapanış Değerlendirmesi',
      ],
      topics2: [
        'Polinomlarda Bölme ve Kalan', 'Çarpanlara Ayırma Yöntemleri', 'Özdeşlikler ve Uygulamaları',
        'İkinci Dereceden Denklemler', 'Kökler ve Katsayılar Bağıntısı', 'Karmaşık Sayılara Giriş',
        'Dörtgenlerin Temel Elemanları', '2. Dönem 1. Yazılı Tekrar', '2. Dönem 1. Yazılı Sınavı',
        'Sınav Değerlendirmesi', 'Yamuk ve Özellikleri', 'Paralelkenar ve Eşkenar Dörtgen',
        'Dikdörtgen ve Kare', 'Deltoid ve Çokgenler', 'Özel Dörtgenlerde Alan Bağıntıları',
        'Yıllık Kapsamlı Tekrar', '2. Dönem 2. Yazılı Sınavı', 'Yıl Sonu Değerlendirmesi',
      ],
    );

    final advancedMath11Plan = _generate36WeekPlan(
      subject: 'İleri Matematik',
      topics1: [
        'Yönlü Açılar ve Birim Çember', 'Trigonometrik Fonksiyonlar (Sin, Cos)', 'Tanjant ve Kotanjant Fonksiyonları',
        'Trigonometrik Özdeşlikler', 'İndirgeme Bağıntıları', 'Trigonometrik Teoremler (Sinüs, Kosinüs)',
        'Periyot ve Trigonometrik Grafikler', '1. Yazılı Öncesi Tekrar', '1. Ortak Yazılı Sınavı',
        'Sınav Analizi ve Geri Bildirim', 'Ters Trigonometrik Fonksiyonlar', 'Noktanın ve Doğrunun Analitiği',
        'Doğrunun Eğimi ve Denklemi', 'İki Doğrunun Birbirine Göre Durumu', 'Noktanın Doğruya Uzaklığı',
        '2. Yazılı Öncesi Tekrar', '2. Ortak Yazılı Sınavı', '1. Dönem Değerlendirmesi',
      ],
      topics2: [
        'Fonksiyonların Simetrisi ve Öteleme', 'İkinci Dereceden Fonksiyonlar (Parabol)', 'Parabolün Tepe Noktası ve Grafiği',
        'Parabol ve Doğrunun Durumu', 'İkinci Dereceden Bir Bilinmeyenli Eşitsizlikler', 'Eşitsizlik Sistemleri ve Tablolar',
        'Çemberin Temel Elemanları ve Açı', '2. Dönem 1. Yazılı Tekrar', '2. Dönem 1. Yazılı Sınavı',
        'Sınav Geri Bildirimi', 'Çemberde Kiriş ve Teğet Özellikleri', 'Dairede Çevre ve Alan Hesabı',
        'Uzay Geometri ve Katı Cisimler', 'Prizmalar ve Piramitler', 'Silindir ve Koni Alan-Hacim',
        'Genel Tekrar ve Soru Çözümleri', '2. Dönem 2. Yazılı Sınavı', 'Yıl Sonu Değerlendirmesi',
      ],
    );

    final appliedMath12Plan = _generate36WeekPlan(
      subject: 'Matematik Uygulamaları',
      topics1: [
        'Üstel Fonksiyon ve Özellikleri', 'Logaritma Fonksiyonu ve Kuralları', 'Doğal Logaritma (ln) ve Özellikleri',
        'Logaritmik Denklem ve Eşitsizlikler', 'Üstel ve Logaritmik Modelleme', 'Gerçek Sayı Dizileri',
        'Aritmetik Dizi ve Genel Terim', '1. Yazılı Öncesi Tekrar', '1. Ortak Yazılı Sınavı',
        'Sınav Analiz ve Geri Bildirimi', 'Geometrik Dizi ve Toplam Formülü', 'Toplam Sembolü ve Uygulamaları',
        'Finansal Matematik ve Faiz Hesapları', 'Trigonometrik Toplam-Fark Formülleri', 'Yarım Açı Formülleri',
        '2. Yazılı Öncesi Tekrar', '2. Ortak Yazılı Sınavı', '1. Dönem Sonu Değerlendirmesi',
      ],
      topics2: [
        'Limit Kavramı ve Soldan-Sağdan Limit', 'Limit Kuralları ve Belirsizlikler', 'Süreklilik Kavramı',
        'Türev Tanımı ve Anlık Hız', 'Türev Alma Kuralları', 'Bileşke Fonksiyonun Türevi (Zincir Kuralı)',
        'Türevin Geometrik Anlamı (Teğet Eğimi)', '2. Dönem 1. Yazılı Tekrar', '2. Dönem 1. Yazılı Sınavı',
        'Sınav Çözümü ve Analizi', 'Artan-Azalan Fonksiyonlar', 'Maksimum ve Minimum Problemleri',
        'Belirsiz İntegral Kavramı', 'İntegral Alma Kuralları ve Değişken Değiştirme', 'Belirli İntegral ve Alan Hesabı',
        'Yıllık Kapsamlı Sınav Tekrarı', '2. Dönem 2. Yazılı Sınavı', 'Yıl Sonu Mezuniyet Değerlendirmesi',
      ],
    );

    final classPlanMap = {
      '9-A': math9Plan,
      '9-B': math9Plan,
      '10-A': geo10Plan,
      '10-B': geo10Plan,
      '11-A': advancedMath11Plan,
      '12-A': appliedMath12Plan,
    };

    int totalPlansCreated = 0;
    for (var entry in classPlanMap.entries) {
      final cid = classIds[entry.key]!;
      for (var item in entry.value) {
        await db.insert('lesson_plans', {
          'class_id': cid,
          'week_no': item['week_no'],
          'term': item['term'],
          'subject': item['subject'],
          'topic': item['topic'],
          'learning_outcomes': item['learning_outcomes'],
          'activities': item['activities'],
          'status': item['status'],
          'created_at': now,
        });
        totalPlansCreated++;
      }
    }

    return {
      'classes': classIds.length,
      'students': totalStudentsCreated,
      'timetable_entries': timetableEntriesCreated,
      'plans': totalPlansCreated,
    };
  }

  static List<Map<String, dynamic>> _generate36WeekPlan({
    required String subject,
    required List<String> topics1,
    required List<String> topics2,
  }) {
    final List<Map<String, dynamic>> items = [];

    // 1. Dönem (1-18)
    for (int i = 0; i < 18; i++) {
      final weekNo = i + 1;
      final topic = i < topics1.length ? topics1[i] : '$subject $weekNo. Hafta Konusu';
      items.add({
        'week_no': weekNo,
        'term': 1,
        'subject': subject,
        'topic': topic,
        'learning_outcomes': '$topic ile ilgili temel kavram ve teoremleri açıklar, problem çözümlerinde etkin şekilde kullanır.',
        'activities': 'Ders anlatımı, akıllı tahta uygulamaları, soru çözümü ve çalışma yaprakları',
        'status': weekNo <= 4 ? 'completed' : 'pending',
      });
    }

    // 2. Dönem (19-36)
    for (int i = 0; i < 18; i++) {
      final weekNo = i + 19;
      final topic = i < topics2.length ? topics2[i] : '$subject $weekNo. Hafta Konusu';
      items.add({
        'week_no': weekNo,
        'term': 2,
        'subject': subject,
        'topic': topic,
        'learning_outcomes': '$topic kazanımlarını kavrar, analiz ve sentez düzeyinde problem çözme stratejilerini uygular.',
        'activities': 'Grup çalışmaları, soru bankası taraması, sınav hazırlık tekrarları ve bireysel testler',
        'status': 'pending',
      });
    }

    return items;
  }

  /// Belirli bir sınıf ve ders için 36 haftalık örnek MEB planı ekler.
  static Future<int> seedPlanForClass({required int classId, required String subject}) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    final items = _generate36WeekPlan(
      subject: subject,
      topics1: [
        'Tanışma, Dersin Amacı ve Hedefleri',
        'Temel Kavramlar ve Giriş',
        'Kavramsal Çerçeve ve Tanımlar',
        'Teorik Esaslar ve İlkeler',
        'Uygulama Örnekleri ve Analizler',
        'Konu Tekrarı ve Pekiştirme',
        'Problem Çözme Yöntemleri',
        '1. Ara Tatil Değerlendirmesi',
        'İleri Düzey Kavramlar',
        '1. Dönem 1. Ortak Yazılı Sınavı',
        'Sınav Analizi ve Eksik Tamamlama',
        'Grup Çalışmaları ve Etkinlikler',
        'Örnek Olay İncelemeleri',
        'Farklı Yaklaşımlar ve Metodoloji',
        'Dönem Sonu Proje ve Sunumlar',
        '1. Dönem 2. Yazılı Sınavı',
        'Genel Dönem Tekrarı',
        'Dönem Değerlendirmesi ve Kapanış',
      ],
      topics2: [
        '2. Dönem Başlangıcı ve Hedef Belirleme',
        'Yeni Üniteye Giriş ve Kavramlar',
        'Uygulamalı Çalışmalar',
        'Kazanım Pekiştirme Çalışmaları',
        'Grup Projeleri ve Tartışma',
        '2. Ara Tatil Değerlendirmesi',
        'Disiplinlerarası Bağlantılar',
        '2. Dönem 1. Yazılı Sınavı',
        'Sınav Geri Bildirimleri',
        'Laboratuvar / Atölye Çalışmaları',
        'Yaratıcı Düşünme ve Uygulama',
        'Problem Çözme Pratikleri',
        'Genel Tekrar ve Soru Çözümü',
        '2. Dönem 2. Yazılı Sınavı',
        'Yıl Sonu Proje Sunumları',
        'Yıllık Kazanım Değerlendirmesi',
        'Yıl Sonu Genel Değerlendirme',
        'Kapanış ve Rehberlik',
      ],
    );

    int count = 0;
    // Önce varsa eski planları temizle
    await db.delete('lesson_plans', where: 'class_id = ?', whereArgs: [classId]);
    for (var item in items) {
      final map = Map<String, dynamic>.from(item);
      map['class_id'] = classId;
      map['created_at'] = now;
      await db.insert('lesson_plans', map);
      count++;
    }
    return count;
  }
}
