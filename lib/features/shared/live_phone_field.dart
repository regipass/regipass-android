/// Telefon alanının canlı sahiplik kontrolü yapan sürümü.
///
/// Kullanıcı numarayı yazarken (hiçbir düğmeye basmadan, sayfa yenilenmeden)
/// numaranın başka bir hesaba ait olup olmadığı sorulur ve sonuç doğrudan
/// alanın altında görünür: sorgu sürerken "kontrol ediliyor", numara serbestse
/// "kullanılabilir", başkasına aitse hata. Kaydetme anındaki kontrol yine de
/// kalır: kullanıcı numarayı yazıp hemen kaydete basarsa sorgu daha bitmemiş
/// olabilir.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/app_strings.dart';
import '../../services/phone_directory_repository.dart';
import '../../state/providers.dart';
import 'phone_field.dart';

/// Sorgu, kullanıcı yazmayı bıraktıktan bu kadar sonra yapılır. Her tuşta
/// Firestore'a gitmemek için; numara zaten ancak tamamlandığında geçerli olur.
const Duration _kDebounce = Duration(milliseconds: 450);

/// Sahiplik sonucunun kullanıcıya gösterilecek karşılığı. Numara
/// kullanılabilir durumdaysa (`free`, `mine`, `unknown`) `null` döner —
/// sorgunun yapılamadığı durumda akış durmaz, Firebase Auth telefon bağlama
/// adımında ikinci bir kontrol daha yapılır.
String? phoneOwnershipError(BuildContext context, PhoneOwnership ownership) =>
    switch (ownership) {
      PhoneOwnership.takenByOther => context.t('form.phoneTaken'),
      PhoneOwnership.pendingByOther => context.t('form.phonePending'),
      _ => null,
    };

class LivePhoneField extends ConsumerStatefulWidget {
  const LivePhoneField({
    required this.controller,
    required this.label,
    this.enabled = true,
    this.errorText,
    this.onChanged,
    this.onOwnershipChanged,
    this.focusNode,
    super.key,
  });

  final PhoneFieldController controller;
  final String label;
  final bool enabled;

  /// Bkz. [PhoneField.focusNode] — bilgi formlarında soyad alanının "ileri"
  /// tuşu odağı telefon alanına taşıyor. Verilmezse burada oluşturulur:
  /// alandan çıkıldığı anda beklemeden sorgulamak için düğüm gerekiyor.
  final FocusNode? focusNode;

  /// Çağıran tarafın kendi hatası (ör. kaydetme anındaki doğrulama). Sahiplik
  /// uyarısının önüne geçer.
  final String? errorText;

  /// Kullanıcı numarayı değiştirdiğinde tetiklenir.
  final VoidCallback? onChanged;

  /// Sorgu sonuçlandığında tetiklenir. `null`: numara henüz geçerli değil ya
  /// da sorgu sürüyor. Çağıran taraf bunu kaydet düğmesini kilitlemek için
  /// kullanabilir.
  final ValueChanged<PhoneOwnership?>? onOwnershipChanged;

  @override
  ConsumerState<LivePhoneField> createState() => _LivePhoneFieldState();
}

class _LivePhoneFieldState extends ConsumerState<LivePhoneField> {
  Timer? _debounce;

  /// Sonucu elde bulunan numara. Alan değişince sonuç geçersizleşir; eski
  /// numaraya ait uyarının yeni numaranın altında kalmasını bu engeller.
  String? _checkedPhone;
  PhoneOwnership? _ownership;

  /// Sorgusu sürmekte olan numara. Alanın altındaki "kontrol ediliyor"
  /// satırını bu belirler.
  String? _checkingPhone;

