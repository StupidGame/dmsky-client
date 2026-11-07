import "dart:async";
import "dart:convert";

import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:misskey_dart/misskey_dart.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../model/account.dart";
import "../model/misskey_emoji_data.dart";
import "../providers.dart";
import "../repository/emoji_repository.dart";
import "../rust/api/aiscript.dart";
import "../rust/api/aiscript/api.dart";
import "../rust/api/aiscript/play.dart";
import "../rust/api/aiscript/ui.dart";

Future<AiScript> createAiScript(
  WidgetRef ref, {
  required Account account,
  String? host,
  FutureOr<void> Function(String value)? write,
  String? token,
  required String storageKey,
  required Uri url,
  ValueNotifier<Map<String, AsUiComponent>>? components,
  String? playId,
}) async {
  final context = ref.context;
  final locale = Localizations.localeOf(context).toLanguageTag();
  final serverUrl = _accountServerUrl(account);
  final emojiRepository = ref.read(emojiRepositoryProvider(account));
  var customEmojis = <Map<String, dynamic>>[];
  try {
    await emojiRepository.loadFromSourceIfNeed();
    customEmojis = (emojiRepository.emoji ?? const <EmojiRepositoryData>[])
        .map((entry) => entry.emoji)
        .whereType<CustomEmojiData>()
        .map(
          (emoji) => <String, dynamic>{
            "name": emoji.baseName,
            "url": emoji.url.toString(),
            "isSensitive": emoji.isSensitive,
            "category": null,
            "aliases": <String>[],
          },
        )
        .toList();
  } catch (_) {}

  if (components != null) components.value = {};
  final updateCounts = <String, int>{};
  final storagePrefix = "dmsky.ai." + account.host + "." +
      account.userId + "." + storageKey;

  Future<void> save(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("$storagePrefix:$key", value);
  }

  Future<String> load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("$storagePrefix:$key") ?? "";
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("$storagePrefix:$key");
  }

  return AiScript.newInstance(
    read: (prompt) async {
      final controller = TextEditingController();
      final value = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(prompt),
          content: TextField(
            controller: controller,
            autofocus: true,
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("キャンセル"),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text),
              child: const Text("送信"),
            ),
          ],
        ),
      );
      controller.dispose();
      return value ?? "";
    },
    write: write ?? (_) {},
    api: AsApiLib(
      userId: account.i.id,
      userName: account.i.name,
      userUsername: account.i.username,
      customEmojis: jsonEncode(customEmojis),
      locale: locale,
      serverUrl: serverUrl.toString(),
      dialog: (title, text, type) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: SelectableText(text)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("閉じる"),
            ),
          ],
        ),
      ),
      confirm: (title, text, type) async {
        return await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(title),
                content: SelectableText(text),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(dialogContext).pop(false),
                    child: const Text("キャンセル"),
                  ),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(dialogContext).pop(true),
                    child: const Text("続行"),
                  ),
                ],
              ),
            ) ??
            false;
      },
      toast: (message) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      token: token ?? account.token,
      api: (endpoint, param, apiToken) async {
        try {
          final decoded = param.trim().isEmpty
              ? <String, dynamic>{}
              : jsonDecode(param);
          final request = decoded is Map
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};
          final targetHost = host ?? account.host;
          final client = _misskeyForHost(
            targetHost,
            targetHost == account.host ? (apiToken ?? account.token) : apiToken,
            scheme: targetHost == account.host ? account.scheme : null,
            port: targetHost == account.host ? account.port : null,
          );
          final response = await client.apiService.post<dynamic>(
            endpoint,
            request,
          );
          return (jsonEncode(response), null);
        } catch (error) {
          return ("", _encodeError(error));
        }
      },
      save: save,
      load: load,
      remove: remove,
      url: url.toString(),
      nyaize: _nyaize,
    ),
    ui: components == null
        ? null
        : AsUiLib(
            onUpdate: (id, component, updateCount) {
              final previous = updateCounts[id];
              if (previous != null && updateCount < previous) return;
              updateCounts[id] = updateCount;
              components.value = {...components.value, id: component};
            },
          ),
    play: playId == null
        ? null
        : AsPlayLib(thisId: playId, thisUrl: url.toString()),
  );
}

Uri _accountServerUrl(Account account) => Uri(
  scheme: account.scheme ?? "https",
  host: account.host,
  port: account.port,
);

Misskey _misskeyForHost(
  String host,
  String? token, {
  String? scheme,
  int? port,
}) {
  final normalized = Uri.parse(
    host.startsWith("http") ? host : (scheme ?? "https") + "://" + host,
  );
  final resolvedPort = port ?? (normalized.hasPort ? normalized.port : null);
  final hostWithPort = resolvedPort == null
      ? normalized.host
      : normalized.host + ":" + resolvedPort.toString();
  final apiUrl = normalized.scheme == "http"
      ? "http://$hostWithPort/api/"
      : null;
  final streamingUrl = normalized.scheme == "http"
      ? "ws://$hostWithPort/streaming/"
      : null;
  return Misskey(
    host: hostWithPort,
    token: token,
    apiUrl: apiUrl,
    streamingUrl: streamingUrl,
  );
}

String _encodeError(Object error) {
  try {
    return jsonEncode(error);
  } catch (_) {
    return jsonEncode({"message": error.toString()});
  }
}

String _nyaize(String value) {
  final enRegex1 = RegExp(r"(?<=n)a", caseSensitive: false);
  final enRegex2 = RegExp(r"(?<=morn)ing", caseSensitive: false);
  final enRegex3 = RegExp(r"(?<=every)one", caseSensitive: false);
  final koRegex1 = RegExp("[나-낳]");
  final koRegex2 = RegExp(
    r"(다$)|(다(?=\.))|(다(?= ))|(다(?=!))|(다(?=\?))",
    multiLine: true,
  );
  final koRegex3 = RegExp(r"(야(?=\?))|(야$)|(야(?= ))", multiLine: true);
  return value
      .replaceAll("な", "にゃ")
      .replaceAll("ナ", "ニャ")
      .replaceAll("ﾅ", "ﾆｬ")
      .replaceAllMapped(enRegex1, (match) => match[0] == "A" ? "YA" : "ya")
      .replaceAllMapped(enRegex2, (match) => match[0] == "ING" ? "YAN" : "yan")
      .replaceAllMapped(enRegex3, (match) => match[0] == "ONE" ? "NYAN" : "nyan")
      .replaceAllMapped(
        koRegex1,
        (match) => String.fromCharCode(
          match[0]!.codeUnitAt(0) + "냐".codeUnitAt(0) - "나".codeUnitAt(0),
        ),
      )
      .replaceAll(koRegex2, "다냥")
      .replaceAll(koRegex3, "냥");
}
