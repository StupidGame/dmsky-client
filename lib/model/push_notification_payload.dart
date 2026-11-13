/// A validated, credential-free push payload used to route notification taps.
enum PushNotificationTarget { note, user, chat, notifications }

final class PushNotificationPayload {
  const PushNotificationPayload({
    required this.eventId,
    required this.host,
    required this.target,
    this.noteId,
    this.userId,
    this.chatId,
  });

  static const version = '1';

  final String eventId;
  final String host;
  final PushNotificationTarget target;
  final String? noteId;
  final String? userId;
  final String? chatId;

  /// Parses FCM/APNs/Web Push data. Invalid or unsupported payloads are ignored.
  /// Push data must never contain an API token or other authentication secret.
  static PushNotificationPayload? tryParse(Map<String, dynamic> data) {
    String? value(String key) {
      final raw = data[key];
      if (raw is! String) return null;
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (value('v') != version) return null;
    final eventId = value('eventId');
    final rawHost = value('host');
    final rawTarget = value('target');
    if (eventId == null || rawHost == null || rawTarget == null) {
      return null;
    }

    // Host is an account selector, never an arbitrary navigation URL.
    final hostUri = Uri.tryParse(
      rawHost.contains('://') ? rawHost : 'https://$rawHost',
    );
    final rawHostName = hostUri?.host ?? '';
    final isDnsHost = rawHostName.isNotEmpty && rawHostName.codeUnits.every(
      (unit) =>
          (unit >= 48 && unit <= 57) ||
          (unit >= 65 && unit <= 90) ||
          (unit >= 97 && unit <= 122) ||
          unit == 45 ||
          unit == 46,
    );
    final isIpv6Host = rawHostName.contains(':') &&
        rawHostName.codeUnits.every(
          (unit) =>
              (unit >= 48 && unit <= 57) ||
              (unit >= 65 && unit <= 70) ||
              (unit >= 97 && unit <= 102) ||
              unit == 58 ||
              unit == 46,
        );

    if (hostUri == null ||
        !hostUri.hasAuthority ||
        hostUri.scheme != 'https' ||
        rawHostName.isEmpty ||
        (!isDnsHost && !isIpv6Host) ||
        hostUri.userInfo.isNotEmpty ||
        (hostUri.path.isNotEmpty && hostUri.path != '/') ||
        hostUri.query.isNotEmpty ||
        hostUri.fragment.isNotEmpty) {
      return null;
    }

    final host = '${hostUri.host.toLowerCase()}${hostUri.hasPort ? ':${hostUri.port}' : ''}';

    final target = switch (rawTarget) {
      'note' => PushNotificationTarget.note,
      'user' => PushNotificationTarget.user,
      'chat' => PushNotificationTarget.chat,
      'notifications' => PushNotificationTarget.notifications,
      _ => null,
    };
    if (target == null) return null;

    final noteId = value('noteId');
    final userId = value('userId');
    final chatId = value('chatId');
    switch (target) {
      case PushNotificationTarget.note:
        if (noteId == null) return null;
        break;
      case PushNotificationTarget.user:
        if (userId == null) return null;
        break;
      case PushNotificationTarget.chat:
        if (chatId == null ||
            (!chatId.startsWith('room:') && !chatId.startsWith('user:')) ||
            chatId.length <= 5) {
          return null;
        }
        break;
      case PushNotificationTarget.notifications:
        break;
    }

    return PushNotificationPayload(
      eventId: eventId,
      host: host,
      target: target,
      noteId: noteId,
      userId: userId,
      chatId: chatId,
    );
  }
}
