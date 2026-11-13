import "dart:async";
import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/log.dart";
import "package:dmsky_client/model/general_settings.dart";
import "package:dmsky_client/model/tab_setting.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/repository/time_line_repository.dart";
import "package:dmsky_client/view/common/misskey_notes/misskey_note.dart";
import "package:dmsky_client/view/common/timeline_listview.dart";
import "package:misskey_dart/misskey_dart.dart";

class MisskeyTimeline extends HookConsumerWidget {
  final TabSetting tabSetting;
  final TimelineScrollController controller;

  MisskeyTimeline({
    required this.tabSetting,
    super.key,
    TimelineScrollController? controller,
  }) : controller = controller ?? TimelineScrollController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineRepository = ref.read(timelineProvider(tabSetting));
    final isDownDirectionLoading = useState(false);
    final isLastLoaded = useState(false);
    final isLoadError = useState(false);

    useEffect(() {
      timelineRepository.startTimeLine();
      return () => timelineRepository.disconnect();
    }, [tabSetting]);

    useMemoized(() {
      isDownDirectionLoading.value = false;
      isLastLoaded.value = false;
    }, [tabSetting]);

    final downDirectionLoad = useCallback(() {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (isDownDirectionLoading.value) return;
        try {
          isLoadError.value = false;
          isDownDirectionLoading.value = true;
          final result = await timelineRepository.previousLoad();
          isDownDirectionLoading.value = false;
          isLastLoaded.value = result == 0;
        } catch (e) {
          isDownDirectionLoading.value = false;
          isLoadError.value = true;
          rethrow;
        }
      });
    }, [isDownDirectionLoading]);

    useEffect(() {
      if (controller.positions.isNotEmpty) {
        controller.scrollToTop();
      }
      return null;
    }, [controller, tabSetting]);

    final repository = ref.watch(timelineProvider(tabSetting));
    final olderNotes = repository.olderNotes;
    final newerNotes = repository.newerNotes;
    final olderCount = olderNotes.length;
    final newerCount = newerNotes.length;
    final leadingOlderCount = olderCount < 5 ? olderCount : 5;
    final remainingOlderCount = olderCount - leadingOlderCount;

    Widget loadMoreMarker() {
      if (isLastLoaded.value) return const SizedBox.shrink();

      if (isDownDirectionLoading.value && newerCount + olderCount != 0) {
        return const Padding(
          padding: EdgeInsets.only(top: 10, bottom: 10),
          child: Center(child: CircularProgressIndicator.adaptive()),
        );
      }

      if (ref.read(
                generalSettingsRepositoryProvider.select(
                  (value) => value.settings.automaticPush,
                ),
              ) ==
              AutomaticPush.automatic &&
          !isLoadError.value) {
        unawaited(downDirectionLoad());
      }

      return Center(
        child: InkWell(
          onTap: downDirectionLoad,
          child: Container(
            alignment: Alignment.center,
            constraints: const BoxConstraints(maxWidth: 800),
            height: 60,
            child: const Icon(Icons.keyboard_arrow_down),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: TimelineListView.builder(
        reverse: true,
        controller: controller,
        itemCount: newerCount + olderCount + 1,
        itemBuilder: (context, index) {
          // Keep item lookup O(1): do not rebuild sliced note lists for every row.
          if (index > 0) {
            final position = index - 1;
            if (position >= leadingOlderCount + newerCount) return null;

            final Note targetNote;
            if (position < leadingOlderCount) {
              targetNote = olderNotes[leadingOlderCount - position - 1];
            } else {
              targetNote = newerNotes[position - leadingOlderCount];
            }

            return NoteWrapper(
              targetNote: targetNote,
              timeline: timelineRepository,
            );
          }

          if (index == 0 && remainingOlderCount > 0) {
            return NoteWrapper(
              targetNote: olderNotes[leadingOlderCount],
              timeline: timelineRepository,
            );
          }

          if (index < 0) {
            final olderPosition = -index;
            if (olderPosition == remainingOlderCount) {
              return loadMoreMarker();
            }
            if (olderPosition > remainingOlderCount) return null;
            return NoteWrapper(
              targetNote: olderNotes[leadingOlderCount + olderPosition],
              timeline: timelineRepository,
            );
          }

          return loadMoreMarker();
        },
      ),
    );
  }
}

class NoteWrapper extends ConsumerStatefulWidget {
  final Note targetNote;
  final TimelineRepository timeline;

  const NoteWrapper({
    required this.targetNote,
    required this.timeline,
    super.key,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => NoteWrapperState();
}

class NoteWrapperState extends ConsumerState<NoteWrapper> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.targetNote.renoteId != null && widget.targetNote.text == null) {
      widget.timeline.subscribe(
        SubscribeItem(
          noteId: widget.targetNote.renoteId!,
          renoteId: null,
          replyId: null,
        ),
      );
    } else {
      widget.timeline.subscribe(
        SubscribeItem(
          noteId: widget.targetNote.id,
          renoteId: widget.targetNote.renoteId,
          replyId: widget.targetNote.replyId,
        ),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
    widget.timeline.preserveDescribe(widget.targetNote.id);
  }

  @override
  Widget build(BuildContext context) {
    final note = ref.watch(
      notesWithProvider.select((note) => note.notes[widget.targetNote.id]),
    );
    if (note == null) {
      logger.info("note was not found. ${widget.targetNote}");
      return MisskeyNote(
        note: widget.targetNote,
        key: ValueKey<String>(widget.targetNote.id),
      );
    }
    return MisskeyNote(note: note, key: ValueKey<String>(note.id));
  }
}
