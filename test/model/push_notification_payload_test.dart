import 'package:flutter_test/flutter_test.dart';
import 'package:dmsky_client/model/push_notification_payload.dart';

void main() {
  const base = <String, dynamic>{
    'v': '1',
    'eventId': 'evt-123',
    'host': 'Misskey.example',
  };

  test('parses a note target and normalizes its HTTPS host', () {
    final payload = PushNotificationPayload.tryParse({
      ...base, 'target': 'note', 'noteId': 'note-1',
    });
    expect(payload, isNotNull);
    expect(payload!.host, 'misskey.example');
    expect(payload.target, PushNotificationTarget.note);
    expect(payload.noteId, 'note-1');
  });

  test('preserves a non-default HTTPS port', () {
    final payload = PushNotificationPayload.tryParse({
      ...base,
      'host': 'https://Misskey.example:8443',
      'target': 'notifications',
    });
    expect(payload?.host, 'misskey.example:8443');
  });

  test('parses user and chat targets', () {
    final user = PushNotificationPayload.tryParse({
      ...base, 'target': 'user', 'userId': 'user-1',
    });
    final chat = PushNotificationPayload.tryParse({
      ...base, 'target': 'chat', 'chatId': 'room:chat-1',
    });
    expect(user?.userId, 'user-1');
    expect(chat?.chatId, 'room:chat-1');
  });

  test('parses a direct-message chat target', () {
    final payload = PushNotificationPayload.tryParse({
      ...base, 'target': 'chat', 'chatId': 'user:user-1',
    });
    expect(payload?.chatId, 'user:user-1');
  });

  test('rejects chat targets without an explicit route prefix', () {
    expect(PushNotificationPayload.tryParse({
      ...base, 'target': 'chat', 'chatId': 'unqualified-id',
    }), isNull);
    expect(PushNotificationPayload.tryParse({
      ...base, 'target': 'chat', 'chatId': 'room:',
    }), isNull);
  });

  test('supports opening the in-app notification list', () {
    final payload = PushNotificationPayload.tryParse({
      ...base, 'target': 'notifications',
    });
    expect(payload?.target, PushNotificationTarget.notifications);
  });

  test('rejects unsupported versions and target names', () {
    expect(PushNotificationPayload.tryParse({
      ...base, 'v': '2', 'target': 'note', 'noteId': 'note-1',
    }), isNull);
    expect(PushNotificationPayload.tryParse({
      ...base, 'target': 'javascript', 'noteId': 'note-1',
    }), isNull);
  });

  test('rejects missing target identifiers', () {
    for (final target in ['note', 'user', 'chat']) {
      expect(PushNotificationPayload.tryParse({
        ...base, 'target': target,
      }), isNull);
    }
  });

  test('rejects malformed, insecure and arbitrary hosts', () {
    for (final host in [
      'http://example.test',
      'https://user:password@example.test',
      'https://example.test/path',
      'https://example.test/?token=secret',
      'ftp://example.test',
      'javascript://example.test',
      'not a host',
    ]) {
      expect(PushNotificationPayload.tryParse({
        ...base, 'host': host, 'target': 'notifications',
      }), isNull, reason: 'host=' + host);
    }
  });

  test('rejects incomplete payloads', () {
    expect(PushNotificationPayload.tryParse({
      'v': '1', 'eventId': 'evt-123', 'target': 'notifications',
    }), isNull);
    expect(PushNotificationPayload.tryParse({
      ...base, 'target': 'notifications', 'eventId': '',
    }), isNull);
  });
}
