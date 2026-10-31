import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/view/channels_page/community_channel_view.dart";
import "package:dmsky_client/view/common/futable_list_builder.dart";
import "package:misskey_dart/misskey_dart.dart";

class ChannelTrend extends ConsumerWidget {
  const ChannelTrend({super.key, this.onChannelSelected});

  final void Function(CommunityChannel channel)? onChannelSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureListView(
      future: ref.read(misskeyGetContextProvider).channels.featured(),
      builder: (context, item) => CommunityChannelView(
        channel: item,
        onTap: onChannelSelected != null
            ? () => onChannelSelected?.call(item)
            : null,
      ),
    );
  }
}
