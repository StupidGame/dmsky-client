import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:misskey_dart/misskey_dart.dart';

import '../../model/account.dart';
import '../../providers.dart';
import '../../rust/api/aiscript.dart';
import '../../rust/api/aiscript/ui.dart';
import '../../rust/frb_generated.dart';
import '../../util/create_aiscript.dart';
import '../aiscript/as_ui_widget.dart';
import '../common/misskey_notes/mfm_text.dart';
import '../common/account_scope.dart';
import '../explore_page/explore_plays.dart';

bool isPlayUri(Uri uri) =>
    (uri.scheme == 'https' || uri.scheme == 'http') &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty &&
    (uri.pathSegments.length == 1 || uri.pathSegments.length == 2) &&
    uri.pathSegments.first == 'play' &&
    (uri.pathSegments.length == 1 || uri.pathSegments[1].isNotEmpty);

Uri playServer(Account account) => Uri(
  scheme: account.scheme ?? 'https',
  host: account.host,
  port: account.port,
);

Account accountForPlay(Uri uri, Account source, Iterable<Account> accounts) {
  if (!isPlayUri(uri)) throw ArgumentError.value(uri, 'uri');
  if (playServer(source).origin == uri.origin) return source;
  for (final account in accounts) {
    if (playServer(account).origin == uri.origin) return account;
  }
  return Account.demoAccount(
    uri.host,
    null,
    scheme: uri.scheme,
    port: uri.hasPort ? uri.port : null,
  );
}

Future<void> openPlay(
  BuildContext context,
  Uri uri, {
  required Account account,
  String? title,
}) async {
  if (!isPlayUri(uri) || uri.origin != playServer(account).origin) {
    throw ArgumentError.value(
      uri,
      'uri',
      'Play URL must match its account origin',
    );
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => AccountContextScope.as(
        account: account,
        child: uri.pathSegments.length == 2
            ? PlayPage(account: account, playId: uri.pathSegments[1])
            : Scaffold(
                appBar: AppBar(title: const Text('Play')),
                body: const ExplorePlay(),
              ),
      ),
    ),
  );
}

/// Fetches the script with the app account and renders its UI with Flutter.
class PlayPage extends ConsumerStatefulWidget {
  const PlayPage({required this.account, required this.playId, super.key});
  final Account account;
  final String playId;

  @override
  ConsumerState<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends ConsumerState<PlayPage> {
  late Future<Flash> _play;
  final _components = ValueNotifier<Map<String, AsUiComponent>>({});
  final _scroll = ScrollController();
  AiScript? _script;
  int _generation = 0;
  bool _started = false;
  bool _executing = false;
  String? _error;
  String? _output;
  static Future<void>? _initializing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _play = ref
        .read(misskeyProvider(widget.account))
        .flash
        .show(FlashShowRequest(flashId: widget.playId));
  }

  Future<void> _release(AiScript? script) async {
    if (script == null) return;
    try {
      await script.abort();
    } finally {
      script.dispose();
    }
  }

  Future<void> _stop() async {
    ++_generation;
    final script = _script;
    _script = null;
    if (mounted) {
      setState(() {
        _started = false;
        _executing = false;
      });
    }
    try {
      await _release(script);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    ++_generation;
    unawaited(_release(_script).catchError((Object _) {}));
    _components.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _execute(Flash play) async {
    if (_executing || _started) return;
    final generation = ++_generation;
    bool active() => mounted && generation == _generation;
    setState(() {
      _started = true;
      _executing = true;
      _error = null;
      _output = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _components.value = {};
    try {
      if (!RustLib.instance.initialized) {
        try {
          await (_initializing ??= RustLib.init());
        } finally {
          _initializing = null;
        }
      }
      if (!active()) return;
      final script = await createAiScript(
        ref,
        account: widget.account,
        storageKey: play.id,
        url: playServer(
          widget.account,
        ).replace(pathSegments: ['play', play.id]),
        playId: play.id,
        components: _components,
        isActive: active,
        write: (message) {
          if (active()) setState(() => _output = message);
        },
      );
      if (!active()) {
        await _release(script);
        return;
      }
      _script = script;
      await script.exec(
        input: play.script,
        isLegacy: play.updatedAt.isBefore(DateTime.utc(2025, 8, 8))
            ? true
            : play.updatedAt.isBefore(DateTime.utc(2025, 11, 23))
            ? null
            : false,
      );
    } catch (error) {
      if (active()) {
        final script = _script;
        _script = null;
        try {
          await _release(script);
        } catch (_) {}
        if (active()) {
          setState(() {
            _error = 'Playを実行できませんでした: $error';
            _started = false;
          });
        }
      }
    } finally {
      if (active()) setState(() => _executing = false);
    }
  }

  Future<void> _back() async {
    if (_started) {
      final end = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Playを終了'),
          content: const Text('実行中のPlayを終了しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('続ける'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('終了'),
            ),
          ],
        ),
      );
      if (end != true || !mounted) return;
      await _stop();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: !_started,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_back());
    },
    child: FutureBuilder<Flash>(
      future: _play,
      builder: (context, snapshot) {
        final play = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: _back),
            title: MfmText(
              mfmText: play?.title ?? 'Play',
              maxLines: 1,
              isEnableAnimatedMFM: false,
            ),
            actions: [
              IconButton(
                tooltip: 'リンクをコピー',
                icon: const Icon(Icons.link),
                onPressed: () => Clipboard.setData(
                  ClipboardData(
                    text: playServer(
                      widget.account,
                    ).replace(pathSegments: ['play', widget.playId]).toString(),
                  ),
                ),
              ),
            ],
          ),
          body: snapshot.hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Playを読み込めませんでした'),
                      FilledButton(
                        onPressed: () => setState(_load),
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : play == null
              ? const Center(child: CircularProgressIndicator.adaptive())
              : ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (!_started) ...[
                      MfmText(
                        mfmText: play.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      MfmText(mfmText: play.summary),
                      const SizedBox(height: 8),
                      Text(
                        '@${widget.account.i.username}@${widget.account.host}',
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (_started) ...[
                      ValueListenableBuilder<Map<String, AsUiComponent>>(
                        valueListenable: _components,
                        builder: (_, components, _) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: switch (components["___root___"]) {
                              AsUiComponent_Root(field0: final root)
                                  when root.children.isNotEmpty =>
                                AsUiWidget(
                                  account: widget.account,
                                  components: components,
                                  onError: (error) {
                                    if (!mounted) return;
                                    setState(() => _error = error.toString());
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Playの操作に失敗しました。エラー表示を確認してください。',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              _ => Column(
                                children: [
                                  if (_executing)
                                    const CircularProgressIndicator.adaptive(),
                                  const SizedBox(height: 12),
                                  Text(
                                    _executing
                                        ? 'Playを準備しています…'
                                        : 'このPlayはまだ画面を出力していません',
                                  ),
                                ],
                              ),
                            },
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _stop,
                        icon: const Icon(Icons.stop),
                        label: const Text('終了'),
                      ),
                    ] else
                      FilledButton.icon(
                        onPressed: kIsWeb ? null : () => _execute(play),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('プレイ'),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: SelectableText(_error!),
                      ),
                    if (_output != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: SelectableText(_output!),
                      ),
                    if (kIsWeb)
                      const Text('Playの実行はAndroid・iOS・デスクトップ版に対応しています'),
                    const SizedBox(height: 16),
                    ExpansionTile(
                      title: const Text('スクリプトソース'),
                      children: [SelectableText(play.script)],
                    ),
                  ],
                ),
        );
      },
    ),
  );
}
