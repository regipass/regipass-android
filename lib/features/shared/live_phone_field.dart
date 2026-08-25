/// Telefon alanının canlı sahiplik kontrolü yapan sürümü.
///
/// Kullanıcı numarayı yazarken (hiçbir düğmeye basmadan, sayfa yenilenmeden)
/// numaranın başka bir hesaba ait olup olmadığı sorulur ve uyarı doğrudan
/// alanın altında görünür. Kaydetme anındaki kontrol yine de kalır: kullanıcı
/// numarayı yazıp hemen kaydete basarsa sorgu daha bitmemiş olabilir.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  /// tuşu odağı telefon alanına taşıyor.
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

  @override
  void initState() {
    super.initState();
    // Ülke kodu değişimi ve profilden gelen ön dolum da alanı değiştirir;
    // ikisi de TextField.onChanged tetiklemez.
    widget.controller.addListener(_schedule);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _schedule();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_schedule);
    _debounce?.cancel();
    super.dispose();
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

    if (current.isEmpty) return;
    _debounce = Timer(_kDebounce, _check);
  }

  Future<void> _check() async {
    if (!mounted || !widget.controller.isValid) return;

    final String phone = widget.controller.e164;
    final String? uid = ref.read(currentUidProvider);
    if (uid == null) return;

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
    });
    widget.onOwnershipChanged?.call(ownership);
  }

  String? _ownershipError() {
    final PhoneOwnership? ownership = _ownership;
    if (_checkedPhone == null || ownership == null) return null;
    return phoneOwnershipError(context, ownership);
  }

  @override
  Widget build(BuildContext context) {
    final String? external = widget.errorText;

    return PhoneField(
      controller: widget.controller,
      label: widget.label,
      enabled: widget.enabled,
      focusNode: widget.focusNode,
      errorText: (external != null && external.isNotEmpty)
          ? external
          : _ownershipError(),
      onChanged: _handleChanged,
    );
  }
}
