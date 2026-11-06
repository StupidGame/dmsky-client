import "dart:math" as math;

import "package:collection/collection.dart";
import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/extensions/date_time_extension.dart";
import "package:dmsky_client/l10n/app_localizations.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/view/common/dialog/dialog_state.dart";
import "package:dmsky_client/view/common/misskey_notes/mfm_text.dart";
import "package:dmsky_client/view/themes/app_theme.dart";
import "package:misskey_dart/misskey_dart.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "note_vote.g.dart";

@Riverpod(dependencies: [misskeyPostContext, notesWith])
class NoteVoteNotifier extends _$NoteVoteNotifier {
  @override
  AsyncValue? build(Note note) => null;

  Future<bool> vote(int index) async {
    final poll = note.poll!;

    final dialogValue = await ref
        .read(dialogStateProvider.notifier)
        .showDialog(
          message: (context) =>
              S.of(context).confirmPoll(poll.choices[index].text),
          actions: (context) => [S.of(context).doVoting, S.of(context).cancel],
        );

    if (dialogValue != 0) return false;
    state = const AsyncLoading();

    state = await ref.read(dialogStateProvider.notifier).guard(() async {
      await ref
          .read(misskeyPostContextProvider)
          .notes
          .polls
          .vote(NotesPollsVoteRequest(noteId: note.id, choice: index));
      await ref.read(notesWithProvider).refresh(note.id);
    });
    return true;
  }
}

class NoteVote extends HookConsumerWidget {
  const NoteVote({required this.displayNote, required this.poll, super.key});

  final Note displayNote;
  final NotePoll poll;

  bool isAnyVotable(WidgetRef ref) {
    if (!ref.read(accountContextProvider).isSame) return false;
    final expiresAt = poll.expiresAt;
    return (expiresAt == null || expiresAt > DateTime.now()) &&
        ((poll.multiple && poll.choices.any((e) => !e.isVoted)) ||
            (!poll.multiple && poll.choices.every((e) => !e.isVoted)));
  }

  bool isVotable(int choice, WidgetRef ref) {
    return isAnyVotable(ref) &&
        ((!poll.multiple) || poll.multiple && !poll.choices[choice].isVoted);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalVotes = poll.choices.map((e) => e.votes).sum;
    final expiresAt = poll.expiresAt;
    final isExpired = expiresAt != null && expiresAt < DateTime.now();
    final differ = isExpired
        ? null
        : poll.expiresAt?.difference(DateTime.now()).format(context);
    final colorTheme = AppTheme.of(context).colorTheme;
    final textTheme = Theme.of(context).textTheme;
    final isOpened = useState(useMemoized(() => !isAnyVotable(ref)));

    ref.watch(noteVoteProvider(displayNote));

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: [
        for (final choice in poll.choices.mapIndexed(
          (index, element) => (index: index, element: element),
        )) ...[
          SizedBox(
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Material(
                color: isOpened.value
                    ? colorTheme.accentedBackground
                    : colorTheme.accentedBackground,
                child: InkWell(
                  onTap: isVotable(choice.index, ref)
                      ? () async {
                          isOpened.value = await ref
                              .read(noteVoteProvider(displayNote).notifier)
                              .vote(choice.index);
                        }
                      : null,
                  child: Stack(
                    children: [
                      if (isOpened.value)
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: totalVotes == 0
                                  ? 0
                                  : (choice.element.votes / math.max(totalVotes, 1))
                                      .clamp(0.0, 1.0)
                                      .toDouble(),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colorTheme.buttonGradateA,
                                      colorTheme.buttonGradateB,
                                    ],
                                  ),
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (choice.element.isVoted) ...[
                              const Icon(Icons.check_circle, size: 18),
                              const SizedBox(width: 7),
                            ],
                            Expanded(
                              child: SimpleMfmText(
                                choice.element.text,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: choice.element.isVoted
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isOpened.value) ...[
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    S.of(context).votesCount(choice.element.votes),
                                    style: textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: const [],
                                    ),
                                  ),
                                  Text(
                                    "${totalVotes == 0 ? '0.0' : (choice.element.votes / math.max(totalVotes, 1) * 100).toStringAsFixed(1)}%",
                                    style: textTheme.labelSmall?.copyWith(
                                      color: textTheme.bodySmall?.color
                                          ?.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
        ],
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: S.of(context).totalVotesCount(totalVotes),
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: "  ·  "),
              TextSpan(
                text: isExpired
                    ? S.of(context).finished
                    : !isOpened.value
                    ? S.of(context).openResult
                    : isAnyVotable(ref)
                    ? S.of(context).doVoting
                    : S.of(context).alreadyVoted,
                recognizer: TapGestureRecognizer()
                  ..onTap = () => isOpened.value = !isOpened.value,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (differ != null) ...[
                const TextSpan(text: "  ·  "),
                TextSpan(text: S.of(context).remainDiffer(differ)),
              ],
            ],
            style: textTheme.bodySmall?.copyWith(
              color: textTheme.bodySmall?.color?.withValues(alpha: 0.75),
            ),
          ),
        ),
      ],
    );
  }
}
