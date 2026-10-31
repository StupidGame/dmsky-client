import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/model/misskey_emoji_data.dart";
import "package:dmsky_client/model/tab_icon.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/view/common/misskey_notes/custom_emoji.dart";

class TabIconView extends ConsumerWidget {
  final TabIcon? icon;
  final Color? color;
  final double? size;

  const TabIconView({required this.icon, super.key, this.color, this.size});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codePoint = icon?.codePoint;
    final iconSize = size ?? IconTheme.of(context).size;
    if (codePoint != null) {
      return Icon(
        // User-defined icons require --no-tree-shake-icons in release builds.
        // ignore: non_const_argument_for_const_parameter
        IconData(codePoint, fontFamily: "MaterialIcons"),
        color: color,
        size: iconSize,
      );
    }
    final customEmoji = icon?.customEmojiName;
    if (customEmoji != null) {
      return CustomEmoji(
        emojiData: MisskeyEmojiData.fromEmojiName(
          emojiName: ":$customEmoji:",
          repository: ref.read(
            emojiRepositoryProvider(
              ref.read(accountContextProvider).getAccount,
            ),
          ),
        ),
        size: iconSize,
        forceSquare: true,
      );
    }
    return const SizedBox.shrink();
  }
}
