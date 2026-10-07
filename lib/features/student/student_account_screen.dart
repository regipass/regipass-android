import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/input_guard.dart';
import '../../core/sanitize.dart';
import '../../data/department_data.dart';
import '../../data/location_data.dart';
import '../../l10n/app_strings.dart';
import '../../models/profiles.dart';
import '../../services/phone_directory_repository.dart';
import '../../state/providers.dart';
import '../auth/auth_actions.dart';
import '../auth/phone_verify_sheet.dart';
import '../shared/account_settings_sheet.dart';
import '../shared/common_widgets.dart';
import '../shared/gender_picker.dart';
import '../shared/legal_consent.dart';
import 'blocked_organizers_section.dart';
import 'followed_clubs_section.dart';
import 'staff_events_section.dart';
import '../shared/live_phone_field.dart';
import '../shared/phone_field.dart';
import '../shared/profile_photo.dart';
import '../shared/searchable_field.dart';
import 'student_shell.dart';

/// student-account.html + js/pages/student-account.js karşılığı — profil özeti.
///
/// Bilgiler doğrudan bu ekranda düzenlenir. Böylece tamamlanmış bir profilin
/// onboarding ya da parola kurulum akışına yeniden düşmesine gerek kalmaz.
///
/// Telefon da bu formun bir alanıdır — ayrı "Numarayı Değiştir" düğmesi yok.
/// Kaydederken numara değişmişse sırayla: sahiplik sorgusu (numara başka bir
/// hesaba ait mi) → SMS doğrulama pop-up'ı → doğrulanınca tek yazımda kayıt.
/// Numara Firestore'a doğrulanmadan yazılmaz; kullanıcı pop-up'ı kapatırsa
/// profildeki numara olduğu gibi kalır.
class StudentAccountScreen extends ConsumerStatefulWidget {
  const StudentAccountScreen({super.key});

  @override
  ConsumerState<StudentAccountScreen> createState() =>
      _StudentAccountScreenState();
}

class _StudentAccountScreenState extends ConsumerState<StudentAccountScreen> {
  static const List<String> _classYears = <String>[
    'Hazırlık',
    '1. Sınıf',
    '2. Sınıf',
    '3. Sınıf',
    '4. Sınıf',
    '5. Sınıf',
    '6. Sınıf',
    'Mezun',
  ];

  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _studentNumber = TextEditingController();
  final PhoneFieldController _phone = PhoneFieldController();

  String _city = '';
  String _university = '';
  String _department = '';
  String _classYear = '';

  /// `male` | `female` | boş — bkz. [GenderPicker].
  String _gender = '';

  bool _uploadingPhoto = false;
  bool _editing = false;
  bool _saving = false;
  bool _prefilled = false;

