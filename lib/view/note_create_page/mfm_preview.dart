import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/state_notifier/note_create_page/note_create_state_notifier.dart";
import "package:dmsky_client/view/common/misskey_notes/mfm_text.dart";

class MfmPreview extends ConsumerWidget {
  const MfmPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewText = ref.watch(
      noteCreateProvider.select((value) => value.text),
    );

    final replyTo = ref
        .watch(noteCreateProvider.select((value) => value.replyTo))
        .map((e) => "@${e.username}${e.host == null ? " " : "@${e.host}"} ")
        .join("");

    return Padding(
      padding: const EdgeInsets.all(5),
      child: MfmText(
        mfmText: "$replyTo$previewText",
        isNyaize: ref.read(accountContextProvider).postAccount.i.isCat,
      ),
    );
  }
}
