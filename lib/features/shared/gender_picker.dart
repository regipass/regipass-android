import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_strings.dart';

/// info.html içindeki `gender-field` radyo grubunun mobil karşılığı.
///
/// Değerler web ile aynı iki dizedir (`male` / `female`); yönetici
/// istatistikleri bu iki değeri sayıyor (bkz. lib/domain/admin_stats.dart).
/// Seçilmemiş hâl boş dizedir — kaydetme doğrulaması burada değil, formun
/// kendi `_save` akışında yapılır.
class GenderPicker extends StatelessWidget {
  const GenderPicker({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            context.t('form.gender'),
            style: TextStyle(fontSize: 13, color: context.inkMuted),
          ),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: _GenderOption(
                label: context.t('form.genderMale'),
                icon: Icons.male,
                active: value == 'male',
                enabled: enabled,
                onTap: () => onChanged('male'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GenderOption(
                label: context.t('form.genderFemale'),
                icon: Icons.female,
                active: value == 'female',
                enabled: enabled,
                onTap: () => onChanged('female'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GenderOption extends StatelessWidget {
  const _GenderOption({
    required this.label,
    required this.icon,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fill = active
        ? BrandColors.redSoft
        : context.isDarkMode
        ? BrandColors.red.withValues(alpha: 0.16)
        : BrandColors.redTint;

    final Color foreground = active ? BrandColors.white : context.brandInk;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(BrandShape.controlRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
