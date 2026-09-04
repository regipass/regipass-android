import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../app/theme.dart';
import '../../core/app_log.dart';
import '../../core/input_guard.dart';
import '../../domain/checkin_mode.dart';
import '../../domain/registration_capacity.dart';
import '../../domain/event_utils.dart';
import '../../domain/paid_event_consent.dart';
import '../../domain/routing.dart';
import '../../l10n/app_strings.dart';
import '../../models/event.dart';
import '../../services/firebase_refs.dart';
import '../../state/providers.dart';
import '../shared/common_widgets.dart';
import '../shared/event_widgets.dart';
import '../shared/media_viewer.dart';
import 'club_providers.dart';
import 'club_session_qr_screen.dart';
import 'club_shell.dart';
import 'registrations_export.dart';

/// Dağıtılabilecek belge türleri — storage.rules `certificates/` kuralıyla
/// (application/pdf veya image/*) birebir aynı olmalı.
const List<String> kCertificateExtensions = <String>['pdf', 'png', 'jpg', 'jpeg'];

/// storage.rules sınırı: certificates/ altına en fazla 10 MB.
const int kMaxCertificateBytes = 10 * 1024 * 1024;

/// club-events.js içindeki etkinlik modalinin mobil karşılığı.
///
/// Web'de tek bir modal; mobilde içerik (oturum yönetimi + katılımcı listesi +
/// belge dağıtımı) bir alt sayfaya sığmayacak kadar çok olduğu için ayrı bir
/// ekran. Etkinlik ve kayıtlar canlı dinlenir: QR başka bir cihazdan
/// okutulduğunda sayılar kendiliğinden güncellenir.
class ClubEventDetailScreen extends ConsumerStatefulWidget {
  const ClubEventDetailScreen({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<ClubEventDetailScreen> createState() =>
      _ClubEventDetailScreenState();
}

class _ClubEventDetailScreenState extends ConsumerState<ClubEventDetailScreen> {
  /// Belgeyi dosya seçici yerine adresle/yolla vermek isteyenler için kutu.
  final TextEditingController _link = TextEditingController();

  bool _busy = false;
  String? _feedback;
  FeedbackTone _tone = FeedbackTone.info;

  /// Otomatik dağıtım bu ekran açıldığından beri çalıştı mı?
  ///
  /// Dağıtım pahalı bir iş (öğrenci başına bir Storage yazımı); her kare
  /// yeniden tetiklenmesin diye tek seferle sınırlanıyor. Kulüp gerekirse
  /// belge kartındaki "Dağıt" tuşuyla elle tekrarlayabilir.
  bool _autoDistributed = false;

  /// Kontenjan parçaları bu ekran açıldığından beri kurulmaya çalışıldı mı?
  bool _shardBackfillTried = false;

  /// Kontenjan durumu ile kayıt bayrağını eşitleyen yazma uçuşta mı?
  ///
  /// Doluluk canlı dinleniyor; bayrağı yazınca etkinlik dokümanı da değişiyor
  /// ve build yeniden çalışıyor. Bu kilit olmadan aynı yazma arka arkaya
  /// tetiklenirdi.
  bool _syncingQuotaState = false;

  /// Kontenjan dolunca etkinliği kendiliğinden **beklemeye alır**, yer
  /// açılınca geri açar.
  ///
  /// Bunu neden öğrenci değil kulüp tarafı yapıyor: `firestore.rules`
  /// etkinlik dokümanını yalnızca sahibi kulübe yazdırıyor. Öğrenciye izin
  /// vermek için kuralın "bütün parçalar dolu mu" diye bakması gerekirdi,
  /// kurallarda tek istekte en çok 10 doküman okunabildiği için 16–32 parçada
  /// bu mümkün değil.
  ///
  /// Kontenjanın kendisi zaten parça sayaçlarıyla korunuyor — öğrenci dolu
  /// etkinliğe kaydolamaz. Bu bayrak yalnızca **görünürlük** için: etkinlik
  /// kulüp listesinde "beklemede" görünsün, öğrencinin keşif listesinden
  /// düşsün.
  void _scheduleQuotaStateSync(AppEvent event, QuotaStatus status) {
    if (_syncingQuotaState) return;

    final QuotaGateAction action = quotaGateAction(
      status: status,
      registrationClosed: event.registrationClosed,
      closedReason: event.registrationClosedReason,
    );
    if (action == QuotaGateAction.none) return;

    _syncingQuotaState = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(eventRepositoryProvider).syncRegistrationStateWithQuota(
              event: event,
              status: status,
            );
        // Başarılıysa kilidi bırak: etkinlik dokümanı değişti, build yeniden
        // çalışacak ve `quotaGateAction` artık `none` diyecek. Sonraki gerçek
        // durum değişimi (iptal, kontenjan artışı) yine yakalanabilsin.
        if (mounted) _syncingQuotaState = false;
      } catch (error) {
        // BAŞARISIZLIKTA KİLİT AÇILMAZ. Doluluk canlı dinlendiği için build
        // sık sık yeniden çalışıyor; kilidi bırakmak, kuralca reddedilen bir
        // yazmayı her karede yeniden denemek olurdu. Ekran kapanıp
        // açıldığında tekrar denenir.
        AppLog.warn('event.quotaStateSyncFailed', <String, Object?>{
          'eventId': event.id,
          'error': error.toString(),
        });
      }
    });
  }

  /// Kontenjan parçaları eksik olan ESKİ etkinliklere onları kurar.
  ///
  /// `quotaShardCount` alanı eklenmeden önce oluşturulmuş etkinliklerde parça
  /// yok; o etkinliklerde kayıt kontenjansız eski yoldan geçiyor (davranış
  /// bozulmasın diye bilerek). Parçaları yalnızca etkinliğin sahibi kulüp
  /// kurabildiği için (bkz. firestore.rules) geri dolumun doğal yeri burası:
  /// kulüp kendi etkinliğine baktığı an.
  ///
  /// O ana kadar yapılmış kayıtlar sayaca işlenir — yoksa kontenjan sıfırdan
  /// sayılıp aşılırdı.
  void _scheduleQuotaShardBackfill(AppEvent event) {
    if (_shardBackfillTried || _busy) return;
    if (event.quota <= 0 || event.quotaShardCount > 0) return;

    _shardBackfillTried = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await ref.read(eventRepositoryProvider).syncQuotaShards(
              eventId: event.id,
              quota: event.quota,
            );
      } catch (error) {
        // Sessiz: kontenjan koruması olmadan da kayıt çalışmaya devam eder,
        // kulübün ekranını bir hata mesajıyla bölmenin anlamı yok.
        AppLog.warn('event.quotaShardBackfillFailed', <String, Object?>{
          'eventId': event.id,
          'error': error.toString(),
        });
      }
    });
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  void _setFeedback(String? message, [FeedbackTone tone = FeedbackTone.info]) {
    if (!mounted) return;
    setState(() {
      _feedback = message;
      _tone = tone;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.t('common.continueAction')),
          ),
        ],
      ),
    );
    return result == true;
  }

  // ── Kayıt aç/kapa ──────────────────────────────────────────────────

  Future<void> _toggleRegistrations(AppEvent event) async {
    final bool reopening = event.registrationClosed;

    final bool ok = await _confirm(
      context.t('clubEvents.registrations.title'),
      reopening
          ? context.t('clubEvents.registrations.confirmOpen')
          : context.t('clubEvents.registrations.confirmClose'),
    );
    if (!ok || !mounted) return;

    // Mesajlar await'ten önce çözülür: sonrasında `context` kullanmak
    // widget ağaçtan çıkmışsa geçersiz olur.
    final String successMessage = reopening
        ? context.t('clubEvents.registrations.opened')
        : context.t('clubEvents.registrations.closed');
    final String errorMessage = context.t('clubEvents.feedback.updateError');

    await _run(() async {
      try {
        await ref
            .read(eventRepositoryProvider)
            .setRegistrationsClosed(event.id, !reopening);
        _setFeedback(successMessage, FeedbackTone.success);
      } catch (_) {
        _setFeedback(errorMessage, FeedbackTone.error);
      }
    });
  }

  // ── Oturum yönetimi ────────────────────────────────────────────────

  Future<void> _advanceSession(AppEvent event) async {
    final int next = event.currentSession + 1;

    // Son oturumdayken düğme "bitir" anlamına gelir: QR girişleri kapanır ve
    // belge dağıtımı açılır.
    if (event.currentSession >= event.sessionCount) {
      final bool ok = await _confirm(
        context.t('clubEvents.session.finishTitle'),
        context.t('clubEvents.session.finishConfirm'),
      );
      if (!ok || !mounted) return;

      final String done = context.t('clubEvents.session.finished');
      final String failed = context.t('clubEvents.feedback.updateError');

      await _run(() async {
        try {
          await ref.read(eventRepositoryProvider).finishSessions(event.id);
          _setFeedback(done, FeedbackTone.success);
        } catch (_) {
          _setFeedback(failed, FeedbackTone.error);
        }
      });
      return;
    }

    final bool ok = await _confirm(
      context.t('clubEvents.session.advanceTitle'),
      next == 1
          ? context.t('clubEvents.session.startConfirm', <String, Object?>{
              'total': event.sessionCount,
            })
          : context.t('clubEvents.session.advanceConfirm', <String, Object?>{
              'next': next,
            }),
    );
    if (!ok || !mounted) return;

    final String started = context.t(
      'clubEvents.session.started',
      <String, Object?>{'session': next},
    );
    final String failed = context.t('clubEvents.feedback.updateError');

    await _run(() async {
      try {
        await ref.read(eventRepositoryProvider).advanceSession(event.id, next);
        if (!mounted) return;
        _setFeedback(started, FeedbackTone.success);
        // Oturum başlar başlamaz QR ekrana gelsin: öğrenciler bunu okutacak.
        await _showSessionQr(event.id, next);
      } catch (_) {
        _setFeedback(failed, FeedbackTone.error);
      }
    });
  }

  /// Aktif oturumu bir geri alır ve o oturumun QR'ını yeniden gösterir.
  ///
  /// "İlerlet" düğmesine yanlışlıkla basmak geri alınamaz bir işlemdi: QR
  /// değişiyor, bir önceki oturuma henüz girmemiş öğrenciler yoklamada
  /// görünemiyordu. Geri alınca eski oturumun QR'ı yeniden geçerli olur ve
  /// hemen ekrana gelir — kulübün ayrıca "QR'ı göster"e basması gerekmez.
  ///
  /// Halihazırda o oturuma girmiş öğrenciler ikinci kez sayılmaz; okuma
  /// tarafındaki `lastAttendedSession >= currentSession` kontrolü bunu
  /// engeller.
  Future<void> _undoSession(AppEvent event) async {
    final int previous = event.currentSession - 1;
    if (previous < 0) return;

    final bool ok = await _confirm(
      context.t('clubEvents.session.undoTitle'),
      previous < 1
          ? context.t('clubEvents.session.undoToStartConfirm')
          : context.t('clubEvents.session.undoConfirm', <String, Object?>{
              'session': previous,
            }),
    );
    if (!ok || !mounted) return;

    final String done = previous < 1
        ? context.t('clubEvents.session.undoneToStart')
        : context.t('clubEvents.session.undone', <String, Object?>{
            'session': previous,
          });
    final String failed = context.t('clubEvents.feedback.updateError');

    await _run(() async {
      try {
        await ref
            .read(eventRepositoryProvider)
            .advanceSession(event.id, previous);
        if (!mounted) return;
        _setFeedback(done, FeedbackTone.success);
        // Geri alınan oturumun QR'ı yeniden geçerli — hemen göster.
        if (previous >= 1) await _showSessionQr(event.id, previous);
      } catch (_) {
        _setFeedback(failed, FeedbackTone.error);
      }
    });
  }

  /// Bitirilmiş oturumları yeniden açar (web'deki modalde bulunan
  /// "Oturumları Tekrar Aç" düğmesinin karşılığı).
  ///
  /// Oturumları yanlışlıkla bitirmek geri alınamaz bir işlemdi: QR girişleri
  /// kapanıyor, geç gelen öğrenci yoklamaya giremiyordu. Aktif oturum
  /// numarası korunur, yalnızca "tamamlandı" işareti kalkar.
  Future<void> _reopenSessions(AppEvent event) async {
    final bool ok = await _confirm(
      context.t('clubEvents.session.reopenTitle'),
      context.t('clubEvents.session.reopenConfirm'),
    );
    if (!ok || !mounted) return;

    final String done = context.t('clubEvents.session.reopened');
    final String failed = context.t('clubEvents.feedback.updateError');

    await _run(() async {
      try {
        await ref.read(eventRepositoryProvider).reopenSessions(event.id);
        _setFeedback(done, FeedbackTone.success);
      } catch (_) {
        _setFeedback(failed, FeedbackTone.error);
      }
    });
  }

  Future<void> _showSessionQr(String eventId, int session) =>
      showSessionQrDialog(context, eventId, session);

  /// Kapıyı açar/kapatır. Kapı açıkken öğrenciler kapıdaki ortak QR'ı kendi
  /// telefonlarından okutup girişlerini onaylar; kapalıyken o QR hiçbir işe
  /// yaramaz (firestore.rules > studentCanMarkOwnEventCheckIn `entryOpen`
  /// alanına bakar). Açar açmaz QR ekrana gelir — kulübün ikinci bir düğme
  /// araması gerekmesin.
  Future<void> _toggleDoorCheckin(AppEvent event) async {
    final bool opening = !event.entryOpen;
    // Metinler async iş BAŞLAMADAN çözülür (dosyadaki diğer eylemlerle aynı
    // kalıp): `context` await sonrası ağaçtan düşmüş olabilir.
    final String failed = context.t('clubEvents.feedback.updateError');

    await _run(() async {
      try {
        await ref.read(eventRepositoryProvider).setEntryOpen(
              event.id,
              opening,
              // Damga BİR KEZ atılır: "Bitir" sonrası aşama "hiç başlamadı"ya
              // dönmesin, etkinlik Aktif listesinden düşmesin.
              alreadyStartedAtMs: event.entryStartedAtMs,
            );
      } catch (_) {
        _setFeedback(failed, FeedbackTone.error);
        return;
      }
      if (opening && mounted) {
        await showDoorCheckinQrDialog(context, event.id);
      }
    });
  }

  /// Kapıda check-in'i kaçıranların oturum yoklamasına doğrudan katılmasına
  /// izin veren anahtar (PDF: "oturumları başlattıktan sonra bir switch").
  /// Kapalıyken yoklama için önce kapı girişi gerekir.
  Future<void> _setAllowSessionWithoutCheckin(AppEvent event, bool allow) async {
    final String failed = context.t('clubEvents.feedback.updateError');

    await _run(() async {
      try {
        await ref
            .read(eventRepositoryProvider)
            .setAllowSessionWithoutCheckin(event.id, allow);
      } catch (_) {
        _setFeedback(failed, FeedbackTone.error);
      }
    });
  }

  // ── Belge dağıtımı ─────────────────────────────────────────────────

  /// Belge kapısının kilit gerekçesi — kapı kapalıyken gösterilen tek metin.
  ///
  /// Oturumlu etkinlikte kapıyı kulüp açar (oturumları bitirerek), tek
  /// oturumluda takvim açar (etkinlik bitince). İki gerekçe de aynı yerden
  /// okunuyor ki kart altındaki uyarı ile işlem sırasındaki uyarı hiçbir
  /// zaman ayrışmasın.
  static String certificateLockReason(BuildContext context, AppEvent event) =>
      event.isMultiSession
          ? context.t('clubEvents.certificate.finishSessionsFirst')
          : context.t('clubEvents.certificate.finishEventFirst');

  /// `true` dönerse yükleme/dağıtım yapılmamalı; uyarı da gösterilmiş olur.
  ///
  /// Kapı burada tek noktada tutuluyor: hem düğme kilitleniyor hem de
  /// (kilidin atlandığı bir yol kalırsa) işlem başlamadan önce uyarı veriliyor.
  bool _blockedBeforeFinish(AppEvent event) {
    if (canDistributeCertificates(event)) return false;
    _setFeedback(certificateLockReason(context, event), FeedbackTone.error);
    return true;
  }

  static String _contentTypeFor(String extension) => extension == 'pdf'
      ? 'application/pdf'
      : 'image/${extension == 'jpg' ? 'jpeg' : extension}';

  /// Arşivdeki belgenin uzantısı — içerik türünden, olmazsa yolundan.
  static String _extensionOf(EventDocument document) {
    final String type = document.contentType.toLowerCase();
    if (type.contains('pdf')) return 'pdf';
    if (type.contains('png')) return 'png';
    if (type.contains('jpeg') || type.contains('jpg')) return 'jpg';

    final String named = document.path.contains('.')
        ? document.path.split('.').last.toLowerCase()
        : '';
    return kCertificateExtensions.contains(named) ? named : 'pdf';
  }

  /// Cihazdan belge seçtirir; seçici kapanır kapanmaz yükleme başlar.
  ///
  /// Araya "onayla" adımı konmuyor: düğmenin adı zaten "Belge Yükle ve
  /// Dağıt", dosyayı seçmek onayın kendisi.
  ///
  /// Dosya **baytlarıyla** okunur (`withData: true`), yolla değil: Android'de
  /// Drive/OneDrive gibi bulut sağlayıcılarından seçilen belgede
  /// `PlatformFile.path` boş dönebiliyor ve düğme hiçbir iz bırakmadan
  /// kapanıyordu. Bayt yolu her sağlayıcıda çalışır; 10 MB'lık sınır zaten
  /// belleğe rahat sığar.
  Future<void> _pickCertificate(AppEvent event) async {
    if (_blockedBeforeFinish(event)) return;

    PlatformFile? picked;
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: kCertificateExtensions,
        withData: true,
      );
      picked = result?.files.singleOrNull;
    } catch (_) {
      // Seçici hiç açılamadıysa kullanıcı tepkisiz bir düğme yerine gerekçeyi
      // görsün.
      if (mounted) {
        _setFeedback(
          context.t('clubEvents.certificate.pickerError'),
          FeedbackTone.error,
        );
      }
      return;
    }

    if (picked == null || !mounted) return;

    final PlatformFile file = picked;
    final String ext = (file.extension ?? '').toLowerCase();
    if (!kCertificateExtensions.contains(ext)) {
      _setFeedback(
        context.t('clubEvents.certificate.invalidType'),
        FeedbackTone.error,
      );
      return;
    }

    // Bazı platformlarda bayt yerine yalnızca yol gelir; ikisi de yoksa dosya
    // okunamamış demektir.
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      try {
        bytes = await File(file.path!).readAsBytes();
      } catch (_) {
        bytes = null;
      }
    }
    if (!mounted) return;

    if (bytes == null) {
      _setFeedback(
        context.t('clubEvents.certificate.readError'),
        FeedbackTone.error,
      );
      return;
    }

    await _uploadAndDistribute(
      event: event,
      bytes: bytes,
      fileName: file.name,
      extension: ext,
    );
  }

  /// Panodan yapıştırılan kaynaktaki belgeyi alıp aynı yoldan dağıtır.
  ///
  /// İki biçim de kabul edilir:
  ///   * `http(s)://.../belge.pdf` — indirilip yüklenir,
  ///   * cihazdaki bir dosya yolu — bazı dosya yöneticileri "kopyala"
  ///     dendiğinde panoya adres yerine yolu yazıyor.
  ///
  /// Dosya seçicinin açılmadığı ya da belgeyi bulamadığı durumlarda kulübün
  /// elinde ikinci bir yol kalsın diye var.
  Future<void> _distributeFromLink(AppEvent event) async {
    if (_blockedBeforeFinish(event)) return;

    final String raw = _link.text.trim();
    if (raw.isEmpty) {
      _setFeedback(
        context.t('clubEvents.certificate.linkEmpty'),
        FeedbackTone.error,
      );
      return;
    }

    final Uri? uri = Uri.tryParse(raw);
    final bool remote = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;

    Uint8List? bytes;
    String fileName = raw.split(RegExp(r'[\\/]')).last;
    String? headerType;

    if (remote) {
      _setFeedback(context.t('clubEvents.certificate.fetching'));
      try {
        final http.Response response = await http.get(uri);
        if (response.statusCode != 200) throw StateError('http');
        bytes = response.bodyBytes;
        headerType = response.headers['content-type'];
        // Sorgu dizesi ("?token=...") dosya adına karışmasın.
        final String last =
            uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
        if (last.isNotEmpty) fileName = last;
      } catch (_) {
        if (!mounted) return;
        _setFeedback(
          context.t('clubEvents.certificate.linkError'),
          FeedbackTone.error,
        );
        return;
      }
    } else {
      try {
        final File local = File(raw);
        if (await local.exists()) bytes = await local.readAsBytes();
      } catch (_) {
        bytes = null;
      }
    }

    if (!mounted) return;

    if (bytes == null) {
      _setFeedback(
        context.t('clubEvents.certificate.linkInvalid'),
        FeedbackTone.error,
      );
      return;
    }

    final String? ext = _resolveExtension(
      fileName: fileName,
      contentType: headerType,
      bytes: bytes,
    );
    if (ext == null) {
      _setFeedback(
        context.t('clubEvents.certificate.invalidType'),
        FeedbackTone.error,
      );
      return;
    }

    await _uploadAndDistribute(
      event: event,
      bytes: bytes,
      fileName: fileName.contains('.') ? fileName : '$fileName.$ext',
      extension: ext,
    );

    // Adres kutusu yalnızca iş bittiğinde temizlenir; hata aldıysa kulüp
    // yapıştırdığını kaybetmesin.
    if (mounted && _tone == FeedbackTone.success) _link.clear();
  }

  /// Panodaki metni adres kutusuna yazar.
  Future<void> _pasteLink() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String text = (data?.text ?? '').trim();
    if (text.isEmpty || !mounted) return;
    setState(() => _link.text = text);
  }

  /// Yapıştırılan kaynağın uzantısını çözer.
  ///
  /// Sırayla: dosya adındaki uzantı, sunucunun bildirdiği içerik türü, son
  /// çare olarak dosyanın kendi imzası. Bulut bağlantılarının çoğunda adreste
  /// uzantı yoktur; imza kontrolü olmasa bu belgeler reddedilirdi.
  static String? _resolveExtension({
    required String fileName,
    required String? contentType,
    required Uint8List bytes,
  }) {
    final String named =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    if (kCertificateExtensions.contains(named)) return named;

    final String type = (contentType ?? '').toLowerCase();
    if (type.contains('pdf')) return 'pdf';
    if (type.contains('png')) return 'png';
    if (type.contains('jpeg') || type.contains('jpg')) return 'jpg';

    // İmza baytları: %PDF / PNG / JPEG.
    if (bytes.length > 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return 'pdf';
    }
    if (bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50) return 'png';
    if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpg';

    return null;
  }

  /// Kulübün yüklediği belgeyi sisteme alır ve hak kazanan her öğrenciye ayrı
  /// bir kayıt olarak dağıtır.
  ///
  /// Sıra bilerek "önce arşiv, sonra dağıtım": belge her hâlükârda sisteme
  /// girsin. Eskiden dağıtım döngüsü öndeydi ve orada alınan tek bir hata
  /// (kural reddi, kopan bağlantı) arşiv yazımına hiç sıra gelmeden işlemi
  /// bitiriyordu — kulübün elinde yeniden deneyebileceği bir belge kalmıyordu.
  ///
  /// Hak sahibi öğrenci yoksa yükleme yine de yapılır: belge etkinliğin
  /// arşivinde bekler ve hak sahipleri belirlendiğinde (otomatik olarak ya da
  /// belge kartındaki "Dağıt" tuşuyla) gönderilir.
  ///
  /// Web sürümü PDF içinde isim alanı arayıp belgeyi kişiselleştiriyor
  /// (pdf-lib). Mobilde belge olduğu gibi iletilir; dağıtım, hak sahibi
  /// hesaplama ve kayıt yapısı web ile birebir aynıdır.
  Future<void> _uploadAndDistribute({
    required AppEvent event,
    required Uint8List bytes,
    required String fileName,
    required String extension,
  }) async {
    if (bytes.length > kMaxCertificateBytes) {
      _setFeedback(
        context.t('clubEvents.certificate.tooLarge'),
        FeedbackTone.error,
      );
      return;
    }

    final String clubId = ref.read(sessionProvider).user?.uid ?? '';
    if (clubId.isEmpty) return;

    final String contentType = _contentTypeFor(extension);
    final String uploading = context.t('clubEvents.certificate.uploading');

    await _run(() async {
      try {
        _setFeedback(uploading);

        // Arşiv kopyası. Yol zaman damgalı: sabit bir ad her yüklemede bir
        // öncekini eziyordu, oysa kulüp aynı etkinliğe birden fazla belge
        // yükleyebilmeli (katılım belgesi + başarı belgesi gibi).
        final String templatePath =
            'certificates/$clubId/${event.id}/'
            '_belge-${DateTime.now().millisecondsSinceEpoch}.$extension';
        final Reference templateRef = fbStorage.ref(templatePath);
        await templateRef.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );

        final EventDocument document = EventDocument(
          url: await templateRef.getDownloadURL(),
          name: fileName,
          path: templatePath,
          contentType: contentType,
          uploadedAtMs: DateTime.now().millisecondsSinceEpoch,
        );

        await ref
            .read(eventRepositoryProvider)
            .addCertificateDocument(event.id, document);

        await _distribute(
          event: event,
          clubId: clubId,
          document: document,
          bytes: bytes,
          extension: extension,
          contentType: contentType,
        );
      } catch (error) {
        if (!mounted) return;
        _setFeedback(_describeUploadError(context, error), FeedbackTone.error);
      }
    });
  }

  /// Belgeyi hak kazanan her öğrenciye ayrı bir kayıt olarak yazar.
  ///
  /// Bir öğrencide alınan hata dağıtımı DURDURMAZ: tek bir kaydın kuralca
  /// reddedilmesi ya da o an kopan bağlantı, sıradaki öğrencilerin de belgeyi
  /// alamaması demekti ve kulüp bunu hiçbir yerden göremiyordu. Sonuçta kaç
  /// kişiye gittiği ve kaçında hata alındığı açıkça yazılır.
  Future<void> _distribute({
    required AppEvent event,
    required String clubId,
    required EventDocument document,
    required Uint8List bytes,
    required String extension,
    required String contentType,
    bool auto = false,
  }) async {
    final List<EventRegistration> registrations =
        ref.read(eventRegistrationsProvider(event.id)).value ??
            const <EventRegistration>[];

    final List<EventRegistration> eligible =
        certificateEligible(event, registrations);

    int sent = 0;
    int failed = 0;

    for (final EventRegistration reg in eligible) {
      try {
        final String filePath =
            'certificates/$clubId/${event.id}/${reg.studentId}.$extension';
        final Reference storageRef = fbStorage.ref(filePath);

        await storageRef.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );

        await ref.read(eventRepositoryProvider).issueCertificate(
              eventId: event.id,
              studentId: reg.studentId,
              eventTitle: event.title,
              clubId: clubId,
              clubName: event.clubName,
              fileUrl: await storageRef.getDownloadURL(),
              filePath: filePath,
              fileName: '${event.title}.$extension',
              contentType: contentType,
              personalized: false,
            );

        sent += 1;
      } catch (_) {
        failed += 1;
      }

      if (mounted) {
        _setFeedback(
          context.t('clubEvents.certificate.sending', <String, Object?>{
            'done': sent + failed,
            'total': eligible.length,
          }),
        );
      }
    }

    // Dağıtım damgası: belgenin kimseye gitmediği başka hiçbir yerden
    // anlaşılmıyordu ve otomatik dağıtım da bu sayıya bakıyor.
    if (sent > 0) {
      try {
        await ref
            .read(eventRepositoryProvider)
            .markCertificateDocumentDistributed(event.id, document, sent);
      } catch (_) {
        // Damga yazılamadıysa dağıtımın kendisi geçerli; en fazla otomatik
        // dağıtım bir kez daha dener.
      }
    }

    if (!mounted) return;

    if (failed > 0) {
      _setFeedback(
        context.t('clubEvents.certificate.partial', <String, Object?>{
          'count': sent,
          'failed': failed,
        }),
        FeedbackTone.error,
      );
    } else if (sent > 0) {
      _setFeedback(
        context.t(
          auto
              ? 'clubEvents.certificate.autoSent'
              : 'clubEvents.certificate.sent',
          <String, Object?>{'count': sent},
        ),
        FeedbackTone.success,
      );
    } else if (!auto) {
      // Kimseye gitmediğini açıkça söyle: kulüp "gönderildi" sanıp dağıtımı
      // bir daha denemezse belge öğrencilere hiç ulaşmaz.
      _setFeedback(
        context.t('clubEvents.certificate.storedOnly'),
        FeedbackTone.success,
      );
    } else {
      // Otomatik dağıtım başlarken hak sahibi vardı, sıra gelince kalmadı
      // (kayıt listesi değişmiş). Sessizce geri çekil: ekranda "belge
      // indiriliyor" yazısı asılı kalmasın.
      _setFeedback(null);
    }
  }

  /// Arşivdeki bir belgeyi hak kazanan öğrencilere (yeniden) gönderir.
  ///
  /// Dağıtım eskiden yalnızca yükleme anında, o andaki hak sahibi listesine
  /// karşı yapılıyordu. Kulüp belgeyi yoklamalar tamamlanmadan yüklediyse (ya
  /// da yükleme sırasında dağıtım yarıda kaldıysa) belgeyi öğrencilere
  /// ulaştıracak ikinci bir yol yoktu: kulüp belgeyi siliyor, yeniden
  /// yüklüyor, sonuç değişmiyordu. Bu yol arşivdeki dosyayı olduğu gibi alıp
  /// aynı dağıtım algoritmasından geçirir.
  Future<void> _redistribute(
    AppEvent event,
    EventDocument document, {
    bool auto = false,
  }) async {
    if (_blockedBeforeFinish(event)) return;

    final String clubId = ref.read(sessionProvider).user?.uid ?? '';
    if (clubId.isEmpty) return;

    final String fetching = context.t('clubEvents.certificate.fetching');
    final String unreadable = context.t('clubEvents.certificate.sourceMissing');

    await _run(() async {
      try {
        _setFeedback(fetching);

        final Uint8List? bytes = await _readDocumentBytes(document);
        if (!mounted) return;

        if (bytes == null) {
          _setFeedback(unreadable, FeedbackTone.error);
          return;
        }

        final String extension = _extensionOf(document);

        await _distribute(
          event: event,
          clubId: clubId,
          document: document,
          bytes: bytes,
          extension: extension,
          contentType: document.contentType.isNotEmpty
              ? document.contentType
              : _contentTypeFor(extension),
          auto: auto,
        );
      } catch (error) {
        if (!mounted) return;
        _setFeedback(_describeUploadError(context, error), FeedbackTone.error);
      }
    });
  }

  /// Arşivdeki belgenin baytları.
  ///
  /// Önce Storage yolundan okunur: indirme adresindeki jeton yenilenmiş
  /// olabilir, yol ise sabittir. Yol yoksa (diziden önce yazılmış kayıtlar)
  /// adrese düşülür.
  Future<Uint8List?> _readDocumentBytes(EventDocument document) async {
    if (document.path.isNotEmpty) {
      try {
        final Uint8List? data = await fbStorage
            .ref(document.path)
            .getData(kMaxCertificateBytes);
        if (data != null) return data;
      } catch (_) {
        // Yol geçersiz ya da nesne silinmiş: adres denenecek.
      }
    }

    final Uri? uri = Uri.tryParse(document.url);
    if (uri == null || !uri.hasScheme) return null;

    try {
      final http.Response response = await http.get(uri);
      if (response.statusCode == 200) return response.bodyBytes;
    } catch (_) {
      // Ağ hatası: çağıran taraf "belge okunamadı" der.
    }
    return null;
  }

  /// Etkinlik bittikten sonra bekleyen belgeyi kendiliğinden dağıtır.
  ///
  /// Kulüp belgeyi çoğu zaman etkinlik bitmeden hazırlıyor; o an hak sahibi
  /// olmadığı için belge arşivde bekliyor ve kimseye ulaşmıyordu. Tek oturumlu
  /// etkinlikte "oturumları bitir" gibi bir adım da olmadığından kulübün
  /// dağıtımı tetikleyecek hiçbir hareketi yoktu.
  ///
  /// Ekran açık kaldığı sürece en fazla bir kez ve yalnızca gerçekten eksik
  /// varsa çalışır: son belge ya hiç dağıtılmamıştır ya da dağıtımdan bu yana
  /// yeni hak sahibi eklenmiştir. Kayıtlar henüz yüklenmediyse (hak sahibi
  /// sayısı 0) hiçbir şey yapılmaz, bir sonraki kareye bakılır.
  void _scheduleAutoDistribute(
    AppEvent event,
    List<EventRegistration> registrations,
  ) {
    if (_autoDistributed || _busy) return;
    if (!canDistributeCertificates(event)) return;
    if (event.certificateDocuments.isEmpty) return;

    final EventDocument latest = event.certificateDocuments.last;
    final int eligible = certificateEligible(event, registrations).length;
    if (eligible == 0 || eligible <= latest.distributedCount) return;

    _autoDistributed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _redistribute(event, latest, auto: true);
    });
  }

  /// club-documents.js#describeUploadError karşılığı.
  ///
  /// Tek bir "hata oluştu" mesajı belge dağıtımında işe yaramıyor: hata
  /// neredeyse her zaman yayınlanmamış bir kuraldan ya da kapalı bir Storage
  /// kovasından geliyor ve bunlar birbirinden çok farklı düzeltmeler.
  static String _describeUploadError(BuildContext context, Object error) {
    final String code = error is FirebaseException ? error.code : '';

    return switch (code) {
      'unauthorized' ||
      'permission-denied' =>
        context.t('clubEvents.certificate.permissionError'),
      'unauthenticated' => context.t('clubEvents.certificate.authError'),
      'quota-exceeded' => context.t('clubEvents.certificate.quotaError'),
      'retry-limit-exceeded' ||
      'unknown' =>
        context.t('clubEvents.certificate.storageError'),
      _ => context.t('clubEvents.certificate.error'),
    };
  }

  // ── Katılımcı listesi ──────────────────────────────────────────────

  /// Katılımcıları web'dekiyle aynı Excel dosyasına yazıp paylaşım sayfasını
  /// açar (club-events.js#downloadStudentsBtn).
  Future<void> _downloadStudentsExcel(AppEvent event) async {
    final List<EventRegistration> registrations =
        ref.read(eventRegistrationsProvider(event.id)).value ??
            const <EventRegistration>[];

    if (registrations.isEmpty) {
      _setFeedback(
        context.t('clubEvents.students.empty'),
        FeedbackTone.error,
      );
      return;
    }

    final RegistrationsSheetLabels labels = RegistrationsSheetLabels(
      sheetName: context.t('clubEvents.excel.sheetName'),
      reportTitle: context.t('clubEvents.excel.reportTitle'),
      eventNameLabel: context.t('clubEvents.excel.eventName'),
      clubLabel: context.t('clubEvents.excel.club'),
      countLabel: context.t('clubEvents.excel.studentCount'),
      reportDateLabel: context.t('clubEvents.excel.reportDate'),
      headers: <String>[
        context.t('table.fullName'),
        context.t('table.email'),
        context.t('table.phone'),
        context.t('table.university'),
        context.t('table.department'),
        context.t('table.registrationDate'),
      ],
    );

    // Metinler await'ten önce çözülür: sonrasında `context` kullanmak widget
    // ağaçtan çıkmışsa geçersiz olur.
    final String locale = context.lang;
    final String subject =
        context.t('clubEvents.excel.subject', <String, Object?>{
      'title': event.title,
    });
    final String preparing = context.t('clubEvents.excel.preparing');
    final String ready = context.t('clubEvents.excel.ready');
    final String failed = context.t('clubEvents.excel.error');

    // iPad'de paylaşım sayfası balon olarak açılıyor ve çıkış noktasını
    // istiyor; verilmezse uygulama çöker. Ekranın tamamını veriyoruz —
    // düğmenin kendi dikdörtgeni alt widget'ın içinde kalıyor ve iOS zaten
    // balonu bu alanın ortasına yerleştiriyor. Ölçüm await'ten ÖNCE
    // alınmalı: sonrasında widget ağaçtan çıkmış olabilir.
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Rect? shareOrigin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    await _run(() async {
      _setFeedback(preparing);
      try {
        await shareRegistrationsExcel(
          event: event,
          registrations: registrations,
          labels: labels,
          subject: subject,
          sharePositionOrigin: shareOrigin,
          locale: locale,
        );
        _setFeedback(ready, FeedbackTone.success);
      } catch (_) {
        _setFeedback(failed, FeedbackTone.error);
      }
    });
  }

  /// Yüklenmiş belgeyi uygulama içinde açar (görsel de PDF de).
  ///
  /// Eskiden harici tarayıcıya çıkılıyordu; öğrenci tarafındaki belge
  /// görüntüleyici zaten uygulama içinde açıyor, kulüp tarafı da aynı olsun.
  Future<void> _openDocument(EventDocument document) => openMedia(
    context,
    source: document.url,
    title: document.name.isNotEmpty
        ? document.name
        : context.t('clubEvents.certificate.uploaded'),
    contentType: document.contentType,
  );

  /// Yüklenmiş belgeyi hem listeden hem Storage'dan siler.
  ///
  /// Storage silme başarısız olsa da liste kaydı kaldırılır: kulüp için
  /// belirleyici olan listede görünmemesidir, artık kimse o adrese
  /// ulaşmayacaktır. Öğrencilere daha önce dağıtılmış kopyalar bundan
  /// etkilenmez — onlar ayrı kayıtlardır.
  Future<void> _deleteDocument(AppEvent event, EventDocument document) async {
    final bool ok = await _confirm(
      context.t('clubEvents.certificate.deleteTitle'),
      context.t('clubEvents.certificate.deleteConfirm'),
    );
    if (!ok || !mounted) return;

    final String done = context.t('clubEvents.certificate.deleted');
    final String failed = context.t('clubEvents.certificate.deleteError');

    await _run(() async {
      try {
        await ref
            .read(eventRepositoryProvider)
            .removeCertificateDocument(event.id, document);

        if (document.path.isNotEmpty) {
          try {
            await fbStorage.ref(document.path).delete();
          } catch (_) {
            // Storage nesnesi zaten yoksa ya da silinemiyorsa liste kaydının
            // kaldırılmış olması yeterli.
          }
        }

        _setFeedback(done, FeedbackTone.success);
      } catch (_) {
        _setFeedback(failed, FeedbackTone.error);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppEvent?> eventAsync =
        ref.watch(clubEventProvider(widget.eventId));

    // Kayıtlar burada da izleniyor: otomatik dağıtım kararı hak sahibi
    // sayısına bakıyor ve liste yüklendiğinde yeniden değerlendirilmeli.
    final List<EventRegistration> registrations =
        ref.watch(eventRegistrationsProvider(widget.eventId)).value ??
            const <EventRegistration>[];

    final AppEvent? watched = eventAsync.value;
    if (watched != null) _scheduleAutoDistribute(watched, registrations);

    return Scaffold(
      appBar: ClubAppBar(
        title: eventAsync.value?.title ?? context.t('clubEvents.title'),
        showBack: true,
      ),
      body: eventAsync.when(
        loading: () => const LoadingView(),
        error: (Object error, StackTrace _) => Padding(
          padding: const EdgeInsets.all(20),
          child: FeedbackBanner(
            message: context.t('clubEvents.feedback.loadError'),
            tone: FeedbackTone.error,
          ),
        ),
        data: (AppEvent? event) {
          if (event == null) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                EmptyState(message: context.t('dashboard.alerts.eventNotFound')),
              ],
            );
          }
          _scheduleQuotaShardBackfill(event);

          // Kontenjan doluluğu canlı izlenir: dolduğu an etkinlik
          // kendiliğinden beklemeye alınır, yer açılınca geri açılır.
          final QuotaStatus quota = ref
                  .watch(quotaStatusProvider(event.id))
                  .value ??
              QuotaStatus.untracked;
          _scheduleQuotaStateSync(event, quota);

          return _Body(
            event: event,
            quota: quota,
            busy: _busy,
            feedback: _feedback,
            tone: _tone,
            linkController: _link,
            onToggleRegistrations: () => _toggleRegistrations(event),
            onAdvanceSession: () => _advanceSession(event),
            onUndoSession: () => _undoSession(event),
            onReopenSessions: () => _reopenSessions(event),
            onShowSessionQr: () =>
                _showSessionQr(event.id, event.currentSession),
            onToggleDoorCheckin: () => _toggleDoorCheckin(event),
            onShowDoorQr: () => showDoorCheckinQrDialog(context, event.id),
            onAllowSessionWithoutCheckin: (bool allow) =>
                _setAllowSessionWithoutCheckin(event, allow),
            onDistribute: () => _pickCertificate(event),
            onDistributeLink: () => _distributeFromLink(event),
            onPasteLink: _pasteLink,
            onOpenDocument: _openDocument,
            onRedistributeDocument: (EventDocument document) =>
                _redistribute(event, document),
            onDeleteDocument: (EventDocument document) =>
                _deleteDocument(event, document),
            onDownloadExcel: () => _downloadStudentsExcel(event),
          );
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.event,
    required this.quota,
    required this.busy,
    required this.feedback,
    required this.tone,
    required this.linkController,
    required this.onToggleRegistrations,
    required this.onAdvanceSession,
    required this.onUndoSession,
    required this.onReopenSessions,
    required this.onShowSessionQr,
    required this.onToggleDoorCheckin,
    required this.onShowDoorQr,
    required this.onAllowSessionWithoutCheckin,
    required this.onDistribute,
    required this.onDistributeLink,
    required this.onPasteLink,
    required this.onOpenDocument,
    required this.onRedistributeDocument,
    required this.onDeleteDocument,
    required this.onDownloadExcel,
  });

  final AppEvent event;

  /// Kontenjan doluluğu — parça sayaçlarından toplanır.
  final QuotaStatus quota;

  final bool busy;
  final String? feedback;
  final FeedbackTone tone;
  final TextEditingController linkController;
  final VoidCallback onToggleRegistrations;
  final VoidCallback onAdvanceSession;
  final VoidCallback onUndoSession;
  final VoidCallback onReopenSessions;
  final VoidCallback onShowSessionQr;
  final VoidCallback onToggleDoorCheckin;
  final VoidCallback onShowDoorQr;
  final ValueChanged<bool> onAllowSessionWithoutCheckin;
  final VoidCallback onDistribute;
  final VoidCallback onDistributeLink;
  final VoidCallback onPasteLink;
  final ValueChanged<EventDocument> onOpenDocument;
  final ValueChanged<EventDocument> onRedistributeDocument;
  final ValueChanged<EventDocument> onDeleteDocument;
  final VoidCallback onDownloadExcel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<EventRegistration>> registrations =
        ref.watch(eventRegistrationsProvider(event.id));

    final List<EventRegistration> list =
        registrations.value ?? const <EventRegistration>[];

    final bool past = isPastEvent(event);

    // Belge kapısı: oturumlu etkinlikte "oturumlar bitti mi", tek oturumluda
    // "etkinlik bitti mi".
    final bool canDistribute = canDistributeCertificates(event);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        if (feedback != null) FeedbackBanner(message: feedback, tone: tone),

        ClipRRect(
          borderRadius: BorderRadius.circular(BrandShape.cardRadius),
          child: EventImage(url: event.displayImageUrl, height: 170),
        ),
        const SizedBox(height: 16),

        EventSectionTitle(context.t('eventModal.info')),
        const SizedBox(height: 10),
        EventInfoTable(rows: eventInfoRows(context, event)),

        // ── Kayıtlar ───────────────────────────────────────────────
        const SizedBox(height: 22),
        EventSectionTitle(context.t('clubEvents.registrations.title')),
        const SizedBox(height: 10),

        // Kontenjan doluluğu. Kayıt kartının ÜSTÜNDE duruyor: kulüp
        // "kayıtları durdur" düğmesine bakmadan önce durdurulacak bir şey
        // kalıp kalmadığını görmeli.
        if (quota.isTracked) ...<Widget>[
          _QuotaMeter(quota: quota, event: event),
          const SizedBox(height: 12),
        ],
        _ActionCard(
          icon: past ? Icons.lock_outline : Icons.how_to_reg_outlined,
          title: past
              ? context.t('clubEvents.registrations.pastLabel')
              : event.registrationClosed
                  ? context.t('clubEvents.registrations.openAction')
                  : context.t('clubEvents.registrations.closeAction'),
          subtitle: context.t('clubEvents.registrations.subtitle'),
          // Sağdaki simge kartın ne yapacağını söyler: ">" her karta konan
          // "ileri git" işaretiydi, oysa bu kart bir yere götürmüyor —
          // kayıtları o anda durduruyor (ya da yeniden başlatıyor).
          trailingIcon: event.registrationClosed
              ? Icons.play_circle_outline
              : Icons.stop_circle_outlined,
          // Süresi geçmiş etkinlikte kayıtlar iki yönde de değiştirilemez.
          onPressed: past || busy ? null : onToggleRegistrations,
          danger: !event.registrationClosed,
        ),

        // ── Oturumlar ──────────────────────────────────────────────
        if (event.isMultiSession) ...<Widget>[
          const SizedBox(height: 22),
          EventSectionTitle(context.t('clubEvents.session.title')),
          const SizedBox(height: 10),
          _SessionPanel(
            event: event,
            busy: busy,
            // İLK oturum, kapı check-in'i bitirilene kadar başlatılamaz:
            // kimin içeride olduğu henüz belli değildir ve erken başlatılan
            // bir oturum, kapıda check-in yapmamış öğrencileri yoklamada
            // reddeder (bkz. domain/checkin_mode.dart).
            sessionsLockedByDoor: event.doorCheckinBlocksSessions,
            onAdvance: onAdvanceSession,
            onUndo: onUndoSession,
            onReopen: onReopenSessions,
            onShowQr: onShowSessionQr,
          ),
          if (event.hasDoorCheckin)
            SwitchListTile.adaptive(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(context.t('clubEvents.session.allowWithoutCheckin')),
              subtitle: Text(
                context.t('clubEvents.session.allowWithoutCheckinHint'),
              ),
              value: event.allowSessionWithoutCheckin,
              onChanged: busy ? null : onAllowSessionWithoutCheckin,
            ),
        ],

        // ── Kapı check-in'i ────────────────────────────────────────
        // Ölçüt oturum sayısı değil MODDUR: "Check-in + Yoklama" modunda
        // etkinlik çok oturumlu olduğu hâlde kapıda bir check-in adımı vardır.
        // Eski kayıtlarda mod oturum sayısından türetilir, davranış değişmez.
        if (event.hasDoorCheckin) ...<Widget>[
          const SizedBox(height: 22),
          EventSectionTitle(context.t('clubEvents.entry.title')),
          const SizedBox(height: 10),
          _CheckinStageBar(
            event: event,
            busy: busy || past,
            attended: list
                .where((EventRegistration r) => r.isCheckedIn)
                .length,
            total: list.length,
            onToggle: onToggleDoorCheckin,
            onShowQr: onShowDoorQr,
          ),
        ],

        // ── QR okutma ──────────────────────────────────────────────
        // Yalnızca TEK oturumlu etkinliklerde. Oturumlu etkinlikte giriş ters
        // yönde işler: kulüp oturum QR'ını ekrana basar, öğrenci kendi
        // telefonundan okutur. Öğrencinin kişisel QR'ını okutmak orada bir
        // yoklama üretmiyor, bu yüzden düğme kafa karıştırmaktan başka bir işe
        // yaramıyordu.
        // Kapı check-in'i olan her etkinlikte görevli bilet okutabilir:
        // öğrenci ya biletini gösterir ya kapıdaki ortak kodu okutur.
        // İki yön de aynı damgayı yazar; hangisinin kullanılacağı
        // kulübün kapıdaki tercihidir (club-qr-checkin.js ile aynı).
        if (event.hasDoorCheckin) ...<Widget>[
          const SizedBox(height: 22),
          EventSectionTitle(context.t('dashboard.drawer.qrCheckin')),
          const SizedBox(height: 10),
          _ActionCard(
            icon: Icons.qr_code_scanner,
            title: context.t('clubEvents.scan.action'),
            subtitle: context.t('clubEvents.scan.subtitle'),
            onPressed: past
                ? null
                : () => context.push(
                      '${Routes.clubQrCheckin}?eventId=${Uri.encodeComponent(event.id)}',
                    ),
          ),
        ],

        // ── Belge ──────────────────────────────────────────────────
        // Bölüm oturum sayısından bağımsız: tek oturumlu etkinlikte de kulüp
        // belge dağıtır, algoritma birebir aynıdır. Değişen yalnızca kapının
        // ne zaman açıldığı — oturumluda kulüp oturumları bitirince, tek
        // oturumluda etkinlik bitince (bkz. `canDistributeCertificates`).
        const SizedBox(height: 22),
        EventSectionTitle(context.t('clubEvents.certificate.title')),
        const SizedBox(height: 10),

        // Kapı kapalıyken gerekçesi kartın hemen üstünde duruyor ki düğme
        // "sebepsiz kapalı" görünmesin.
        if (!canDistribute) ...<Widget>[
          _NoticeCard(
            icon: Icons.lock_clock,
            message: _ClubEventDetailScreenState.certificateLockReason(
              context,
              event,
            ),
          ),
          const SizedBox(height: 10),
        ],

        _ActionCard(
          icon: Icons.workspace_premium_outlined,
          title: context.t('clubEvents.certificate.action'),
          trailingIcon: canDistribute
              ? Icons.upload_file_outlined
              : Icons.lock_outline,
          subtitle: canDistribute
              ? context.t('clubEvents.certificate.subtitle')
              : context.t(
                  event.isMultiSession
                      ? 'clubEvents.certificate.lockedSubtitle'
                      : 'clubEvents.certificate.lockedSubtitleSingle',
                ),
          onPressed: busy || !canDistribute ? null : onDistribute,
        ),

        // Dosya seçicinin yanındaki ikinci yol: kulüp belgeyi bir yerden
        // kopyaladıysa (bulut bağlantısı ya da dosya yolu) doğrudan buraya
        // yapıştırıp aynı işi yapabilir. Kapı kapalıyken bu yol da açılmaz,
        // aksi hâlde kilit tek yönlü kalırdı.
        if (canDistribute) ...<Widget>[
          const SizedBox(height: 12),
          _CertificateLinkField(
            controller: linkController,
            enabled: !busy,
            onPaste: onPasteLink,
            onSubmit: onDistributeLink,
          ),
        ],

        // Yüklenmiş belgeler: kaç tane olursa olsun hepsi görünür, her biri
        // kendi tuşlarıyla yeniden dağıtılabilir ya da silinebilir.
        if (event.hasCertificateDocuments) ...<Widget>[
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.t('clubEvents.certificate.uploadedTitle'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.ink,
                  ),
                ),
              ),
              StatusPill(label: '${event.certificateDocuments.length}'),
            ],
          ),
          const SizedBox(height: 4),
          // Öğrenci tarafında etkinlik başına tek belge kaydı tutuluyor:
          // buradaki liste kulübün arşivi, öğrencinin elindeki ise en son
          // dağıtılan belge. Kulüp iki belge yükleyip "ikisi de gitti"
          // sanmasın diye açıkça yazıyor.
          Text(
            context.t('clubEvents.certificate.uploadedHint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          for (final EventDocument document in event.certificateDocuments)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _UploadedDocumentCard(
                document: document,
                enabled: !busy,
                canDistribute: canDistribute,
                onOpen: () => onOpenDocument(document),
                onRedistribute: () => onRedistributeDocument(document),
                onDelete: () => onDeleteDocument(document),
              ),
            ),
        ],

        // ── Ücretli etkinlik onay kaydı ────────────────────────────
        // Yalnızca ücretli etkinlikte görünür: kulübün oluşturma anında,
        // öğrencilerin kayıt anında onayladığı metnin işlem logu.
        if (event.isPaid) ...<Widget>[
          const SizedBox(height: 22),
          EventSectionTitle(context.t('paidEventConsent.log.title')),
          const SizedBox(height: 10),
          _PaidEventConsentLogCard(event: event, registrations: list),
        ],

        // ── Katılımcılar ───────────────────────────────────────────
        const SizedBox(height: 22),
        Row(
          children: <Widget>[
            Expanded(
              child: EventSectionTitle(context.t('clubEvents.students.title')),
            ),
            StatusPill(label: '${list.length}'),
          ],
        ),
        const SizedBox(height: 10),

        // "Tabloda Gör" kaldırıldı: aynı kayıtlar zaten hemen aşağıda, tüm
        // bilgileriyle listeleniyordu — düğme kulübü aynı listenin ikinci bir
        // kopyasına götürmekten başka bir iş yapmıyordu. Excel dışa aktarma
        // kaldı, o listede olmayan bir şey veriyor.
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: list.isEmpty || busy ? null : onDownloadExcel,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: Text(
              context.t('clubEvents.students.downloadExcel'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (registrations.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: LoadingView(),
          )
        else if (list.isEmpty)
          EmptyState(
            message: context.t('clubEvents.students.empty'),
            icon: Icons.person_off_outlined,
          )
        else
          for (final EventRegistration reg in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StudentTile(registration: reg, event: event),
            ),
      ],
    );
  }
}

