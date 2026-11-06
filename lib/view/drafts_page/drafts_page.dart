import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/l10n/app_localizations.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/repository/note_draft_repository.dart";
import "package:dmsky_client/router/app_router.dart";
import "package:dmsky_client/view/common/account_scope.dart";
import "package:dmsky_client/view/common/error_detail.dart";
import "package:dmsky_client/view/drafts_page/note_draft_item.dart";
import "package:misskey_dart/misskey_dart.dart";

@RoutePage()
class DraftsPage extends ConsumerWidget implements AutoRouteWrapper {
  final AccountContext accountContext;

  const DraftsPage({required this.accountContext, super.key});

  @override
  Widget wrappedRoute(BuildContext context) =>
      AccountContextScope(context: accountContext, child: this);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(S.of(context).drafts),
          bottom: const TabBar(
            tabs: [
              Tab(text: "下書き"),
              Tab(text: "予約投稿"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DraftsListView(),
            _ScheduledDraftsListView(),
          ],
        ),
      ),
    );
  }
}

class _DraftsListView extends ConsumerWidget {
  const _DraftsListView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftRepository = ref.watch(noteDraftRepositoryProvider.notifier);

    return FutureBuilder<List<NoteDraft>>(
      future: draftRepository.list(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        if (snapshot.hasError) {
          return Center(
            child: ErrorDetail(
              error: snapshot.error,
              stackTrace: snapshot.stackTrace,
            ),
          );
        }

        final drafts = snapshot.data ?? [];

        if (drafts.isEmpty) {
          return Center(
            child: Text(
              "下書きがありません",
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await draftRepository.list();
          },
          child: ListView.builder(
            itemCount: drafts.length,
            itemBuilder: (context, index) {
              final draft = drafts[index];
              return NoteDraftItem(
                draft: draft,
                onTap: () {
                  context.pushRoute(
                    NoteCreateRoute(
                      initialAccount: ref
                          .read(accountContextProvider)
                          .postAccount,
                      draftId: draft.id,
                    ),
                  );
                },
                onDelete: () async {
                  await draftRepository.delete(draft.id);
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _ScheduledDraftsListView extends HookConsumerWidget {
  const _ScheduledDraftsListView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refreshVersion = useState(0);
    final misskey = ref.watch(misskeyGetContextProvider);
    final scheduledNotes = useMemoized(
      () => misskey.notes.drafts.list(
        const NotesDraftsListRequest(limit: 100, scheduled: true),
      ),
      [misskey, refreshVersion.value],
    );

    Future<void> refresh() async {
      await misskey.notes.drafts.list(
        const NotesDraftsListRequest(limit: 100, scheduled: true),
      );
      refreshVersion.value++;
    }

    return FutureBuilder<Iterable<NoteDraft>>(
      future: scheduledNotes,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorDetail(
                error: snapshot.error,
                stackTrace: snapshot.stackTrace,
              ),
            ),
          );
        }

        final drafts = snapshot.data?.toList() ?? const <NoteDraft>[];
        if (drafts.isEmpty) {
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 180),
                Center(child: Text("予約投稿はありません")),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: drafts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final draft = drafts[index];
              final scheduledAt = draft.scheduledAt?.toLocal();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              scheduledAt == null
                                  ? "投稿予定日時が未設定"
                                  : "投稿予定: ${scheduledAt.toString()}",
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: "予約投稿の操作",
                            onSelected: (action) async {
                              try {
                                if (action == "cancel") {
                                  await misskey.apiService.post<void>(
                                    "notes/drafts/update",
                                    {
                                      "draftId": draft.id,
                                      "scheduledAt": null,
                                      "isActuallyScheduled": false,
                                    },
                                  );
                                } else if (action == "delete") {
                                  await misskey.notes.drafts.delete(
                                    NotesDraftsDeleteRequest(
                                      draftId: draft.id,
                                    ),
                                  );
                                }
                                await refresh();
                              } catch (error) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("操作に失敗しました: $error"),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: "cancel",
                                child: ListTile(
                                  leading: Icon(Icons.cancel_schedule_send),
                                  title: Text("予約を取り消す"),
                                ),
                              ),
                              PopupMenuItem(
                                value: "delete",
                                child: ListTile(
                                  leading: Icon(Icons.delete_outline),
                                  title: Text("削除"),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if ((draft.text ?? "").trim().isNotEmpty)
                        SelectableText(draft.text!),
                      if (draft.cw?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text("CW: ${draft.cw}"),
                        ),
                      if (draft.files?.isNotEmpty == true)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text("添付ファイル: ${draft.files!.length}件"),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
