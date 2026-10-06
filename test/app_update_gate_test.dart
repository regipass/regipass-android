import 'package:flutter_test/flutter_test.dart';
import 'package:regipass/services/app_update_gate.dart';

void main() {
  test('belge yoksa ya da en düşük derleme 0 ise kapı açık', () {
    expect(evaluateUpdateRequirement(config: null, installedBuild: 15, isIos: true).required, isFalse);
    expect(
      evaluateUpdateRequirement(config: <String, dynamic>{'minBuildIos': 0}, installedBuild: 15, isIos: true).required,
      isFalse,
    );
  });

  test('kurulu derleme en düşükten küçükse güncelleme istenir', () {
    final UpdateRequirement r = evaluateUpdateRequirement(
      config: <String, dynamic>{'minBuildIos': 16, 'minBuildAndroid': 14, 'storeUrlIos': 'https://apps.apple.com/app/x'},
      installedBuild: 15,
      isIos: true,
    );
    expect(r.required, isTrue);
    expect(r.storeUrl, 'https://apps.apple.com/app/x');
    expect(
      evaluateUpdateRequirement(
        config: <String, dynamic>{'minBuildIos': 16, 'minBuildAndroid': 14},
        installedBuild: 15,
        isIos: false,
      ).required,
      isFalse,
    );
  });

  test('güvensiz mağaza adresi yok sayılır', () {
    final UpdateRequirement r = evaluateUpdateRequirement(
      config: <String, dynamic>{'minBuildAndroid': 99, 'storeUrlAndroid': 'javascript:alert(1)'},
      installedBuild: 15,
      isIos: false,
    );
    expect(r.storeUrl, kAndroidStoreUrl);
  });
}
