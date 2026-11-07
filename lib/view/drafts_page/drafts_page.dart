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

class _DraftsListView extends HookConsumerWidget {
  const _DraftsListView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revision = useState(0);
    final draftRepository = ref.watch(noteDraftRepositoryProvider.notifier);
    final draftsFuture = useMemoized(
      draftRepository.list,
      [draftRepository, revision.value],
    );

    Future<void> refresh() async {
      revision.value++;
      await Future<void>.value();
    }

    return FutureBuilder<List<NoteDraft>>(
      future: draftsFuture,
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
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 180),
                Center(
                  child: Text(
                    "下書きがありません",
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
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
                  await refresh();
                },
              );
            },
          ),
        );
      },
    );
  }
}

String _scheduledDateValue(Object? value) {
  if (value is DateTime) return value.toIso8601String();
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt()).toIso8601String();
  }
  if (value is String) return value;
  return DateTime.now().toIso8601String();
}

Map<String, dynamic> _asJsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

Future<List<NoteDraft>> _loadScheduledDrafts(Misskey misskey) async {
  final endpoints = await misskey.endpoints();

  if (endpoints.contains("notes/schedule/list")) {
    final response = await misskey.apiService.post<List>(
      "notes/schedule/list",
      const <String, dynamic>{},
    );
    return Future.wait(
      response.map((item) async {
        final schedule = _asJsonMap(item);
        final note = _asJsonMap(schedule["note"]);
        final fileIds = (note["fileIds"] as List? ?? const [])
            .whereType<String>()
            .toList();
        final files = <DriveFile>[];
        for (final fileId in fileIds) {
          try {
            files.add(
              await misskey.drive.files.show(
                DriveFilesShowRequest(fileId: fileId),
              ),
            );
          } catch (_) {
            // A missing or inaccessible file must not hide the scheduled note.
          }
        }
        final user = note["user"] is Map
            ? _asJsonMap(note["user"])
            : (await misskey.i.i()).toJson();
        final visibleUsers = note["visibleUsers"] as List? ?? const [];
        final visibleUserIds = visibleUsers
            .map((item) => item is Map ? _asJsonMap(item)["id"] : item)
            .whereType<String>()
            .toList();
        return NoteDraft.fromJson({
          "id": schedule["id"] as String,
          "createdAt": _scheduledDateValue(
            schedule["createdAt"] ?? schedule["scheduledAt"],
          ),
          "text": note["text"],
          "cw": note["cw"],
          "userId": schedule["userId"] ?? note["userId"] ?? user["id"],
          "user": user,
          "replyId": note["replyId"],
          "renoteId": note["renoteId"],
          "visibility": note["visibility"] ?? "public",
          "visibleUserIds": visibleUserIds,
          "fileIds": fileIds,
          "files": files.map((file) => file.toJson()).toList(),
          "localOnly": note["localOnly"],
          "reactionAcceptance": note["reactionAcceptance"],
          "scheduledAt": _scheduledDateValue(schedule["scheduledAt"]),
          "isActuallyScheduled": true,
        });
      }),
    );
  }

  if (endpoints.contains("notes/scheduled/list")) {
    final response = await misskey.apiService.post<List>(
      "notes/scheduled/list",
      const {"offset": 0},
    );
    final me = await misskey.i.i();
    return response.map((item) {
      final scheduled = _asJsonMap(item);
      final data = _asJsonMap(scheduled["data"]);
      final reply = _asJsonMap(scheduled["reply"]);
      final renote = _asJsonMap(scheduled["renote"]);
      final channel = _asJsonMap(scheduled["channel"]);
      final files = data["files"] as List? ?? const [];
      return NoteDraft.fromJson({
        "id": scheduled["id"] as String,
        "createdAt": _scheduledDateValue(
          scheduled["updatedAt"] ?? scheduled["scheduledAt"],
        ),
        "text": data["text"],
        "cw": data["cw"],
        "userId": me.id,
        "user": me.toJson(),
        "replyId": reply["id"],
        "renoteId": renote["id"],
        "visibility": data["visibility"] ?? "public",
        "visibleUserIds": data["visibleUserIds"],
        "fileIds": files
            .map((file) => _asJsonMap(file)["id"])
            .whereType<String>()
            .toList(),
        "files": files,
        "channelId": channel["id"],
        "localOnly": data["localOnly"],
        "scheduledAt": _scheduledDateValue(scheduled["scheduledAt"]),
        "isActuallyScheduled": true,
      });
    }).toList();
  }

  final drafts = await misskey.notes.drafts.list(
    const NotesDraftsListRequest(limit: 100, scheduled: true),
  );
  return drafts.toList();
}

class _ScheduledDraftsListView extends HookConsumerWidget {
  const _ScheduledDraftsListView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refreshVersion = useState(0);
    final misskey = ref.watch(misskeyGetContextProvider);
    final scheduledNotes = useMemoized(
      () => _loadScheduledDrafts(misskey),
      [misskey, refreshVersion.value],
    );

    Future<void> refresh() async {
      await _loadScheduledDrafts(misskey);
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
                                final endpoints = await misskey.endpoints();
                                if (action == "cancel") {
                                  if (endpoints.contains("notes/schedule/delete")) {
                                    await misskey.apiService.post<void>(
                                      "notes/schedule/delete",
                                      {"noteId": draft.id},
                                    );
                                  } else if (endpoints.contains("notes/scheduled/cancel")) {
                                    await misskey.apiService.post<void>(
                                      "notes/scheduled/cancel",
                                      {"draftId": draft.id},
                                    );
                                  } else {
                                    await misskey.notes.drafts.update(
                                      NotesDraftsUpdateRequest(
                                        draftId: draft.id,
                                        scheduledAt: null,
                                        isActuallyScheduled: false,
                                      ),
                                    );
                                  }
                                } else if (action == "delete") {
                                  if (endpoints.contains("notes/schedule/delete")) {
                                    await misskey.apiService.post<void>(
                                      "notes/schedule/delete",
                                      {"noteId": draft.id},
                                    );
                                  } else if (endpoints.contains("notes/scheduled/cancel")) {
                                    await misskey.apiService.post<void>(
                                      "notes/scheduled/cancel",
                                      {"draftId": draft.id},
                                    );
                                  } else {
                                    await misskey.notes.drafts.delete(
                                      NotesDraftsDeleteRequest(
                                        draftId: draft.id,
                                      ),
                                    );
                                  }
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
