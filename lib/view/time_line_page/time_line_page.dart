import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/model/general_settings.dart";
import "package:dmsky_client/model/tab_setting.dart";
import "package:dmsky_client/model/tab_type.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/repository/socket_timeline_repository.dart";
import "package:dmsky_client/router/app_router.dart";
import "package:dmsky_client/view/common/account_scope.dart";
import "package:dmsky_client/view/common/common_drawer.dart";
import "package:dmsky_client/view/common/dialog/dialog_state.dart";
import "package:dmsky_client/view/common/error_detail.dart";
import "package:dmsky_client/view/common/notification_icon.dart";
import "package:dmsky_client/view/common/timeline_listview.dart";
import "package:dmsky_client/view/themes/dmsky_circuit.dart";
import "package:dmsky_client/view/time_line_page/misskey_time_line.dart";
import "package:dmsky_client/view/time_line_page/nyanpuppu.dart";
import "package:dmsky_client/view/time_line_page/timeline_emoji.dart";
import "package:dmsky_client/view/time_line_page/timeline_note.dart";
import "package:dmsky_client/view/time_line_page/timeline_announcements.dart";
import "package:dmsky_client/view/time_line_page/timeline_layout.dart";
import "package:dmsky_client/view/time_line_page/timeline_tablet_ui.dart";
import "package:dmsky_client/view/time_line_page/timeline_tab_button.dart";
import "package:misskey_dart/misskey_dart.dart";

@RoutePage()
class TimeLinePage extends ConsumerStatefulWidget {
  final TabSetting initialTabSetting;

  const TimeLinePage({required this.initialTabSetting, super.key});

  @override
  ConsumerState<TimeLinePage> createState() => TimeLinePageState();
}

class TimeLinePageState extends ConsumerState<TimeLinePage> {
  late List<TabSetting> tabSettings;
  late int currentIndex;
  late final PageController pageController;
  late final List<TimelineScrollController> scrollControllers;

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();

  @override
  void initState() {
    tabSettings = ref.read(
      tabSettingsRepositoryProvider.select((repo) => repo.tabSettings.toList()),
    );
    currentIndex = tabSettings.indexOf(widget.initialTabSetting);
    pageController = PageController(initialPage: currentIndex);
    scrollControllers = List.generate(
      tabSettings.length,
      (_) => TimelineScrollController(),
    );
    super.initState();
  }

