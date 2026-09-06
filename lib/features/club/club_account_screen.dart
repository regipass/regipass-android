import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/input_guard.dart';
import '../../core/sanitize.dart';
import '../../data/club_fields.dart';
import '../../data/location_data.dart';
import '../../l10n/app_strings.dart';
import '../../models/profiles.dart';
import '../../services/phone_directory_repository.dart';
import '../../state/providers.dart';
import '../auth/auth_actions.dart';
import '../auth/phone_verify_sheet.dart';
import '../shared/account_settings_sheet.dart';
import '../shared/common_widgets.dart';
import '../shared/legal_consent.dart';
import '../shared/multi_select_chips.dart';
import '../shared/profile_photo.dart';
import '../shared/live_phone_field.dart';
import '../shared/phone_field.dart';
import '../shared/searchable_field.dart';
import 'club_documents_card.dart';
import 'club_shell.dart';

/// club-account.html + js/pages/club-account.js karşılığı.
///
/// Web'de tek bir form var; "Düzenle" ile alanlar açılıyor, "İptal" son
/// kaydedilen hâle dönüyor. Mobilde aynı davranış: görüntüleme modunda alanlar
/// kilitli, düzenleme modunda açık.
///
/// Telefon da formun bir alanıdır (ayrı "Değiştir" düğmesi yok). Kaydederken
/// numara değişmişse sırayla: sahiplik sorgusu (numara başka bir hesaba ait mi)
/// → SMS doğrulama pop-up'ı → doğrulanınca kayıt. Numara doğrulanmadan
/// Firestore'a yazılmaz; pop-up kapatılırsa profildeki numara olduğu gibi kalır.
class ClubAccountScreen extends ConsumerStatefulWidget {
  const ClubAccountScreen({super.key});

  @override
  ConsumerState<ClubAccountScreen> createState() => _ClubAccountScreenState();
}

class _ClubAccountScreenState extends ConsumerState<ClubAccountScreen> {
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _clubName = TextEditingController();
  final TextEditingController _clubPurpose = TextEditingController();
  final TextEditingController _clubContents = TextEditingController();
  final PhoneFieldController _phone = PhoneFieldController();

  String _city = '';
  String _university = '';
  List<String> _clubFields = <String>[];

  bool _prefilled = false;
  bool _editing = false;
  bool _saving = false;
  bool _uploadingLogo = false;
  String? _feedback;
  FeedbackTone _tone = FeedbackTone.info;

  /// Telefon alanının altında gösterilen hata: geçersiz numara ya da sahiplik
  /// sorgusunun sonucu ("bu numara başka bir hesaba ait"). Kullanıcı numarayı
  /// düzeltmeye başlayınca temizlenir.
  String? _phoneError;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _clubName.dispose();
    _clubPurpose.dispose();
    _clubContents.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _setFeedback(String? message, [FeedbackTone tone = FeedbackTone.info]) {
    if (!mounted) return;
    setState(() {
      _feedback = message;
      _tone = tone;
    });
  }

  /// Formu profile göre doldurur. [force] iptal düğmesinde kullanılır.
  void _fill(ClubProfile? profile, {bool force = false}) {
    if (profile == null) return;
    if (_prefilled && !force) return;
    _prefilled = true;

    _firstName.text = profile.firstName;
    _lastName.text = profile.lastName;
    _clubName.text = profile.clubName;
    _clubPurpose.text = profile.clubPurpose;
    _clubContents.text = profile.clubContents;

    _city = profile.city;
    _university = profile.university;
    _clubFields = List<String>.of(profile.clubFields);

    // setValue boş değeri yok sayar (kayıtlı numarayı silmesin diye); numarası
    // olmayan profilde alanın da boş kalması için burada elle temizlenir.
    if (profile.phone.isEmpty) {
      _phone.text.clear();
    } else {
      _phone.setValue(profile.phone);
    }
  }