/// Oturum durumu ve ilerletme çubuğu (club-events.js#updateSessionControls).
///
/// İlerleme artık "2/4" gibi bir metinle değil, oturum sayısı kadar bölmesi
/// olan bir çubukla anlatılıyor: kulüp ekrana bir kez bakınca kaçıncı oturumda
/// olduğunu ve ne kadar kaldığını görüyor.
/// Kapı check-in'inin üç aşamalı kontrol çubuğu
/// (club-events.js#updateCheckinControls karşılığı).
///
/// Süreç bilerek üç adımdır ve sırası zorunludur:
///
///   1. **Check-in'i Başlat** → `entryOpen = true` (+ ilk kez `entryStartedAtMs`)
///   2. Öğrenciler kapıdaki QR'ı okutur ya da biletini görevliye gösterir
///   3. **Check-in'i Bitir** → `entryOpen = false`
///
/// Ancak 3. adımdan sonra oturumlar başlatılabilir; sebebi
/// `domain/checkin_mode.dart > doorCheckinBlocksSessionsFor` içinde yazıyor.
///
/// "Yeniden Başlat" **veriyi sıfırlamaz**: okunan girişler kayıtlarda durur
/// (`checkedInAtMs` bir kez yazılır), yeni okutulanlar üzerine eklenir.
class _CheckinStageBar extends StatelessWidget {
  const _CheckinStageBar({
    required this.event,
    required this.busy,
    required this.attended,
    required this.total,
    required this.onToggle,
    required this.onShowQr,
  });

