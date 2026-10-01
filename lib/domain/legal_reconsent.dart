import '../models/profiles.dart';
import 'legal_docs.dart';

/// İP-HK: hukuki metinler güncellendiğinde (kLegalDocsVersion) daha önce
/// onay vermiş kullanıcıdan BİR KEZ yeniden onay istenir.
///
/// Hiç onayı olmayan (kaydı yarım) hesaplara bakılmaz: onlar bilgi formunda
/// zaten onay veriyor. Web (`consent.tosAndKvkk`) ve mobil (`termsVersion`)
/// kayıtlarından biri güncel sürümse yeterli.
bool needsLegalReconsent(AppUser? user, {String current = kLegalDocsVersion}) {
  if (user == null) return false;
  final bool hasAny = user.termsAccepted || user.webTermsGiven;
  if (!hasAny) return false;
  return user.termsVersion != current && user.webTermsVersion != current;
}
