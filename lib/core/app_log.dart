/// Yapılandırılmış uygulama günlüğü.
///
/// Projede şu ana kadar yalnızca `debugPrint` vardı: serbest metin, alan yok,
/// üretimde okunacak bir yer yok. Kayıt akışı gibi **eşzamanlılığa duyarlı**
/// işlerde "ne oldu" sorusu ancak alanlarla yanıtlanabilir — kaçıncı denemede,
/// hangi parçada, ne kadar beklendikten sonra.
///
/// Bu yüzden günlük satırı bir metin değil, bir **olay + alan haritası**:
///
/// ```dart
/// AppLog.i('registration.attempt', <String, Object?>{
///   'eventId': event.id, 'round': 2, 'shard': 7,
/// });
/// ```
///
/// İki hedefe birden yazar:
///   • `dart:developer` → IDE / `flutter logs` (yalnızca profil ve hata ayıklama)
///   • bellekteki halka tampon → [dump] ile tek seferde dışa alınabilir
///
/// Halka tampon üretimde de doludur: kullanıcı "kaydolamadım" dediğinde
/// son [_kCapacity] olay elimizdedir.
library;

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

enum LogLevel {
  debug(0, 'DEBUG'),
  info(1, 'INFO'),
  warn(2, 'WARN'),
  error(3, 'ERROR');

  const LogLevel(this.severity, this.label);

  final int severity;
  final String label;
}

/// Tek bir günlük satırı.
@immutable
class LogRecord {
  const LogRecord({
    required this.at,
    required this.level,
    required this.event,
    required this.fields,
    this.error,
    this.stack,
  });

  final DateTime at;
  final LogLevel level;

  /// Nokta ile ayrılmış olay adı: `registration.shard.aborted`.
  /// Serbest cümle DEĞİL — böylece günlükler alana göre süzülebilir.
  final String event;

  final Map<String, Object?> fields;
  final Object? error;
  final StackTrace? stack;

  Map<String, Object?> toJson() => <String, Object?>{
    'at': at.toIso8601String(),
    'level': level.label,
    'event': event,
    if (fields.isNotEmpty) 'fields': fields,
    if (error != null) 'error': error.toString(),
  };

  /// İnsan okuması için tek satır.
  @override
  String toString() {
    final String suffix = fields.isEmpty
        ? ''
        : ' ${fields.entries.map((MapEntry<String, Object?> e) => '${e.key}=${e.value}').join(' ')}';
    final String errorPart = error == null ? '' : ' error=$error';
    return '[${level.label}] $event$suffix$errorPart';
  }
}

/// Uygulama günlüğü — tümü statik, tek örnek.
class AppLog {
  const AppLog._();

  /// Bellekte tutulan olay sayısı. Kayıt fırtınasında bir öğrencinin
  /// tüm denemeleri (8 tur × birkaç olay) rahatça sığsın diye geniş.
  static const int _kCapacity = 500;

  static final List<LogRecord> _buffer = <LogRecord>[];

  /// Bu seviyenin altındaki olaylar hiç kaydedilmez.
  /// Üretimde `debug` satırları gürültü olduğu için elenir.
  static LogLevel minLevel = kReleaseMode ? LogLevel.info : LogLevel.debug;

  /// Testlerin olayları doğrulaması için: her kayıtta çağrılır.
  @visibleForTesting
  static void Function(LogRecord record)? onRecord;

  static void debug(String event, [Map<String, Object?> fields = const <String, Object?>{}]) =>
      _write(LogLevel.debug, event, fields);

  static void info(String event, [Map<String, Object?> fields = const <String, Object?>{}]) =>
      _write(LogLevel.info, event, fields);

  static void warn(String event, [Map<String, Object?> fields = const <String, Object?>{}]) =>
      _write(LogLevel.warn, event, fields);

  static void error(
    String event, {
    Object? error,
    StackTrace? stack,
    Map<String, Object?> fields = const <String, Object?>{},
  }) => _write(LogLevel.error, event, fields, error: error, stack: stack);

  static void _write(
    LogLevel level,
    String event,
    Map<String, Object?> fields, {
    Object? error,
    StackTrace? stack,
  }) {
    if (level.severity < minLevel.severity) return;

    final LogRecord record = LogRecord(
      at: DateTime.now(),
      level: level,
      event: event,
      fields: fields,
      error: error,
      stack: stack,
    );

    _buffer.add(record);
    if (_buffer.length > _kCapacity) _buffer.removeAt(0);

    onRecord?.call(record);

    // Üretim paketinde konsola yazmak hem maliyetli hem gereksiz: satırlar
    // zaten halka tamponda ve [dump] ile alınabiliyor.
    if (!kReleaseMode) {
      developer.log(
        record.toString(),
        name: 'regipass',
        level: switch (level) {
          LogLevel.debug => 500,
          LogLevel.info => 800,
          LogLevel.warn => 900,
          LogLevel.error => 1000,
        },
        error: error,
        stackTrace: stack,
      );
    }
  }

  /// Tampondaki olaylar (en eskiden yeniye).
  static List<LogRecord> get records => List<LogRecord>.unmodifiable(_buffer);

  /// Yalnızca adı [prefix] ile başlayan olaylar — `AppLog.where('registration.')`.
  static List<LogRecord> where(String prefix) =>
      _buffer.where((LogRecord r) => r.event.startsWith(prefix)).toList();

  /// Tamponun tamamı JSONL olarak: destek talebine eklenebilir,
  /// yük testi çıktısıyla aynı biçimdedir.
  static String dump() =>
      _buffer.map((LogRecord r) => jsonEncode(r.toJson())).join('\n');

  static void clear() => _buffer.clear();
}