  /// Telefon alanının altında gösterilen hata: geçersiz numara ya da sahiplik
  /// sorgusunun sonucu ("bu numara başka bir hesaba ait"). Kullanıcı numarayı
  /// düzeltmeye başlayınca temizlenir.
  String? _phoneError;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _studentNumber.dispose();
    _phone.dispose();
    super.dispose();
  }

  List<String> get _universitiesForCity => _city.isEmpty
      ? const <String>[]
      : (kCityUniversities[_city] ?? const <String>[]);

  /// Uyarılar AppBar'ın hemen altında çıkar. Eskiden `SnackBar` kullanılıyordu
  /// ve uyarı, kabuktaki yüzen alt gezinme çubuğuna yapışık görünüyordu.
  void _toast(String message, [FeedbackTone tone = FeedbackTone.error]) =>
      showTopFeedback(context, message, tone: tone);

  Future<void> _changePhoto(StudentProfile profile) async {
    final XFile? file = await pickProfilePhoto(context);
    if (file == null || !mounted) return;

    if (await file.length() > kMaxProfilePhotoBytes) {
      if (!mounted) return;
      _toast(context.t('studentInfo.feedback.photoTooLarge'));
      return;
    }

    final String? uid = ref.read(sessionProvider).user?.uid;
    if (uid == null || !mounted) return;

    setState(() => _uploadingPhoto = true);

    try {
      final ({String path, String url}) uploaded = await uploadStudentPhoto(
        uid: uid,
        file: file,
        previousPath: profile.photoPath,
      );

      await ref
          .read(profileRepositoryProvider)
          .updateStudentPhoto(
            uid: uid,
            photoUrl: uploaded.url,
            photoPath: uploaded.path,
          );
    } catch (_) {
      if (mounted) _toast(context.t('feedback.saveErrorRetry'));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _logout() async {
    await logout(ref);
  }

  void _fill(StudentProfile profile, {bool force = false}) {
    if (_prefilled && !force) return;
    _prefilled = true;
    _firstName.text = profile.firstName;
    _lastName.text = profile.lastName;
    _city = profile.city;
    _university = profile.university;
    _department = profile.department;
    _studentNumber.text = profile.studentNumber;
    _classYear = profile.classYear;
    _gender = profile.gender == 'male' || profile.gender == 'female'
        ? profile.gender
        : '';
    // setValue boş değeri yok sayar (kayıtlı numarayı silmesin diye); numarası
    // olmayan profilde alanın da boş kalması için burada elle temizlenir.
    if (profile.phone.isEmpty) {
      _phone.text.clear();
    } else {
      _phone.setValue(profile.phone);
    }
  }

  void _startEditing(StudentProfile profile) {
    setState(() {
      _fill(profile, force: true);
      _editing = true;
      _phoneError = null;
    });
  }

  void _cancelEditing(StudentProfile profile) {
    FocusScope.of(context).unfocus();
    setState(() {
      _fill(profile, force: true);
      _editing = false;
      _phoneError = null;
    });
  }

  /// Kullanıcı numarayı düzeltmeye başladı: eski uyarı artık geçerli değil.
  void _clearPhoneError() {
    if (_phoneError == null) return;
    setState(() => _phoneError = null);
  }

  Future<void> _saveDetails(StudentProfile profile) async {
    final String firstName = sanitizeName(_firstName.text);
    final String lastName = sanitizeName(_lastName.text);
    final String studentNumber = sanitizeText(
      _studentNumber.text,
      maxLength: 30,
    );

    if (detectHarmfulInput(_firstName.text) ||
        detectHarmfulInput(_lastName.text) ||
        detectHarmfulInput(_studentNumber.text)) {
      _toast(context.t('feedback.harmfulInputDetected'));
      return;
    }
    if (firstName.isEmpty || lastName.isEmpty || studentNumber.isEmpty) {
      _toast(context.t('feedback.fillAllRequired'));
      return;
    }
    if (_city.isEmpty) {
      _toast(context.t('studentInfo.feedback.invalidCity'));
      return;
    }
    if (_university.isEmpty) {
      _toast(context.t('studentInfo.feedback.invalidUniversity'));
      return;
    }
    if (_department.isEmpty) {
      _toast(context.t('studentInfo.feedback.invalidDepartment'));
      return;
    }
    if (_classYear.isEmpty) {
      _toast(context.t('studentInfo.feedback.invalidClassYear'));
      return;
    }
    if (_gender.isEmpty) {
      _toast(context.t('studentInfo.feedback.invalidGender'));
      return;
    }
    // Numara hatası alanın altında gösterilir; kullanıcı hangi alanı
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
    // doğrulama adımına hiç sokulmaz (SMS de gönderilmez).
    if (phoneChanged &&
        !await _phoneIsAvailable(uid: profile.uid, phoneE164: newPhone)) {
      return;
    }

    try {
      // Telefon burada YAZILMAZ: doğrulanmadan yazılırsa firestore.rules
      // `phoneVerified` bayrağını geçersiz kılar ve router kullanıcıyı tam
      // ekran doğrulama kapısına kilitler.
      await ref
          .read(profileRepositoryProvider)
          .updateStudentProfileDetails(
            uid: profile.uid,
            firstName: firstName,
            lastName: lastName,
            city: _city,
            university: _university,
            department: _department,
            studentNumber: studentNumber,
            classYear: _classYear,
            gender: _gender,
          );

      // Kulüp katılımcı listesini, Excel'i ve belgeye işlenen ismi kayıt
      // dokümanından okur; profil değişikliği oraya taşınmazsa kulüp eski
      // ismi görmeye devam eder.
      await _syncRegistrations(
        profile: profile,
        firstName: firstName,
        lastName: lastName,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(context.t('feedback.saveErrorRetry'));
      return;
    }

    if (!mounted) return;
    FocusScope.of(context).unfocus();

    if (!phoneChanged) {
      setState(() {
        _saving = false;
        _editing = false;
      });
      return;
    }

    await _verifyNewPhone(profile: profile, newPhone: newPhone);
  }

  /// `true` dönerse numara kullanılabilir; aitse uyarı telefon alanının
  /// altında görünür ve hiçbir şey kaydedilmez. Sorgu yapılamazsa (kural henüz
  /// yayınlanmamış, çevrimdışı) akış durmaz: Firebase Auth telefon bağlama
  /// sırasında ikinci bir kontrol daha yapar.
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
    return false;
  }

  /// Profildeki değişikliği öğrencinin TÜM etkinlik kayıtlarına taşır.
  ///
  /// Kayıt dokümanı kulübün gördüğü tek öğrenci kaynağıdır (firestore.rules
  /// kulübe profil okuma izni vermez), bu yüzden isim/bölüm/telefon burada da
  /// tazelenmezse katılımcı listesi, Excel çıktısı ve belgeye işlenen isim
  /// eski bilgide kalır.
  ///
  /// En iyi çaba: başarısız olursa profil kaydı yine de geçerlidir, kullanıcı
  /// bir hata görmez.
  Future<void> _syncRegistrations({
    required StudentProfile profile,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    try {
      await ref
          .read(eventRepositoryProvider)
          .syncStudentInfoOnRegistrations(
            studentId: profile.uid,
            firstName: firstName,
            lastName: lastName,
            phone: phone ?? profile.phone,
            city: _city,
            university: _university,
            department: _department,
            classYear: _classYear,
            email: profile.email,
          );
    } catch (_) {
      // Yoksay — bkz. docs/kayit-profil-senkronu.md
    }
  }

  /// Doğrulama pop-up'ı: numarayı Firestore'a yazan taraf da burasıdır
  /// (bkz. `showPhoneVerifyDialog`). Kullanıcı çarpıya basarsa profil
  /// değişmez; alan son kayıtlı numaraya geri alınır ve düzenleme açık kalır.
  Future<void> _verifyNewPhone({
    required StudentProfile profile,
    required String newPhone,
  }) async {
    final bool verified = await showPhoneVerifyDialog(
      context,
      phoneE164: newPhone,
      role: UserRole.student,
      previousPhoneE164: profile.phone,
    );

    if (verified) {
      // Numara da kayıtlara kopyalanan alanlardan biri.
      await _syncRegistrations(
        profile: profile,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        phone: newPhone,
      );

      // Aynı Firebase Auth kimliğindeki kulübün ücretli etkinliklerinde
      // iletişim bilgisi etkinlik dokümanına kopyalanır. Ortak numara
      // öğrenciden değiştirildiyse bu kopya da eski numarada kalmasın.
      final ClubProfile? linkedClub = ref.read(sessionProvider).clubProfile;
      if (linkedClub != null) {
        try {
          await ref
              .read(eventRepositoryProvider)
              .syncClubContact(
                clubId: linkedClub.uid,
                phone: newPhone,
                email: linkedClub.email,
              );
        } catch (_) {
          // Profil senkronu geçerlidir; etkinlik kopyası sonraki kayıtta
          // yeniden güncellenir.
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      _editing = verified ? false : _editing;
      if (!verified) _phone.setValue(profile.phone);
    });
    _toast(
      context.t(
        verified ? 'phoneChange.feedback.success' : 'account.phoneNotChanged',
      ),
      verified ? FeedbackTone.success : FeedbackTone.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Session session = ref.watch(sessionProvider);
    final StudentProfile? profile = session.studentProfile;

    if (profile == null) {
      return ReadableScaffold(body: LoadingView());
    }
    _fill(profile);

    return ReadableScaffold(
      appBar: StudentAppBar(
        title: context.t('studentAccount.title'),
        // Bu ekranda sağdaki eylem çıkıştır: hesabın kendisi zaten burası,
        // bildirime gitmek için alt çubuktaki diğer sekmeler var.
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
                EditableAvatar(
                  photoUrl: profile.photoUrl,
                  busy: _uploadingPhoto,
                  onEdit: () => _changePhoto(profile),
                ),
                const SizedBox(height: 14),
                Text(
                  profile.fullName.isNotEmpty
                      ? profile.fullName
                      : context.t('dashboard.studentFallback'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.email,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          if (_editing) ...<Widget>[
            TextField(
              controller: _firstName,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              inputFormatters: guardedInput(InputLimits.name),
              decoration: InputDecoration(
                labelText: context.t('form.firstName'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lastName,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              inputFormatters: guardedInput(InputLimits.name),
              decoration: InputDecoration(
                labelText: context.t('form.lastName'),
              ),
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
                // Şehir değişince üniversite seçimi geçersizleşir.
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
              hint: _city.isEmpty
                  ? context.t('form.universityPlaceholderSelectCityFirst')
                  : context.t('form.universityPlaceholderWithSearch'),
              onSelected: (String value) => setState(() => _university = value),
            ),
            const SizedBox(height: 12),
            SearchableField(
              label: context.t('form.department'),
              value: _department,
              options: kCommonDepartments,
              enabled: !_saving,
              noResultText: context.t('search.department.noResult'),
              onSelected: (String value) => setState(() => _department = value),
            ),
            const SizedBox(height: 12),
            SearchableField(
              label: context.t('form.classYear'),
              value: _classYear,
              options: _classYears,
              enabled: !_saving,
              searchable: false,
              noResultText: context.t('search.classYear.noResult'),
              onSelected: (String value) => setState(() => _classYear = value),
            ),
            const SizedBox(height: 12),
            GenderPicker(
              value: _gender,
              enabled: !_saving,
              onChanged: (String value) => setState(() => _gender = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _studentNumber,
              enabled: !_saving,
              keyboardType: TextInputType.text,
              inputFormatters: guardedInput(InputLimits.studentNumber),
              decoration: InputDecoration(
                labelText: context.t('form.studentNumber'),
              ),
            ),
            const SizedBox(height: 12),
            // Telefon artık formun bir alanı. Kaydederken numara değişmişse
            // sahiplik sorgusu + SMS doğrulama pop-up'ı devreye girer.
            LivePhoneField(
              controller: _phone,
              label: context.t('form.phone'),
              enabled: !_saving,
              errorText: _phoneError,
              onChanged: _clearPhoneError,
            ),
            const SizedBox(height: 6),
            Text(
              context.t('account.phoneChangeHint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _cancelEditing(profile),
                    child: Text(context.t('common.cancel')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : () => _saveDetails(profile),
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
              ],
            ),
          ] else ...<Widget>[
            _InfoTile(
              icon: Icons.phone_outlined,
              label: context.t('form.phone'),
              value: formatE164ForDisplay(profile.phone),
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
              icon: Icons.menu_book_outlined,
              label: context.t('form.department'),
              value: profile.department,
            ),
            _InfoTile(
              icon: Icons.grade_outlined,
              label: context.t('form.classYear'),
              value: profile.classYear,
            ),
            _InfoTile(
              icon: Icons.badge_outlined,
              label: context.t('form.studentNumber'),
              value: profile.studentNumber,
            ),
            // Sözleşme/KVKK onayının tam anı — gün, saat, dakika, saniye.
            // Kullanıcı ne zaman onay verdiğini kendi kartından görebilmeli
            // (bkz. KVKK Aydınlatma Metni madde 7).
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
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _startEditing(profile),
              icon: const Icon(Icons.edit_outlined),
              label: Text(context.t('studentAccount.edit')),
            ),
          ],

          const SizedBox(height: 24),

          // İP-TK: takip edilen kulüpler (düzenleme kipinde gizli).
          if (!_editing) ...<Widget>[
            // İP-GR: organizatör bu hesabı görevli eklediyse.
            const StaffEventsSection(),
            const FollowedClubsSection(),
            const SizedBox(height: 24),
            // İP-ŞK: engellenen organizatörler (liste boşsa görünmez).
            const BlockedOrganizersSection(),
          ],

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

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: context.cardDecoration(radius: BrandShape.controlRadius),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.brandTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: context.brandInk),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    value.isNotEmpty ? value : '-',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: context.ink,
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
