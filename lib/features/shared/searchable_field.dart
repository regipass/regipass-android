/// js/modules/forms/searchable-input.js portu.
///
/// Kritik davranış: kullanıcı serbest metin yazabilir, ancak Firestore'a
/// **yalnızca listedeki kanonik değer** yazılır. Web'de `findCanonicalOption`
/// bunu sağlıyordu; aynı kural burada da geçerli — aksi hâlde etkinlik
/// hedefleme (üniversite/bölüm eşleşmesi) bozulur.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/input_guard.dart';
import '../../core/text_utils.dart';

/// Değer listede varsa kanonik yazımını, yoksa boş dize döner.
String findCanonicalOption(String? value, List<String> options) {
  final String normalized = foldTr(value);
  if (normalized.isEmpty) return '';

  for (final String option in options) {
    if (foldTr(option) == normalized) return option;
  }
  return '';
}

/// Basit Levenshtein — "bunu mu demek istediniz" sıralaması için.
int levenshteinDistance(String a, String b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  List<int> previous = List<int>.generate(b.length + 1, (int i) => i);
  final List<int> current = List<int>.filled(b.length + 1, 0);

  for (int i = 1; i <= a.length; i++) {
    current[0] = i;
    for (int j = 1; j <= b.length; j++) {
      final int cost = a[i - 1] == b[j - 1] ? 0 : 1;
      current[j] = <int>[
        previous[j] + 1,
        current[j - 1] + 1,
        previous[j - 1] + cost,
      ].reduce((int x, int y) => x < y ? x : y);
    }
    previous = List<int>.of(current);
  }

  return previous[b.length];
}

/// Arama sonuçlarını puanlar: önce tam eşleşme, sonra baştan eşleşme,
/// sonra içerme, en sonda yazım hatası toleransı.
List<String> rankOptions(String query, List<String> options, {int limit = 30}) {
  final String q = foldTr(query);
  if (q.isEmpty) return options.take(limit).toList();

  final List<MapEntry<String, int>> scored = <MapEntry<String, int>>[];

  for (final String option in options) {
    final String o = foldTr(option);
    int score = 0;

    if (o == q) {
      score = 1000;
    } else if (o.startsWith(q)) {
      score = 700 + (q.length * 100 ~/ o.length);
    } else if (o.split(' ').any((String token) => token.startsWith(q))) {
      score = 500;
    } else if (o.contains(q)) {
      score = 300;
    } else if (q.length >= 4) {
      // Yazım hatası toleransı yalnızca uzun sorgularda; kısa sorgularda
      // yanlış eşleşme oranı çok yükseliyor.
      final int distance = levenshteinDistance(q, o);
      if (distance <= 2) score = 150 - distance * 10;
    }

    if (score > 0) scored.add(MapEntry<String, int>(option, score));
  }

  scored.sort((MapEntry<String, int> a, MapEntry<String, int> b) {
    final int byScore = b.value.compareTo(a.value);
    return byScore != 0 ? byScore : compareTr(a.key, b.key);
  });

  return scored.take(limit).map((MapEntry<String, int> e) => e.key).toList();
}

/// Aranabilir, tam ekran seçim sayfası açan alan.
///
/// Mobilde açılır liste yerine tam ekran arama kullanılır: 612 bölüm ya da
/// 200+ üniversite arasından klavyeyle seçim, küçük ekranda böyle çok daha
/// kullanışlı.
class SearchableField extends StatelessWidget {
  const SearchableField({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
    this.enabled = true,
    this.searchable = true,
    this.emptyListText,
    this.noResultText,
    this.hint,
    this.icon,
    super.key,
  });

  final String label;

  /// Seçili kanonik değer ('' = seçim yok).
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final bool enabled;

  /// Seçim sayfasında arama çubuğu gösterilsin mi. Sınıf gibi bir ekrana
  /// sığan kısa listelerde arama gereksiz — kapatınca doğrudan liste açılır.
  final bool searchable;

  /// Seçenek listesi boşken gösterilecek metin (ör. "Önce şehir seçin").
  final String? emptyListText;
  final String? noResultText;
  final String? hint;

  /// Etiketin solunda duran simge. Uzun formlarda alanları okumadan ayırt
  /// etmeyi sağlar; verilmezse alan eskisi gibi simgesiz çizilir.
  final IconData? icon;

  Future<void> _open(BuildContext context) async {
    if (!enabled) return;

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emptyListText ?? 'Seçenek bulunmuyor.')),
      );
      return;
    }

    final String? picked = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) => _SearchablePickerPage(
          title: label,
          options: options,
          selected: value,
          searchable: searchable,
          noResultText: noResultText ?? 'Sonuç bulunamadı.',
        ),
      ),
    );

    if (picked != null) onSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasValue = value.isNotEmpty;

    return InkWell(
      onTap: enabled ? () => _open(context) : null,
      borderRadius: BorderRadius.circular(BrandShape.controlRadius),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          prefixIcon: icon == null
              ? null
              : Icon(icon, size: 20, color: context.inkMuted),
          suffixIcon: Icon(Icons.expand_more, color: context.inkMuted),
        ),
        child: Text(
          hasValue ? value : (hint ?? 'Seçiniz'),
          style: TextStyle(
            color: hasValue ? context.ink : context.inkMuted,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _SearchablePickerPage extends StatefulWidget {
  const _SearchablePickerPage({
    required this.title,
    required this.options,
    required this.selected,
    required this.searchable,
    required this.noResultText,
  });

  final String title;
  final List<String> options;
  final String selected;
  final bool searchable;
  final String noResultText;

  @override
  State<_SearchablePickerPage> createState() => _SearchablePickerPageState();
}

class _SearchablePickerPageState extends State<_SearchablePickerPage> {
  String _query = '';
  late List<String> _results = widget.options;

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
      _results = value.trim().isEmpty
          ? widget.options
          : rankOptions(value, widget.options, limit: 60);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: <Widget>[
          if (widget.searchable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                autofocus: true,
                onChanged: _onQueryChanged,
                inputFormatters: guardedInput(InputLimits.search),
                decoration: const InputDecoration(
                  hintText: 'Ara...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        widget.noResultText,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.inkMuted),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = _results[index];
                      final bool isSelected = option == widget.selected;

                      return ListTile(
                        title: Text(option),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: BrandColors.red)
                            : null,
                        selected: isSelected,
                        onTap: () => Navigator.of(context).pop(option),
                      );
                    },
                  ),
          ),
          if (_query.isNotEmpty && _results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '${_results.length} sonuç',
                style: TextStyle(color: context.inkMuted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
