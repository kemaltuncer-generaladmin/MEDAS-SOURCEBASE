class UniversityCatalog {
  UniversityCatalog._();

  static const List<String> all = [
    'Acıbadem Mehmet Ali Aydınlar Üniversitesi',
    'Ankara Üniversitesi',
    'Atatürk Üniversitesi',
    'Başkent Üniversitesi',
    'Bezmialem Vakıf Üniversitesi',
    'Cerrahpaşa Tıp Fakültesi',
    'Dokuz Eylül Üniversitesi',
    'Ege Üniversitesi',
    'Erciyes Üniversitesi',
    'Gazi Üniversitesi',
    'Hacettepe Üniversitesi',
    'İstanbul Medipol Üniversitesi',
    'İstanbul Üniversitesi',
    'Koç Üniversitesi',
    'Marmara Üniversitesi',
    'Ondokuz Mayıs Üniversitesi',
    'Sağlık Bilimleri Üniversitesi',
    'Selçuk Üniversitesi',
    'Trakya Üniversitesi',
    'Uludağ Üniversitesi',
    'Yeditepe Üniversitesi',
  ];

  static String _fold(String value) => value
      .toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ı', 'i')
      .replaceAll('i̇', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u')
      .trim();

  static List<String> matches(String query) {
    final normalized = _fold(query);
    if (normalized.isEmpty) return all.take(8).toList();
    return all.where((u) => _fold(u).contains(normalized)).toList();
  }
}
