import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jake_flutter/jake_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ai.tryjake.sdk/methods');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'getUnreadCount' ? 3 : null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('forwards the complete method API', () async {
    await Jake.configure(workspaceId: 'w', publicKey: 'pk');
    await Jake.authenticate(userId: 'u', token: 'token');
    await Jake.present();
    await Jake.track('opened', {'source': 'test'});
    await Jake.setUserAttributes({'plan': 'pro'});
    await Jake.setPushToken('push-token');
    expect(await Jake.getUnreadCount(), 3);
    await Jake.dismiss();
    await Jake.logout();

    expect(
      calls.map((call) => call.method),
      [
        'configure',
        'authenticate',
        'present',
        'track',
        'setUserAttributes',
        'setPushToken',
        'getUnreadCount',
        'dismiss',
        'logout',
      ],
    );
  });

  test('decodes native events', () {
    expect(
      JakeEvent.fromMap({'type': 'unreadCountChanged', 'count': 2}),
      isA<JakeUnreadCountChanged>()
          .having((event) => event.count, 'count', 2),
    );
    expect(
      JakeEvent.fromMap({'type': 'authenticationExpired'}),
      isA<JakeAuthenticationExpired>(),
    );
  });
}
