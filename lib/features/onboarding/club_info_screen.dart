import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/input_guard.dart';
import '../../core/password_policy.dart';
import '../../core/sanitize.dart';
import '../../data/club_fields.dart';
import '../../data/location_data.dart';
import '../../domain/legal_docs.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../models/profiles.dart';
import '../../services/firebase_refs.dart';
import '../../services/phone_directory_repository.dart';
import '../../state/providers.dart';
import '../auth/auth_actions.dart';
import '../shared/common_widgets.dart';
import '../shared/legal_consent.dart';
import '../shared/live_phone_field.dart';
import '../shared/media_viewer.dart';
import '../shared/multi_select_chips.dart';
import '../shared/phone_field.dart';
import '../shared/profile_photo.dart';
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
  XFile? _pickedLogo;
  bool _removeLogo = false;

  bool _prefilled = false;

  /// Formun hangi hesap için doldurulduğu. Hesap değişince sıfırlanır.
  String? _prefilledFor;
  bool _saving = false;
  bool _usesSharedPhone = false;

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

  void _prefill(
    ClubProfile? profile,
    StudentProfile? linkedStudent,
    User? user,
  ) {
    // Hesap değiştiyse form yeniden doldurulmalı (bkz. öğrenci formu).
    final String uid = user?.uid ?? '';
    if (_prefilledFor != uid) {
      _prefilled = false;
      _prefilledFor = uid;
      _usesSharedPhone = false;
      _pickedLogo = null;
      _removeLogo = false;
    }

    if (_prefilled) return;
    _prefilled = true;
    _usesSharedPhone = linkedStudent?.onboardingCompleted == true;

    if (profile != null) {
      _firstName.text = profile.firstName;
      _lastName.text = profile.lastName;
      _clubName.text = profile.clubName;
      _clubPurpose.text = profile.clubPurpose;
      _clubContents.text = profile.clubContents;
      _phone.setValue(profile.phone);

      _city = profile.city;
      _university = profile.university;
      _clubFields = List<String>.of(profile.clubFields);
    }

    if (_usesSharedPhone) {
      final String sharedPhone = (user?.phoneNumber ?? '').isNotEmpty
          ? user!.phoneNumber!
          : linkedStudent!.phone;
      if (sharedPhone.isNotEmpty) _phone.setValue(sharedPhone);
    }

    if (_firstName.text.isEmpty && (user?.displayName ?? '').isNotEmpty) {
      final List<String> parts = user!.displayName!.trim().split(
        RegExp(r'\s+'),
      );
      _firstName.text = parts.first;
      if (parts.length > 1) _lastName.text = parts.sublist(1).join(' ');
    }
  }

  List<String> get _universitiesForCity => _city.isEmpty
      ? const <String>[]
      : (kCityUniversities[_city] ?? const <String>[]);

  bool _needsPassword(User? user, ClubProfile? profile) {
    if (user == null) return false;
    if (profile?.hasPassword == true) return false;
    return !ref.read(authRepositoryProvider).hasPasswordProvider(user);
  }

  Future<void> _pickLogo() async {
    final XFile? file = await pickProfilePhoto(context);
    if (file == null || !mounted) return;

    if (await file.length() > kMaxProfilePhotoBytes) {
      if (mounted) {
        _setFeedback(
          context.t('studentInfo.feedback.photoTooLarge'),
          FeedbackTone.error,
        );
      }
      return;
    }

    setState(() {
      _pickedLogo = file;
      _removeLogo = false;
    });
  }

  void _removeLogoSelection() {
    setState(() {
      _pickedLogo = null;
      _removeLogo = true;
    });
  }

  Future<void> _save() async {
    final Session session = ref.read(sessionProvider);
    final User? user = session.user;
    if (user == null) return;

    if (!_phone.isValid) {
      _setFeedback(
        context.t('clubInfo.feedback.invalidPhone'),
        FeedbackTone.error,
      );
      return;
    }
    if (_city.isEmpty) {
      _setFeedback(
        context.t('clubInfo.feedback.invalidCity'),
        FeedbackTone.error,
      );
      return;
    }
    if (_university.isEmpty) {
      _setFeedback(
        context.t('clubInfo.feedback.invalidUniversity'),
        FeedbackTone.error,
      );
      return;
    }
    if (_clubFields.isEmpty) {
      _setFeedback(
        context.t('clubInfo.feedback.invalidField'),
        FeedbackTone.error,
      );
      return;
    }

    if (detectHarmfulInput(_clubName.text) ||
        detectHarmfulInput(_clubPurpose.text) ||
        detectHarmfulInput(_clubContents.text)) {
      _setFeedback(
        context.t('feedback.harmfulInputDetected'),
        FeedbackTone.error,
      );
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
        await ref
            .read(authRepositoryProvider)
            .linkPassword(user, _password.text);
      }

      final String phone = _phone.e164;
      // Numara değişmediyse önceki doğrulama korunur; Auth hesabında bu numara
      // zaten bağlıysa da doğrulanmış sayılır.
      final bool verifiedUnchanged =
          session.clubProfile?.phoneVerified == true &&
          session.clubProfile?.phone == phone;
      final bool verifiedViaAuthAccount = user.phoneNumber == phone;
      final bool phoneVerified = verifiedUnchanged || verifiedViaAuthAccount;

      if (phoneVerified) {
        // Firestore kuralı, true yazılırken taze ID token'daki phone_number
        // iddiasını kontrol eder.
        try {
          await user.getIdToken(true);
        } catch (_) {
          // En iyi çaba; yazım mevcut token ile yine de denenir.
        }
      }

      ({String path, String url})? logoUpdate;
      if (_pickedLogo != null) {
        logoUpdate = await uploadClubLogo(
          uid: user.uid,
          file: _pickedLogo!,
          previousPath: session.clubProfile?.logoPath ?? '',
        );
      } else if (_removeLogo) {
        final String previousPath = session.clubProfile?.logoPath ?? '';
        if (previousPath.isNotEmpty) {
          try {
            await fbStorage.ref(previousPath).delete();
          } catch (_) {
            // Dosya zaten yoksa yok say.
          }
        }
        logoUpdate = (url: '', path: '');
      }

      // Onay kaynağı sırası: bellekteki taze onay → users/{uid} kaydı (bkz.
      // öğrenci bilgi formundaki aynı akış). İkisi de boşsa profildeki
      // mevcut kayda dokunulmaz.
      final PendingConsent? pendingConsent = ref.read(pendingConsentProvider);
      final AppUser? appUser = session.appUser;
      final bool? termsAccepted =
          pendingConsent?.termsAccepted ??
          (appUser?.termsAccepted == true ? true : null);
      final int? termsAcceptedAtMs =
          pendingConsent?.acceptedAtMs ?? appUser?.termsAcceptedAtMs;
      final bool? marketingConsent =
          pendingConsent?.marketingConsent ??
          (appUser?.termsAccepted == true ? appUser?.marketingConsent : null);

      await ref
          .read(profileRepositoryProvider)
          .saveClubProfile(
            uid: user.uid,
            email: user.email ?? session.clubProfile?.email ?? '',
            firstName: firstName,
            lastName: lastName,
            phone: phone,
            city: _city,
            university: _university,
            clubName: clubName,
            clubFields: _clubFields,
            clubPurpose: clubPurpose,
            clubContents: clubContents,
            phoneVerified: phoneVerified,
            hasPassword: true,
            logoUrl: logoUpdate?.url,
            logoPath: logoUpdate?.path,
            termsAccepted: termsAccepted,
            termsAcceptedAtMs: termsAcceptedAtMs,
            marketingConsent: marketingConsent,
            termsVersion: kLegalDocsVersion,
          );
      if (pendingConsent != null) {
        ref.read(pendingConsentProvider.notifier).clear();
      }

      // Ücretli etkinliklerin penceresinde gösterilen iletişim bilgileri
      // etkinlik dokümanına kopyalanıyor; profil değişince tazelenir.
      // En iyi çaba: yazılamazsa profil kaydı yine de geçerlidir.
      try {
        await ref
            .read(eventRepositoryProvider)
            .syncClubContact(
              clubId: user.uid,
              phone: phone,
              email: user.email ?? session.clubProfile?.email ?? '',
            );
      } catch (_) {
        // Yoksay.
      }

      if (logoUpdate != null && logoUpdate.url.isNotEmpty) {
        try {
          await ref
              .read(eventRepositoryProvider)
              .syncClubLogo(clubId: user.uid, logoUrl: logoUpdate.url);
        } catch (_) {
          // İlk kurulumda henüz etkinlik yoktur; varsa sonraki logo
          // güncellemesinde yeniden eşitlenir.
        }
      }

      try {
        await ref.read(activeRoleProvider.notifier).select(UserRole.club);
      } catch (_) {
        // Firestore kaydı tamamlandı; yerel tercih yazılamasa da lastRole
        // sonraki açılışta doğru hesabı çözer.
      }
      ref.read(pendingOnboardingRoleProvider.notifier).clear();
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

  void _changeRole() {
    if (_saving) return;

    final GoRouter router = GoRouter.of(context);
    ref.read(pendingOnboardingRoleProvider.notifier).clear();
    router.go(Routes.roleSelect);
  }

  @override
  Widget build(BuildContext context) {
    final Session session = ref.watch(sessionProvider);
    _prefill(session.clubProfile, session.studentProfile, session.user);

    final bool needsPassword = _needsPassword(
      session.user,
      session.clubProfile,
    );
    final bool isEditing =
        session.pendingRole == null &&
        (session.clubProfile?.onboardingCompleted ?? false);

    final Widget content = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: isEditing,
        leading: isEditing
            ? null
            : IconButton(
                tooltip: context.t('common.back'),
                onPressed: _saving ? null : _changeRole,
                icon: const Icon(Icons.arrow_back),
              ),
        title: Text(context.t('clubInfo.title')),
        actions: <Widget>[
          TextButton(
            onPressed: _saving
                ? null
                : () async {
                    await logout(ref);
                  },
            child: Text(context.t('common.logout')),
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              _LogoPicker(
                picked: _pickedLogo,
                existingUrl: _removeLogo
                    ? ''
                    : (session.clubProfile?.logoUrl ?? ''),
                onPick: _saving ? () {} : _pickLogo,
                onRemove: _saving ? () {} : _removeLogoSelection,
              ),
              const SizedBox(height: 20),
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
                decoration: InputDecoration(
                  labelText: context.t('form.founderFirstName'),
                ),
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
                decoration: InputDecoration(
                  labelText: context.t('form.founderLastName'),
                ),
              ),
              const SizedBox(height: 12),

              LivePhoneField(
                controller: _phone,
                label: context.t('form.phone'),
                enabled: !_saving && !_usesSharedPhone,
                focusNode: _phoneFocus,
                errorText: _phoneError,
                onChanged: () {
                  if (_phoneError != null) setState(() => _phoneError = null);
                },
              ),
              if (_usesSharedPhone) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  context.t('account.sharedPhoneNotice'),
                  style: TextStyle(
                    color: context.inkMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
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
                onSelected: (String value) =>
                    setState(() => _university = value),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _clubName,
                enabled: !_saving,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                inputFormatters: guardedInput(InputLimits.shortText),
                decoration: InputDecoration(
                  labelText: context.t('form.clubName'),
                ),
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
                textInputAction: TextInputAction.done,
                onSubmitted: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                inputFormatters: guardedInput(
                  InputLimits.longText,
                  multiline: true,
                ),
                decoration: InputDecoration(
                  labelText: context.t('form.clubPurpose'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clubContents,
                enabled: !_saving,
                maxLines: 4,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                inputFormatters: guardedInput(
                  InputLimits.longText,
                  multiline: true,
                ),
                decoration: InputDecoration(
                  labelText: context.t('form.clubContents'),
                ),
              ),

              if (needsPassword) ...<Widget>[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                TextField(
                  controller: _password,
                  enabled: !_saving,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  inputFormatters: lengthOnlyInput(InputLimits.password),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: context.t('form.password'),
                  ),
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
              const Divider(),
              const SizedBox(height: 12),
              ConsentSummary(
                termsAccepted:
                    ref.watch(pendingConsentProvider)?.termsAccepted ??
                    session.clubProfile?.termsAccepted ??
                    session.appUser?.termsAccepted ??
                    false,
                marketingConsent:
                    ref.watch(pendingConsentProvider)?.marketingConsent ??
                    session.clubProfile?.marketingConsent ??
                    session.appUser?.marketingConsent ??
                    false,
                acceptedAtMs:
                    ref.watch(pendingConsentProvider)?.acceptedAtMs ??
                    session.clubProfile?.termsAcceptedAtMs ??
                    session.appUser?.termsAcceptedAtMs,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );

    return PopScope(
      canPop: isEditing,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop && !isEditing) _changeRole();
      },
      child: content,
    );
  }
}

/// Öğrenci profil formundaki `_PhotoPicker` ile aynı tasarım — kulüp logosu
/// da aynı yuvarlak avatar + kalem rozetiyle en üstte gösterilir.
class _LogoPicker extends StatelessWidget {
  const _LogoPicker({
    required this.picked,
    required this.existingUrl,
    required this.onPick,
    required this.onRemove,
  });

  final XFile? picked;
  final String existingUrl;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final bool hasImage = picked != null || existingUrl.isNotEmpty;

    return Row(
      children: <Widget>[
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              GestureDetector(
                onTap: hasImage
                    ? () => openMedia(
                        context,
                        source: picked?.path ?? existingUrl,
                        title: context.t('clubAccount.logo'),
                        contentType: 'image/jpeg',
                      )
                    : null,
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: context.subtleFill,
                  backgroundImage: picked != null
                      ? FileImage(File(picked!.path))
                      : existingUrl.isNotEmpty
                      ? NetworkImage(existingUrl) as ImageProvider<Object>
                      : null,
                  child: hasImage
                      ? null
                      : Icon(
                          Icons.groups_outlined,
                          size: 32,
                          color: context.hairline,
                        ),
                ),
              ),
              Positioned(
                right: -3,
                bottom: -3,
                child: Tooltip(
                  message: context.t('form.photoUpload'),
                  child: Material(
                    color: BrandColors.red,
                    shape: CircleBorder(
                      side: BorderSide(color: context.surface, width: 2.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onPick,
                      child: const Padding(
                        padding: EdgeInsets.all(7),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 15,
                          color: BrandColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.t('clubAccount.logo'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                context.t('form.optionalHint'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    onPressed: onPick,
                    child: Text(context.t('form.photoUpload')),
                  ),
                  if (hasImage) ...<Widget>[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: onRemove,
                      child: Text(context.t('form.photoRemove')),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
