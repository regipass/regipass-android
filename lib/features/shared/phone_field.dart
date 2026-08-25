/// js/modules/forms/phone-input.js portu.
///
/// Ülke kodu seçimi + ulusal numara -> E.164. Doğrulama kuralı web ile aynı:
/// hane sayısı ülkenin [min]..[max] aralığında olmalı.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/input_guard.dart';
import '../../data/country_codes.dart';
import '../../l10n/app_strings.dart';

/// Uzun arama kodları önce denenecek şekilde sıralı liste
/// (ör. "+1" ile "+1242" karışmasın).
final List<CountryCode> _byDialDesc = List<CountryCode>.of(kCountryCodes)
  ..sort(
    (CountryCode a, CountryCode b) => b.dial.length.compareTo(a.dial.length),
  );

CountryCode findCountry(String code) => kCountryCodes.firstWhere(
  (CountryCode c) => c.code == code,
  orElse: () => kCountryCodes.first,
);

/// E.164 numarayı bayrak + arama kodu + gruplanmış hanelerle gösterir.
/// Örn. "+905551234567" -> "🇹🇷 +90 555 123 45 67"
String formatE164ForDisplay(String? e164) {
  final String value = (e164 ?? '').trim();
  if (!value.startsWith('+')) return value;

  CountryCode? match;
  for (final CountryCode c in _byDialDesc) {
    if (value.startsWith(c.dial)) {
      match = c;
      break;
    }
  }
  if (match == null) return value;

  final String digits = value
      .substring(match.dial.length)
      .replaceAll(RegExp(r'\D'), '');

  // Türkiye için 3-3-2-2 gruplaması, diğerleri için 3'lü bloklar.
  final String grouped = match.code == 'TR' && digits.length == 10
      ? '${digits.substring(0, 3)} ${digits.substring(3, 6)} '
            '${digits.substring(6, 8)} ${digits.substring(8)}'
      : _groupBy3(digits);

  return '${match.flag} ${match.dial} $grouped'.trim();
}

/// E.164 numarayı maskeler: son [visibleCount] hane açık, gerisi `X`.
///   +905551234567  ->  "+90 XXX XXX XX 67"
///
/// js/modules/forms/phone-input.js#maskE164ForDisplay ile aynı çıktıyı
/// üretmek zorunda: `phone_hints` belgelerini web ve mobil birlikte yazıyor,
/// biçim ayrışırsa aynı kullanıcı iki farklı maske görür.
///
/// Gruplama gerçek hane sayısına göre seçilir; ülkenin sabit deseni ancak
/// toplamı bu uzunluğa eşitse kullanılır, aksi hâlde 3'lü bloklara düşülür.
String maskE164ForDisplay(String? e164, {int visibleCount = 2}) {
  final String value = (e164 ?? '').trim();
  if (!value.startsWith('+')) return '';

  CountryCode? match;
  for (final CountryCode c in _byDialDesc) {
    if (value.startsWith(c.dial)) {
      match = c;
      break;
    }
  }
  if (match == null) return '';

  final String digits = value
      .substring(match.dial.length)
      .replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';

  final int keep = visibleCount < digits.length ? visibleCount : digits.length;
  final String masked =
      'X' * (digits.length - keep) + digits.substring(digits.length - keep);

  // Türkiye'de 10 hane 3-3-2-2; diğerlerinde 3'lü bloklar.
  final String grouped = match.code == 'TR' && masked.length == 10
      ? '${masked.substring(0, 3)} ${masked.substring(3, 6)} '
            '${masked.substring(6, 8)} ${masked.substring(8)}'
      : _groupBy3(masked);

  return '${match.dial} $grouped'.trim();
}

String _groupBy3(String digits) {
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < digits.length; i += 3) {
    if (i > 0) out.write(' ');
    out.write(digits.substring(i, (i + 3).clamp(0, digits.length)));
  }
  return out.toString();
}

/// Giriş sırasında hint'teki X gruplarına göre görünür boşluk ekler.
/// Türkiye için `5xx xxx xx xx`, diğer ülkeler için 3'lü bloklar kullanılır.
String formatNationalDigits(String digits, CountryCode country) {
  final String clean = digits.replaceAll(RegExp(r'\D'), '');
  if (country.code == 'TR' && clean.length <= 10) {
    final List<String> groups = <String>[];
    if (clean.isNotEmpty) {
      groups.add(clean.substring(0, clean.length.clamp(0, 3)));
    }
    if (clean.length > 3) {
      groups.add(clean.substring(3, clean.length.clamp(3, 6)));
    }
    if (clean.length > 6) {
      groups.add(clean.substring(6, clean.length.clamp(6, 8)));
    }
    if (clean.length > 8) groups.add(clean.substring(8));
    return groups.join(' ');
  }
  return _groupBy3(clean);
}