  /// Dışarıdan düğüm verilmediyse oluşturulan düğüm; yalnızca onu atmalıyız.
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    // Ülke kodu değişimi ve profilden gelen ön dolum da alanı değiştirir;
    // ikisi de TextField.onChanged tetiklemez.
    widget.controller.addListener(_schedule);
    _focus.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _schedule();
    });
  }

  @override
  void didUpdateWidget(LivePhoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;

    (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocusChanged);
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_schedule);
    _focus.removeListener(_onFocusChanged);
    _ownFocus?.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Kullanıcı alandan çıktığında numara zaten tamamlanmıştır; beklemeye gerek
  /// yok, sorguyu hemen yap.
  void _onFocusChanged() {
    if (_focus.hasFocus) return;
    if (!widget.controller.isValid) return;
    if (_checkedPhone == widget.controller.e164) return;

    _debounce?.cancel();
    unawaited(_check());
  }

  void _handleChanged() {
    widget.onChanged?.call();
    _schedule();
  }

  void _schedule() {
    _debounce?.cancel();

    // Numara değiştiği anda eski sonucu düşür: kullanıcı bir hane silip
    // düzeltirken "bu numara başkasına ait" uyarısı asılı kalmasın.
    final String current = widget.controller.isValid
        ? widget.controller.e164
        : '';
    if (_checkedPhone != null && _checkedPhone != current) {
      setState(() {
        _checkedPhone = null;
        _ownership = null;
      });
      widget.onOwnershipChanged?.call(null);
    }

    if (current.isEmpty) {
      if (_checkingPhone != null) setState(() => _checkingPhone = null);
      return;
    }
    if (current == _checkedPhone) return;

    // Numara tamamlandı: sorgu daha başlamadan da kullanıcı bir şeyin
    // döndüğünü görsün.
    if (_checkingPhone != current) setState(() => _checkingPhone = current);
    _debounce = Timer(_kDebounce, _check);
  }

  Future<void> _check() async {
    if (!mounted || !widget.controller.isValid) return;

    final String phone = widget.controller.e164;
    final String? uid = ref.read(currentUidProvider);
    if (uid == null) {
      // Oturum henüz çözülmediyse (ya da kullanıcı çıkış yaptıysa) sorgu
      // yapılamaz; asılı kalan "kontrol ediliyor" satırını kaldır.
      if (mounted && _checkingPhone != null) {
        setState(() => _checkingPhone = null);
      }
      return;
    }

    if (mounted && _checkingPhone != phone) {
      setState(() => _checkingPhone = phone);
    }

    final PhoneOwnership ownership = await ref
        .read(phoneDirectoryRepositoryProvider)
        .lookup(phoneE164: phone, uid: uid);

    // Sorgu sürerken kullanıcı numarayı değiştirmiş olabilir; geç gelen yanıt
    // yeni numaranın altına yazılmamalı.
    if (!mounted || !widget.controller.isValid) return;
    if (widget.controller.e164 != phone) return;

    setState(() {
      _checkedPhone = phone;
      _ownership = ownership;
      _checkingPhone = null;
    });
    widget.onOwnershipChanged?.call(ownership);
  }

  String? _ownershipError() {
    final PhoneOwnership? ownership = _ownership;
    if (_checkedPhone == null || ownership == null) return null;
    return phoneOwnershipError(context, ownership);
  }

  /// Alanın altındaki durum satırı. Hata varsa (kendi sahiplik uyarımız ya da
  /// dışarıdan gelen hata) alanın kendi hata metni zaten görünür, ikinci bir
  /// satır yazmayız.
  Widget? _statusLine(BuildContext context, {required bool hasError}) {
    if (hasError) return null;

    final String? checking = _checkingPhone;
    if (checking != null) {
      return _StatusRow(
        color: context.inkMuted,
        text: context.t('form.phoneChecking'),
        leading: SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.6,
            color: context.inkMuted,
          ),
        ),
      );
    }

    // Yalnızca sorgunun gerçekten "serbest / benim" dediği durumda yeşil
    // satır: `unknown` (kural yayınlanmamış, çevrimdışı) hiçbir şey bilmiyor
    // demektir, kullanıcıya numara boşmuş gibi göstermeyiz.
    final PhoneOwnership? ownership = _ownership;
    if (_checkedPhone == null || ownership == null) return null;
    if (ownership != PhoneOwnership.free && ownership != PhoneOwnership.mine) {
      return null;
    }

    final Color color = context.isDarkMode
        ? BrandColors.successOnDark
        : BrandColors.success;
    return _StatusRow(
      color: color,
      text: context.t('form.phoneAvailable'),
      leading: Icon(Icons.check_circle_outline, size: 14, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? external = widget.errorText;
    final String? error = (external != null && external.isNotEmpty)
        ? external
        : _ownershipError();

    final Widget? status = _statusLine(context, hasError: error != null);

    final Widget field = PhoneField(
      controller: widget.controller,
      label: widget.label,
      enabled: widget.enabled,
      focusNode: _focus,
      errorText: error,
      onChanged: _handleChanged,
    );

    if (status == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[field, const SizedBox(height: 6), status],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.color,
    required this.text,
    required this.leading,
  });

  final Color color;
  final String text;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(padding: const EdgeInsets.only(top: 2), child: leading),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 12, height: 1.35),
          ),
        ),
      ],
    );
  }
}
