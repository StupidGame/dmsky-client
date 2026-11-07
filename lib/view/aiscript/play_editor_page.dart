import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:misskey_dart/misskey_dart.dart";

import "../../model/account.dart";
import "../../providers.dart";
import "../../rust/api/aiscript.dart";
import "../../rust/frb_generated.dart";

class PlayEditorPage extends HookConsumerWidget {
  const PlayEditorPage({required this.account, this.playId, super.key});

  final Account account;
  final String? playId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final misskey = ref.watch(misskeyProvider(account));
    final original = useMemoized(
      () => playId == null
          ? Future<Flash?>.value(null)
          : misskey.flash.show(FlashShowRequest(flashId: playId!)),
      [misskey, playId],
    );
    final loaded = useFuture(original);
    final title = useTextEditingController();
    final summary = useTextEditingController();
    final source = useTextEditingController();
    final visibility = useState<FlashVisibility>(FlashVisibility.public);
    final initialized = useState(false);
    final saving = useState(false);

    useEffect(() {
      final play = loaded.data;
      if (play != null && !initialized.value) {
        title.text = play.title;
        summary.text = play.summary;
        source.text = play.script;
        visibility.value = play.visibility ?? FlashVisibility.public;
        initialized.value = true;
      }
      if (playId == null && !initialized.value) {
        initialized.value = true;
      }
      return null;
    }, [loaded.data, playId]);

    Future<void> save() async {
      if (title.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("タイトルを入力してください")),
        );
        return;
      }
      saving.value = true;
      try {
        if (playId == null) {
          await misskey.flash.create(
            FlashCreateRequest(
              title: title.text.trim(),
              summary: summary.text,
              script: source.text,
              permissions: const [],
              visibility: visibility.value,
            ),
          );
        } else {
          await misskey.flash.update(
            FlashUpdateRequest(
              flashId: playId!,
              title: title.text.trim(),
              summary: summary.text,
              script: source.text,
              permissions: const [],
              visibility: visibility.value,
            ),
          );
        }
        if (!context.mounted) return;
        Navigator.of(context).pop();
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("保存に失敗しました: $error")),
        );
      } finally {
        saving.value = false;
      }
    }

    Future<void> delete() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Playを削除"),
          content: const Text("このPlayを削除しますか？"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("キャンセル"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("削除"),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      try {
        await misskey.flash.delete(FlashDeleteRequest(flashId: playId!));
        if (context.mounted) Navigator.of(context).pop();
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("削除に失敗しました: $error")),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(playId == null ? "Playを作成" : "Playを編集"),
        actions: [
          if (playId != null)
            IconButton(
              tooltip: "削除",
              onPressed: loaded.data == null ? null : delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: loaded.connectionState == ConnectionState.waiting
          ? const Center(child: CircularProgressIndicator.adaptive())
          : loaded.hasError
              ? Center(child: Text("Playの取得に失敗しました: ${loaded.error}"))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(
                        labelText: "タイトル",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: summary,
                      minLines: 2,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: "説明",
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<FlashVisibility>(
                      initialValue: visibility.value,
                      decoration: const InputDecoration(
                        labelText: "公開範囲",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: FlashVisibility.public,
                          child: Text("公開"),
                        ),
                        DropdownMenuItem(
                          value: FlashVisibility.private,
                          child: Text("非公開"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) visibility.value = value;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: source,
                      minLines: 12,
                      maxLines: null,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(fontFamily: "monospace"),
                      decoration: const InputDecoration(
                        labelText: "AiScript",
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: saving.value ? null : save,
                      icon: saving.value
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text("保存"),
                    ),
                  ],
                ),
    );
  }
}
