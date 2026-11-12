import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/database_helper.dart';
import '../models/models.dart';

class NotesProvider with ChangeNotifier {
  List<DailyNoteModel> _notes = [];
  bool _isLoading = false;

  List<DailyNoteModel> get notes => _notes;
  bool get isLoading => _isLoading;

  /// Tüm notları veritabanından çeker (En son oluşturulan en üstte)
  Future<void> fetchNotes() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query(
        'daily_notes',
        orderBy: 'created_at DESC, id DESC',
      );
      _notes = res.map((r) => DailyNoteModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('NotesProvider fetchNotes error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Seçili gün ve tarihe uyan notları filtreler
  /// isRecurring == true ise: weekday kontrolü (örn. her Perşembe)
  /// isRecurring == false ise: date kontrolü (YYYY-MM-DD eşleşmesi)
  List<DailyNoteModel> getNotesForDay(int weekday, DateTime targetDate) {
    final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
    return _notes.where((n) {
      if (n.isRecurring) {
        return n.weekday == weekday;
      } else {
        if (n.date != null && n.date!.isNotEmpty) {
          return n.date == dateStr;
        }
        return n.weekday == weekday;
      }
    }).toList();
  }

  /// Yeni not ekler
  Future<DailyNoteModel?> addNote({
    String? title,
    required String content,
    String? date,
    int? weekday,
    bool isRecurring = false,
    String? color,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().toIso8601String();
      final noteData = {
        'title': title,
        'content': content.trim(),
        'date': isRecurring ? null : date,
        'weekday': weekday,
        'is_recurring': isRecurring ? 1 : 0,
        'color': color,
        'created_at': now,
        'updated_at': now,
      };

      final id = await db.insert('daily_notes', noteData);
      final newNote = DailyNoteModel(
        id: id,
        title: title,
        content: content.trim(),
        date: isRecurring ? null : date,
        weekday: weekday,
        isRecurring: isRecurring,
        color: color,
        createdAt: now,
        updatedAt: now,
      );

      _notes.insert(0, newNote);
      notifyListeners();
      return newNote;
    } catch (e) {
      debugPrint('NotesProvider addNote error: $e');
      return null;
    }
  }

  /// Mevcut notu günceller
  Future<bool> updateNote(DailyNoteModel note) async {
    if (note.id == null) return false;
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().toIso8601String();
      final updatedNote = note.copyWith(
        content: note.content.trim(),
        updatedAt: now,
      );

      await db.update(
        'daily_notes',
        updatedNote.toMap(),
        where: 'id = ?',
        whereArgs: [note.id],
      );

      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = updatedNote;
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('NotesProvider updateNote error: $e');
      return false;
    }
  }

  /// Notu siler
  Future<bool> deleteNote(int id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'daily_notes',
        where: 'id = ?',
        whereArgs: [id],
      );

      _notes.removeWhere((n) => n.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('NotesProvider deleteNote error: $e');
      return false;
    }
  }
}
