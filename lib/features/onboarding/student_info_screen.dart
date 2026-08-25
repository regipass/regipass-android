import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../core/input_guard.dart';
import '../../core/password_policy.dart';
import '../../core/sanitize.dart';
import '../../data/department_data.dart';
import '../../data/location_data.dart';
import '../../l10n/app_strings.dart';
import '../../models/profiles.dart';
import '../../services/firebase_refs.dart';
import '../../services/phone_directory_repository.dart';
import '../../state/providers.dart';
import '../auth/auth_actions.dart';
import '../shared/common_widgets.dart';
import '../shared/gender_picker.dart';
import '../shared/live_phone_field.dart';
import '../shared/media_viewer.dart';
import '../shared/phone_field.dart';
import '../shared/profile_photo.dart';
import '../shared/searchable_field.dart';

/// info.html + js/pages/info.js karşılığı — öğrenci profil formu.
///
/// Kaydetme sonrası yönlendirme yapılmaz; profil akışı `onboardingCompleted`
/// ve `phoneVerified` değerlerini görünce router doğru ekrana alır.
class StudentInfoScreen extends ConsumerStatefulWidget {
  const StudentInfoScreen({super.key});

  @override
  ConsumerState<StudentInfoScreen> createState() => _StudentInfoScreenState();
}

/// Hazırlık -> 6. Sınıf -> Mezun sırası korunmalı (alfabetik sıralanmamalı).
const List<String> kClassYears = <String>[
  'Hazırlık',
  '1. Sınıf',
  '2. Sınıf',
  '3. Sınıf',
  '4. Sınıf',
  '5. Sınıf',
  '6. Sınıf',
  'Mezun',
];

class _StudentInfoScreenState extends ConsumerState<StudentInfoScreen> {
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _studentNumber = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _passwordConfirm = TextEditingController();
  final PhoneFieldController _phone = PhoneFieldController();

  /// Klavyenin "ileri" tuşuyla ad -> soyad -> telefon zinciri. Alanların
  /// arasında seçim kutuları olduğu için Flutter'ın kendi odak sıralamasına
  /// güvenilemez; hedef düğüm açıkça verilir.
  final FocusNode _lastNameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();

  String _city = '';
  String _university = '';
  String _department = '';
  String _classYear = '';

  /// `male` | `female` | boş. Web'deki radyo grubuyla aynı iki değer.
  String _gender = '';

  XFile? _pickedPhoto;
  bool _removePhoto = false;

  /// Hesap sayfasından "Bilgileri Düzenle" ile gelindiyse true. Bu durumda
  /// ekran bir onboarding adımı değil, geri dönülebilir bir düzenleme
  /// sayfasıdır: çıkış düğmesi yerine geri oku gösterilir ve kayıttan sonra
  /// yönlendirmeyi router değil, bu ekran (pop ederek) yapar.
  bool _editMode = false;

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
    _studentNumber.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
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

