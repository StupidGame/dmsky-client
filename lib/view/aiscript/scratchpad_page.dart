import "dart:async";

import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/model/account.dart";
import "package:dmsky_client/rust/api/aiscript.dart";
import "package:dmsky_client/rust/api/aiscript/ui.dart";
import "package:dmsky_client/rust/frb_generated.dart";
import "package:dmsky_client/util/create_aiscript.dart";
import "package:dmsky_client/view/aiscript/as_ui_widget.dart";

class ScratchpadPage extends HookConsumerWidget {
  const ScratchpadPage({required this.account, super.key});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = useTextEditingController(
      text: '// Misskey AiScript v1 を試せます\nlet greeting = Ui:C:text({text: "Hello, AiScript!"})\nUi:render([greeting])',
    );
    final editorKey =
        "dmsky.ai.scratchpad.${account.host}.${account.userId}.source";
    final restored = useState(false);
    final preferences = useMemoized(SharedPreferences.getInstance);
    final saveTimer = useRef<Timer?>(null);

    useEffect(() {
      Future<void> restore() async {
        final prefs = await preferences;
        final saved = prefs.getString(editorKey);
        if (saved != null && context.mounted) code.text = saved;
        restored.value = true;
      }

      restore();
      return () {
        saveTimer.value?.cancel();
        if (restored.value) {
          unawaited(
            preferences.then((prefs) async {
              await prefs.setString(editorKey, code.text);
            }),
          );
        }
      };
    }, [editorKey]);
    final running = useState(false);
    final logs = useState<List<String>>([]);
    final components = useValueNotifier<Map<String, AsUiComponent>>({});
    final currentScript = useState<AiScript?>(null);

    void appendLog(String message) {
      if (!context.mounted) return;
      final next = [...logs.value, message];
      if (next.length > 200) {
        next.removeRange(0, next.length - 200);
      }
      logs.value = next;
    }

    Future<void> stop() async {
      try {
        await currentScript.value?.abort();
      } catch (_) {}
      if (context.mounted) running.value = false;
    }

    Future<void> execute() async {
      if (running.value) return;
      running.value = true;
      logs.value = [];
      components.value = {};
      try {
        if (!RustLib.instance.initialized) await RustLib.init();
        final serverUrl = Uri(
          scheme: account.scheme ?? "https",
          host: account.host,
          port: account.port,
        );
        final script = await createAiScript(
          ref,
          account: account,
          host: account.host,
          token: account.token,
          storageKey: "scratchpad",
          url: serverUrl.replace(pathSegments: ["scratchpad"]),
          components: components,
          write: appendLog,
        );
        currentScript.value = script;
        final result = await script.exec(input: code.text, isLegacy: false);
        if (context.mounted && result.isNotEmpty) {
          appendLog(result);
        }
      } catch (error, stack) {
        appendLog("$error\n$stack");
      } finally {
        if (context.mounted) {
          currentScript.value = null;
          running.value = false;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("AiScript スクラッチパッド"),
        actions: [
          IconButton(
            tooltip: "停止",
            onPressed: running.value ? stop : null,
            icon: const Icon(Icons.stop_circle_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: code,
            onChanged: (value) {
              if (!restored.value) return;
              saveTimer.value?.cancel();
              saveTimer.value = Timer(const Duration(milliseconds: 350), () async {
                final prefs = await preferences;
                await prefs.setString(editorKey, value);
              });
            },
            minLines: 8,
            maxLines: 24,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontFamily: "monospace", fontSize: 13),
            decoration: const InputDecoration(
              labelText: "AiScript",
              hintText: "// Write your script",
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: running.value ? null : execute,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("実行"),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: running.value ? stop : null,
                icon: const Icon(Icons.stop),
                label: const Text("停止"),
              ),
            ],
          ),
          if (components.value.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text("UI", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: AsUiWidget(
                  account: account,
                  components: components.value,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text("出力", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: logs.value.isEmpty
                  ? const Text("実行結果はここに表示されます")
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final log in logs.value)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: SelectableText(log),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
