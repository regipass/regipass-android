import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/input_guard.dart';
import '../../core/password_policy.dart';
import '../../core/sanitize.dart';
import '../../data/club_fields.dart';
import '../../data/location_data.dart';
import '../../l10n/app_strings.dart';
import '../../models/profiles.dart';
import '../../services/phone_directory_repository.dart';
import '../../state/providers.dart';
import '../auth/auth_actions.dart';
import '../shared/common_widgets.dart';
import '../shared/live_phone_field.dart';
import '../shared/multi_select_chips.dart';
import '../shared/phone_field.dart';
import '../shared/searchable_field.dart';

/// club-info.html + js/pages/club-info.js karşılığı — kulüp bilgi formu.
///
/// Kaydettikten sonra kulüp durumu (`clubStatus`) belge yükleme aşamasına
/// alınır; yönlendirmeyi router yapar.
class ClubInfoScreen extends ConsumerStatefulWidget {
  const ClubInfoScreen({super.key});

  @override
  ConsumerState<ClubInfoScreen> createState() => _ClubInfoScreenState();
}

class _ClubInfoScreenState extends ConsumerState<ClubInfoScreen> {
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _clubName = TextEditingController();
  final TextEditingController _clubPurpose = TextEditingController();
  final TextEditingController _clubContents = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final PhoneFieldController _phone = PhoneFieldController();

  /// Klavyenin "ileri" tuşuyla ad -> soyad -> telefon zinciri
  /// (bkz. öğrenci bilgi formu).
  final FocusNode _lastNameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();

  String _city = '';
  String _university = '';

  /// Kulüpler birden fazla alan seçebilir (web'de de dizi olarak tutulur).
  List<String> _clubFields = <String>[];

  bool _prefilled = false;

  /// Formun hangi hesap için doldurulduğu. Hesap değişince sıfırlanır.
  String? _prefilledFor;
  bool _saving = false;

  /// Telefon alanının altında gösterilen "bu numara başka bir hesaba ait"
  /// uyarısı. Kullanıcı numarayı değiştirince temizlenir.
  String? _phoneError;
  String? _feedback;
  FeedbackTone _tone = FeedbackTone.info;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _clubName.dispose();
    _clubPurpose.dispose();
    _clubContents.dispose();
    _password.dispose();
    _phone.dispose();
    _lastNameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _setFeedback(String? message, [FeedbackTone tone = FeedbackTone.info]) {
    if (!mounted) return;
    setState(() {
      _feedback = message;
      _tone = tone;
    });
  }

  void _prefill(ClubProfile? profile, User? user) {
    // Hesap değiştiyse form yeniden doldurulmalı (bkz. öğrenci formu).
    final String uid = user?.uid ?? '';
    if (_prefilledFor != uid) {
      _prefilled = false;
      _prefilledFor = uid;
    }

    if (_prefilled || profile == null) return;
    _prefilled = true;

    _firstName.text = profile.firstName;
    _lastName.text = profile.lastName;
    _clubName.text = profile.clubName;
    _clubPurpose.text = profile.clubPurpose;
    _clubContents.text = profile.clubContents;
    _phone.setValue(profile.phone);

    _city = profile.city;
    _university = profile.university;
    _clubFields = List<String>.of(profile.clubFields);

    if (_firstName.text.isEmpty && (user?.displayName ?? '').isNotEmpty) {
      final List<String> parts = user!.displayName!.trim().split(RegExp(r'\s+'));
      _firstName.text = parts.first;
      if (parts.length > 1) _lastName.text = parts.sublist(1).join(' ');
    }
  }

  List<String> get _universitiesForCity =>
      _city.isEmpty ? const <String>[] : (kCityUniversities[_city] ?? const <String>[]);

  bool _needsPassword(User? user, ClubProfile? profile) {
    if (user == null) return false;
    if (profile?.hasPassword == true) return false;
    return !ref.read(authRepositoryProvider).hasPasswordProvider(user);
  }

