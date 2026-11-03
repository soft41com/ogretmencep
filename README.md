# ÖğretmenCep - Mobil Android Uygulaması (Flutter & Yerel SQLite)

Bu uygulama, öğretmenlerin günlük sınıf yönetimi, ders programı takibi, yoklama, performans değerlendirme (+ / - puanlama), sınav notları ve yıllık planlarını **tamamen çevrimdışı (offline)** olarak doğrudan mobil cihazlarında yönetebilmeleri için Flutter ile geliştirilmiştir.

Uygulama **bulut sunucu veya PHP API'ye ihtiyaç duymaz**. Tüm veriler cihazın yerel depolama alanında **SQLite veritabanında (`ogretmencep.db`)** güvenli bir şekilde saklanır.

---

## 📱 Temel Özellikler

1. **Bugün & Canlı Ders Programı (`HomeScreen`):**
   - Güncel saat ve ders ziline göre **"Şu Anki / Sıradaki Ders"** altın vurgulu canlı kartı.
   - Tek tıkla ilgili ders için **Yoklama Al** veya **Haftalık Planı Gör** aksiyonları.
   - Pazartesi - Cuma hap sekmeleri ile günlük program akışı.

2. **Sınıflar & Öğrenciler (`ClassesScreen` & `ClassDetailScreen`):**
   - Sınıf kartları (öğrenci sayıları, ders ve kademe rozetleri).
   - **Sadeleştirilmiş Sınıf Ekleme:** Sınıf eklerken eğitim-öğretim yılı sormaz, Ayarlar'daki merkezi yılı otomatik kullanır.
   - **📊 1 Tıkla Excel / e-Okul'dan Toplu Öğrenci Aktarımı:** e-Okul veya Excel'den kopyalanan listeyi doğrudan yapıştırarak saniyeler içinde tüm sınıfı oluşturma.
   - Öğrenci kartları, fotoğraflı profiller, numaralar ve veli iletişim bilgileri.
   - **🎲 "Kim Kalksın?" (Rastgele Öğrenci Seçici):** Sınıf içinden tahtaya kaldırmak için animasyonlu rastgele kura çekimi ve anında tahta performansı (+1 / -1) puanlama.
   - **Hızlı Artı/Eksi Değerlendirmesi:** Her öğrenciye tek dokunuşla +1 veya -1 verme.
   - **Öğrenci Akışı & Notlar:** Gözlem, Davranış, Veli Görüşmesi veya Akademik notlar ekleme ve geçmiş akışını görüntüleme.

3. **Haftalık Hızlı Ders Matrisi (`TimetableMatrixScreen`):**
   - 5 Gün x 8 Ders Saati interaktif haftalık tablo görünümü.
   - **⚡ Hızlı Doldurma (Damga) Modu:** Sınıf ve dersi üstten seçip boş hücrelere dokunarak 30 saniyede tüm haftayı doldurma imkanı.
   - **📊 Toplu Program Aktarımı:** Panodan veya Excel'den ders programı satırlarını yapıştırarak otomatik doldurma.

4. **Yoklama Modülü (`AttendanceScreen`):**
   - Tarih ve sınıf seçimi.
   - **Tümünü Geldi Yap** hızlı butonu.
   - Durum hap butonları: 🟢 Geldi, 🔴 Gelmedi, 🟡 Geç, 🔵 İzinli, 🟣 Raporlu.

5. **Sınavlar & Not Girişi (`ExamsScreen`):**
   - Yazılı, sözlü, proje ve performans sınavı oluşturma.
   - Sınıf listesi üzerinden hızlı not girişi ve otomatik sınıf ortalaması hesaplama.

6. **Yıllık Ders Planları & Müfredat (`PlansScreen`):**
   - 36 haftalık MEB müfredat konuları ve kazanım listesi.
   - Tamamlanan haftaları işaretleme ve ilerleme çubuğu takibi.

7. **Ayarlar & Yerel Yedekleme (`SettingsScreen`):**
   - Açık, Koyu ve Sistem tema modu.
   - Öğretmen Profili (Ad Soyad, Okul, Branş).
   - **Merkezi Eğitim-Öğretim Yılı:** Hızlı seçim butonları (2024-2025, 2025-2026, 2026-2027) ile tek tıkla güncelleme.
   - Zil Saatleri (Ders Periyotları) düzenleme.
   - **Veritabanını Dışa Aktar (JSON / SQLite):** Tek dokunuşla tüm verileri yedekleyip WhatsApp, e-posta veya Google Drive'a paylaşma.

---

## 🏗️ Mimari & Klasör Yapısı

```
app/
├── android/                   # Yerel Android proje yapılandırması
├── lib/
│   ├── data/
│   │   └── database_helper.dart  # SQLite veritabanı (11 tablo, yabancı anahtarlar, cascade silme)
│   ├── models/
│   │   └── models.dart           # Sınıf, Öğrenci, Yoklama, Sınav, Plan domain modelleri
│   ├── providers/
│   │   ├── app_provider.dart        # Global ayarlar ve tema durumu
│   │   ├── classes_provider.dart    # Sınıf işlemleri ve öğrenci sayıları
│   │   ├── students_provider.dart   # Öğrenciler, +/- puanlar, timeline ve toplu aktarım
│   │   ├── schedule_provider.dart   # Ders programı ve zil saatleri
│   │   ├── attendance_provider.dart # Yoklama alma ve durum kaydı
│   │   ├── exams_provider.dart      # Sınavlar ve not hesaplama
│   │   └── plans_provider.dart      # Yıllık plan ve kazanım takibi
│   ├── screens/
│   │   ├── home_shell.dart          # 5 sekmeli alt gezinme çubuğu (BottomNavigationBar)
│   │   ├── home_screen.dart         # Bugün ve canlı ders ekranı
│   │   ├── classes_screen.dart      # Sınıflar ekranı
│   │   ├── class_detail_screen.dart # Öğrenci listesi, Kim Kalksın? ve akış
│   │   ├── attendance_screen.dart   # Yoklama ekranı
│   │   ├── exams_screen.dart        # Sınavlar ekranı
│   │   ├── plans_screen.dart        # Müfredat planları ekranı
│   │   ├── settings_screen.dart     # Ayarlar ve yedekleme ekranı
│   │   ├── timetable_matrix_screen.dart # 5x8 hızlı damga ders matrisi
│   │   └── dialogs/
│   │       ├── bulk_student_import_dialog.dart # e-Okul / Excel toplu öğrenci aktarım
│   │       └── bulk_timetable_import_dialog.dart # Toplu program aktarım
│   ├── theme/
│   │   └── app_theme.dart           # Web arayüzü ile birebir uyumlu açık/koyu tasarım sistemi
│   └── main.dart                    # MultiProvider başlatıcı ve ana uygulama
└── pubspec.yaml                     # Bağımlılıklar (sqflite, provider, intl, csv, excel...)
```

---

## 🚀 Çalıştırma ve APK Üretme

### 1. Uygulamayı Geliştirme Modunda Çalıştırma:
```bash
cd app
flutter run
```

### 2. Android APK Üretme (Cihaza Yüklenebilir):
```bash
cd app
flutter build apk --release
```
Üretilen APK dosyası: `app/build/app/outputs/flutter-apk/app-release.apk`

---

## 🔒 Gizlilik & Güvenlik
- Bu uygulama **%100 internetsiz** çalışır.
- Hiçbir öğrenci adı, numarası veya notu harici bir sunucuya gönderilmez.
- Tüm veriler cihazınızın güvenli SQLite deposunda tutulur.
