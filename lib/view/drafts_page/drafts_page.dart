import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
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
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).drafts)),
      body: _DraftsListView(),
    );
  }
}

class _DraftsListView extends ConsumerWidget {
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
                  // Refresh the list
                  // Note: In a real implementation, you might want to use a more sophisticated state management
                },
              );
            },
          ),
        );
      },
    );
  }
}