  Future<void> _save() async {
    final Session session = ref.read(sessionProvider);
    final User? user = session.user;
    if (user == null) return;

    if (!_phone.isValid) {
      _setFeedback(context.t('clubInfo.feedback.invalidPhone'), FeedbackTone.error);
      return;
    }
    if (_city.isEmpty) {
      _setFeedback(context.t('clubInfo.feedback.invalidCity'), FeedbackTone.error);
      return;
    }
    if (_university.isEmpty) {
      _setFeedback(context.t('clubInfo.feedback.invalidUniversity'), FeedbackTone.error);
      return;
    }
    if (_clubFields.isEmpty) {
      _setFeedback(context.t('clubInfo.feedback.invalidField'), FeedbackTone.error);
      return;
    }

    if (detectHarmfulInput(_clubName.text) ||
        detectHarmfulInput(_clubPurpose.text) ||
        detectHarmfulInput(_clubContents.text)) {
      _setFeedback(context.t('feedback.harmfulInputDetected'), FeedbackTone.error);
      return;
    }

    final String firstName = sanitizeName(_firstName.text);
    final String lastName = sanitizeName(_lastName.text);
    final String clubName = sanitizeText(_clubName.text, maxLength: 150);
    final String clubPurpose = sanitizeLongText(_clubPurpose.text);
    final String clubContents = sanitizeLongText(_clubContents.text);

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        clubName.isEmpty ||
        clubPurpose.isEmpty ||
        clubContents.isEmpty) {
      _setFeedback(context.t('feedback.fillAllRequired'), FeedbackTone.error);
      return;
    }

    final bool needsPassword = _needsPassword(user, session.clubProfile);
    if (needsPassword && !isStrongPassword(_password.text)) {
      _setFeedback(context.t('auth.error.weakPassword'), FeedbackTone.error);
      return;
    }

    setState(() {
      _saving = true;
      _phoneError = null;
    });
    _setFeedback(context.t('clubInfo.feedback.saving'));

    // Sahiplik sorgusu profil yazılmadan ve doğrulama kapısına düşülmeden
    // ÖNCE: numara başkasına aitse kullanıcı SMS beklemeden burada öğrenir.
    if (!await _phoneIsAvailable(uid: user.uid, phoneE164: _phone.e164)) return;