  /// Mevcut profil bir kez forma doldurulur; sonraki snapshot güncellemeleri
  /// kullanıcının yazdıklarının üzerine yazmamalı.
  void _prefill(StudentProfile? profile, User? user) {
    // Hesap değiştiyse form yeniden doldurulmalı: aynı ekran nesnesi
    // ayakta kalıp önceki kullanıcının bilgilerini taşıyabiliyor.
    final String uid = user?.uid ?? '';
    if (_prefilledFor != uid) {
      _prefilled = false;
      _prefilledFor = uid;
    }

    if (_prefilled || profile == null) return;
    _prefilled = true;
    _editMode = profile.onboardingCompleted;

    _firstName.text = profile.firstName;
    _lastName.text = profile.lastName;
    _studentNumber.text = profile.studentNumber;
    _phone.setValue(profile.phone);

    _city = profile.city;
    _university = profile.university;
    _department = profile.department;
    _classYear = profile.classYear;
    // Eski kayıtlarda alan boş olabilir; o hâlde hiçbir seçenek işaretlenmez
    // ve kullanıcı kaydetmeden önce seçmek zorunda kalır.
    _gender = profile.gender == 'male' || profile.gender == 'female'
        ? profile.gender
        : '';

    // Yeni Google kullanıcısında profil boşsa adı hesap adından türet.
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

  /// Şifre sağlayıcısı yoksa (Google ile gelmiş hesap) şifre belirlenmesi
  /// zorunludur — web'deki `ensureManualPassword` akışı.
  bool _needsPassword(User? user, StudentProfile? profile) {
    if (user == null) return false;
    if (profile?.hasPassword == true) return false;
    return !ref.read(authRepositoryProvider).hasPasswordProvider(user);
  }

  Future<void> _pickPhoto() async {
    final XFile? file = await pickProfilePhoto(context);
    if (file == null) return;

    final bool tooLarge = await file.length() > kMaxProfilePhotoBytes;
    if (!mounted) return;

    if (tooLarge) {
      _setFeedback(
        context.t('studentInfo.feedback.photoTooLarge'),
        FeedbackTone.error,
      );
      return;
    }

    setState(() {
      _pickedPhoto = file;
      _removePhoto = false;
    });
  }

  /// Seçilen fotoğrafı Storage'a yükler, "kaldır" işaretliyse mevcudu siler.
  Future<({String url, String path})> _resolvePhoto(
    String uid,
    StudentProfile? profile,
  ) async {
    if (_pickedPhoto != null) {
      final String ext = (_pickedPhoto!.name.split('.').lastOrNull ?? 'jpg')
          .toLowerCase();
      final String path = 'student_photos/$uid/profile.$ext';
      final Reference storageRef = fbStorage.ref(path);

      await storageRef.putFile(File(_pickedPhoto!.path));
      final String url = await storageRef.getDownloadURL();

      // Farklı uzantıyla yeniden yüklendiyse eski dosyayı temizle.
      final String oldPath = profile?.photoPath ?? '';
      if (oldPath.isNotEmpty && oldPath != path) {
        try {
          await fbStorage.ref(oldPath).delete();
        } catch (_) {
          // Eski dosya yoksa yok say.
        }
      }

      return (url: url, path: path);
    }

    if (_removePhoto && (profile?.photoPath ?? '').isNotEmpty) {
      try {
        await fbStorage.ref(profile!.photoPath).delete();
      } catch (_) {
        // Yok say.
      }
      return (url: '', path: '');
    }

    return (url: profile?.photoUrl ?? '', path: profile?.photoPath ?? '');
  }

  Future<void> _save() async {
    final Session session = ref.read(sessionProvider);
    final User? user = session.user;
    if (user == null) return;

    final StudentProfile? profile = session.studentProfile;

    // ── Doğrulamalar (info.js#saveStudentProfile sırası) ──────────────
    if (!_phone.isValid) {
      _setFeedback(
        context.t('studentInfo.feedback.invalidPhone'),
        FeedbackTone.error,
      );
      return;
    }
    if (_city.isEmpty) {
      _setFeedback(
        context.t('studentInfo.feedback.invalidCity'),
        FeedbackTone.error,
      );
      return;
    }
    if (_university.isEmpty) {
      _setFeedback(
        context.t('studentInfo.feedback.invalidUniversity'),
        FeedbackTone.error,
      );
      return;
    }
    if (_department.isEmpty) {
      _setFeedback(
        context.t('studentInfo.feedback.invalidDepartment'),
        FeedbackTone.error,
      );
      return;
    }
    if (_classYear.isEmpty) {
      _setFeedback(
        context.t('studentInfo.feedback.invalidClassYear'),
        FeedbackTone.error,
      );
      return;
    }
    if (_gender.isEmpty) {
      _setFeedback(
        context.t('studentInfo.feedback.invalidGender'),
        FeedbackTone.error,
      );
      return;
    }

    // XSS kalıbı yakalanırsa kaydetmeden uyar (web ile aynı davranış).
    if (detectHarmfulInput(_firstName.text) ||
        detectHarmfulInput(_lastName.text) ||
        detectHarmfulInput(_studentNumber.text)) {
      _setFeedback(
        context.t('feedback.harmfulInputDetected'),
        FeedbackTone.error,
      );
      return;
    }

    final String firstName = sanitizeName(_firstName.text);
    final String lastName = sanitizeName(_lastName.text);
    final String studentNumber = sanitizeText(
      _studentNumber.text,
      maxLength: 30,
    );

    if (firstName.isEmpty || lastName.isEmpty || studentNumber.isEmpty) {
      _setFeedback(context.t('feedback.fillAllRequired'), FeedbackTone.error);
      return;
    }

    final bool needsPassword = _needsPassword(user, profile);
    if (needsPassword) {
      if (_password.text.isEmpty || _passwordConfirm.text.isEmpty) {
        _setFeedback(
          context.t('auth.feedback.passwordRequired'),
          FeedbackTone.error,
        );
        return;
      }
      if (_password.text != _passwordConfirm.text) {
        _setFeedback(
          context.t('auth.feedback.passwordMismatch'),
          FeedbackTone.error,
        );
        return;
      }
      if (!isStrongPassword(_password.text)) {
        _setFeedback(context.t('auth.error.weakPassword'), FeedbackTone.error);
        return;
      }
    }

    setState(() {
      _saving = true;
      _phoneError = null;
    });
    _setFeedback(context.t('studentInfo.feedback.saving'));

    // Numara sahiplik sorgusu, profil yazılmadan ve doğrulama kapısına
    // düşülmeden ÖNCE. Numara başkasına aitse kullanıcı burada öğrenir;
    // eskiden hiçbir uyarı çıkmadan kaydediliyor, kullanıcı doğrulama
    // ekranında SMS isteyip kodu girdikten sonra hataya çarpıyordu.
    if (!await _phoneIsAvailable(uid: user.uid, phoneE164: _phone.e164)) return;

    try {
      if (needsPassword) {
        await ref
            .read(authRepositoryProvider)
            .linkPassword(user, _password.text);
      }

      final ({String path, String url}) photo = await _resolvePhoto(
        user.uid,
        profile,
      );
      final String phone = _phone.e164;

      // Numara değişmediyse önceki doğrulama korunur; Auth hesabında bu numara
      // zaten bağlıysa da doğrulanmış sayılır.
      final bool verifiedUnchanged =
          profile?.phoneVerified == true && profile?.phone == phone;
      final bool verifiedViaAuthAccount = user.phoneNumber == phone;
      final bool phoneVerified = verifiedUnchanged || verifiedViaAuthAccount;

      if (phoneVerified) {
        // Kural yazma anındaki token'ın phone_number iddiasına bakar.
        try {
          await user.getIdToken(true);
        } catch (_) {
          // En iyi çaba.
        }
      }

      await ref
          .read(profileRepositoryProvider)
          .saveStudentProfile(
            uid: user.uid,
            email: user.email ?? profile?.email ?? '',
            firstName: firstName,
            lastName: lastName,
            phone: phone,
            city: _city,
            university: _university,
            department: _department,
            studentNumber: studentNumber,
            classYear: _classYear,
            gender: _gender,
            photoUrl: photo.url,
            photoPath: photo.path,
            phoneVerified: phoneVerified,
            hasPassword: true,
          );

      // Formu düzenleme modunda açan öğrencinin eski kayıtları olabilir;
      // kulübün gördüğü kopya alanlar (isim, bölüm, telefon) da tazelenir.
      // En iyi çaba: başarısız olursa profil kaydı yine de geçerlidir.
      try {
        await ref
            .read(eventRepositoryProvider)
            .syncStudentInfoOnRegistrations(
              studentId: user.uid,
              firstName: firstName,
              lastName: lastName,
              phone: phone,
              city: _city,
              university: _university,
              department: _department,
              classYear: _classYear,
              email: user.email ?? profile?.email ?? '',
            );
      } catch (_) {
        // Yoksay — bkz. docs/kayit-profil-senkronu.md
      }

      // Onboarding'de yönlendirmeyi router yapar; düzenleme modunda profil
      // zaten tamam olduğu için router bir şey değiştirmez, geri dönmek bu
      // ekranın işi.
      if (_editMode && mounted && context.canPop()) context.pop();
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
    _prefill(session.studentProfile, session.user);

    final bool needsPassword = _needsPassword(
      session.user,
      session.studentProfile,
    );
    final String existingPhotoUrl = session.studentProfile?.photoUrl ?? '';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: _editMode,
        titleSpacing: _editMode ? 0 : 16,
        title: Row(
          children: <Widget>[
            const BrandMark(size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _editMode
                    ? context.t('studentAccount.edit')
                    : context.t('studentInfo.title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: _editMode
            ? null
            : <Widget>[
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
              context.t('studentInfo.subtitle'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),

            _PhotoPicker(
              picked: _pickedPhoto,
              existingUrl: _removePhoto ? '' : existingPhotoUrl,
              onPick: _pickPhoto,
              onRemove: () => setState(() {
                _pickedPhoto = null;
                _removePhoto = true;
              }),
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
                labelText: context.t('form.firstName'),
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
                labelText: context.t('form.lastName'),
              ),
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
              options: kClassYears,
              enabled: !_saving,
              noResultText: context.t('search.classYear.noResult'),
              onSelected: (String value) => setState(() => _classYear = value),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _studentNumber,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: guardedInput(InputLimits.studentNumber),
              decoration: InputDecoration(
                labelText: context.t('form.studentNumber'),
              ),
            ),
            const SizedBox(height: 16),

            // Cinsiyet zorunlu: yönetici istatistiklerindeki dağılım bu
            // alandan hesaplanıyor, boş bırakılan kayıt orada "belirtilmemiş"
            // kovasında birikiyordu.
            GenderPicker(
              value: _gender,
              enabled: !_saving,
              onChanged: (String value) => setState(() => _gender = value),
            ),

            if (needsPassword) ...<Widget>[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                context.t('auth.feedback.passwordRequired'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                enabled: !_saving,
                obscureText: true,
                inputFormatters: lengthOnlyInput(InputLimits.password),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: context.t('form.password'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordConfirm,
                enabled: !_saving,
                obscureText: true,
                inputFormatters: lengthOnlyInput(InputLimits.password),
                decoration: InputDecoration(
                  labelText: context.t('form.passwordConfirm'),
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
                      : context.inkMuted,
                ),
              ),
            ],

            const SizedBox(height: 28),
            // Buton içeriği sabit yükseklikte: metin ile göstergenin doğal
            // boyutları farklı olduğu için kaydederken buton zıplıyordu.
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

            // Geri bildirim butonun ALTINDA: listenin tepesinde belirdiğinde
            // altındaki her şeyi aşağı itiyor ve kaydete basan parmağın
            // altından buton kayıyordu.
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

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
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
                        title: context.t('form.photo'),
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
                          Icons.person_outline,
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
                context.t('form.photo'),
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