  final AppEvent event;
  final bool busy;

  /// Kapıda girişi alınmış öğrenci sayısı / toplam kayıt.
  final int attended;
  final int total;

  final VoidCallback onToggle;
  final VoidCallback onShowQr;

  @override
  Widget build(BuildContext context) {
    final CheckinStage? stage = event.checkinStage;
    // Kapı check-in'i olmayan modda çubuk hiç çizilmez (çağıran zaten
    // `hasDoorCheckin` ile koruyor; bu yalnızca güvenli varsayılan).
    if (stage == null) return const SizedBox.shrink();

    final String tally = total > 0
        ? context.t('clubEvents.entry.tally', <String, Object?>{
            'attended': attended,
            'total': total,
          })
        : '';

    final (IconData icon, String info, String action) = switch (stage) {
      CheckinStage.notStarted => (
        Icons.door_front_door_outlined,
        context.t('clubEvents.entry.stateNotStarted'),
        context.t('clubEvents.entry.start'),
      ),
      CheckinStage.running => (
        Icons.sensor_door_outlined,
        '${context.t('clubEvents.entry.stateRunning')}$tally',
        context.t('clubEvents.entry.finish'),
      ),
      CheckinStage.finished => (
        Icons.check_circle_outline,
        '${context.t('clubEvents.entry.stateFinished')}$tally',
        context.t('clubEvents.entry.restart'),
      ),
    };

    final bool running = stage == CheckinStage.running;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        boxShadow: BrandShape.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                size: 19,
                color: stage == CheckinStage.finished
                    ? BrandColors.success
                    : context.brandInk,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  info,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Kapı açıkken asıl iş QR'ı ekranda tutmaktır; "Bitir" ikincil
          // kalır ki yanlışlıkla basılmasın.
          if (running) ...<Widget>[
            FilledButton.icon(
              onPressed: busy ? null : onShowQr,
              icon: const Icon(Icons.qr_code_2, size: 18),
              label: Text(context.t('clubEvents.entry.show')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : onToggle,
              icon: const Icon(Icons.stop_circle_outlined, size: 18),
              label: Text(action),
            ),
          ] else
            FilledButton.icon(
              onPressed: busy ? null : onToggle,
              icon: Icon(
                stage == CheckinStage.finished
                    ? Icons.restart_alt
                    : Icons.play_circle_outline,
                size: 18,
              ),
              label: Text(action),
            ),
        ],
      ),
    );
  }
}

