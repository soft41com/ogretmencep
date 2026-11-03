/// Türkçe karakter duyarlı küçük harfe dönüştürme ve metin arama yardımcıları
class TurkishSearchHelper {
  /// 'İ' -> 'i', 'I' -> 'ı' dönüşümü yaparak Türkçe kurallarına uygun küçük harfe çevirir.
  static String toLower(String? text) {
    if (text == null || text.isEmpty) return '';
    return text
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase();
  }

  /// Türkçe kurallarına uygun arama kontrolü (source, query'yi içeriyor mu?)
  static bool contains(String? source, String query) {
    if (source == null || source.isEmpty) return false;
    final cleanQuery = toLower(query.trim());
    if (cleanQuery.isEmpty) return true;
    return toLower(source).contains(cleanQuery);
  }
}
