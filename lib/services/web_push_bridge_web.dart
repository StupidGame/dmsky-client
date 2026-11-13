import 'dart:js_interop';

@JS('dmskyShowForegroundPush')
external void _showWebForegroundPush(
  JSString title,
  JSString body,
  JSString payloadJson,
);

void showForegroundPush(
  String title,
  String body,
  String payloadJson,
) {
  _showWebForegroundPush(title.toJS, body.toJS, payloadJson.toJS);
}