class _SessionPanel extends StatelessWidget {
  const _SessionPanel({
    required this.event,
    required this.busy,
    required this.sessionsLockedByDoor,
    required this.onAdvance,
    required this.onUndo,
    required this.onReopen,
    required this.onShowQr,
  });

  final AppEvent event;
  final bool busy;
  final bool sessionsLockedByDoor;
  final VoidCallback onAdvance;
  final VoidCallback onUndo;
  final VoidCallback onReopen;
  final VoidCallback onShowQr;

  @override
  Widget build(BuildContext context) {
    final int current = event.currentSession;
    final int total = event.sessionCount;
    final bool done = event.sessionsCompleted;

    final String info;
    final String? actionLabel;

    if (done) {
      info = context.t('clubEvents.session.stateAllDone');
      actionLabel = null;
    } else if (current < 1) {
      info = sessionsLockedByDoor
          ? context.t('clubEvents.session.blockedByCheckin')
          : context.t('clubEvents.session.stateNotStarted');
      actionLabel = context.t('clubEvents.session.start');
    } else if (current < total) {
      info = context.t('clubEvents.session.stateActive');
      actionLabel = context.t('clubEvents.session.advanceNext');
    } else {
      info = context.t('clubEvents.session.stateLastActive');
      actionLabel = context.t('clubEvents.session.finish');
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        boxShadow: BrandShape.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                done ? Icons.check_circle_outline : Icons.repeat,
                size: 19,
                color: done ? BrandColors.success : context.brandInk,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  info,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SessionProgressBar(
            total: total,
            completed: done ? total : current,
            done: done,
          ),
          const SizedBox(height: 14),
          if (actionLabel != null)
            FilledButton.icon(
              // Kilit yalnızca YENİ oturum başlatmayı kapatır; başlamış bir
              // etkinliği ilerletmek hiçbir zaman kilitlenmez.
              onPressed: busy || sessionsLockedByDoor ? null : onAdvance,
              icon: Icon(
                current >= total ? Icons.flag_outlined : Icons.skip_next,
                size: 18,
              ),
              label: Text(actionLabel),
            ),
          // Yanlışlıkla ilerletilen oturumun tek çıkış yolu. Geri alınca eski
          // oturumun QR'ı yeniden geçerli olur ve kendiliğinden ekrana gelir.
          if (current >= 1 && !done) ...<Widget>[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : onUndo,
              icon: const Icon(Icons.undo, size: 18),
              label: Text(context.t('clubEvents.session.undo')),
            ),
          ],
          // Oturumlar bitirildikten sonra tek çıkış yolu: yanlışlıkla
          // bitirildiğinde ya da geç gelen öğrenci yoklamaya alınacağında
          // kulüp oturumları geri açabilsin.
          if (done)
            OutlinedButton.icon(
              onPressed: busy ? null : onReopen,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: Text(context.t('clubEvents.session.reopen')),
            ),
          // Aktif oturum varken QR tekrar gösterilebilir.
          if (current >= 1 && !done) ...<Widget>[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onShowQr,
              icon: const Icon(Icons.qr_code_2),
              label: Text(context.t('clubEvents.session.showQr')),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bir eylemin neden kapalı olduğunu anlatan uyarı kartı.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.isDarkMode
        ? BrandColors.infoOnDark
        : BrandColors.info;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? BrandColors.infoBgDark
            : BrandColors.infoBg,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 19, color: accent),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12.5, height: 1.45, color: accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Yüklenmiş tek belge kartı — dokununca açılır, sağ üstündeki tuşlarla
/// yeniden dağıtılır ya da silinir.
///
/// Tuşlar kartın **dışına taşan** yuvarlak düğmeler: liste uzadığında hangi
/// belgeye ait oldukları tartışmasız kalsın ve yanlışlıkla kartın kendisine
/// (yani "aç") basılmasın diye kart gövdesinden ayrı duruyorlar.
///
/// Kartın alt satırı belgenin kaç öğrenciye gittiğini yazar: "yükledim, iş
/// bitti" sanılan ama aslında kimseye ulaşmamış belgeler tek bakışta
/// görünsün.
class _UploadedDocumentCard extends StatelessWidget {
  const _UploadedDocumentCard({
    required this.document,
    required this.enabled,
    required this.canDistribute,
    required this.onOpen,
    required this.onRedistribute,
    required this.onDelete,
  });

  final EventDocument document;
  final bool enabled;

  /// Belge kapısı açık mı (oturumlar bitti / etkinlik bitti).
  final bool canDistribute;

  final VoidCallback onOpen;
  final VoidCallback onRedistribute;
  final VoidCallback onDelete;

  bool get _isPdf => document.contentType.contains('pdf');

  /// Alt satır: dağıtıldıysa kaç kişiye gittiği, dağıtılmadıysa beklediği.
  String _statusLabel(BuildContext context) => document.isDistributed
      ? context.t('clubEvents.certificate.distributedCount', <String, Object?>{
          'count': document.distributedCount,
        })
      : context.t('clubEvents.certificate.notDistributed');

  @override
  Widget build(BuildContext context) {
    final String name = document.name.isNotEmpty
        ? document.name
        : context.t('clubEvents.certificate.uploaded');

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Material(
          color: context.surface,
          borderRadius: BorderRadius.circular(BrandShape.controlRadius),
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(BrandShape.controlRadius),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 13, 62, 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(BrandShape.controlRadius),
                boxShadow: BrandShape.card,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    _isPdf
                        ? Icons.picture_as_pdf_outlined
                        : Icons.image_outlined,
                    size: 22,
                    color: context.brandInk,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.visibility_outlined,
                              size: 13,
                              color: context.inkMuted,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                document.uploadedAtMs > 0
                                    ? formatDateTime(
                                        document.uploadedAtMs,
                                        locale: context.lang,
                                      )
                                    : context.t(
                                        'clubEvents.certificate.view',
                                      ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: <Widget>[
                            Icon(
                              document.isDistributed
                                  ? Icons.check_circle_outline
                                  : Icons.schedule_send_outlined,
                              size: 13,
                              color: document.isDistributed
                                  ? BrandColors.success
                                  : context.inkMuted,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _statusLabel(context),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -8,
          right: -6,
          child: Row(
            children: <Widget>[
              // Yeniden dağıt: belgeyi arşivden alıp o anki hak sahiplerine
              // gönderir. Yükleme anında hak sahibi olmayan (ya da sonradan
              // yoklamaya giren) öğrencilere belgenin ulaşmasının tek yolu
              // buydu; eskiden kulüp belgeyi silip yeniden yüklemekten başka
              // bir şey yapamıyor, sonuç değişmiyordu.
              _DocumentCircleButton(
                icon: Icons.send_outlined,
                color: context.brandInk,
                tooltip: context.t('clubEvents.certificate.redistribute'),
                onTap: enabled && canDistribute ? onRedistribute : null,
              ),
              const SizedBox(width: 6),
              _DocumentCircleButton(
                icon: Icons.delete_outline,
                color: BrandColors.danger,
                tooltip: context.t('clubEvents.certificate.delete'),
                onTap: enabled ? onDelete : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Belge kartının üstüne taşan yuvarlak tuş.
class _DocumentCircleButton extends StatelessWidget {
  const _DocumentCircleButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    return Material(
      color: enabled ? color : context.inkMuted,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 17, color: BrandColors.white),
          ),
        ),
      ),
    );
  }
}

/// Kontenjan doluluk göstergesi.
///
/// Kulübün "kaç kişi kaldı" sorusunun tek yanıtı burası: kayıt sayısını
/// katılımcı listesini açıp saymak gerekiyordu. Dolduğunda etkinliğin
/// kendiliğinden beklemeye alındığı da burada söylenir — aksi hâlde kulüp,
/// kayıtları kendisinin durdurmadığı hâlde neden kapalı olduğunu anlamaz.
class _QuotaMeter extends StatelessWidget {
  const _QuotaMeter({required this.quota, required this.event});

  final QuotaStatus quota;
  final AppEvent event;

  @override
  Widget build(BuildContext context) {
    final bool full = quota.isFull;
    final bool autoPaused =
        event.registrationClosed &&
        event.registrationClosedReason == ClosedReason.quotaFull;

    // Dolmaya yaklaşırken markanın kırmızısı, dolunca koyu kırmızı: ayrı bir
    // "uyarı sarısı" temada yok ve tek bir etkinlik kartı için palet
    // genişletmeye değmez.
    final Color accent = full
        ? BrandColors.danger
        : quota.percent >= 80
            ? BrandColors.red
            : BrandColors.success;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: context.subtleFill,
        borderRadius: BorderRadius.circular(BrandShape.cardRadius),
        border: Border.all(color: context.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                full ? Icons.pause_circle_outline : Icons.groups_outlined,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t('clubEvents.quota.title'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${quota.used} / ${quota.capacity}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: quota.percent / 100,
              minHeight: 7,
              backgroundColor: context.hairline,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            autoPaused
                ? context.t('clubEvents.quota.autoPaused')
                : full
                    ? context.t('clubEvents.quota.full')
                    : context.t('clubEvents.quota.remaining', <String, Object?>{
                        'count': quota.remaining,
                      }),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: full ? accent : context.inkMuted,
                  fontWeight: full ? FontWeight.w600 : null,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.trailingIcon = Icons.chevron_right,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onPressed;

  /// Sağ uçtaki simge. Varsayılan ">" yalnızca başka bir ekrana götüren
  /// kartlar için doğru; yerinde iş yapan kartlar kendi simgesini verir.
  final IconData trailingIcon;

  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Color accent = danger ? BrandColors.danger : context.brandInk;

    return Material(
      color: context.surface,
      borderRadius: BorderRadius.circular(BrandShape.controlRadius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BrandShape.controlRadius),
            boxShadow: BrandShape.card,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                size: 21,
                color: enabled ? accent : context.inkMuted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: enabled ? context.ink : context.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              // Kapalı kartlarda da simge çizilir (soluk): kilit simgesi
              // kartın neden tepki vermediğini söyleyen tek işaret.
              if (enabled || trailingIcon != Icons.chevron_right)
                Icon(
                  trailingIcon,
                  color: !enabled
                      ? context.inkMuted
                      : trailingIcon == Icons.chevron_right
                      ? context.inkMuted
                      : accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Belge adresi/yolu kutusu: "yapıştır" + "yükle ve dağıt".
///
/// Dosya seçici bazı cihazlarda (özellikle bulut sağlayıcılarında) belgeyi hiç
/// döndürmüyor. Kulüp belgeyi zaten bir yerden kopyalamış oluyor; buraya
/// yapıştırmak aynı yükleme yolunu ikinci bir kapıdan açar.
class _CertificateLinkField extends StatelessWidget {
  const _CertificateLinkField({
    required this.controller,
    required this.enabled,
    required this.onPaste,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onPaste;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    // Kutu boşken gönderme düğmesi kapalı kalsın diye metin dinleniyor.
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        final bool hasText = controller.text.trim().isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.url,
              inputFormatters: guardedInput(InputLimits.url),
              decoration: InputDecoration(
                labelText: context.t('clubEvents.certificate.linkLabel'),
                helperText: context.t('clubEvents.certificate.linkHint'),
                helperMaxLines: 3,
                suffixIcon: IconButton(
                  tooltip: context.t('clubEvents.certificate.paste'),
                  onPressed: enabled ? onPaste : null,
                  icon: const Icon(Icons.content_paste, size: 19),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
              onPressed: enabled && hasText ? onSubmit : null,
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(context.t('clubEvents.certificate.linkAction')),
            ),
          ],
        );
      },
    );
  }
}

/// Katılımcı satırı (club-events.js#renderStudentsTable).

/// Ücretli etkinliğin onay işlem logu — YALNIZCA ücretli etkinlikte çizilir.
///
/// İki kayıt bir arada gösterilir:
///   • kulübün etkinliği oluştururken onayladığı metin (etkinlik belgesinde),
///   • kaydolan her öğrencinin onayladığı metin (kaydın kendi belgesinde).
///
/// Damga `formatPaidEventConsentStamp` ile yazıldığı gibi gösterilir:
/// gün.ay.yıl saat:dakika:saniye. Metinler uzun olduğu için katlanır durur;
/// dokununca açılır.
class _PaidEventConsentLogCard extends StatefulWidget {
  const _PaidEventConsentLogCard({
    required this.event,
    required this.registrations,
  });

  final AppEvent event;
  final List<EventRegistration> registrations;

  @override
  State<_PaidEventConsentLogCard> createState() =>
      _PaidEventConsentLogCardState();
}

class _PaidEventConsentLogCardState extends State<_PaidEventConsentLogCard> {
  /// Metni açılmış kayıtlar. Kulüp onayı için `club`, öğrenciler için kayıt
  /// kimliği tutulur.
  final Set<String> _expanded = <String>{};

  void _toggle(String key) => setState(
    () => _expanded.contains(key) ? _expanded.remove(key) : _expanded.add(key),
  );

  @override
  Widget build(BuildContext context) {
    final PaidEventConsentLog? clubLog = widget.event.clubConsentLog;

    // Onay veren öğrenciler: onaysız (ücretli etkinlik alanları eklenmeden
    // önce yapılmış) kayıtlar listede yer almaz, sayı da onları saymaz.
    final List<EventRegistration> consented = widget.registrations
        .where((EventRegistration r) => r.studentConsentLog != null)
        .toList()
      ..sort(
        (EventRegistration a, EventRegistration b) =>
            b.studentConsentLog!.atMs.compareTo(a.studentConsentLog!.atMs),
      );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        boxShadow: BrandShape.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.t('paidEventConsent.log.club'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          if (clubLog == null)
            Text(
              context.t('paidEventConsent.log.missing'),
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            _ConsentLogRow(
              log: clubLog,
              label: widget.event.clubName,
              expanded: _expanded.contains('club'),
              onToggle: () => _toggle('club'),
            ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.t('paidEventConsent.log.students'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              StatusPill(label: '${consented.length}'),
            ],
          ),
          const SizedBox(height: 6),
          if (consented.isEmpty)
            Text(
              context.t('paidEventConsent.log.studentsEmpty'),
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            for (final EventRegistration reg in consented)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ConsentLogRow(
                  log: reg.studentConsentLog!,
                  label: reg.displayName,
                  expanded: _expanded.contains(reg.id),
                  onToggle: () => _toggle(reg.id),
                ),
              ),
          const SizedBox(height: 10),
          Text(
            context.t('paidEventConsent.log.note'),
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: context.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek bir onay satırı: kim, ne zaman — ve istenirse metnin tamamı.
class _ConsentLogRow extends StatelessWidget {
  const _ConsentLogRow({
    required this.log,
    required this.label,
    required this.expanded,
    required this.onToggle,
  });

  final PaidEventConsentLog log;
  final String label;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final String who = label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.verified_outlined, size: 15, color: context.inkMuted),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                who,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  context.t(
                    expanded
                        ? 'paidEventConsent.log.hideText'
                        : 'paidEventConsent.log.showText',
                  ),
                  style: TextStyle(fontSize: 11.5, color: context.inkMuted),
                ),
              ),
            ),
          ],
        ),
        _Line(icon: Icons.schedule, text: log.stamp),
        if (expanded) ...<Widget>[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.isDarkMode
                  ? BrandColors.infoBgDark
                  : BrandColors.infoBg,
              borderRadius: BorderRadius.circular(BrandShape.controlRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  log.text.isNotEmpty
                      ? log.text
                      : context.t('paidEventConsent.log.legacyText'),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: context.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.registration, required this.event});

  final EventRegistration registration;
  final AppEvent event;

  @override
  Widget build(BuildContext context) {
    final bool checkedIn = registration.isCheckedIn;

    final bool hasCertificate = event.isMultiSession &&
        event.certificateThresholdPercent != null &&
        (registration.sessionsAttended / event.sessionCount) * 100 >=
            event.certificateThresholdPercent!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(BrandShape.controlRadius),
        boxShadow: BrandShape.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  registration.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (event.isMultiSession)
                StatusPill(
                  label:
                      '${registration.sessionsAttended}/${event.sessionCount}',
                  tone:
                      hasCertificate ? FeedbackTone.success : FeedbackTone.info,
                )
              else
                StatusPill(
                  label: checkedIn
                      ? context.t('clubEvents.students.checkedIn')
                      : context.t('clubEvents.students.registered'),
                  tone: checkedIn ? FeedbackTone.success : FeedbackTone.info,
                ),
            ],
          ),
          const SizedBox(height: 6),
          _Line(icon: Icons.mail_outline, text: registration.studentEmail),
          if (registration.studentPhone.isNotEmpty)
            _Line(icon: Icons.phone_outlined, text: registration.studentPhone),
          _Line(
            icon: Icons.account_balance_outlined,
            text: <String>[
              if (registration.studentUniversity.isNotEmpty)
                registration.studentUniversity,
              if (registration.studentDepartment.isNotEmpty)
                registration.studentDepartment,
              if (registration.studentClassYear.isNotEmpty)
                registration.studentClassYear,
            ].join(' • '),
          ),
          _Line(
            icon: Icons.schedule,
            text: formatDateTime(
              registration.registeredAtMs,
              locale: context.lang,
            ),
          ),
          // Ücretli etkinlikte öğrencinin onay damgası, kaydın hemen
          // altında: listeye bakan kulüp onayın alındığını görsün.
          if (event.isPaid && registration.studentConsentLog != null)
            _Line(
              icon: Icons.verified_outlined,
              text:
                  '${context.t('paidEventConsent.log.tileLabel')}: '
                  '${registration.studentConsentLog!.stamp}',
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: context.inkMuted),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
