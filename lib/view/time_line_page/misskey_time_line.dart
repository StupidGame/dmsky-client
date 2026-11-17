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
import "package:dmsky_client/view/time_line_page/timeline_items.dart";
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

    if (controller.positions.isNotEmpty) {
      controller.scrollToTop();
    }
    final repository = ref.watch(timelineProvider(tabSetting));
    final items = TimelineItems(
      older: repository.olderNotes,
      newer: repository.newerNotes,
    );

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: TimelineListView.builder(
        reverse: true,
        controller: controller,
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          final note = items[index];
          if (note != null) {
            return NoteWrapper(targetNote: note, timeline: repository);
          }
          if (index == -items.olderCount) {
            if (isLastLoaded.value) {
              return const SizedBox.shrink();
            }

            if (isDownDirectionLoading.value &&
                repository.newerNotes.length + repository.olderNotes.length !=
                    0) {
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

          return null;
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
