import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'searchable_field.dart';

/// js/modules/forms/multi-select-chips.js karşılığı.
///
/// Arama kutusundan seçilen değerler kutunun altında çip olarak birikir;
/// zaten seçilmiş olanlar listeden düşürülür. Kulüpler birden fazla alan
/// seçebilsin diye eklendi (tek alanlı eski davranış, tek çip ile aynı).
class MultiSelectChipsField extends StatelessWidget {
  const MultiSelectChipsField({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.hint,
    this.helperText,
    this.noResultText,
    this.emptyListText,
    this.maxSelection,
    this.icon,
    super.key,
  });

  final String label;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;
  final String? hint;

  /// Kutunun altındaki açıklama. Çoklu seçim mümkün olduğunu duyurmak için:
  /// kutu tek seçimlik göründüğü sürece kulüpler ikinci alanı eklemeyi hiç
  /// denemiyordu.
  final String? helperText;

  final String? noResultText;
  final String? emptyListText;

  /// Boş bırakılırsa sınır yoktur.
  final int? maxSelection;

  /// Arama kutusunun solunda duran simge (bkz. [SearchableField.icon]).
  final IconData? icon;

  bool get _atLimit =>
      maxSelection != null && selected.length >= maxSelection!;

  @override
  Widget build(BuildContext context) {
    // Seçilenler listeden düşürülür; aynı alan iki kez eklenemez.
    final List<String> available = options
        .where((String option) => !selected.contains(option))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SearchableField(
          label: label,
          icon: icon,
          // Kutu her zaman boş kalır: seçim çipe dönüşür, kutuda iz bırakmaz.
          value: '',
          options: available,
          enabled: enabled && !_atLimit,
          hint: hint,
          noResultText: noResultText,
          emptyListText: emptyListText,
          onSelected: (String value) {
            if (value.isEmpty || selected.contains(value)) return;
            onChanged(<String>[...selected, value]);
          },
        ),
        if (helperText != null) ...<Widget>[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              helperText!,
              style: TextStyle(fontSize: 12, color: context.inkMuted),
            ),
          ),
        ],
        if (selected.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String item in selected)
                _SelectionChip(
                  label: item,
                  enabled: enabled,
                  onRemove: () => onChanged(
                    selected.where((String s) => s != item).toList(),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SelectionChip extends StatelessWidget {
  const _SelectionChip({
    required this.label,
    required this.enabled,
    required this.onRemove,
  });

  final String label;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: BrandColors.red.withValues(
          alpha: context.isDarkMode ? 0.18 : 0.09,
        ),
        borderRadius: BorderRadius.circular(BrandShape.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: context.brandInk,
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            onPressed: enabled ? onRemove : null,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: Icon(Icons.close, size: 15, color: context.brandInk),
          ),
        ],
      ),
    );
  }
}
