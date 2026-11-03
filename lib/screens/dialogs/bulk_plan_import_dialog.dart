import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/classes_provider.dart';
import '../../providers/plans_provider.dart';
import '../../theme/app_theme.dart';

class BulkPlanImportDialog extends StatefulWidget {
  final int targetClassId;

  const BulkPlanImportDialog({Key? key, required this.targetClassId}) : super(key: key);

  @override
  State<BulkPlanImportDialog> createState() => _BulkPlanImportDialogState();
}

class _BulkPlanImportDialogState extends State<BulkPlanImportDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _pasteCtrl = TextEditingController();

  bool _isParsed = false;
  bool _isLoadingFile = false;
  bool _isSaving = false;
  bool _replaceExisting = true;

  // Parsed plan entries: List of { 'week_no': 1, 'term': 1, 'topic': '...', 'learning_outcomes': '...', 'activities': '...' }
  List<Map<String, dynamic>> _parsedItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pasteCtrl.dispose();
    super.dispose();
  }

  // Örnek Excel Şablonu Oluştur ve Paylaş
  Future<void> _exportSampleExcelTemplate() async {
    try {
      final excel = Excel.createExcel();
      const sheetName = 'Yıllık Plan';
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      // Başlıklar
      sheet.appendRow([
        TextCellValue('Hafta No'),
        TextCellValue('Dönem'),
        TextCellValue('Konu / Ünite'),
        TextCellValue('Kazanımlar'),
        TextCellValue('Etkinlikler ve Yöntemler'),
      ]);

      // 36 Haftalık Örnek MEB Plan Satırları
      final sampleRows = [
        ['1', '1', 'Tanışma, Dersin Tanıtımı ve Hedeflerin Belirlenmesi', 'Dersin amaç ve ilkelerini kavrar, çalışma planını oluşturur.', 'Ders anlatımı, soru-cevap, sınıf içi etkileşim'],
        ['2', '1', 'Ünite 1: Temel Kavramlar ve Giriş', 'Temel kavramsal tanımları yapar, örnek durumlarla açıklar.', 'Akıllı tahta sunumu, kavram haritası'],
        ['3', '1', 'Ünite 1: Temel Kurallar ve Bağıntılar', 'Temel bağıntı ve kuralları kavrar, basit problemlere uygular.', 'Örnek soru çözümleri, bireysel çalışma'],
        ['4', '1', 'Ünite 1: Örnek Problem Çözümleri ve Uygulama', 'Farklı soru tiplerinde analiz ve sentez yapar.', 'Grup çalışması, çalışma yaprağı'],
        ['5', '1', 'Ünite 2: İleri Düzey İlişkiler', 'Kavramlar arasındaki ileri düzey ilişkileri modeller.', 'Problem çözme stratejileri'],
        ['6', '1', 'Ünite 2: Uygulamalar ve Pekiştirme', 'Kazanılan bilgileri yeni durumlara transfer eder.', 'Etkinlik uygulaması, akıllı tahta'],
        ['7', '1', 'Ünite 2: Grafik ve Tablo Okuma', 'Verileri okur ve tablo/grafik üzerinde yorumlar.', 'Grafik çizimi, analiz'],
        ['8', '1', '1. Yazılı Öncesi Genel Tekrar', 'İlk 7 haftanın konularını pekiştirir, eksiklerini giderir.', 'Örnek yazılı soru çözümü'],
        ['9', '1', '1. Ortak Yazılı Sınav Haftası', 'Dönem başı kazanımlarını değerlendirir.', 'Ortak yazılı sınav'],
        ['10', '1', 'Sınav Sorularının Çözümü ve Geri Bildirim', 'Eksik öğrenmeleri tespit edip giderir.', 'Sınav analizi ve soru çözümü'],
        ['11', '1', 'Ünite 3: Yeni Konu Başlangıcı', 'Yeni konunun temel ilkelerini kavrar.', 'Giriş etkinliği, beyin fırtınası'],
        ['12', '1', 'Ünite 3: Derinlemesine Kavrama', 'Konuyla ilgili karmaşık durumları çözümler.', 'Soru çözümü'],
        ['13', '1', 'Ünite 3: Araştırma ve Proje Çalışması', 'Konu hakkında küçük çaplı araştırma yürütür.', 'Proje hazırlığı'],
        ['14', '1', 'Ünite 4: Günlük Hayat Uygulamaları', 'Kazanımları günlük yaşam durumlarıyla ilişkilendirir.', 'Gerçek yaşam örnekleri'],
        ['15', '1', 'Ünite 4: Problem Çözme', 'Gelişmiş problem çözme adımlarını uygular.', 'Çalışma kağıdı'],
        ['16', '1', '2. Yazılı Öncesi Genel Tekrar', '1. Dönem konularını özetler ve pekiştirir.', 'Kapsamlı tekrar testi'],
        ['17', '1', '2. Ortak Yazılı Sınav Haftası', '1. Dönem kazanımlarını değerlendirir.', 'Ortak yazılı sınav'],
        ['18', '1', '1. Dönem Değerlendirmesi ve Sosyal Etkinlikler', 'Dönemlik başarı grafiğini analiz eder.', 'Dönem sonu değerlendirmesi'],
        ['19', '2', '2. Dönem Başlangıcı: Hedeflerin Güncellenmesi', '2. Dönem konu ve hedeflerini kavrar.', 'Planlama ve motivasyon'],
        ['20', '2', 'Ünite 5: Temel Prensipler', 'Yeni ünitenin temel kazanımlarını edinir.', 'Akıllı tahta, sunum'],
        ['21', '2', 'Ünite 5: Modelleme ve İspat', 'Matematiksel/mantıksal modeller kurar.', 'Grup çalışması'],
        ['22', '2', 'Ünite 5: Soru Çözümleri', 'ÖSYM ve MEB soru tiplerini çözümler.', 'Soru bankası uygulaması'],
        ['23', '2', 'Ünite 6: Yeni Kavramlar', 'Kavramlar arasındaki bağlamı anlar.', 'Kavram haritası'],
        ['24', '2', 'Ünite 6: Pratik Uygulamalar', 'Pratik problem çözme yöntemlerini kullanır.', 'Bireysel test'],
        ['25', '2', 'Ünite 6: Etkinlikler ve Deney/Atölye', 'Uygulamalı çalışma ile öğrenmeyi kalıcılaştırır.', 'Atölye/Etkinlik'],
        ['26', '2', '2. Dönem 1. Yazılı Öncesi Genel Tekrar', '2. Dönem ilk 7 haftasını gözden geçirir.', 'Örnek sınav çözümü'],
        ['27', '2', '2. Dönem 1. Ortak Yazılı Sınav Haftası', 'Kazanımları ölçer ve değerlendirir.', 'Yazılı sınav'],
        ['28', '2', 'Sınav Değerlendirmesi ve Geri Bildirim', 'Hatalarını fark eder ve düzeltir.', 'Geri bildirim oturumu'],
        ['29', '2', 'Ünite 7: İleri Düzey Konular', 'İleri seviye kazanımları öğrenir.', 'Detaylı anlatım'],
        ['30', '2', 'Ünite 7: Uygulama ve Pekiştirme', 'Öğrendiklerini farklı bağlamlarda kullanır.', 'Soru çözümü'],
        ['31', '2', 'Ünite 8: Son Üniteye Giriş', 'Müfredatın son ünitesini kavrar.', 'Giriş etkinliği'],
        ['32', '2', 'Ünite 8: Kapsamlı Örnekler', 'Konuyu pekiştirici kapsamlı sorular çözer.', 'Çalışma kağıdı'],
        ['33', '2', 'Ünite 8: Ünite Sonu Değerlendirme', 'Ünitenin tamamını değerlendirir.', 'Özet test'],
        ['34', '2', '2. Dönem 2. Yazılı Öncesi Yıllık Genel Tekrar', 'Tüm yılın anahtar kazanımlarını pekiştirir.', 'Kapsamlı genel tekrar'],
        ['35', '2', '2. Dönem 2. Ortak Yazılı Sınav Haftası', 'Yıl sonu akademik başarısını ölçer.', 'Ortak yazılı sınav'],
        ['36', '2', 'Yıl Sonu Değerlendirmesi ve Sosyal Faaliyetler', 'Yıllık müfredatın kazanım gerçekleşme durumunu değerlendirir.', 'Yıl sonu kapanış etkinlikleri'],
      ];

      for (var row in sampleRows) {
        sheet.appendRow(row.map((cell) => TextCellValue(cell)).toList());
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Excel dosyası oluşturulamadı');

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/Ornek_Yillik_Plan_Sablonu.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'ÖğretmenCep - Yıllık Plan & Kazanım Excel Şablonu (36 Hafta)',
        subject: 'Ornek_Yillik_Plan_Sablonu.xlsx',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Şablon oluşturulurken hata: $e')),
        );
      }
    }
  }

  // Excel Dosyası Seç ve Ayrıştır
  Future<void> _pickAndParseExcelFile() async {
    setState(() => _isLoadingFile = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoadingFile = false);
        return;
      }

      final file = result.files.first;
      List<int>? bytes = file.bytes;

      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null || bytes.isEmpty) {
        throw Exception('Dosya içeriği okunamadı.');
      }

      final excel = Excel.decodeBytes(bytes);
      final List<Map<String, dynamic>> parsedList = [];

      for (var tableName in excel.tables.keys) {
        final sheet = excel.tables[tableName];
        if (sheet == null || sheet.rows.isEmpty) continue;

        int headerRowIdx = -1;
        int colWeek = -1;
        int colTerm = -1;
        int colTopic = -1;
        int colOutcomes = -1;
        int colActivities = -1;

        // Başlık satırını ara (ilk 10 satırda)
        for (int r = 0; r < sheet.rows.length && r < 10; r++) {
          final row = sheet.rows[r];
          for (int c = 0; c < row.length; c++) {
            final val = row[c]?.value?.toString().trim().toLowerCase() ?? '';
            if (val.isEmpty) continue;

            if (val.contains('hafta') || val == 'hft' || val == 'week' || (val == 'no' && colWeek == -1)) {
              colWeek = c;
            } else if (val.contains('dönem') || val.contains('donem') || val.contains('yarıyıl') || val.contains('term')) {
              colTerm = c;
            } else if (val.contains('konu') || val.contains('ünite') || val.contains('unite') || val.contains('öğrenme alanı') || val.contains('tema') || val.contains('topic')) {
              colTopic = c;
            } else if (val.contains('kazanım') || val.contains('kazanim') || val.contains('çıktı') || val.contains('hedef') || val.contains('outcome')) {
              colOutcomes = c;
            } else if (val.contains('etkinlik') || val.contains('yöntem') || val.contains('yontem') || val.contains('teknik') || val.contains('açıklama') || val.contains('activity') || val.contains('not')) {
              colActivities = c;
            }
          }

          if (colTopic != -1 || colOutcomes != -1 || colWeek != -1) {
            headerRowIdx = r;
            break;
          }
        }

        final startIdx = (headerRowIdx != -1) ? headerRowIdx + 1 : 0;
        int fallbackWeek = 1;

        for (int r = startIdx; r < sheet.rows.length; r++) {
          final row = sheet.rows[r];
          if (row.isEmpty) continue;

          String rawWeek = (colWeek != -1 && colWeek < row.length)
              ? (row[colWeek]?.value?.toString().trim() ?? '')
              : '';

          String rawTopic = (colTopic != -1 && colTopic < row.length)
              ? (row[colTopic]?.value?.toString().trim() ?? '')
              : (row.length > 1 ? (row[1]?.value?.toString().trim() ?? '') : '');

          String rawOutcomes = (colOutcomes != -1 && colOutcomes < row.length)
              ? (row[colOutcomes]?.value?.toString().trim() ?? '')
              : (row.length > 2 ? (row[2]?.value?.toString().trim() ?? '') : '');

          String rawActivities = (colActivities != -1 && colActivities < row.length)
              ? (row[colActivities]?.value?.toString().trim() ?? '')
              : (row.length > 3 ? (row[3]?.value?.toString().trim() ?? '') : '');

          String rawTerm = (colTerm != -1 && colTerm < row.length)
              ? (row[colTerm]?.value?.toString().trim() ?? '')
              : '';

          // Eğer satırda ne konu ne de kazanım varsa atla
          if (rawTopic.isEmpty && rawOutcomes.isEmpty) continue;

          // Hafta numarasını ayıkla
          int weekNo = fallbackWeek;
          final matchNum = RegExp(r'\d+').firstMatch(rawWeek);
          if (matchNum != null) {
            weekNo = int.tryParse(matchNum.group(0)!) ?? fallbackWeek;
          }

          // Dönemi tespit et
          int term = 1;
          if (rawTerm.contains('2') || rawTerm.toLowerCase().contains('ikinci') || weekNo > 18) {
            term = 2;
          }

          parsedList.add({
            'week_no': weekNo,
            'term': term,
            'topic': rawTopic.isNotEmpty ? rawTopic : 'Konu',
            'learning_outcomes': rawOutcomes,
            'activities': rawActivities,
          });

          fallbackWeek = weekNo + 1;
        }

        if (parsedList.isNotEmpty) break;
      }

      if (parsedList.isEmpty) {
        throw Exception('Excel dosyasında uygun yıllık plan veya kazanım satırları bulunamadı.');
      }

      // Hafta sırasına göre sırala
      parsedList.sort((a, b) => (a['week_no'] as int).compareTo(b['week_no'] as int));

      setState(() {
        _parsedItems = parsedList;
        _isParsed = true;
        _isLoadingFile = false;
      });
    } catch (e) {
      setState(() => _isLoadingFile = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.negLight,
            content: Text('Dosya ayrıştırılırken hata: $e'),
          ),
        );
      }
    }
  }

  // Metin Yapıştırarak Ayrıştır
  void _parsePastedText() {
    final text = _pasteCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen Excel veya tablodan kopyaladığınız metni yapıştırın.')),
      );
      return;
    }

    final lines = const LineSplitter().convert(text);
    final List<Map<String, dynamic>> parsedList = [];
    int fallbackWeek = 1;

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      List<String> parts = [];
      if (trimmed.contains('\t')) {
        parts = trimmed.split('\t');
      } else if (trimmed.contains(';')) {
        parts = trimmed.split(';');
      } else {
        parts = trimmed.split(',');
      }

      parts = parts.map((p) => p.trim()).toList();
      if (parts.isEmpty) continue;

      // Başlık satırını atla
      final firstLower = parts.first.toLowerCase();
      if (firstLower.contains('hafta') || firstLower.contains('dönem') || firstLower == 'no') {
        continue;
      }

      String rawWeek = parts[0];
      String rawTopic = parts.length > 1 ? parts[1] : '';
      String rawOutcomes = parts.length > 2 ? parts[2] : '';
      String rawActivities = parts.length > 3 ? parts[3] : '';
      int term = 1;

      // Eğer 2. sütun sayı veya dönem ise kaydır
      if (parts.length > 4 && (parts[1].trim() == '1' || parts[1].trim() == '2')) {
        term = int.tryParse(parts[1].trim()) ?? 1;
        rawTopic = parts[2];
        rawOutcomes = parts[3];
        rawActivities = parts.length > 4 ? parts[4] : '';
      }

      if (rawTopic.isEmpty && rawOutcomes.isEmpty) continue;

      int weekNo = fallbackWeek;
      final matchNum = RegExp(r'\d+').firstMatch(rawWeek);
      if (matchNum != null) {
        weekNo = int.tryParse(matchNum.group(0)!) ?? fallbackWeek;
      }

      if (weekNo > 18) term = 2;

      parsedList.add({
        'week_no': weekNo,
        'term': term,
        'topic': rawTopic.isNotEmpty ? rawTopic : 'Konu',
        'learning_outcomes': rawOutcomes,
        'activities': rawActivities,
      });

      fallbackWeek = weekNo + 1;
    }

    if (parsedList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yapıştırılan metinde uygun satır bulunamadı.')),
      );
      return;
    }

    parsedList.sort((a, b) => (a['week_no'] as int).compareTo(b['week_no'] as int));

    setState(() {
      _parsedItems = parsedList;
      _isParsed = true;
    });
  }

  // Veritabanına Kaydet
  Future<void> _saveParsedPlans(ClassModel targetClass) async {
    if (_parsedItems.isEmpty) return;

    setState(() => _isSaving = true);
    final plansProv = context.read<PlansProvider>();

    try {
      final subject = targetClass.subject?.trim().isNotEmpty == true ? targetClass.subject!.trim() : 'Ders';

      final count = await plansProv.bulkImportPlans(
        classId: widget.targetClassId,
        subject: subject,
        items: _parsedItems,
        replaceExisting: _replaceExisting,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.posLight,
            content: Text('$count haftalık plan ${targetClass.name} sınıfına başarıyla yüklendi.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.negLight,
            content: Text('Planlar kaydedilirken hata: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesProv = context.watch<ClassesProvider>();
    final appProv = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final targetClass = classesProv.classes.firstWhere(
      (c) => c.id == widget.targetClassId,
      orElse: () => ClassModel(
        id: widget.targetClassId,
        name: 'Sınıf',
        gradeLevel: '9',
        subject: 'Ders',
        academicYear: SettingsModel.defaultAcademicYear,
        color: '#17433B',
        studentCount: 0,
      ),
    );

    final subjectName = (targetClass.subject != null && targetClass.subject!.isNotEmpty)
        ? targetClass.subject!
        : 'Ders';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: 620,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Başlık ve Şablon Butonu
            Row(
              children: [
                const Text('📚', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Excel ile Yıllık Plan Yükle',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Text(
                        'Haftalık müfredat ve kazanımları topluca aktarın',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: _exportSampleExcelTemplate,
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text('Şablon İndir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Sabit Hedef Sınıf ve Ders Bilgi Rozeti (Değiştirilemez)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (isDark ? AppTheme.accent : AppTheme.brandLight).withOpacity(0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.class_rounded,
                    size: 22,
                    color: isDark ? AppTheme.accent : AppTheme.brandLight,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              targetClass.name,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.cardDark : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                subjectName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppTheme.accent : AppTheme.brandLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Yüklenecek plan sadece bu sınıfa ait ders programına atanacaktır.',
                          style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      appProv.activeAcademicYear,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tab veya Önizleme Durumu
            if (!_isParsed) ...[
              TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.brandLight,
                labelColor: isDark ? AppTheme.accent : AppTheme.brandLight,
                unselectedLabelColor: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                tabs: const [
                  Tab(icon: Icon(Icons.file_upload_outlined, size: 18), text: 'Excel Dosyası (.xlsx)'),
                  Tab(icon: Icon(Icons.content_paste_rounded, size: 18), text: 'Kopyala - Yapıştır'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // 1. Tab: Excel Dosyası Seçme
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.table_chart_rounded, size: 54, color: AppTheme.brandLight.withOpacity(0.8)),
                            const SizedBox(height: 12),
                            const Text(
                              'Yıllık Plan Excel Dosyanızı Seçin',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'MEB, EBA veya zümrenizden indirdiğiniz .xlsx dosyasındaki Hafta, Konu ve Kazanım sütunları otomatik tanınır.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              onPressed: _isLoadingFile ? null : _pickAndParseExcelFile,
                              icon: _isLoadingFile
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.folder_open_rounded),
                              label: Text(_isLoadingFile ? 'Ayrıştırılıyor...' : 'Excel Dosyası Seç (.xlsx)'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 2. Tab: Metin Yapıştırma
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Excel tablosundaki satırları kopyalayıp (Ctrl+C) aşağıdaki alana yapıştırın (Ctrl+V):',
                          style: TextStyle(fontSize: 11, color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: TextField(
                            controller: _pasteCtrl,
                            maxLines: null,
                            expands: true,
                            keyboardType: TextInputType.multiline,
                            decoration: const InputDecoration(
                              hintText: 'Hafta\tDönem\tKonu / Ünite\tKazanımlar\tEtkinlikler\n1\t1\tTemel Kavramlar\tKavramları açıklar\tSoru çözümü\n2\t1\tİkinci Hafta...\n...',
                              contentPadding: EdgeInsets.all(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _parsePastedText,
                          icon: const Icon(Icons.flash_on_rounded, size: 16),
                          label: const Text('Yapıştırılan Metni Ayrıştır'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Önizleme Alanı
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.posLight.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_parsedItems.length} Hafta Ayrıştırıldı',
                          style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.posLight, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _isParsed = false;
                      _parsedItems = [];
                    }),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Yeniden Seç', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.bgDark : AppTheme.bgLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppTheme.lineDark : AppTheme.lineLight),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: _parsedItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final item = _parsedItems[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.brandLight.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${item['week_no']}. Hft',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['topic'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                  ),
                                  if (item['learning_outcomes'] != null && item['learning_outcomes'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Kazanım: ${item['learning_outcomes']}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? AppTheme.mutedDark : AppTheme.mutedLight,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                value: _replaceExisting,
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('${targetClass.name} sınıfının mevcut planını temizle ve üzerine yaz', style: const TextStyle(fontSize: 12)),
                onChanged: (val) => setState(() => _replaceExisting = val ?? true),
              ),
              const SizedBox(height: 6),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : () => _saveParsedPlans(targetClass),
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_rounded),
                label: Text(_isSaving ? 'Kaydediliyor...' : '${_parsedItems.length} Haftalık Planı ${targetClass.name} Sınıfına Kaydet'),
              ),
            ],

            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