    try {
      if (needsPassword) {
        await ref.read(authRepositoryProvider).linkPassword(user, _password.text);
      }

      await ref.read(profileRepositoryProvider).saveClubProfile(
            uid: user.uid,
            email: user.email ?? session.clubProfile?.email ?? '',
            firstName: firstName,
            lastName: lastName,
            phone: _phone.e164,
            city: _city,
            university: _university,
            clubName: clubName,
            clubFields: _clubFields,
            clubPurpose: clubPurpose,
            clubContents: clubContents,
            hasPassword: true,
          );

      // Ücretli etkinliklerin penceresinde gösterilen iletişim bilgileri
      // etkinlik dokümanına kopyalanıyor; profil değişince tazelenir.
      // En iyi çaba: yazılamazsa profil kaydı yine de geçerlidir.
      try {
        await ref.read(eventRepositoryProvider).syncClubContact(
              clubId: user.uid,
              phone: _phone.e164,
              email: user.email ?? session.clubProfile?.email ?? '',
            );
      } catch (_) {
        // Yoksay.
      }
      // Yönlendirmeyi router yapar (belge yükleme / bekleme / panel).
    } catch (error) {
      if (!mounted) return;
      _setFeedback(context.t('feedback.saveErrorRetry'), FeedbackTone.error);
      setState(() => _saving = false);
    }
  }

  /// `true` dönerse numara kullanılabilir. Sorgu yapılamazsa (kural henüz
  /// yayınlanmamış, çevrimdışı) akış durmaz: Firebase Auth telefon bağlama
  /// adımında ikinci bir kontrol daha yapar.
  Future<bool> _phoneIsAvailable({
    required String uid,
    required String phoneE164,
  }) async {
    final PhoneOwnership ownership = await ref
        .read(phoneDirectoryRepositoryProvider)
        .lookup(phoneE164: phoneE164, uid: uid);

    if (!mounted) return false;
    final String? problem = phoneOwnershipError(context, ownership);
    if (problem == null) return true;

    setState(() {
      _saving = false;
      _phoneError = problem;
    });
    _setFeedback(problem, FeedbackTone.error);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final Session session = ref.watch(sessionProvider);
    _prefill(session.clubProfile, session.user);

    final bool needsPassword = _needsPassword(session.user, session.clubProfile);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('clubInfo.title')),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await logout(ref);
            },
            child: Text(context.t('common.logout')),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Text(
              context.t('clubInfo.subtitle'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _firstName,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _lastNameFocus.requestFocus(),
              inputFormatters: guardedInput(InputLimits.name),
              decoration:
                  InputDecoration(labelText: context.t('form.founderFirstName')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lastName,
              focusNode: _lastNameFocus,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _phoneFocus.requestFocus(),
              inputFormatters: guardedInput(InputLimits.name),
              decoration:
                  InputDecoration(labelText: context.t('form.founderLastName')),
            ),
            const SizedBox(height: 12),

            LivePhoneField(
              controller: _phone,
              label: context.t('form.phone'),
              enabled: !_saving,
              focusNode: _phoneFocus,
              errorText: _phoneError,
              onChanged: () {
                if (_phoneError != null) setState(() => _phoneError = null);
              },
            ),
            const SizedBox(height: 12),

            SearchableField(
              label: context.t('form.city'),
              value: _city,
              options: kTurkeyCities,
              enabled: !_saving,
              noResultText: context.t('search.city.noResult'),
              onSelected: (String value) => setState(() {
                _city = value;
                _university = '';
              }),
            ),
            const SizedBox(height: 12),
            SearchableField(
              label: context.t('form.university'),
              value: _university,
              options: _universitiesForCity,
              enabled: !_saving,
              emptyListText: context.t('search.university.emptyListByCity'),
              noResultText: context.t('search.university.noResult'),
              onSelected: (String value) => setState(() => _university = value),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _clubName,
              enabled: !_saving,
              inputFormatters: guardedInput(InputLimits.shortText),
              decoration: InputDecoration(labelText: context.t('form.clubName')),
            ),
            const SizedBox(height: 12),
            MultiSelectChipsField(
              label: context.t('form.clubFields'),
              options: kClubFields,
              selected: _clubFields,
              enabled: !_saving,
              hint: context.t('form.multiSelect.addHint'),
              helperText: context.t('form.clubFields.hint'),
              noResultText: context.t('search.clubField.noResult'),
              onChanged: (List<String> value) =>
                  setState(() => _clubFields = value),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _clubPurpose,
              enabled: !_saving,
              maxLines: 4,
              inputFormatters: guardedInput(
                InputLimits.longText,
                multiline: true,
              ),
              decoration: InputDecoration(labelText: context.t('form.clubPurpose')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _clubContents,
              enabled: !_saving,
              maxLines: 4,
              inputFormatters: guardedInput(
                InputLimits.longText,
                multiline: true,
              ),
              decoration: InputDecoration(labelText: context.t('form.clubContents')),
            ),

            if (needsPassword) ...<Widget>[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                enabled: !_saving,
                obscureText: true,
                inputFormatters: lengthOnlyInput(InputLimits.password),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: context.t('form.password')),
              ),
              const SizedBox(height: 8),
              Text(
                isStrongPassword(_password.text)
                    ? context.t('auth.passwordPolicyValid')
                    : context.t('auth.passwordPolicyHint'),
                style: TextStyle(
                  fontSize: 12.5,
                  color: isStrongPassword(_password.text)
                      ? BrandColors.success
                      : BrandColors.muted,
                ),
              ),
            ],

            const SizedBox(height: 28),
            // Buton içeriği sabit yükseklikte (bkz. öğrenci formu).
            FilledButton(
              onPressed: _saving ? null : _save,
              child: SizedBox(
                height: 22,
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: BrandColors.white,
                          ),
                        )
                      : Text(context.t('common.save')),
                ),
              ),
            ),

            // Geri bildirim butonun altında: listenin tepesinde belirdiğinde
            // altındaki her şeyi aşağı itiyordu.
            if (_feedback != null) ...<Widget>[
              const SizedBox(height: 12),
              FeedbackBanner(message: _feedback, tone: _tone),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
