import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

class HolidayService {
  HolidayService._internal();
  static final HolidayService instance = HolidayService._internal();

  /// Varsayılan tatil JSON dosya adresleri
  static const String defaultUrl2016 = 'https://dersprogram.okulsinav.com/json/2016tatil.json';
  static String getYearUrl(int year) => 'https://dersprogram.okulsinav.com/json/${year}tatil.json';

  /// Uzak sunucudan tatil günlerini çeker ve parse eder
  Future<List<HolidayModel>> fetchHolidaysFromRemote({int? year, String? customUrl}) async {
    final targetYear = year ?? DateTime.now().year;
    final urlsToTry = <String>[];

    // 1. Özel URL belirtilmişse öncelikle onu dene
    if (customUrl != null && customUrl.trim().isNotEmpty) {
      urlsToTry.add(customUrl.trim());
    }

    // 2. Yıla özel adres: https://dersprogram.okulsinav.com/json/{year}tatil.json (örn. 2026tatil.json veya 2027tatil.json)
    final yearUrl = getYearUrl(targetYear);
    if (!urlsToTry.contains(yearUrl)) {
      urlsToTry.add(yearUrl);
    }

    // 3. Kullanıcının belirttiği 2016tatil.json adresi (2026 için yedek bağlantı)
    if (targetYear == 2026 || targetYear == 2016) {
      if (!urlsToTry.contains(defaultUrl2016)) {
        urlsToTry.add(defaultUrl2016);
      }
    }

    String? responseBody;
    String? lastError;

    for (final url in urlsToTry) {
      try {
        debugPrint('Tatil verisi indiriliyor: $url');
        final uri = Uri.parse(url);
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 10)
          ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;

        final request = await client.getUrl(uri);
        final response = await request.close().timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          responseBody = await response.transform(utf8.decoder).join();
          client.close();
          break;
        } else {
          lastError = 'HTTP ${response.statusCode} (${uri.path})';
          client.close();
        }
      } catch (e) {
        lastError = e.toString();
        debugPrint('$url bağlantı hatası: $e');
      }
    }

    if (responseBody != null && responseBody.trim().isNotEmpty) {
      final holidays = parseHolidaysJson(responseBody, defaultYear: targetYear);
      if (holidays.isNotEmpty) {
        return holidays;
      }
    }

    // Eğer sunucuya erişilemediyse veya henüz sunucuya dosya yüklenmediyse
    // kullanıcıyı mağdur etmemek için yerleşik tatil verilerini döner.
    debugPrint('Sunucudan veri alınamadı ($lastError), yerleşik $targetYear tatil listesi kullanılıyor.');
    if (targetYear == 2026) {
      return getBuiltinHolidaysFor2026();
    } else if (targetYear == 2027) {
      return getBuiltinHolidaysFor2027();
    }

    throw Exception(lastError ?? '$targetYear yılı için tatil verileri indirilemedi.');
  }

  /// JSON metnini ayrıştırır ve çoklu günleri (ara tatiller vb.) tekil günlere genişletir
  List<HolidayModel> parseHolidaysJson(String jsonStr, {int? defaultYear}) {
    final List<HolidayModel> results = [];
    final dynamic decoded = jsonDecode(jsonStr);

    List<dynamic> items = [];
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map<String, dynamic>) {
      if (decoded['holidays'] is List) {
        items = decoded['holidays'] as List;
      } else if (decoded['tatiller'] is List) {
        items = decoded['tatiller'] as List;
      } else if (decoded['data'] is List) {
        items = decoded['data'] as List;
      }
    }

    final dateFormat = DateFormat('yyyy-MM-dd');

    for (final item in items) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);

      final startDateStr = map['date']?.toString() ?? map['start_date']?.toString();
      final endDateStr = map['end_date']?.toString();
      final name = map['name']?.toString() ?? map['title']?.toString() ?? 'Tatil';
      final type = map['type']?.toString() ?? 'official';
      final description = map['description']?.toString();
      final isHalfDay = map['is_half_day'] == true || map['is_half_day'] == 1;

      if (startDateStr == null || startDateStr.isEmpty) continue;

      try {
        final startDate = dateFormat.parse(startDateStr.trim());
        DateTime endDate = startDate;

        if (endDateStr != null && endDateStr.trim().isNotEmpty) {
          try {
            endDate = dateFormat.parse(endDateStr.trim());
          } catch (_) {}
        }

        // Eğer başlangıç ve bitiş arası bir aralıksa gün gün ekle
        DateTime current = startDate;
        while (!current.isAfter(endDate)) {
          final dateStr = dateFormat.format(current);
          results.add(HolidayModel(
            date: dateStr,
            name: name,
            type: type,
            description: description,
            isHalfDay: isHalfDay,
          ));
          current = current.add(const Duration(days: 1));
        }
      } catch (e) {
        debugPrint('Tarih ayrıştırma hatası ($startDateStr): $e');
      }
    }

    // Tarihe göre sırala
    results.sort((a, b) => a.date.compareTo(b.date));
    return results;
  }

  /// Çevrimdışı veya sunucu henüz kurulmadığında devreye giren 2026 Resmi & MEB Tatilleri
  List<HolidayModel> getBuiltinHolidaysFor2026() {
    const rawJson = '''
    [
      {"date": "2026-01-01", "name": "Yılbaşı", "type": "official", "is_half_day": false},
      {"date": "2026-01-19", "end_date": "2026-01-30", "name": "Yarıyıl Tatili (15 Tatil)", "type": "break", "is_half_day": false},
      {"date": "2026-03-19", "name": "Ramazan Bayramı Arifesi", "type": "religious", "is_half_day": true},
      {"date": "2026-03-20", "name": "Ramazan Bayramı 1. Gün", "type": "religious", "is_half_day": false},
      {"date": "2026-03-21", "name": "Ramazan Bayramı 2. Gün", "type": "religious", "is_half_day": false},
      {"date": "2026-03-22", "name": "Ramazan Bayramı 3. Gün", "type": "religious", "is_half_day": false},
      {"date": "2026-04-13", "end_date": "2026-04-17", "name": "2. Dönem Ara Tatili", "type": "break", "is_half_day": false},
      {"date": "2026-04-23", "name": "Ulusal Egemenlik ve Çocuk Bayramı", "type": "official", "is_half_day": false},
      {"date": "2026-05-01", "name": "Emek ve Dayanışma Günü", "type": "official", "is_half_day": false},
      {"date": "2026-05-19", "name": "Atatürk'ü Anma, Gençlik ve Spor Bayramı", "type": "official", "is_half_day": false},
      {"date": "2026-05-26", "name": "Kurban Bayramı Arifesi", "type": "religious", "is_half_day": true},
      {"date": "2026-05-27", "name": "Kurban Bayramı 1. Gün", "type": "religious", "is_half_day": false},
      {"date": "2026-05-28", "name": "Kurban Bayramı 2. Gün", "type": "religious", "is_half_day": false},
      {"date": "2026-05-29", "name": "Kurban Bayramı 3. Gün", "type": "religious", "is_half_day": false},
      {"date": "2026-05-30", "name": "Kurban Bayramı 4. Gün", "type": "religious", "is_half_day": false},
      {"date": "2026-07-15", "name": "Demokrasi ve Milli Birlik Günü", "type": "official", "is_half_day": false},
      {"date": "2026-08-30", "name": "Zafer Bayramı", "type": "official", "is_half_day": false},
      {"date": "2026-10-28", "name": "Cumhuriyet Bayramı Arifesi", "type": "official", "is_half_day": true},
      {"date": "2026-10-29", "name": "Cumhuriyet Bayramı", "type": "official", "is_half_day": false},
      {"date": "2026-11-16", "end_date": "2026-11-20", "name": "1. Dönem Ara Tatili", "type": "break", "is_half_day": false}
    ]
    ''';
    return parseHolidaysJson(rawJson, defaultYear: 2026);
  }

  /// Çevrimdışı veya sunucu henüz kurulmadığında devreye giren 2027 Resmi & MEB Tatilleri
  List<HolidayModel> getBuiltinHolidaysFor2027() {
    const rawJson = '''
    [
      {"date": "2027-01-01", "name": "Yılbaşı", "type": "official", "is_half_day": false},
      {"date": "2027-01-18", "end_date": "2027-01-29", "name": "Yarıyıl Tatili (15 Tatil)", "type": "break", "is_half_day": false},
      {"date": "2027-03-09", "name": "Ramazan Bayramı Arifesi", "type": "religious", "is_half_day": true},
      {"date": "2027-03-10", "name": "Ramazan Bayramı 1. Gün", "type": "religious", "is_half_day": false},
      {"date": "2027-03-11", "name": "Ramazan Bayramı 2. Gün", "type": "religious", "is_half_day": false},
      {"date": "2027-03-12", "name": "Ramazan Bayramı 3. Gün", "type": "religious", "is_half_day": false},
      {"date": "2027-04-12", "end_date": "2027-04-16", "name": "2. Dönem Ara Tatili", "type": "break", "is_half_day": false},
      {"date": "2027-04-23", "name": "Ulusal Egemenlik ve Çocuk Bayramı", "type": "official", "is_half_day": false},
      {"date": "2027-05-01", "name": "Emek ve Dayanışma Günü", "type": "official", "is_half_day": false},
      {"date": "2027-05-16", "name": "Kurban Bayramı Arifesi", "type": "religious", "is_half_day": true},
      {"date": "2027-05-17", "name": "Kurban Bayramı 1. Gün", "type": "religious", "is_half_day": false},
      {"date": "2027-05-18", "name": "Kurban Bayramı 2. Gün", "type": "religious", "is_half_day": false},
      {"date": "2027-05-19", "name": "Atatürk'ü Anma, Gençlik ve Spor Bayramı", "type": "official", "is_half_day": false},
      {"date": "2027-05-20", "name": "Kurban Bayramı 4. Gün", "type": "religious", "is_half_day": false},
      {"date": "2027-07-15", "name": "Demokrasi ve Milli Birlik Günü", "type": "official", "is_half_day": false},
      {"date": "2027-08-30", "name": "Zafer Bayramı", "type": "official", "is_half_day": false},
      {"date": "2027-10-28", "name": "Cumhuriyet Bayramı Arifesi", "type": "official", "is_half_day": true},
      {"date": "2027-10-29", "name": "Cumhuriyet Bayramı", "type": "official", "is_half_day": false},
      {"date": "2027-11-15", "end_date": "2027-11-19", "name": "1. Dönem Ara Tatili", "type": "break", "is_half_day": false}
    ]
    ''';
    return parseHolidaysJson(rawJson, defaultYear: 2027);
  }
}