int _formattedOffsetForDigits(String formatted, int digitCount) {
  if (digitCount <= 0) return 0;
  int seen = 0;
  for (int i = 0; i < formatted.length; i++) {
    if (RegExp(r'\d').hasMatch(formatted[i])) {
      seen++;
      if (seen >= digitCount) return i + 1;
    }
  }
  return formatted.length;
}

/// Telefon alanının denetleyicisi — form tarafı `isValid` ve `e164` okur.
class PhoneFieldController extends ChangeNotifier {
  PhoneFieldController({String? initialE164}) {
    if (initialE164 != null) setValue(initialE164);
  }

  final TextEditingController text = TextEditingController();
  CountryCode _country = findCountry(kDefaultCountry);

  CountryCode get country => _country;

  /// Yalnızca haneler; trunk ön eki (ör. baştaki 0) atılır.
  String get digits {
    String raw = text.text.replaceAll(RegExp(r'\D'), '');
    final String trunk = _country.trunk;
    if (trunk.isNotEmpty &&
        raw.startsWith(trunk) &&
        raw.length > _country.min) {
      raw = raw.substring(trunk.length);
    }
    return raw;
  }

  /// Türkiye cep telefonu numaraları ulusal bölümde 5 ile başlar.
  bool get hasInvalidPrefix =>
      _country.code == 'TR' && digits.isNotEmpty && !digits.startsWith('5');

  bool get isValid =>
      !hasInvalidPrefix &&
      digits.length >= _country.min &&
      digits.length <= _country.max;

  String get e164 => '${_country.dial}$digits';

  void selectCountry(CountryCode next) {
    final String current = digits;
    _country = next;
    final String formatted = formatNationalDigits(current, next);
    text.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    notifyListeners();
  }

  /// Kayıtlı E.164 değerini alana geri yükler (profil düzenleme).
  void setValue(String? stored) {
    final String value = (stored ?? '').trim();
    if (value.isEmpty) return;

    if (value.startsWith('+')) {
      for (final CountryCode c in _byDialDesc) {
        if (value.startsWith(c.dial)) {
          _country = c;
          final String digits = value
              .substring(c.dial.length)
              .replaceAll(RegExp(r'\D'), '');
          text.text = formatNationalDigits(digits, c);
          notifyListeners();
          return;
        }
      }
    }

    text.text = formatNationalDigits(
      value.replaceAll(RegExp(r'\D'), ''),
      _country,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }
}

class PhoneField extends StatefulWidget {
  const PhoneField({
    required this.controller,
    this.label = 'Telefon',
    this.enabled = true,
    this.errorText,
    this.onChanged,
    this.focusNode,
    super.key,
  });

  final PhoneFieldController controller;
  final String label;
  final bool enabled;

  /// Dışarıdan verilirse alanın odağı çağıran taraftan yönetilebilir — bilgi
  /// formlarında soyad alanının "ileri" tuşu odağı buraya taşıyor. Verilmezse
  /// alan kendi düğümünü oluşturur.
  final FocusNode? focusNode;

  /// Alanın altında gösterilecek, dışarıdan gelen hata — ör. "bu numara başka
  /// bir hesaba ait" (sahiplik sorgusu) ya da kaydetme anındaki doğrulama.
  /// Doluyken alanın kendi uzunluk/ön ek uyarısının önüne geçer.
  final String? errorText;

  /// Kullanıcı numarayı değiştirdiğinde tetiklenir; çağıran taraf bunu
  /// [errorText] ile gösterdiği hatayı temizlemek için kullanır.
  final VoidCallback? onChanged;

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  /// Dışarıdan düğüm verilmediyse oluşturulan düğüm; yalnızca onu atmalıyız.
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  /// Kullanıcı alanı bir kez doldurup çıktı mı? Uzunluk uyarısı ancak bundan
  /// sonra gösterilir — aksi hâlde ilk haneyi yazdığı anda "10 haneli olmalı"
  /// uyarısını görürdü.
  bool _leftFieldWithContent = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(PhoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;

    (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocusChanged);
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.removeListener(_onFocusChanged);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (!_focus.hasFocus && widget.controller.text.text.isNotEmpty) {
      _leftFieldWithContent = true;
    }
    if (mounted) setState(() {});
  }

