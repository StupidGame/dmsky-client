import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/model/tab_setting.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/router/app_router.dart";
import "package:misskey_dart/misskey_dart.dart";

class BannerArea extends ConsumerWidget {
  final TabSetting tabSetting;

  const BannerArea({required this.tabSetting, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannerAnnouncement = ref.watch(
      iProvider(
        tabSetting.acct,
      ).select((account) => account.unreadAnnouncements),
    );

    // ダイアログの実装が大変なので（状態管理とか）いったんバナーと一緒に扱う
    final bannerDatas = bannerAnnouncement.where(
      (element) =>
          element.display == AnnouncementDisplayType.banner ||
          element.display == AnnouncementDisplayType.dialog,
    );

    if (bannerDatas.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 10, top: 3, bottom: 3),
      decoration: BoxDecoration(color: Theme.of(context).primaryColor),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          for (final bannerData in bannerDatas)
            Row(
              children: [
                if (bannerData.icon != null)
                  AnnouncementIcon(iconType: bannerData.icon!),
                const Padding(padding: EdgeInsets.only(left: 10)),
                Expanded(
                  child: Text(
                    "${bannerData.title}　${bannerData.text.replaceAll("\n", "　")}",
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class AnnouncementInfo extends ConsumerWidget {
  final TabSetting tabSetting;

  const AnnouncementInfo({required this.tabSetting, super.key});

  Future<void> announcementsRoute(BuildContext context, WidgetRef ref) async {
    final account = ref.read(accountProvider(tabSetting.acct));
    await context.pushRoute(
      AnnouncementRoute(accountContext: AccountContext.as(account)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUnread = ref.watch(
      iProvider(
        tabSetting.acct,
      ).select((i) => i.unreadAnnouncements.isNotEmpty),
    );

    return IconButton(
      onPressed: () => announcementsRoute(context, ref),
      icon: hasUnread
          ? Stack(
              children: [
                const Icon(Icons.campaign),
                Transform.translate(
                  offset: const Offset(12, 12),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 1.5),
                      borderRadius: BorderRadius.circular(20),
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            )
          : const Icon(Icons.campaign),
    );
  }
}

class AnnouncementIcon extends StatelessWidget {
  final AnnouncementIconType iconType;

  const AnnouncementIcon({required this.iconType, super.key});

  @override
  Widget build(BuildContext context) {
    switch (iconType) {
      case AnnouncementIconType.info:
        return const Icon(Icons.info, color: Colors.white);
      case AnnouncementIconType.warning:
        return const Icon(Icons.warning, color: Colors.white);
      case AnnouncementIconType.error:
        return const Icon(Icons.error, color: Colors.white);
      case AnnouncementIconType.success:
        return const Icon(Icons.check, color: Colors.white);
    }
  }
}
