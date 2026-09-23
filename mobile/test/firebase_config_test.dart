// Una configuración de Firebase mal formada cierra la app en iOS al abrirla
// (FIRInstallations lanza una excepción nativa): se valida antes en Dart.

import 'package:agendaservi/features/notifications/push_service.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Valores del proyecto agendaservi (configuración pública de las apps).
  const real = (
    projectId: 'agendaservi',
    senderId: '877387960055',
    androidApiKey: 'AIzaSyDbp9RCqZnpKdUlziiOoRxa5DfzeYrXhSY',
    androidAppId: '1:877387960055:android:5f38358a0cf89e2f274df2',
    iosApiKey: 'AIzaSyD39VCnTpqS7ki8sDkehh_oNC-ATncGOvs',
    iosAppId: '1:877387960055:ios:ed477ba7e9ea840b274df2',
  );

  FirebaseOptions? para(TargetPlatform p, {String? iosApiKey, String? iosAppId, String? senderId, String? projectId, bool web = false}) =>
      ConfigFirebase.construir(
        web: web,
        plataforma: p,
        projectId: projectId ?? real.projectId,
        senderId: senderId ?? real.senderId,
        androidApiKey: real.androidApiKey,
        androidAppId: real.androidAppId,
        iosApiKey: iosApiKey ?? real.iosApiKey,
        iosAppId: iosAppId ?? real.iosAppId,
      );

  test('la configuración real es válida en Android e iOS', () {
    final ios = para(TargetPlatform.iOS)!;
    expect(ios.apiKey, real.iosApiKey);
    expect(ios.appId, real.iosAppId);
    expect(ios.iosBundleId, 'com.agendaservi.agendaservi');
    expect(para(TargetPlatform.android)!.appId, real.androidAppId);
  });

  test('valores de ejemplo o mal copiados no inician Firebase (la app abre sin push)', () {
    expect(para(TargetPlatform.iOS, iosApiKey: 'AIza...'), isNull); // firebase.example.json
    expect(para(TargetPlatform.iOS, iosApiKey: ' ${real.iosApiKey}'), isNull);
    expect(para(TargetPlatform.iOS, iosApiKey: real.iosApiKey.substring(1)), isNull);
    expect(para(TargetPlatform.iOS, iosAppId: '1:123456789012:ios:abcdef0123456789'), isNull); // otro proyecto
    expect(para(TargetPlatform.iOS, iosAppId: real.androidAppId), isNull); // app de Android en iOS
    expect(para(TargetPlatform.iOS, senderId: '123456789012'), isNull);
    expect(para(TargetPlatform.iOS, projectId: 'agendaservi-xxxxx'), isNotNull); // el id puede tener guiones
    expect(para(TargetPlatform.iOS, projectId: ''), isNull);
    expect(para(TargetPlatform.iOS, web: true), isNull);
  });
}