  /// Öncelik sırası: dışarıdan gelen hata → yanlış operatör ön eki (yazıldığı
  /// anda belli) → eksik/fazla hane (yalnızca alandan çıkıldıktan sonra).
  String? _resolveError() {
    final String? external = widget.errorText;
    if (external != null && external.isNotEmpty) return external;

    final PhoneFieldController controller = widget.controller;
    if (controller.text.text.isEmpty) return null;
    if (controller.hasInvalidPrefix) {
      return context.t('form.phoneOperatorPrefix');
    }
    if (controller.isValid) return null;
    if (!_leftFieldWithContent) return null;

    final CountryCode country = controller.country;
    final String digits = country.min == country.max
        ? '${country.min}'
        : '${country.min}-${country.max}';
    return '$digits haneli olmalı';
  }

  Future<void> _pickCountry() async {
    final CountryCode? picked = await showModalBottomSheet<CountryCode>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CountryPickerSheet(),
    );
    if (picked != null) widget.controller.selectCountry(picked);
  }

  @override
  Widget build(BuildContext context) {
    final CountryCode country = widget.controller.country;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          onTap: widget.enabled ? _pickCountry : null,
          borderRadius: BorderRadius.circular(BrandShape.controlRadius),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: context.hairline),
              borderRadius: BorderRadius.circular(BrandShape.controlRadius),
              color: context.surface,
            ),
            child: Row(
              children: <Widget>[
                Text(country.flag, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Text(
                  country.dial,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Icon(Icons.expand_more, size: 18, color: context.inkMuted),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: widget.controller.text,
            focusNode: _focus,
            enabled: widget.enabled,
            keyboardType: TextInputType.phone,
            inputFormatters: <TextInputFormatter>[
              TextInputFormatter.withFunction((
                TextEditingValue oldValue,
                TextEditingValue newValue,
              ) {
                final String raw = newValue.text.replaceAll(RegExp(r'\D'), '');
                final int maxDigits = country.max + country.trunk.length;
                final String limited = raw.length > maxDigits
                    ? raw.substring(0, maxDigits)
                    : raw;
                final String formatted = formatNationalDigits(limited, country);
                final int cursor = newValue.selection.baseOffset.clamp(
                  0,
                  newValue.text.length,
                );
                final int digitsBeforeCursor = newValue.text
                    .substring(0, cursor)
                    .replaceAll(RegExp(r'\D'), '')
                    .length;
                return TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(
                    offset: _formattedOffsetForDigits(
                      formatted,
                      digitsBeforeCursor.clamp(0, limited.length),
                    ),
                  ),
                  composing: TextRange.empty,
                );
              }),
            ],
            // Numara klavyesinin "bitti" tuşu: başka alana atlamak yerine
            // klavyeyi kapatır — telefon formun son yazılan alanı ve rakam
            // klavyesi açık kaldığında altındaki seçim alanlarını örtüyordu.
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _focus.unfocus(),
            onChanged: (_) {
              setState(() {});
              widget.onChanged?.call();
            },
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: '5xx xxx xx xx',
              // Sahiplik uyarısı gibi uzun metinler tek satıra sığmıyor.
              errorMaxLines: 3,
              errorText: _resolveError(),
            ),
          ),
        ),
      ],
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet();

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  List<CountryCode> _results = kCountryCodes;

  void _search(String query) {
    final String q = query.trim().toLowerCase();
    setState(() {
      _results = q.isEmpty
          ? kCountryCodes
          : kCountryCodes
                .where(
                  (CountryCode c) =>
                      c.name.toLowerCase().contains(q) ||
                      c.dial.contains(q) ||
                      c.code.toLowerCase().contains(q),
                )
                .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) =>
          Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  autofocus: true,
                  onChanged: _search,
                  inputFormatters: guardedInput(InputLimits.search),
                  decoration: const InputDecoration(
                    hintText: 'Ülke ara...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _results.length,
                  itemBuilder: (BuildContext context, int index) {
                    final CountryCode c = _results[index];
                    return ListTile(
                      leading: Text(
                        c.flag,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(c.name),
                      trailing: Text(
                        c.dial,
                        style: const TextStyle(color: BrandColors.muted),
                      ),
                      onTap: () => Navigator.of(context).pop(c),
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }
}
