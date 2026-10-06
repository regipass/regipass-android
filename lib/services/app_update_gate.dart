/// İP-H: zorunlu güncelleme kapısı.
///
/// Firestore `app_config/mobile` belgesindeki en düşük derleme numarasının
/// (`minBuildIos` / `minBuildAndroid`) altındaki sürümler "Güncelle" ekranında
/// durur. Böylece eski (güvenlik açığı kapatılmamış) sürümler kapatılabilir ve
/// sunucudaki geçiş dönemi izinleri (Aşama 2) kaldırılabilir.
///
/// Belge yoksa, okunamazsa ya da 4 saniyede gelmezse kapı AÇIK kalır: ağ
/// sorunu kimseyi uygulamanın dışında bırakmaz.
library;

import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/demo_mode.dart';
import '../app/theme.dart';
import '../l10n/app_strings.dart';

// App Store kimliği belgedeki storeUrlIos ile verilir; yoksa siteye gidilir.
const String kIosStoreUrl = 'https://regipass.com';
const String kAndroidStoreUrl =
    'https://play.google.com/store/apps/details?id=app.regipassapp.mobile';

@immutable
class UpdateRequirement {
  const UpdateRequirement({required this.required, this.storeUrl = '', this.message = ''});

  final bool required;
  final String storeUrl;
  final String message;

  static const UpdateRequirement none = UpdateRequirement(required: false);
}

/// Saf karar: kurulu derleme en düşük derlemenin altında mı?
UpdateRequirement evaluateUpdateRequirement({
  required Map<String, dynamic>? config,
  required int installedBuild,
  required bool isIos,
}) {
  if (config == null || installedBuild <= 0) return UpdateRequirement.none;
  final Object? raw = config[isIos ? 'minBuildIos' : 'minBuildAndroid'];
  final int minBuild = raw is num ? raw.toInt() : 0;
  if (minBuild <= 0 || installedBuild >= minBuild) return UpdateRequirement.none;
  final Object? url = config[isIos ? 'storeUrlIos' : 'storeUrlAndroid'];
  final Object? message = config['message'];
  return UpdateRequirement(
    required: true,
    storeUrl: url is String && url.startsWith('https://')
        ? url
        : (isIos ? kIosStoreUrl : kAndroidStoreUrl),
    message: message is String ? message : '',
  );
}

final FutureProvider<UpdateRequirement> updateRequirementProvider =
    FutureProvider<UpdateRequirement>((Ref ref) async {
  if (kIsWeb || kDemoMode) return UpdateRequirement.none;
  if (!Platform.isIOS && !Platform.isAndroid) return UpdateRequirement.none;
  try {
    final PackageInfo info = await PackageInfo.fromPlatform();
    final DocumentSnapshot<Map<String, dynamic>> snap = await FirebaseFirestore
        .instance
        .collection('app_config')
        .doc('mobile')
        .get()
        .timeout(const Duration(seconds: 4));
    return evaluateUpdateRequirement(
      config: snap.data(),
      installedBuild: int.tryParse(info.buildNumber) ?? 0,
      isIos: Platform.isIOS,
    );
  } catch (_) {
    return UpdateRequirement.none;
  }
});

/// Uygulamanın tamamını sarar; güncelleme gerekiyorsa yalnızca uyarıyı gösterir.
class UpdateGate extends ConsumerWidget {
  const UpdateGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UpdateRequirement req =
        ref.watch(updateRequirementProvider).value ?? UpdateRequirement.none;
    if (!req.required) return child;
    return UpdateRequiredScreen(requirement: req);
  }
}

class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({required this.requirement, super.key});

  final UpdateRequirement requirement;

  @override
  Widget build(BuildContext context) {
    final bool en = context.lang == 'en';
    final String message = requirement.message.isNotEmpty
        ? requirement.message
        : (en
            ? 'A new version of Regipass is available with important security and speed improvements. Please update to continue.'
            : "Regipass'in önemli güvenlik ve hız iyileştirmeleri içeren yeni sürümü hazır. Devam etmek için uygulamayı güncelle.");
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.system_update_rounded, size: 64, color: BrandColors.red),
                  const SizedBox(height: 18),
                  Text(
                    en ? 'Update required' : 'Güncelleme gerekli',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.ink),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, height: 1.45, color: context.inkBody),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: BrandColors.red,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () => launchUrl(
                        Uri.parse(requirement.storeUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(
                        en ? 'Update' : 'Güncelle',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
