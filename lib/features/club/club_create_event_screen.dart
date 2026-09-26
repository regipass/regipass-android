import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/input_guard.dart';
import '../../core/sanitize.dart';
import '../../data/club_fields.dart';
import '../../data/department_data.dart';
import '../../data/location_data.dart';
import '../../domain/checkin_mode.dart';
import '../../domain/event_contact.dart';
import '../../domain/event_utils.dart';
import '../../domain/paid_event_consent.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../models/profiles.dart';
import '../../services/event_repository.dart';
import '../../services/firebase_refs.dart';
import '../../services/registration_service.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import '../shared/event_widgets.dart';
import '../shared/multi_select_chips.dart';
import 'club_shell.dart';
import 'location_picker_screen.dart';

/// Doğrulamada işaretlenebilecek alanlar.
enum _Field {
  title,
  description,
  purpose,
  image,
  deadline,
  eventDate,
  time,
  fee,
  quota,
  contact,
  targetUniversity,
  targetDepartment,
  threshold,
  checkinMode,
  location,
}

/// Etkinlik görseli için üst sınır.
///
/// Etkinlik görseli Storage'a yüklenir; Firestore'da yalnızca indirme adresi
/// tutulduğu için etkinliği gören diğer kullanıcılar da görsele erişebilir.
const int kMaxEventImageBytes = 5 * 1024 * 1024;

/// club-create-event.html + js/pages/club-create-event.js karşılığı.
///
/// Konum, web'deki Leaflet modalinin aynısı olan bir harita ekranından
/// seçilir (bkz. location_picker_screen.dart): arama, cihaz konumu ve
/// yarıçap ayarı hepsi orada. Enlem/boylamı elle yazma yolu bilerek yok —
/// rakamla koordinat girmek hataya çok açıktı.
class ClubCreateEventScreen extends ConsumerStatefulWidget {
  const ClubCreateEventScreen({this.eventId, super.key});

  /// Dolu ise düzenleme modu (web'deki `?eventId=` sorgu parametresi).
  final String? eventId;

  @override
  ConsumerState<ClubCreateEventScreen> createState() =>
      _ClubCreateEventScreenState();
}

