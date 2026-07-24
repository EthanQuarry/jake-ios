import 'package:flutter/services.dart';

typedef JakeValue = Object?;
typedef JakeProperties = Map<String, JakeValue>;

sealed class JakeEvent {
  const JakeEvent();

  factory JakeEvent.fromMap(Map<Object?, Object?> value) {
    switch (value['type']) {
      case 'unreadCountChanged':
        return JakeUnreadCountChanged((value['count'] as num?)?.toInt() ?? 0);
      case 'authenticationExpired':
        return const JakeAuthenticationExpired();
      case 'error':
        return JakeErrorEvent(
          value['code'] as String? ?? 'jake_error',
          value['message'] as String? ?? 'An unknown Jake error occurred.',
        );
      default:
        throw FormatException('Unknown Jake event: ${value['type']}');
    }
  }
}

final class JakeUnreadCountChanged extends JakeEvent {
  const JakeUnreadCountChanged(this.count);
  final int count;
}

final class JakeAuthenticationExpired extends JakeEvent {
  const JakeAuthenticationExpired();
}

final class JakeErrorEvent extends JakeEvent {
  const JakeErrorEvent(this.code, this.message);
  final String code;
  final String message;
}

abstract final class Jake {
  static const MethodChannel _methods = MethodChannel('ai.tryjake.sdk/methods');
  static const EventChannel _events = EventChannel('ai.tryjake.sdk/events');

  static Stream<JakeEvent>? _eventStream;

  static Stream<JakeEvent> get events => _eventStream ??= _events
      .receiveBroadcastStream()
      .map((value) => JakeEvent.fromMap(value as Map<Object?, Object?>));

  static Future<void> configure({
    required String workspaceId,
    required String publicKey,
    String? messengerUrl,
  }) {
    return _methods.invokeMethod<void>('configure', {
      'workspaceId': workspaceId,
      'publicKey': publicKey,
      if (messengerUrl != null) 'messengerUrl': messengerUrl,
    });
  }

  static Future<void> authenticate({
    required String userId,
    required String token,
  }) {
    return _methods.invokeMethod<void>('authenticate', {
      'userId': userId,
      'token': token,
    });
  }

  static Future<void> present() => _methods.invokeMethod<void>('present');
  static Future<void> dismiss() => _methods.invokeMethod<void>('dismiss');
  static Future<void> logout() => _methods.invokeMethod<void>('logout');

  static Future<void> track(
    String event, [
    JakeProperties properties = const {},
  ]) {
    return _methods.invokeMethod<void>('track', {
      'event': event,
      'properties': properties,
    });
  }

  static Future<void> setUserAttributes(JakeProperties attributes) {
    return _methods.invokeMethod<void>('setUserAttributes', attributes);
  }

  static Future<void> setPushToken(String token) {
    return _methods.invokeMethod<void>('setPushToken', token);
  }

  static Future<int> getUnreadCount() async {
    return await _methods.invokeMethod<int>('getUnreadCount') ?? 0;
  }
}
