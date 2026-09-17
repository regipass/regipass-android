/// Shared wire format with the web notification-targets.js module.
library;

import '../core/text_utils.dart';

const String globalNotificationUniversity = 'TÜM ÜNİVERSİTELER';

List<String> notificationRecipientKeys({
  required String university,
  required String audience,
  bool global = false,
}) {
  final List<String> roles = switch (audience) {
    'both' => <String>['student', 'club'],
    'student' || 'club' => <String>[audience],
    _ => <String>[],
  };
  if (global) return roles.map((String role) => 'all:$role').toList();
  final String key = foldTr(university);
  if (key.isEmpty) return <String>[];
  return roles.map((String role) => 'uni:$key:$role').toList();
}

List<String> notificationViewerKeys({
  required String university,
  required String role,
}) {
  if (role != 'student' && role != 'club') return <String>[];
  final String key = foldTr(university);
  return <String>['all:$role', if (key.isNotEmpty) 'uni:$key:$role'];
}
