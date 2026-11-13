import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:mfm/mfm.dart";
import "package:dmsky_client/view/common/account_scope.dart";
import "package:dmsky_client/view/common/dialog/dialog_state.dart";

class DialogScope extends ConsumerWidget {
  final Widget child;

  const DialogScope({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dialogs = ref.watch(
      dialogStateProvider.select((value) => value.dialogs),
    );

    return Stack(
      children: [
        child,
        if (dialogs.isNotEmpty)
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(color: Color.fromRGBO(0, 0, 0, .3)),
              child: SizedBox.shrink(),
            ),
          ),
        for (final dialog in dialogs)
          PopScope(
            onPopInvokedWithResult: (didPop, result) async => ref
                .read(dialogStateProvider.notifier)
                .completeDialog(dialog, null),
            child: AlertDialog.adaptive(
              content: dialog.isMFM
                  ? AccountContextScope(
                      context: dialog.accountContext!,
                      child: Mfm(mfmText: dialog.message(context)),
                    )
                  : Text(dialog.message(context)),
              actions: [
                for (final action in dialog.actions(context).indexed)
                  TextButton(
                    onPressed: () => ref
                        .read(dialogStateProvider.notifier)
                        .completeDialog(dialog, action.$1),
                    child: Text(action.$2),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