  List<String> get _universitiesForCity => _city.isEmpty
      ? const <String>[]
      : (kCityUniversities[_city] ?? const <String>[]);

  /// Kullanıcı numarayı düzeltmeye başladı: eski uyarı artık geçerli değil.
  void _clearPhoneError() {
    if (_phoneError == null) return;
    setState(() => _phoneError = null);
  }

  /// Logo seçimi → Storage → profil → kulübün etkinlikleri.
  ///
  /// Etkinlikler de güncellenir: logo etkinlik penceresinde kulüp adının
  /// yanındaki rozettir ve o rozet etkinlik dokümanındaki kopyadan gelir
  /// (bkz. `EventRepository.syncClubLogo`).
  Future<void> _changeLogo(ClubProfile profile) async {
    final XFile? file = await pickProfilePhoto(context);
    if (file == null || !mounted) return;

    if (await file.length() > kMaxProfilePhotoBytes) {
      if (!mounted) return;
      _setFeedback(
        context.t('studentInfo.feedback.photoTooLarge'),
        FeedbackTone.error,
      );
      return;
    }

    final String? uid = ref.read(sessionProvider).user?.uid;
    if (uid == null || !mounted) return;

    setState(() => _uploadingLogo = true);

    try {
      final ({String path, String url}) uploaded = await uploadClubLogo(
        uid: uid,
        file: file,
        previousPath: profile.logoPath,
      );

      await ref
          .read(profileRepositoryProvider)
          .updateClubLogo(
            uid: uid,
            logoUrl: uploaded.url,
            logoPath: uploaded.path,
          );

      // Etkinliklerin güncellenmesi logonun kendisinden ayrı bir yazım:
      // burada bir şey ters giderse logo yine de kaydedilmiş olur.
      try {
        await ref
            .read(eventRepositoryProvider)
            .syncClubLogo(clubId: uid, logoUrl: uploaded.url);
      } catch (_) {
        // Eski etkinliklerin rozeti eski logoda kalır; kulüp bir sonraki
        // yüklemede yeniden dener.
      }

      if (!mounted) return;
      _setFeedback(
        context.t('clubAccount.feedback.logoUpdated'),
        FeedbackTone.success,
      );
    } catch (_) {
      if (mounted) {
        _setFeedback(context.t('feedback.saveErrorRetry'), FeedbackTone.error);
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _save(ClubProfile profile) async {
    final String? uid = ref.read(sessionProvider).user?.uid;
    if (uid == null) return;

    if (_city.isEmpty) {
      _setFeedback(
        context.t('clubAccount.feedback.invalidCity'),
        FeedbackTone.error,
      );
      return;
    }
    if (_university.isEmpty) {
      _setFeedback(
        context.t('clubAccount.feedback.invalidUniversity'),
        FeedbackTone.error,
      );
      return;
    }
    if (_clubFields.isEmpty) {
      _setFeedback(
        context.t('clubAccount.feedback.invalidField'),
        FeedbackTone.error,
      );
      return;
    }

    if (detectHarmfulInput(_firstName.text) ||
        detectHarmfulInput(_lastName.text) ||
        detectHarmfulInput(_clubName.text) ||
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
    // Numara hataları alanın altında gösterilir; kullanıcı hangi alanı
    // düzelteceğini aramak zorunda kalmasın.
    if (!_phone.isValid) {
      setState(
        () => _phoneError = context.t('studentInfo.feedback.invalidPhone'),
      );
      return;
    }

    final String newPhone = _phone.e164;
    final bool phoneChanged = newPhone != profile.phone;

    setState(() {
      _saving = true;
      _phoneError = null;
    });

    // Sahiplik sorgusu SMS'ten ÖNCE: numara başka bir hesaba aitse kullanıcı
    // doğrulama adımına hiç sokulmaz (SMS de gönderilmez) ve hiçbir şey
    // kaydedilmez. Sorgu yapılamazsa akış durmaz — Firebase Auth telefon
    // bağlarken ikinci kez kontrol eder.
    if (phoneChanged) {
      final PhoneOwnership ownership = await ref
          .read(phoneDirectoryRepositoryProvider)
          .lookup(phoneE164: newPhone, uid: uid);

      if (!mounted) return;
      final String? problem = phoneOwnershipError(context, ownership);
      if (problem != null) {
        setState(() {
          _saving = false;
          _phoneError = problem;
        });
        return;
      }
    }

    try {
      await ref
          .read(profileRepositoryProvider)
          .saveClubProfile(
            uid: uid,
            email: profile.email,
            firstName: firstName,
            lastName: lastName,
            // Telefon burada YAZILMAZ: yeni numara ancak SMS kodu
            // doğrulandıktan sonra pop-up tarafından kaydedilir.
            phone: profile.phone,
            city: _city,
            university: _university,
            clubName: clubName,
            clubFields: _clubFields,
            clubPurpose: clubPurpose,
            clubContents: clubContents,
            phoneVerified: profile.phoneVerified,
            hasPassword: profile.hasPassword,
          );

      // Ücretli etkinliklerin penceresinde gösterilen iletişim bilgileri
      // etkinlik dokümanında kopya duruyor; profil kaydında tazelenir.
      // Numara değiştiyse yenisi ancak SMS doğrulandıktan sonra yazıldığı
      // için burada eski numara gider, doğrulama sonrası ikinci kez
      // çağrılarak güncellenir.
      await _syncContactOnEvents(
        uid: uid,
        phone: profile.phone,
        email: profile.email,
      );

      // Etkinlik pop-up'larında gösterilen kulüp adı/üniversite/alan da
      // etkinlik dokümanında kopya duruyor; kulüp bunları değiştirdiğinde
      // eski etkinliklerin penceresi eski bilgide kalmasın diye tazelenir.
      await _syncIdentityOnEvents(
        uid: uid,
        clubName: clubName,
        university: _university,
        clubFields: _clubFields,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _setFeedback(context.t('feedback.saveErrorRetry'), FeedbackTone.error);
      return;
    }

    if (!mounted) return;

    if (!phoneChanged) {
      setState(() {
        _saving = false;
        _editing = false;
      });
      _setFeedback(
        context.t('clubAccount.feedback.updated'),
        FeedbackTone.success,
      );
      return;
    }

    // Doğrulama pop-up'ı: numarayı Firestore'a yazan taraf da burasıdır.
    // Kullanıcı çarpıya basarsa profildeki numara değişmez; alan son kayıtlı
    // numaraya geri alınır ve düzenleme açık kalır.
    final bool verified = await showPhoneVerifyDialog(
      context,
      phoneE164: newPhone,
      role: UserRole.club,
      previousPhoneE164: profile.phone,
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
      if (verified) {
        _editing = false;
      } else {
        _phone.setValue(profile.phone);
      }
    });
    _setFeedback(
      context.t(
        verified ? 'phoneChange.feedback.success' : 'account.phoneNotChanged',
      ),
      verified ? FeedbackTone.success : FeedbackTone.error,
    );

    if (verified) {
      await _syncContactOnEvents(
        uid: profile.uid,
        phone: newPhone,
        email: profile.email,
      );
      await _syncLinkedStudentPhone(uid: profile.uid, phone: newPhone);
    }
  }

  /// Kulübün etkinliklerindeki iletişim kopyasını tazeler.
  ///
  /// En iyi çaba: yazılamazsa profil kaydı yine de geçerlidir, ücretli
  /// etkinlik penceresi bir sonraki kayıtta güncellenir.
  Future<void> _syncContactOnEvents({
    required String uid,
    required String phone,
    required String email,
  }) async {
    try {
      await ref
          .read(eventRepositoryProvider)
          .syncClubContact(clubId: uid, phone: phone, email: email);
    } catch (_) {
      // Yoksay.
    }
  }

  /// Kulübün etkinliklerindeki ad/üniversite/alan kopyasını tazeler.
  ///
  /// En iyi çaba: yazılamazsa profil kaydı yine de geçerlidir, etkinlik
  /// pop-up'ları bir sonraki senkronizasyona kadar eski bilgiyi gösterir.
  Future<void> _syncIdentityOnEvents({
    required String uid,
    required String clubName,
    required String university,
    required List<String> clubFields,
  }) async {
    try {
      await ref
          .read(eventRepositoryProvider)
          .syncClubIdentity(
            clubId: uid,
            clubName: clubName,
            clubUniversity: university,
            clubFields: clubFields,
          );
    } catch (_) {
      // Yoksay.
    }
  }

  /// Kulüp hesabından değişen ortak numara, öğrencinin geçmiş etkinlik
  /// kayıtlarındaki iletişim kopyasına da yansıtılır. Kulübün öğrencinin
  /// profilini doğrudan okuyamadığı güvenlik modelinde bu kopya, kulübün
  /// katılımcı listesi ve dışa aktarımında kullanılan tek kaynak olabilir.
  Future<void> _syncLinkedStudentPhone({
    required String uid,
    required String phone,
  }) async {
    try {
      final StudentProfile? student = await ref
          .read(profileRepositoryProvider)
          .fetchStudentProfile(uid);
      if (student == null || !student.onboardingCompleted) return;

      await ref
          .read(eventRepositoryProvider)
          .syncStudentInfoOnRegistrations(
            studentId: student.uid,
            firstName: student.firstName,
            lastName: student.lastName,
            phone: phone,
            city: student.city,
            university: student.university,
            department: student.department,
            classYear: student.classYear,
            email: student.email,
          );
    } catch (_) {
      // Profil ve Auth telefonu çoktan ortak güncellenmiştir; etkinlikteki
      // denormalize kopya sonraki profil kaydında yeniden eşitlenir.
    }
  }

  Future<void> _logout() async {
    await logout(ref);
  }

  @override
  Widget build(BuildContext context) {
    final Session session = ref.watch(sessionProvider);
    final ClubProfile? profile = session.clubProfile;
    if (profile == null) {
      return const Scaffold(body: LoadingView());
    }

    _fill(profile);

    // Görüntüleme modunda alanlar hiç çizilmiyor (yerlerine bilgi kartları
    // geliyor), bu yüzden kilit yalnızca kaydetme sırasında anlamlı.
    final bool locked = _saving;

    return Scaffold(
      appBar: ClubAppBar(
        title: context.t('clubAccount.title'),
        actions: <Widget>[
          IconButton(
            tooltip: context.t('common.logout'),
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: BrandColors.danger),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          // Sayfanın sağ üstü, üst çubuktaki çıkış düğmesinin tam altı:
          // iletişim ve hesap ayarları. İkisi de birer alt sayfa açar, o
          // yüzden gövdede yer kaplamıyorlar (bkz. account_settings_sheet.dart).
          const AccountToolbar(),
          const SizedBox(height: 8),
          Center(
            child: Column(
              children: <Widget>[
                EditableClubLogo(
                  logoUrl: profile.logoUrl,
                  busy: _uploadingLogo,
                  onEdit: () => _changeLogo(profile),
                ),
                const SizedBox(height: 14),
                Text(
                  profile.clubName.isNotEmpty
                      ? profile.clubName
                      : context.t('dashboard.clubFallback'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  profile.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          FeedbackBanner(message: _feedback, tone: _tone),

          if (_editing) ...<Widget>[
            _SectionHeader(
              icon: Icons.person_outline,
              label: context.t('clubAccount.section.manager'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _firstName,
              enabled: !locked,
              textCapitalization: TextCapitalization.words,
              inputFormatters: guardedInput(InputLimits.name),
              decoration: InputDecoration(
                labelText: context.t('form.founderFirstName'),
                prefixIcon: const Icon(Icons.person_outline, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lastName,
              enabled: !locked,
              textCapitalization: TextCapitalization.words,
              inputFormatters: guardedInput(InputLimits.name),
              decoration: InputDecoration(
                labelText: context.t('form.founderLastName'),
                prefixIcon: const Icon(Icons.badge_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 12),

            // Telefon formun bir alanı; numara değişirse kaydetmede sahiplik
            // sorgusu + SMS doğrulama pop-up'ı devreye girer.
            LivePhoneField(
              controller: _phone,
              label: context.t('form.phone'),
              enabled: !locked,
              errorText: _phoneError,
              onChanged: _clearPhoneError,
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.info_outline, size: 14, color: context.inkMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.t('account.phoneChangeHint'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),
            _SectionHeader(
              icon: Icons.groups_outlined,
              label: context.t('clubAccount.section.club'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _clubName,
              enabled: !locked,
              inputFormatters: guardedInput(InputLimits.shortText),
              decoration: InputDecoration(
                labelText: context.t('form.clubName'),
                prefixIcon: const Icon(Icons.groups_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            SearchableField(
              label: context.t('form.city'),
              icon: Icons.location_city_outlined,
              value: _city,
              options: kTurkeyCities,
              enabled: !locked,
              noResultText: context.t('search.city.noResult'),
              onSelected: (String value) => setState(() {
                _city = value;
                // Şehir değişince üniversite seçimi geçersizleşir.
                _university = '';
              }),
            ),
            const SizedBox(height: 12),
            SearchableField(
              label: context.t('form.university'),
              icon: Icons.account_balance_outlined,
              value: _university,
              options: _universitiesForCity,
              enabled: !locked,
              emptyListText: context.t('search.university.emptyListByCity'),
              noResultText: context.t('search.university.noResult'),
              hint: _city.isEmpty
                  ? context.t('form.universityPlaceholderSelectCityFirst')
                  : context.t('form.universityPlaceholderWithSearch'),
              onSelected: (String value) => setState(() => _university = value),
            ),
            const SizedBox(height: 12),
            MultiSelectChipsField(
              label: context.t('form.clubFields'),
              icon: Icons.category_outlined,
              options: kClubFields,
              selected: _clubFields,
              enabled: !locked,
              hint: context.t('form.multiSelect.addHint'),
              helperText: context.t('form.clubFields.hint'),
              noResultText: context.t('search.clubField.noResult'),
              onChanged: (List<String> value) =>
                  setState(() => _clubFields = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _clubPurpose,
              enabled: !locked,
              maxLines: 4,
              inputFormatters: guardedInput(
                InputLimits.longText,
                multiline: true,
              ),
              decoration: InputDecoration(
                labelText: context.t('form.clubPurpose'),
                alignLabelWithHint: true,
                prefixIcon: const Icon(Icons.flag_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _clubContents,
              enabled: !locked,
              maxLines: 4,
              inputFormatters: guardedInput(
                InputLimits.longText,
                multiline: true,
              ),
              decoration: InputDecoration(
                labelText: context.t('form.clubContents'),
                alignLabelWithHint: true,
                prefixIcon: const Icon(Icons.list_alt_outlined, size: 20),
              ),
            ),

            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                // Expanded şart: tema düğmelere `Size.fromHeight(48)` (yani
                // sonsuz genişlik) veriyor, Row'da esnek olmayan çocuk
                // sınırsız genişlik aldığı için düzen çöküyor ve ekran
                // donuyordu.
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () {
                            // İptal: son kaydedilen hâle dön.
                            FocusScope.of(context).unfocus();
                            setState(() {
                              _fill(profile, force: true);
                              _editing = false;
                              _phoneError = null;
                            });
                            _setFeedback(
                              context.t('feedback.changesCancelled'),
                            );
                          },
                    icon: const Icon(Icons.close, size: 18),
                    label: Text(context.t('common.cancel')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _save(profile),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: BrandColors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(context.t('common.save')),
                  ),
                ),
              ],
            ),
          ] else ...<Widget>[
            _SectionHeader(
              icon: Icons.person_outline,
              label: context.t('clubAccount.section.manager'),
            ),
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.person_outline,
              label: context.t('form.founderFirstName'),
              value: profile.firstName,
            ),
            _InfoTile(
              icon: Icons.badge_outlined,
              label: context.t('form.founderLastName'),
              value: profile.lastName,
            ),
            _InfoTile(
              icon: Icons.phone_outlined,
              label: context.t('form.phone'),
              value: formatE164ForDisplay(profile.phone),
            ),

            const SizedBox(height: 14),
            _SectionHeader(
              icon: Icons.groups_outlined,
              label: context.t('clubAccount.section.club'),
            ),
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.groups_outlined,
              label: context.t('form.clubName'),
              value: profile.clubName,
            ),
            _InfoTile(
              icon: Icons.location_city_outlined,
              label: context.t('form.city'),
              value: profile.city,
            ),
            _InfoTile(
              icon: Icons.account_balance_outlined,
              label: context.t('form.university'),
              value: profile.university,
            ),
            _InfoTile(
              icon: Icons.category_outlined,
              label: context.t('form.clubFields'),
              value: profile.clubFields.join(' • '),
            ),
            _InfoTile(
              icon: Icons.flag_outlined,
              label: context.t('form.clubPurpose'),
              value: profile.clubPurpose,
              multiline: true,
            ),
            _InfoTile(
              icon: Icons.list_alt_outlined,
              label: context.t('form.clubContents'),
              value: profile.clubContents,
              multiline: true,
            ),
            // Sözleşme/KVKK onayının tam anı (bkz. öğrenci hesap kartı).
            _InfoTile(
              icon: Icons.verified_user_outlined,
              label: context.t('legal.consent.tileLabel'),
              value: consentTileValue(
                context,
                termsAccepted: profile.termsAccepted,
                acceptedAtMs: profile.termsAcceptedAtMs,
                marketingConsent: profile.marketingConsent,
              ),
            ),

            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _editing = true;
                  _phoneError = null;
                });
                _setFeedback(context.t('clubAccount.feedback.editModeOn'));
              },
              icon: const Icon(Icons.edit_outlined),
              label: Text(context.t('clubAccount.edit')),
            ),
          ],

          // Onaylanmış başvurunun belgeleri. Belge ekranı onay kapısının
          // dışında yaşadığı (ve oraya yapılan her kayıt başvuruyu yeniden
          // incelemeye düşürdüğü) için kulüp yüklediklerini onaydan sonra
          // yalnızca burada görebiliyor — bkz. club_documents_card.dart.
          if (!_editing) ...<Widget>[
            const SizedBox(height: 20),
            ClubDocumentsCard(profile: profile),
          ],

          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: BrandColors.danger),
            label: Text(
              context.t('common.logout'),
              style: const TextStyle(color: BrandColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// Form ve bilgi bloklarını ayıran başlık: solda simge, yanında etiket ve
/// satırın kalanını dolduran ince çizgi.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      Icon(icon, size: 18, color: context.brandInk),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: context.ink,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Divider(color: context.hairline, height: 1)),
    ],
  );
}

/// Görüntüleme modundaki tek bilgi satırı — öğrenci hesabındakiyle aynı kart
/// dili (simge + etiket + değer).
class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Kulüp amacı/içerikleri gibi paragraf uzunluğundaki alanlar tek satıra
  /// sıkıştırılmaz.
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(BrandShape.controlRadius),
          boxShadow: BrandShape.card,
        ),
        child: Row(
          crossAxisAlignment: multiline
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 20, color: context.inkMuted),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    value.isNotEmpty ? value : '-',
                    maxLines: multiline ? null : 2,
                    overflow: multiline
                        ? TextOverflow.clip
                        : TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      height: multiline ? 1.45 : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