  @override
  void dispose() {
    pageController.dispose();
    for (final controller in scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  TabSetting get currentTabSetting {
    return tabSettings[currentIndex];
  }

  Future<void> note() async {
    final text = ref.read(timelineNoteProvider).value.text;
    if (text.isEmpty) return;
    try {
      final accountSettings = ref
          .read(accountSettingsRepositoryProvider)
          .fromAcct(currentTabSetting.acct);
      ref.read(timelineNoteProvider).clear();
      FocusManager.instance.primaryFocus?.unfocus();

      final account = ref.read(accountProvider(currentTabSetting.acct));
      await ref
          .read(misskeyProvider(account))
          .notes
          .create(
            NotesCreateRequest(
              text: text,
              channelId: currentTabSetting.channelId,
              visibility: accountSettings.defaultNoteVisibility,
              localOnly:
                  currentTabSetting.channelId != null ||
                  accountSettings.defaultIsLocalOnly,
              reactionAcceptance: accountSettings.defaultReactionAcceptance,
            ),
          );
    } catch (e) {
      ref.read(timelineNoteProvider).text = text;
      rethrow;
    }
  }

  void reload() {
    ref.read(timelineProvider(currentTabSetting)).moveToOlder();
    scrollControllers[currentIndex].forceScrollToTop();
  }

  void changeTab(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  Future<void> noteCreateRoute() async {
    CommunityChannel? channel;
    if (currentTabSetting.channelId != null) {
      final Note? note;
      final timeline = ref.read(timelineProvider(currentTabSetting));
      if (timeline.olderNotes.isNotEmpty) {
        note = timeline.olderNotes.first;
      } else if (timeline.newerNotes.isNotEmpty) {
        note = timeline.newerNotes.first;
      } else {
        //TODO: チャンネルにノートがないとき
        note = null;
      }
      final noteChannel = note?.channel;

      if (noteChannel != null) {
        channel = CommunityChannel(
          id: noteChannel.id,
          createdAt: DateTime.now(),
          name: noteChannel.name,
          pinnedNoteIds: [],
          usersCount: 0,
          notesCount: 0,
          isFollowing: false,
          isFavorited: false,
          hasUnreadNote: false,
          pinnedNotes: [],
        );
      }
    }
    final sendText = ref.read(timelineNoteProvider).text;
    ref.read(timelineNoteProvider).text = "";
    final account = ref.read(accountProvider(currentTabSetting.acct));
    await context.pushRoute(
      NoteCreateRoute(
        channel: channel,
        initialText: sendText,
        initialAccount: account,
      ),
    );
  }

  Widget buildAppbar(WidgetRef ref) {
    final account = ref.watch(accountProvider(currentTabSetting.acct));
    final toolbarHeight = MediaQuery.textScalerOf(context).scale(32) + 32;
    // This toolbar lives inside a Column, which does not constrain its height.
    // Bound the flexible background before it can expand to an infinite size.
    return SizedBox(
      height: toolbarHeight,
      child: AppBar(
        primary: false,
        toolbarHeight: toolbarHeight,
        flexibleSpace: const DmskyPanel(child: SizedBox.expand()),
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: tabSettings.mapIndexed((index, tabSetting) {
              final account = ref.watch(accountProvider(tabSetting.acct));
              return AccountContextScope.as(
                account: account,
                child: TimelineTabButton(
                  tabSetting: tabSetting,
                  active: tabSetting == currentTabSetting,
                  onPressed: () => tabSetting == currentTabSetting
                      ? reload()
                      : pageController.jumpToPage(index),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          AccountContextScope.as(
            account: account,
            child: const NotificationIcon(),
          ),
        ],
        leading: IconButton(
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
          icon: const Icon(Icons.menu),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deckMode = ref.watch(
      generalSettingsRepositoryProvider.select(
        (value) => value.settings.isDeckMode,
      ),
    );
    return TimelineLayout(
      deckMode: deckMode,
      compactBuilder: (_) => Consumer(
        builder: (context, ref, _) => buildCompactTimeline(context, ref),
      ),
      deckBuilder: (_) => const TimelineTablet(),
    );
  }

  Widget buildCompactTimeline(BuildContext context, WidgetRef ref) {
    final tabPosition = ref.watch(
      generalSettingsRepositoryProvider.select(
        (value) => value.settings.tabPosition,
      ),
    );

    final timelineRepository = ref.watch(timelineProvider(currentTabSetting));
    final socketTimeline = timelineRepository is SocketTimelineRepository
        ? timelineRepository
        : null;
    tabSettings = ref.watch(
      tabSettingsRepositoryProvider.select((repo) => repo.tabSettings.toList()),
    );
    final account = ref.watch(accountProvider(currentTabSetting.acct));

    return Scaffold(
      key: scaffoldKey,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: AppBar(automaticallyImplyLeading: false),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (tabPosition == TabPosition.top) buildAppbar(ref),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).primaryColor),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 5,
                        top: 5,
                        bottom: 5,
                      ),
                      child: TimelineTabLabel(tabSetting: currentTabSetting),
                    ),
                  ),
                  const Nyanpuppu(),
                  if (currentTabSetting.tabType == TabType.channel)
                    IconButton(
                      onPressed: () async {
                        await context.pushRoute(
                          ChannelDescriptionRoute(
                            account: account,
                            channelId: currentTabSetting.channelId ?? "",
                          ),
                        );
                      },
                      icon: const Icon(Icons.info_outline),
                    )
                  else if (currentTabSetting.tabType == TabType.userList)
                    IconButton(
                      icon: const Icon(Icons.info_outline),
                      onPressed: () async {
                        await context.pushRoute(
                          UsersListDetailRoute(
                            accountContext: AccountContext.as(account),
                            listId: currentTabSetting.listId!,
                          ),
                        );
                      },
                    )
                  else if ([
                    TabType.hybridTimeline,
                    TabType.localTimeline,
                    TabType.globalTimeline,
                    TabType.homeTimeline,
                  ].contains(currentTabSetting.tabType)) ...[
                    AnnouncementInfo(tabSetting: currentTabSetting),
                    IconButton(
                      onPressed: () async {
                        await context.pushRoute(
                          ServerDetailRoute(
                            accountContext: AccountContext.as(account),
                          ),
                        );
                      },
                      icon: const Icon(Icons.smart_toy_outlined),
                    ),
                  ],
                  const Padding(padding: EdgeInsets.only(right: 5)),
                  IconButton(
                    onPressed: () async => ref
                        .read(timelineProvider(currentTabSetting))
                        .reconnect(),
                    icon:
                        socketTimeline != null && socketTimeline.isReconnecting
                        ? const CircularProgressIndicator.adaptive()
                        : const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            if (socketTimeline?.isLoading == true)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
            if (socketTimeline?.error != null)
              ErrorDetail(
                error: socketTimeline?.error?.$1,
                stackTrace: socketTimeline?.error?.$2,
              ),
            Expanded(
              child: PageView.builder(
                controller: pageController,
                itemCount: tabSettings.length,
                onPageChanged: (index) => changeTab(index),
                itemBuilder: (_, index) {
                  final tabSetting = tabSettings[index];
                  final account = ref.watch(accountProvider(tabSetting.acct));
                  return AccountContextScope.as(
                    account: account,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        BannerArea(tabSetting: currentTabSetting),
                        Expanded(
                          child: MisskeyTimeline(
                            controller: scrollControllers[index],
                            tabSetting: tabSetting,
                          ),
                        ),
                        const TimelineEmoji(),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              child: Row(
                children: [
                  Expanded(
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent) {
                          if (event.logicalKey == LogicalKeyboardKey.enter &&
                              HardwareKeyboard.instance.isControlPressed) {
                            ref
                                .read(dialogStateProvider.notifier)
                                .guard(() => note());
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: const TimelineNoteField(),
                    ),
                  ),
                  IconButton(
                    onPressed: () => ref
                        .read(dialogStateProvider.notifier)
                        .guard(() => note()),
                    icon: const Icon(Icons.send),
                  ),
                  IconButton(
                    onPressed: noteCreateRoute,
                    icon: const Icon(Icons.edit_note),
                  ),
                ],
              ),
            ),
            if (tabPosition == TabPosition.bottom &&
                !ref.watch(timelineFocusNode).hasFocus)
              buildAppbar(ref),
          ],
        ),
      ),
      resizeToAvoidBottomInset: true,
      drawerEnableOpenDragGesture: true,
      drawer: CommonDrawer(initialOpenAcct: currentTabSetting.acct),
    );
  }
}