class _ClubCreateEventScreenState extends ConsumerState<ClubCreateEventScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _purpose = TextEditingController();
  final TextEditingController _quota = TextEditingController();
  final TextEditingController _feeAmount = TextEditingController();
  final TextEditingController _contactPhone = TextEditingController();
  final TextEditingController _contactEmail = TextEditingController();
  final TextEditingController _imageUrl = TextEditingController();
  final TextEditingController _sessionCount = TextEditingController(text: '1');
  final TextEditingController _threshold = TextEditingController();
  final TextEditingController _locationName = TextEditingController();
  final TextEditingController _locationRadius = TextEditingController(
    text: '50',
  );

  /// İlk üç alan tek bir yazım akışı oluşturur: etkinlik adı → açıklama →
  /// amaç. Son alandaki "bitir" odağı kaldırıp klavyeyi kapatır.
  final FocusNode _descriptionFocus = FocusNode();
  final FocusNode _purposeFocus = FocusNode();

  String _feeType = 'free';

  /// Etkinlikte gösterilecek iletişim: `club` (sistemdeki kulüp bilgileri),
  /// `custom` (bu etkinliğe özel), `hidden` (yalnızca ücretsiz etkinlikte).
  String _contactMode = 'club';
  String _checkinMode = CheckinMode.checkinOnly;
  String _targetScope = TargetScope.public;

  /// Hedeflenen üniversiteler / bölümler. Kulüp birden fazla seçebilir:
  /// bir etkinlik çoğu zaman tek bir bölüme değil, birbirine yakın birkaç
  /// bölüme hitap ediyor.
  List<String> _targetUniversities = <String>[];
  List<String> _targetDepartments = <String>[];

  DateTime? _deadline;
  DateTime? _eventDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  double? _lat;
  double? _lng;

  /// Eski etkinliklerdeki base64 görselleri düzenleme ekranında korumak için.
  String? _pickedImageDataUrl;

  /// Yeni seçilen dosya; kaydetme sırasında Storage'a yüklenir.
  XFile? _pickedImageFile;

  bool _prefilled = false;
  bool _saving = false;
  String? _feedback;
  FeedbackTone _tone = FeedbackTone.info;

  /// Doğrulamada takılan alan. Uyarı metniyle birlikte o alan neon kırmızı
  /// bir halkayla işaretlenir; kullanıcı uzun formda nereye bakacağını
  /// aramak zorunda kalmasın.
  _Field? _invalidField;

  bool get _isEdit => (widget.eventId ?? '').isNotEmpty;

  /// Uyarıyı ve suçlu alanı birlikte ayarlar.
  void _fail(_Field field, String message) {
    _markInvalid(field);
    _setFeedback(message, FeedbackTone.error);
  }

  void _markInvalid(_Field field) {
    if (!mounted) return;
    setState(() => _invalidField = field);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _purpose.dispose();
    _quota.dispose();
    _feeAmount.dispose();
    _contactPhone.dispose();
    _contactEmail.dispose();
    _imageUrl.dispose();
    _sessionCount.dispose();
    _threshold.dispose();
    _locationName.dispose();
    _locationRadius.dispose();
    _descriptionFocus.dispose();
    _purposeFocus.dispose();
    super.dispose();
  }

  void _setFeedback(String? message, [FeedbackTone tone = FeedbackTone.info]) {
    if (!mounted) return;
    setState(() {
      _feedback = message;
      _tone = tone;
    });
  }

  /// Düzenleme modunda mevcut etkinlik bir kez forma doldurulur.
  void _prefill(AppEvent? event) {
    if (_prefilled || event == null) return;
    _prefilled = true;

    _title.text = event.title;
    _description.text = event.description;
    _purpose.text = event.purpose;
    _quota.text = event.quota > 0 ? '${event.quota}' : '';
    _feeType = event.feeType.isEmpty ? 'free' : event.feeType;
    _feeAmount.text = event.feeAmount > 0 ? '${event.feeAmount}' : '';
    _contactMode = const <String>{'club', 'custom', 'hidden'}
            .contains(event.contactMode)
        ? event.contactMode
        : 'club';
    if (_contactMode == 'hidden' && _feeType == 'paid') _contactMode = 'club';
    _contactPhone.text = formatContactPhone(event.contactPhone);
    _contactEmail.text = event.contactEmail;
    _sessionCount.text = '${event.sessionCount}';
    _checkinMode = event.resolvedCheckinMode;
    _threshold.text = event.certificateThresholdPercent?.toString() ?? '';
    _locationName.text = event.locationName;
    _locationRadius.text = '${event.effectiveRadius}';
    _lat = event.locationLat;
    _lng = event.locationLng;

    _targetScope = event.targetScope;
    _targetUniversities = List<String>.of(event.targetUniversities);
    _targetDepartments = List<String>.of(event.targetDepartments);

    // Eski kayıtlarda "bölüme özel" üniversiteyi de kısıtlıyordu. Düzenleme
    // ekranında bu kayıt yeni kapsama taşınır; aksi hâlde kulüp yalnızca
    // başlığı değiştirse bile üniversite kısıtı sessizce düşerdi.
    if (_targetScope == TargetScope.department &&
        _targetUniversities.isNotEmpty) {
      _targetScope = TargetScope.universityDepartment;
    }

    // Görsel base64 veri URL'i ise metin kutusuna sığmaz; seçilmiş sayılır.
    if (event.imageUrl.startsWith('data:')) {
      _pickedImageDataUrl = event.imageUrl;
    } else {
      // Kulübün kendi seçmediği kapaklar (eski web kayıtlarındaki doğa
      // fotoğrafı ya da ağ yer tutucusu) forma hiç taşınmaz: kutuya yazılsa
      // kulübün kendi yapıştırdığı bir adresmiş gibi görünürdü. Form onları
      // "kapak yok" sayar; kaydedince etkinliğin kapağı gri marka perdesine
      // döner.
      if (!isAutoCoverUrl(event.imageUrl)) {
        _imageUrl.text = event.imageUrl;
      }
    }

    if (event.deadlineAtMs > 0) {
      _deadline = DateTime.fromMillisecondsSinceEpoch(event.deadlineAtMs);
    }
    if ((event.eventDateAtMs ?? 0) > 0) {
      _eventDate = DateTime.fromMillisecondsSinceEpoch(event.eventDateAtMs!);
    }
    _startTime = _parseTime(event.eventStartTime);
    _endTime = _parseTime(event.eventEndTime);
  }

  static TimeOfDay? _parseTime(String value) {
    final List<String> parts = value.split(':');
    if (parts.length < 2) return null;
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _formatTime(TimeOfDay? time) => time == null
      ? ''
      : '${time.hour.toString().padLeft(2, '0')}:'
            '${time.minute.toString().padLeft(2, '0')}';

  static String _formatDate(DateTime? date) => date == null
      ? ''
      : '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';

  List<String> get _allUniversities =>
      kCityUniversities.values
          .expand((List<String> list) => list)
          .toSet()
          .toList()
        ..sort();

  /// Bölüm listesi kulübün kendi alanlarıyla başlar.
  ///
  /// Varsayılan hedef zaten kulübün alanı; çipi silen kulüp aynı seçimi
  /// listede bulamazsa geri koyamazdı. Ayrıca "tüm bilgisayar/yazılım
  /// bölümleri" gibi geniş bir hedef, 600 bölümü tek tek seçmekten kolay.
  List<String> _departmentOptions(ClubProfile? club) => <String>{
    ...?club?.clubFields,
    ...kClubFields,
    ...kCommonDepartments,
  }.toList();

  ClubProfile? get _club => ref.read(sessionProvider).clubProfile;

  /// Kulübün kendi üniversitesi — hedef seçilmediğinde kullanılan varsayılan.
  List<String> get _clubUniversityDefault {
    final String university = _club?.university ?? '';
    return university.isEmpty ? const <String>[] : <String>[university];
  }

  /// Kulübün kendi alanları. Birden fazlaysa hedef kutusuna İLK alan düşer;
  /// kulüp isterse diğerlerini de ekler.
  List<String> get _clubFieldDefault {
    final List<String> fields = _club?.clubFields ?? const <String>[];
    return fields.isEmpty ? const <String>[] : <String>[fields.first];
  }

  /// Kapsam değişince ilgili kutu kulübün kendi bilgisiyle açılır: kulüp
  /// hiçbir şeye dokunmadan kaydederse etkinlik kendi üniversitesini ve
  /// kendi alanını hedefler.
  void _onScopeChanged(String value) {
    setState(() {
      _targetScope = value;
      _invalidField = null;

      if (TargetScope.needsUniversity(value) && _targetUniversities.isEmpty) {
        _targetUniversities = List<String>.of(_clubUniversityDefault);
      }
      if (TargetScope.needsDepartment(value) && _targetDepartments.isEmpty) {
        _targetDepartments = List<String>.of(_clubFieldDefault);
      }
    });
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    // Düzenlenen etkinliğin tarihi geçmişte olabilir. `initialDate`
    // `firstDate`ten önce olursa showDatePicker assert ile patlıyor; bu yüzden
    // alt sınır mevcut değerle bugünün ERKEN olanına çekilir.
    final DateTime first = initial != null && initial.isBefore(today)
        ? initial
        : today;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial ?? today,
      firstDate: first,
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) onPicked(picked);
  }

  /// Saat sorar.
  ///
  /// Android'de Material'ın kendi seçicisi klavye kipiyle açılır: kulüp
  /// istediği saati ve dakikayı doğrudan yazabilir (kadran kipine de
  /// geçebilir). 15 dakikalık hazır listeye dönmüyoruz — 19:40'ta başlayan
  /// bir etkinlik yazılamıyordu. iOS'ta aynı davranış (serbest dakika, 24
  /// saatlik biçim, aynı varsayılan) yerli tekerlek seçiciyle sunulur —
  /// yalnızca görünüm platforma uyar, mantık değişmez.
  Future<TimeOfDay?> _askTime(TimeOfDay? initial) => Platform.isIOS
      ? _askTimeCupertino(initial)
      : showTimePicker(
          context: context,
          initialTime: initial ?? const TimeOfDay(hour: 10, minute: 0),
          initialEntryMode: TimePickerEntryMode.input,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            // Türkiye'de saat 24'lük yazılır; ÖÖ/ÖS kutusu kafa karıştırıyordu.
            data: MediaQuery.of(
              context,
            ).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );

  /// iOS'un yerli saat tekerleğini bir alt sayfada gösterir.
  ///
  /// Material sürümüyle aynı varsayılan saati başlangıç alır, aynı 24 saatlik
  /// biçimi kullanır ve dakikayı serbestçe (1'er dakikalık adımlarla, kadranı
  /// çevirerek) seçtirir — klavye yerine tekerlek olması dışında davranış
  /// Android'dekiyle birebir aynıdır.
  Future<TimeOfDay?> _askTimeCupertino(TimeOfDay? initial) {
    final TimeOfDay start = initial ?? const TimeOfDay(hour: 10, minute: 0);
    DateTime selected = DateTime(2000, 1, 1, start.hour, start.minute);

    return showCupertinoModalPopup<TimeOfDay>(
      context: context,
      builder: (BuildContext sheetContext) => Container(
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(BrandShape.cardRadius),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  CupertinoButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: Text(context.t('common.cancel')),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.of(sheetContext).pop(
                      TimeOfDay(hour: selected.hour, minute: selected.minute),
                    ),
                    child: Text(
                      context.t('common.done'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              Divider(height: 1, color: context.hairline),
              SizedBox(
                height: 216,
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: context.isDarkMode
                        ? Brightness.dark
                        : Brightness.light,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        color: context.ink,
                        fontSize: 21,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: selected,
                    onDateTimeChanged: (DateTime value) => selected = value,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickStartTime() async {
    final TimeOfDay? picked = await _askTime(_startTime);
    if (picked == null || !mounted) return;

    setState(() {
      _startTime = picked;
      // Bitiş artık başlangıçtan önce kalıyorsa temizlenir; kullanıcı geçersiz
      // bir aralıkla kaydetmeye çalışıp uyarı yemesin.
      if (_endTime != null && !_isAfter(_endTime!, picked)) _endTime = null;
      _invalidField = null;
    });
  }

  Future<void> _pickEndTime() async {
    final TimeOfDay? picked = await _askTime(_endTime ?? _startTime);
    if (picked == null || !mounted) return;

    // Seçici saatleri kilitleyemediği için aralık burada doğrulanır.
    if (_startTime != null && !_isAfter(picked, _startTime!)) {
      _fail(
        _Field.time,
        context.t('clubCreateEvent.feedback.invalidTimeRange'),
      );
      return;
    }

    setState(() {
      _endTime = picked;
      _invalidField = null;
    });
  }

  static bool _isAfter(TimeOfDay a, TimeOfDay b) =>
      a.hour * 60 + a.minute > b.hour * 60 + b.minute;

  Future<void> _pickImage() async {
    // Storage'a gönderilecek dosyayı uygulama içinde makul boyutta tut.
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 70,
    );
    if (file == null) return;

    final Uint8List bytes = await file.readAsBytes();
    if (!mounted) return;

    if (bytes.length > kMaxEventImageBytes) {
      // Ne kadar aştığını söyle: kullanıcı "biraz daha küçüğünü seçeyim"
      // diyebilsin, tahmin etmek zorunda kalmasın.
      _setFeedback(
        context.t(
          'clubCreateEvent.feedback.imageTooLargeDetail',
          <String, Object?>{
            'size': (bytes.length / 1024).round(),
            'limit': (kMaxEventImageBytes / 1024).round(),
          },
        ),
        FeedbackTone.error,
      );
      _markInvalid(_Field.image);
      return;
    }

    // Önizleme için geçici data URL tutulur; Firestore'a yazılmaz, kaydetmede
    // dosyanın kendisi Storage'a yüklenir.
    setState(() {
      _pickedImageDataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      _pickedImageFile = file;
      _imageUrl.clear();
      _invalidField = null;
    });
  }

  Future<String> _uploadEventImage({
    required String clubId,
    required String eventId,
    required XFile file,
  }) async {
    final Uint8List bytes = await file.readAsBytes();
    final Reference reference = fbStorage.ref(
      'event_images/$clubId/$eventId.jpg',
    );
    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public,max-age=3600',
      ),
    );
    return reference.getDownloadURL();
  }

  /// Haritayı açar; kullanıcı iğneyi konumlandırıp onaylayınca koordinat,
  /// adres ve yarıçap forma geri döner.
  ///
  /// Koordinat elle girilmez: enlem/boylamı rakamla yazmak hataya çok açık
  /// ve kulüp için anlamsız bir iş.
  Future<void> _pickOnMap() async {
    final PickedLocation? picked = await Navigator.of(context)
        .push<PickedLocation>(
          MaterialPageRoute<PickedLocation>(
            builder: (_) => LocationPickerScreen(
              initialLat: _lat,
              initialLng: _lng,
              initialRadius: int.tryParse(_locationRadius.text.trim()) ?? 50,
            ),
          ),
        );

    if (picked == null || !mounted) return;

    setState(() {
      _lat = picked.lat;
      _lng = picked.lng;
      _locationRadius.text = '${picked.radius}';
      // Konum adı boşsa haritadan gelen adresle doldur; kulüp yazdıysa
      // kendi metnini bozma.
      if (_locationName.text.trim().isEmpty && picked.address.isNotEmpty) {
        _locationName.text = picked.address;
      }
    });

    _setFeedback(
      context.t('clubCreateEvent.location.captured'),
      FeedbackTone.success,
    );
  }

  /// Konumu tamamen kaldırır — ad alanı da kapanır.
  void _clearLocation() {
    setState(() {
      _lat = null;
      _lng = null;
      _locationName.clear();
      _invalidField = null;
    });
  }

  // ── Kaydetme (club-create-event.js#saveEvent) ──────────────────────

  Future<void> _save() async {
    final Session session = ref.read(sessionProvider);
    final String? uid = session.user?.uid;
    if (uid == null) return;

    final String title = sanitizeText(_title.text, maxLength: 200);
    final String description = sanitizeLongText(_description.text);
    final String purpose = sanitizeLongText(_purpose.text);

    // Boş bırakılan ilk zorunlu alanı işaretle: "hepsini doldur" demek uzun
    // formda kullanıcıyı arama zahmetine sokuyordu.
    final _Field? missing =
        <_Field, String>{
              _Field.title: title,
              _Field.description: description,
              _Field.purpose: purpose,
            }.entries
            .where((MapEntry<_Field, String> e) => e.value.isEmpty)
            .firstOrNull
            ?.key;

    if (missing != null) {
      _fail(missing, context.t('feedback.fillAllRequired'));
      return;
    }

    if (detectHarmfulInput(_title.text) ||
        detectHarmfulInput(_description.text) ||
        detectHarmfulInput(_purpose.text)) {
      _fail(_Field.title, context.t('feedback.harmfulInputDetected'));
      return;
    }

    // Ücret
    int feeAmount = 0;
    String feeInfo = context.t('eventModal.free');
    if (_feeType == 'paid') {
      final int? amount = int.tryParse(_feeAmount.text.trim());
      if (amount == null || amount < 1) {
        _fail(_Field.fee, context.t('clubCreateEvent.feedback.invalidFee'));
        return;
      }
      feeAmount = amount;
      feeInfo = '$amount TL';
    }

    // İletişim bilgisi
    final String contactMode = _feeType == 'paid' && _contactMode == 'hidden'
        ? 'club'
        : _contactMode;
    final String contactPhone = formatContactPhone(_contactPhone.text);
    final String contactEmail = _contactEmail.text.trim();
    if (contactMode == 'custom') {
      final String? error = contactFieldsError(contactPhone, contactEmail);
      if (error != null) {
        _fail(_Field.contact, context.t(error));
        return;
      }
    }

    final int? quota = int.tryParse(_quota.text.trim());
    if (quota == null || quota < 1) {
      _fail(_Field.quota, context.t('clubCreateEvent.feedback.invalidQuota'));
      return;
    }

    // Son başvuru BUGÜN olabilir: gün sonuna kadar geçerlidir.
    final int? deadlineAtMs = parseDeadlineFromInput(_deadline);
    if (deadlineAtMs == null) {
      _fail(
        _Field.deadline,
        context.t('clubCreateEvent.feedback.invalidDeadline'),
      );
      return;
    }

    final int? eventDateAtMs = parseDeadlineFromInput(_eventDate);
    if (eventDateAtMs == null) {
      _fail(
        _Field.eventDate,
        context.t('clubCreateEvent.feedback.invalidEventDate'),
      );
      return;
    }

    // Kayıtlar etkinlik gününden SONRA kapanamaz.
    if (deadlineAtMs > eventDateAtMs) {
      _fail(
        _Field.deadline,
        context.t('clubCreateEvent.feedback.deadlineAfterEventDate'),
      );
      return;
    }

    final String startTime = _formatTime(_startTime);
    final String endTime = _formatTime(_endTime);
    if (startTime.isNotEmpty &&
        endTime.isNotEmpty &&
        endTime.compareTo(startTime) <= 0) {
      _fail(
        _Field.time,
        context.t('clubCreateEvent.feedback.invalidTimeRange'),
      );
      return;
    }

    // Hedef kitle. Kutuya hiç dokunulmadıysa kulübün kendi üniversitesi ve
    // kendi alanı hedeflenir; uyarı yalnızca kulüp profilinde de bu bilgi
    // yoksa çıkar.
    List<String> targetUniversities = const <String>[];
    List<String> targetDepartments = const <String>[];

    if (TargetScope.needsUniversity(_targetScope)) {
      targetUniversities = _targetUniversities.isNotEmpty
          ? _targetUniversities
          : _clubUniversityDefault;
      if (targetUniversities.isEmpty) {
        _fail(
          _Field.targetUniversity,
          context.t('clubCreateEvent.feedback.invalidTargetUniversity'),
        );
        return;
      }
    }
    if (TargetScope.needsDepartment(_targetScope)) {
      targetDepartments = _targetDepartments.isNotEmpty
          ? _targetDepartments
          : _clubFieldDefault;
      if (targetDepartments.isEmpty) {
        _fail(
          _Field.targetDepartment,
          context.t('clubCreateEvent.feedback.invalidTargetDepartment'),
        );
        return;
      }
    }

    // Mod, oturum sayısını değil kapı girişinin gerekip gerekmediğini de
    // belirler. Yoklama içeren iki modda en az iki oturum zorunludur.
    final int rawSessions = int.tryParse(_sessionCount.text.trim()) ?? 1;
    final bool hasSessions = CheckinMode.hasSessions(_checkinMode);
    if (hasSessions && rawSessions <= 1) {
      _fail(
        _Field.checkinMode,
        context.t('clubCreateEvent.feedback.sessionCountRequired'),
      );
      return;
    }
    final int sessionCount = hasSessions ? rawSessions : 1;

    int? threshold;
    if (sessionCount > 1 && _threshold.text.trim().isNotEmpty) {
      final int? raw = int.tryParse(_threshold.text.trim());
      if (raw == null || raw < 1 || raw > 100) {
        _fail(
          _Field.threshold,
          context.t('clubCreateEvent.feedback.invalidCertificateThreshold'),
        );
        return;
      }
      threshold = raw;
    }

    // Konumun tek kaynağı harita: koordinat varsa kaydedilir, ad yalnızca
    // öğrenciye gösterilecek açıklamadır (boş bırakılabilir).
    final String locationName = sanitizeText(
      _locationName.text,
      maxLength: 200,
    );

    // Kapak verilmediyse alan BOŞ kaydedilir: etkinlik kartlarında ve
    // penceresinde gri marka perdesi çizilir (bkz. `EventCoverPlaceholder`).
    // Eskiden bu noktada havuzdan rastgele bir doğa fotoğrafı atanıyordu;
    // etkinlikle ilgisi olmayan fotoğraflar listeleri yanıltıyordu.
    final String imageUrl = _pickedImageFile == null
        ? (_pickedImageDataUrl ?? sanitizeUrl(_imageUrl.text))
        : '';

    // Tüm form kontrolleri tamamlandıktan sonra, yalnızca ücretli etkinliğin
    // ödeme sorumluluğu onayı istenir. İptal eden kulübün formdaki bilgileri
    // korunur; hiçbir etkinlik ya da görsel yüklemesi başlatılmaz.
    final PaidEventConsentAcceptance? paidEventConsent = _feeType == 'paid'
        ? await showPaidEventClubCreationConsentDialog(context)
        : null;
    if ((_feeType == 'paid' && paidEventConsent == null) || !mounted) return;

    setState(() {
      _saving = true;
      _invalidField = null;
    });
    _setFeedback(context.t('clubCreateEvent.feedback.saving'));

    final EventDraft draft = EventDraft(
      title: title,
      description: description,
      purpose: purpose,
      feeType: _feeType,
      feeAmount: feeAmount,
      feeInfo: feeInfo,
      targetScope: _targetScope,
      targetUniversities: targetUniversities,
      targetDepartments: targetDepartments,
      targetSector: '',
      imageUrl: imageUrl,
      quota: quota,
      deadlineAtMs: deadlineAtMs,
      eventDate: _formatDate(_eventDate),
      eventDateAtMs: eventDateAtMs,
      eventStartTime: startTime,
      eventEndTime: endTime,
      eventStartAtMs: _combine(_eventDate, _startTime),
      eventEndAtMs: _combine(_eventDate, _endTime),
      sessionCount: sessionCount,
      checkinMode: _checkinMode,
      certificateThresholdPercent: threshold,
      locationName: locationName,
      locationLat: _lat,
      locationLng: _lng,
      locationRadius: int.tryParse(_locationRadius.text.trim()) ?? 50,
      contactMode: contactMode,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
    );

    String? createdEventId;
    try {
      final EventRepository repo = ref.read(eventRepositoryProvider);

      if (_isEdit) {
        String savedImageUrl = imageUrl;
        if (_pickedImageFile != null) {
          savedImageUrl = await _uploadEventImage(
            clubId: uid,
            eventId: widget.eventId!,
            file: _pickedImageFile!,
          );
        }
        await repo.updateEvent(
          widget.eventId!,
          draft.copyWith(imageUrl: savedImageUrl),
          paidEventConsent: paidEventConsent,
        );
      } else {
        createdEventId = await repo.createEvent(
          draft: draft,
          clubId: uid,
          club: session.clubProfile,
          clubFallbackName: context.t('dashboard.clubFallback'),
          paidEventConsent: paidEventConsent,
        );
        if (_pickedImageFile != null) {
          final String savedImageUrl = await _uploadEventImage(
            clubId: uid,
            eventId: createdEventId,
            file: _pickedImageFile!,
          );
          await repo.updateEvent(
            createdEventId,
            draft.copyWith(imageUrl: savedImageUrl),
            paidEventConsent: paidEventConsent,
          );
        }
      }

      if (!mounted) return;
      if (context.canPop()) context.pop();
    } catch (error) {
      if (createdEventId != null) {
        try {
          // İP-K: yeni (kaydı olmayan) etkinliği sunucu tamamen siler;
          // istemciden silme yalnızca günü geçmiş etkinlikte açık.
          await ref
              .read(registrationServiceProvider)
              .cancelEvent(eventId: createdEventId);
        } catch (_) {
          // Temizleme başarısızsa asıl kayıt hatasını yine göster.
        }
      }
      if (!mounted) return;
      if (error is RegistrationFailure && !error.isNetwork) {
        _setFeedback(
          context.t('registration.errors.${error.reason}', <String, Object?>{
            'registered': error.registered ?? '',
          }),
          FeedbackTone.error,
        );
      } else {
        _setFeedback(context.t('feedback.saveErrorRetry'), FeedbackTone.error);
      }
      setState(() => _saving = false);
    }
  }

  static int? _combine(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    ).millisecondsSinceEpoch;
  }

  Widget _contactSection(ClubProfile? club) {
    final bool paid = _feeType == 'paid';
    final String clubPhone = club?.phone.trim() ?? '';
    final String clubEmail = club?.email.trim() ?? '';
    final String clubSummary = <String>[
      if (clubPhone.isNotEmpty) clubPhone,
      if (clubEmail.isNotEmpty) clubEmail,
    ].join(' · ');
    final TextStyle hint = TextStyle(fontSize: 12.5, color: context.inkMuted);
    return _NeonAlert(
      active: _invalidField == _Field.contact,
      child: _CaptionedField(
        label: context.t(
          paid
              ? 'clubCreateEvent.contact.labelPaid'
              : 'clubCreateEvent.contact.label',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _ChoiceRow(
              options: <({String value, String label})>[
                (
                  value: 'club',
                  label: context.t('clubCreateEvent.contact.club'),
                ),
                (
                  value: 'custom',
                  label: context.t('clubCreateEvent.contact.custom'),
                ),
                if (!paid)
                  (
                    value: 'hidden',
                    label: context.t('clubCreateEvent.contact.hidden'),
                  ),
              ],
              selected: _contactMode,
              enabled: !_saving,
              onChanged: (String value) =>
                  setState(() => _contactMode = value),
            ),
            const SizedBox(height: 8),
            if (_contactMode == 'club')
              Text(
                clubSummary.isEmpty
                    ? context.t('clubCreateEvent.contact.clubEmpty')
                    : context.t(
                        'clubCreateEvent.contact.clubPreview',
                        <String, Object?>{'contact': clubSummary},
                      ),
                style: hint,
              ),
            if (_contactMode == 'hidden')
              Text(context.t('clubCreateEvent.contact.hiddenHint'), style: hint),
            if (_contactMode == 'custom') ...<Widget>[
              TextField(
                controller: _contactPhone,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: const <TextInputFormatter>[
                  ContactPhoneFormatter(),
                ],
                decoration: InputDecoration(
                  labelText: context.t('clubCreateEvent.contact.phone'),
                  hintText: '0XXX XXX XX XX',
                  prefixIcon: Icon(
                    Icons.phone_outlined,
                    size: 19,
                    color: context.inkMuted,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _contactEmail,
                enabled: !_saving,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                inputFormatters: guardedInput(InputLimits.email),
                decoration: InputDecoration(
                  labelText: context.t('clubCreateEvent.contact.email'),
                  prefixIcon: Icon(
                    Icons.alternate_email,
                    size: 19,
                    color: context.inkMuted,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(context.t('clubCreateEvent.contact.customHint'), style: hint),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Düzenleme modunda mevcut etkinlik bir kez forma doldurulur; sonraki
    // snapshot güncellemeleri kullanıcının yazdıklarının üzerine yazmaz.
    if (_isEdit) {
      _prefill(ref.watch(_editEventProvider(widget.eventId!)).value);
    }

    final bool multiSession = CheckinMode.hasSessions(_checkinMode);

    // Bölüm listesi kulübün alanlarıyla başladığı için profil izlenir.
    final ClubProfile? club = ref.watch(sessionProvider).clubProfile;

    return Scaffold(
      appBar: ClubAppBar(
        title: _isEdit
            ? context.t('clubCreateEvent.editTitle')
            : context.t('clubCreateEvent.title'),
        // Yeni etkinlik alt çubuktaki kendi sekmesi: geri oku hem gereksiz hem
        // de sekmeyle çelişiyordu. Düzenleme ise etkinlik ekranından itiliyor,
        // orada geri dönüş şart.
        showBack: _isEdit,
      ),
      // Web'deki kart şeması: form tek uzun ızgara değil, konusuna göre
      // ayrılmış kartlar. Kartların sırası, başlıkları ve açıklamaları
      // club-create-event.html ile birebir aynı — iki istemci aynı formu
      // anlatıyor, kullanıcı web'den mobile geçince formu yeniden öğrenmiyor.
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: <Widget>[
            // ── 1. Temel bilgiler ─────────────────────────────────
            _SectionCard(
              icon: Icons.notes_rounded,
              title: context.t('clubCreateEvent.section.basics'),
              description: context.t('clubCreateEvent.section.basicsDesc'),
              children: <Widget>[
                _NeonAlert(
                  active: _invalidField == _Field.title,
                  child: TextField(
                    controller: _title,
                    enabled: !_saving,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _descriptionFocus.requestFocus(),
                    inputFormatters: guardedInput(InputLimits.title),
                    decoration: InputDecoration(
                      labelText: context.t('form.eventTitle'),
                      hintText: context.t('placeholder.eventTitleExample'),
                    ),
                  ),
                ),
                _NeonAlert(
                  active: _invalidField == _Field.description,
                  child: TextField(
                    controller: _description,
                    focusNode: _descriptionFocus,
                    enabled: !_saving,
                    maxLines: 4,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _purposeFocus.requestFocus(),
                    inputFormatters: guardedInput(
                      InputLimits.longText,
                      multiline: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.t('form.description'),
                      hintText: context.t(
                        'placeholder.eventDescriptionExample',
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                _NeonAlert(
                  active: _invalidField == _Field.purpose,
                  child: TextField(
                    controller: _purpose,
                    focusNode: _purposeFocus,
                    enabled: !_saving,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    inputFormatters: guardedInput(
                      InputLimits.paragraph,
                      multiline: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.t('form.purpose'),
                      hintText: context.t('placeholder.eventPurposeExample'),
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── 2. Katılım ve ücret ───────────────────────────────
            _SectionCard(
              icon: Icons.groups_outlined,
              title: context.t('clubCreateEvent.section.participation'),
              description: context.t(
                'clubCreateEvent.section.participationDesc',
              ),
              info: context.t('clubCreateEvent.sessions.hint'),
              children: <Widget>[
                _CaptionedField(
                  label: context.t('form.feeInfo'),
                  child: _ChoiceRow(
                    options: <({String value, String label})>[
                      (value: 'free', label: context.t('eventModal.free')),
                      (
                        value: 'paid',
                        label: context.t('clubCreateEvent.fee.paid'),
                      ),
                    ],
                    selected: _feeType,
                    enabled: !_saving,
                    onChanged: (String value) => setState(() {
                      _feeType = value;
                      // Ücretli etkinlikte iletişim gizlenemez.
                      if (value == 'paid' && _contactMode == 'hidden') {
                        _contactMode = 'club';
                      }
                    }),
                  ),
                ),
                if (_feeType == 'paid')
                  _NeonAlert(
                    active: _invalidField == _Field.fee,
                    child: TextField(
                      controller: _feeAmount,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      inputFormatters: digitsInput(InputLimits.money),
                      decoration: InputDecoration(
                        labelText: context.t('placeholder.feeAmount'),
                        prefixIcon: Icon(
                          Icons.payments_outlined,
                          size: 19,
                          color: context.inkMuted,
                        ),
                      ),
                    ),
                  ),
                _contactSection(club),
                _NeonAlert(
                  active: _invalidField == _Field.quota,
                  child: TextField(
                    controller: _quota,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    inputFormatters: digitsInput(InputLimits.quota),
                    decoration: InputDecoration(
                      labelText: context.t('form.quota'),
                      hintText: context.t('placeholder.quotaExample'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _NeonAlert(
                  active: _invalidField == _Field.checkinMode,
                  child: DropdownButtonFormField<String>(
                    initialValue: _checkinMode,
                    // Mod adlari dar ekranda kutuya sigmiyor; isExpanded
                    // olmadan satir kendi genisligini dayatip tasiyor.
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.t('form.checkinMode'),
                    ),
                    items: <DropdownMenuItem<String>>[
                      for (final String mode in CheckinMode.values)
                        DropdownMenuItem<String>(
                          value: mode,
                          child: Text(context.t('checkinMode.$mode')),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (String? value) {
                            if (value == null) return;
                            setState(() {
                              _checkinMode = value;
                              if (!CheckinMode.hasSessions(value)) {
                                _sessionCount.text = '1';
                                _threshold.clear();
                              } else if ((int.tryParse(_sessionCount.text) ?? 1) <= 1) {
                                _sessionCount.text = '2';
                              }
                            });
                          },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    context.t('checkinMode.${_checkinMode}Desc'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (multiSession) ...<Widget>[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sessionCount,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    inputFormatters: digitsInput(InputLimits.sessionCount),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: context.t('form.sessionCount'),
                      hintText: context.t('placeholder.sessionCountExample'),
                    ),
                  ),
                ],
                if (multiSession)
                  _NeonAlert(
                    active: _invalidField == _Field.threshold,
                    child: TextField(
                      controller: _threshold,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      inputFormatters: digitsInput(InputLimits.percent),
                      decoration: InputDecoration(
                        labelText: context.t('form.certificateThreshold'),
                        hintText: context.t(
                          'placeholder.certificateThresholdExample',
                        ),
                        suffixText: '%',
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // ── 3. Tarih ve saat ──────────────────────────────────
            _SectionCard(
              icon: Icons.calendar_month_outlined,
              title: context.t('clubCreateEvent.section.schedule'),
              description: context.t('clubCreateEvent.section.scheduleDesc'),
              children: <Widget>[
                _NeonAlert(
                  active: _invalidField == _Field.eventDate,
                  child: _PickerTile(
                    icon: Icons.event_outlined,
                    label: context.t('form.eventDate'),
                    value: _eventDate == null
                        ? context.t('common.select')
                        : formatDeadline(
                            _eventDate!.millisecondsSinceEpoch,
                            locale: context.lang,
                          ),
                    onTap: _saving
                        ? null
                        : () => _pickDate(
                            initial: _eventDate,
                            onPicked: (DateTime d) =>
                                setState(() => _eventDate = d),
                          ),
                  ),
                ),
                _NeonAlert(
                  active: _invalidField == _Field.deadline,
                  child: _PickerTile(
                    icon: Icons.event_available_outlined,
                    label: context.t('form.deadline'),
                    value: _deadline == null
                        ? context.t('common.select')
                        : formatDeadline(
                            _deadline!.millisecondsSinceEpoch,
                            locale: context.lang,
                          ),
                    onTap: _saving
                        ? null
                        : () => _pickDate(
                            initial: _deadline,
                            onPicked: (DateTime d) =>
                                setState(() => _deadline = d),
                          ),
                  ),
                ),
                _CaptionedField(
                  label: context.t('form.eventHours'),
                  optional: true,
                  child: _NeonAlert(
                    active: _invalidField == _Field.time,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: _PickerTile(
                            icon: Icons.schedule,
                            label: context.t('form.startTime'),
                            value: _formatTime(_startTime).isEmpty
                                ? '--:--'
                                : _formatTime(_startTime),
                            onTap: _saving ? null : _pickStartTime,
                            dense: true,
                          ),
                        ),
                        // Web'de iki saat kutusunu ayıran ok (.time-sep).
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: context.inkMuted,
                          ),
                        ),
                        Expanded(
                          child: _PickerTile(
                            icon: Icons.schedule,
                            label: context.t('form.endTime'),
                            value: _formatTime(_endTime).isEmpty
                                ? '--:--'
                                : _formatTime(_endTime),
                            onTap: _saving ? null : _pickEndTime,
                            dense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── 4. Hedef kitle ────────────────────────────────────
            _SectionCard(
              icon: Icons.adjust_rounded,
              title: context.t('clubCreateEvent.section.audience'),
              description: context.t('clubCreateEvent.section.audienceDesc'),
              children: <Widget>[
                // Dört uzun Türkçe etiket çip olarak yan yana dizilince
                // kartın üst yarısını kaplıyordu; açılır liste tek satıra
                // iniyor ve seçenekleri yalnızca gerektiğinde gösteriyor.
                DropdownButtonFormField<String>(
                  initialValue: _targetScope,
                  // Uzun etiketler seçili haldeyken de tam genişliği
                  // kullansın: dar kutuda ortadan kırpılıyorlardı.
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.t('clubCreateEvent.scope.label'),
                  ),
                  items: <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: TargetScope.public,
                      child: Text(context.t('dashboard.scope.all')),
                    ),
                    DropdownMenuItem<String>(
                      value: TargetScope.university,
                      child: Text(context.t('dashboard.scope.university')),
                    ),
                    DropdownMenuItem<String>(
                      value: TargetScope.department,
                      child: Text(
                        context.t('clubCreateEvent.scope.departmentOnly'),
                      ),
                    ),
                    DropdownMenuItem<String>(
                      value: TargetScope.universityDepartment,
                      child: Text(
                        context.t(
                          'clubCreateEvent.scope.universityAndDepartment',
                        ),
                      ),
                    ),
                  ],
                  // `null` verildiğinde liste açılmaz: kayıt sürerken alan
                  // diğer kutularla birlikte kilitli kalıyor.
                  onChanged: _saving
                      ? null
                      : (String? value) {
                          if (value != null) _onScopeChanged(value);
                        },
                ),
                // Üniversite kutusu YALNIZCA üniversite kısıtı olan
                // kapsamlarda açılır: "sadece bölüme özel" seçildiğinde kulüp
                // üniversite seçmek zorunda kalmamalı.
                if (TargetScope.needsUniversity(_targetScope))
                  _NeonAlert(
                    active: _invalidField == _Field.targetUniversity,
                    child: MultiSelectChipsField(
                      label: context.t('form.targetUniversity'),
                      options: _allUniversities,
                      selected: _targetUniversities,
                      enabled: !_saving,
                      hint: context.t('form.multiSelect.addHint'),
                      helperText: context.t(
                        'clubCreateEvent.target.universityHint',
                      ),
                      noResultText: context.t('search.university.noResult'),
                      onChanged: (List<String> value) => setState(() {
                        _targetUniversities = value;
                        _invalidField = null;
                      }),
                    ),
                  ),
                if (TargetScope.needsDepartment(_targetScope))
                  _NeonAlert(
                    active: _invalidField == _Field.targetDepartment,
                    child: MultiSelectChipsField(
                      label: context.t('form.targetDepartment'),
                      options: _departmentOptions(club),
                      selected: _targetDepartments,
                      enabled: !_saving,
                      hint: context.t('form.multiSelect.addHint'),
                      helperText: context.t(
                        'clubCreateEvent.target.departmentHint',
                      ),
                      noResultText: context.t('search.department.noResult'),
                      onChanged: (List<String> value) => setState(() {
                        _targetDepartments = value;
                        _invalidField = null;
                      }),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // ── 5. Konum ──────────────────────────────────────────
            // Konumun tek kaynağı harita. Ad alanı yalnızca seçim yapıldıktan
            // sonra açılır ve sadece açıklamadır: koordinat zaten haritadan
            // geldiği için "ad yazarsan koordinat da gir" uyarısına gerek yok.
            _SectionCard(
              icon: Icons.place_outlined,
              title: context.t('clubCreateEvent.section.location'),
              description: context.t('clubCreateEvent.section.locationDesc'),
              optional: true,
              children: <Widget>[
                _NeonAlert(
                  active: _invalidField == _Field.location,
                  child: _MapPickerTile(
                    lat: _lat,
                    lng: _lng,
                    radius: int.tryParse(_locationRadius.text.trim()) ?? 50,
                    onTap: _saving ? null : _pickOnMap,
                    onClear: _saving || _lat == null ? null : _clearLocation,
                  ),
                ),
                if (_lat != null && _lng != null)
                  TextField(
                    controller: _locationName,
                    enabled: !_saving,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    inputFormatters: guardedInput(InputLimits.shortText),
                    decoration: InputDecoration(
                      labelText: context.t('form.locationName'),
                      helperText: context.t(
                        'clubCreateEvent.location.nameHint',
                      ),
                      helperMaxLines: 3,
                      prefixIcon: Icon(
                        Icons.edit_location_alt_outlined,
                        size: 20,
                        color: context.inkMuted,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // ── 6. Görsel ─────────────────────────────────────────
            _SectionCard(
              icon: Icons.image_outlined,
              title: context.t('clubCreateEvent.section.media'),
              description: context.t('clubCreateEvent.section.mediaDesc'),
              optional: true,
              children: <Widget>[
                _NeonAlert(
                  active: _invalidField == _Field.image,
                  child: _ImagePickerRow(
                    dataUrl: _pickedImageDataUrl,
                    urlController: _imageUrl,
                    enabled: !_saving,
                    onPick: _pickImage,
                    onClear: () => setState(() {
                      _pickedImageDataUrl = null;
                      _pickedImageFile = null;
                    }),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: BrandColors.white,
                      ),
                    )
                  : Icon(
                      _isEdit ? Icons.save_outlined : Icons.add_rounded,
                      size: 20,
                    ),
              label: Text(
                _isEdit
                    ? context.t('common.save')
                    : context.t('clubCreateEvent.create'),
              ),
            ),

            // Uyari butonun HEMEN ALTINDA: kullanici kaydete bastigi yerden
            // gozunu ayirmadan neyin eksik oldugunu goruyor. Sayfanin tepesinde
            // dururken uzun formda hic fark edilmiyordu.
            if (_feedback != null) ...<Widget>[
              const SizedBox(height: 12),
              FeedbackBanner(message: _feedback, tone: _tone),
            ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Düzenleme modunda mevcut etkinliği okumak için.
// ignore: always_specify_types
final _editEventProvider = StreamProvider.family<AppEvent?, String>(
  (Ref ref, String eventId) =>
      ref.watch(eventRepositoryProvider).watchEvent(eventId),
);

/// Doğrulamada takılan alanı neon kırmızı bir halkayla işaretler.
///
/// Nefes alan bir parıltı kullanılıyor: sabit bir çerçeve uzun formda gözden
/// kaçabiliyor, hareket ise kullanıcıyı doğrudan hatalı alana çekiyor.
class _NeonAlert extends StatefulWidget {
  const _NeonAlert({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_NeonAlert> createState() => _NeonAlertState();
}

class _NeonAlertState extends State<_NeonAlert>
    with SingleTickerProviderStateMixin {
  // Denetleyici `initState`te kurulmalı: tembel kurulumda hiç işaretlenmemiş
  // bir alan `dispose` sırasında denetleyiciyi ilk kez yaratıyor, o anda
  // widget ağaçtan koptuğu için "deactivated widget's ancestor" hatası
  // veriyordu. Formdaki her alan için bu hata ekrandan çıkarken tekrarlıyordu.
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_NeonAlert oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;

    if (widget.active) {
      _controller.repeat(reverse: true);
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeInOut.transform(_controller.value);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BrandShape.controlRadius + 3),
            border: Border.all(
              color: BrandColors.danger.withValues(alpha: 0.55 + 0.45 * t),
              width: 1.6,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: BrandColors.danger.withValues(alpha: 0.25 + 0.30 * t),
                blurRadius: 12 + 14 * t,
                spreadRadius: 1 + 2 * t,
              ),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Web'deki `.form-section` kartının karşılığı: simge + başlık + açıklama,
/// altında o konunun alanları.
///
/// Alanların arasındaki boşluğu kartın kendisi koyar; çağıran taraf koşullu
/// alanları (`if (...) Widget`) araya `SizedBox` serpiştirmeden yazabiliyor.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.children,
    this.optional = false,
    this.info,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Widget> children;

  /// Web'deki `.form-section-badge`: kartın doldurulmasının şart olmadığını
  /// söyler.
  final bool optional;

  /// Kartın sağ üstündeki "i" düğmesinin arkasındaki kısa özet.
  ///
  /// Kuralı anlatan metin kartın içinde dururken formu uzatıyor ve kuralı
  /// zaten bilen kulübe her açılışta yeniden okutuyordu; düğmenin arkasında
  /// yalnızca merak eden tek dokunuşla ulaşıyor.
  final String? info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.cardRadius),
        border: Border.all(color: context.hairline),
        boxShadow: BrandShape.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.isDarkMode
                      ? BrandColors.red.withValues(alpha: 0.16)
                      : BrandColors.redTint,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: context.brandInk),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Rozet başlığın yanında akar: dar ekranda başlığı
                    // sıkıştırmak yerine alt satıra iner.
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 7,
                      runSpacing: 3,
                      children: <Widget>[
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                            color: context.ink,
                          ),
                        ),
                        if (optional) const _OptionalBadge(),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: context.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (info != null) _SectionInfoButton(title: title, text: info!),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 14),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// "(isteğe bağlı)" rozeti — web'deki `.optional-hint`.
class _OptionalBadge extends StatelessWidget {
  const _OptionalBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: context.subtleFill,
      borderRadius: BorderRadius.circular(BrandShape.pillRadius),
    ),
    child: Text(
      context.t('form.optionalHint'),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: context.inkMuted,
      ),
    ),
  );
}

/// Üstünde ayrı başlığı olan alan (web'deki `.field-caption` + kutu).
///
/// Material'ın yüzen etiketi tek bir kutunun içinde durur; çip satırı ya da
/// yan yana iki saat kutusu gibi birden çok parçadan oluşan alanların
/// üstünde ise böyle ayrı bir başlık gerekiyor.
class _CaptionedField extends StatelessWidget {
  const _CaptionedField({
    required this.label,
    required this.child,
    this.optional = false,
  });

  final String label;
  final Widget child;
  final bool optional;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      // `Row` değil `Wrap`: uzun etiket + "(isteğe bağlı)" ikilisi dar
      // ekranda ya da büyük yazı tipi ayarında tek satıra sığmıyor, alt
      // satıra inmesi gerekiyor.
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 2,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.ink,
            ),
          ),
          if (optional)
            Text(
              context.t('form.optionalHint'),
              style: TextStyle(fontSize: 11.5, color: context.inkMuted),
            ),
        ],
      ),
      const SizedBox(height: 8),
      child,
    ],
  );
}

/// Bölüm kartının sağ üstündeki özet düğmesi.
///
/// Kuralın tamamı formu uzatmasın diye bir iletişim kutusunda bekler; kart
/// başlığı iletişim kutusunun da başlığı olur, böylece özetin hangi bölümü
/// anlattığı kutuyu açan için belirsiz kalmaz.
class _SectionInfoButton extends StatelessWidget {
  const _SectionInfoButton({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => IconButton(
    // Simgenin kutusu başlıktaki 36'lık rozetle aynı yükseklikte tutuluyor:
    // varsayılan 48'lik dokunma alanı kart başlığını aşağı itiyordu.
    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
    tooltip: context.t('common.info'),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(
          text,
          style: const TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.t('common.close')),
          ),
        ],
      ),
    ),
    icon: Icon(Icons.info_outline_rounded, size: 20, color: context.inkMuted),
  );
}

/// Sarmalanan seçim çipleri.
///
/// `SegmentedButton` sabit genişlikli bölmeler üretiyor ve uzun Türkçe
/// etiketlerde dar ekranda taşıyor; bu satır ise gerektiğinde alt satıra
/// geçiyor.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.options,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final List<({String value, String label})> options;
  final String selected;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final ({String value, String label}) option in options)
          _Choice(
            label: option.label,
            active: option.value == selected,
            enabled: enabled,
            onTap: () => onChanged(option.value),
          ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final String label;
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

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(BrandShape.pillRadius),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(BrandShape.pillRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: active ? BrandColors.white : context.brandInk,
            ),
          ),
        ),
      ),
    );
  }
}

/// Konum özeti + haritayı açan kart.
///
/// Konum seçmenin tek yolu bu: arama, cihaz konumu ve yarıçap ayarı hepsi
/// haritanın içinde. Formda enlem/boylam kutusu bilerek yok.
class _MapPickerTile extends StatelessWidget {
  const _MapPickerTile({
    required this.lat,
    required this.lng,
    required this.radius,
    required this.onTap,
    this.onClear,
  });

  final double? lat;
  final double? lng;
  final int radius;
  final VoidCallback? onTap;

  /// Konum seçiliyken görünen kaldırma eylemi.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final bool hasLocation = lat != null && lng != null;

    return Material(
      color: context.surface,
      borderRadius: BorderRadius.circular(BrandShape.controlRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BrandShape.controlRadius),
            border: Border.all(
              color: hasLocation ? BrandColors.red : context.hairline,
              width: hasLocation ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                hasLocation ? Icons.place : Icons.map_outlined,
                size: 22,
                color: hasLocation ? context.brandInk : context.inkMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.t('clubCreateEvent.location.pickOnMap'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasLocation
                          ? '${lat!.toStringAsFixed(5)}, '
                                '${lng!.toStringAsFixed(5)} · $radius m'
                          : context.t('clubCreateEvent.location.notSet'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (hasLocation && onClear != null)
                IconButton(
                  tooltip: context.t('clubCreateEvent.location.clear'),
                  onPressed: onClear,
                  icon: Icon(Icons.close, size: 20, color: context.inkMuted),
                )
              else
                Icon(Icons.chevron_right, color: context.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarih/saat gibi seçilerek doldurulan alanların kutusu.
class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  /// Yan yana duran iki saat kutusu için: sağdaki ok gizlenir, iç boşluk
  /// daralır — yoksa dar ekranda "Başlangıç / --:--" metni kırpılıyor.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surface,
      borderRadius: BorderRadius.circular(BrandShape.controlRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 11 : 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BrandShape.controlRadius),
            border: Border.all(color: context.hairline),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: dense ? 17 : 19, color: context.inkMuted),
              SizedBox(width: dense ? 9 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (!dense) Icon(Icons.chevron_right, color: context.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Görsel: cihazdan seçilir (base64 gömülür).
///
/// "Görsel Adresi" kutusu kaldırıldı: kulüplerin neredeyse tamamı kapağı
/// telefonundan seçiyordu, adres kutusu ise formu uzatıp "hangisini
/// dolduracağım" sorusu yaratıyordu. Kutu gitse de [urlController] duruyor —
/// daha önce adresle kaydedilmiş etkinlikler düzenlenirken önizlemesi
/// buradan okunuyor ve kaldırma düğmesiyle temizlenebiliyor.
class _ImagePickerRow extends StatelessWidget {
  const _ImagePickerRow({
    required this.dataUrl,
    required this.urlController,
    required this.enabled,
    required this.onPick,
    required this.onClear,
  });

  final String? dataUrl;
  final TextEditingController urlController;

  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    // Adres kutusuna yazmak önizlemeyi anında değiştirmeli; controller'ı
    // dinlemezsek otomatik fotoğraf, kulüp kendi adresini yapıştırdıktan
    // sonra da ekranda kalırdı.
    return ListenableBuilder(
      listenable: urlController,
      builder: (BuildContext context, _) {
        final String typedUrl = urlController.text.trim();
        final bool hasImage = dataUrl != null || typedUrl.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (dataUrl != null) ...<Widget>[
              _preview(
                context,
                child: Image.memory(
                  base64Decode(dataUrl!.split(',').last),
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Container(height: 150, color: context.subtleFill),
                ),
                onRemove: onClear,
              ),
              const SizedBox(height: 10),
            ] else if (typedUrl.isNotEmpty) ...<Widget>[
              _preview(
                context,
                child: EventImage(url: typedUrl, height: 150),
                onRemove: enabled ? urlController.clear : null,
              ),
              const SizedBox(height: 10),
            ],

            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: enabled ? onPick : null,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text(context.t('clubCreateEvent.image.pick')),
              ),
            ),

            // Düğmenin altındaki açıklama + kapağın görsel eklenmediğinde
            // nasıl görüneceğinin küçük bir önizlemesi. Görsel seçildiğinde
            // gizlenir: kapak ekranda dururken yedek perdeyi göstermek
            // kafa karıştırırdı.
            if (!hasImage) ...<Widget>[
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  SizedBox(
                    width: 76,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: const EventCoverPlaceholder(height: 44),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.t('clubCreateEvent.image.autoShort'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  /// Seçili görselin önizlemesi; sağ üstteki düğme onu kaldırır.
  Widget _preview(
    BuildContext context, {
    required Widget child,
    required VoidCallback? onRemove,
  }) {
    return Stack(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(BrandShape.cardRadius),
          child: child,
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: BrandColors.danger,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.remove, size: 17, color: BrandColors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
