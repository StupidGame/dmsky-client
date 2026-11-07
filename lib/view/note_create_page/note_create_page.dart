import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:hooks_riverpod/legacy.dart";
import "package:dmsky_client/extensions/text_editing_controller_extension.dart";
import "package:dmsky_client/l10n/app_localizations.dart";
import "package:dmsky_client/model/account.dart";
import "package:dmsky_client/model/image_file.dart";
import "package:dmsky_client/model/misskey_emoji_data.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/repository/note_draft_repository.dart";
import "package:dmsky_client/router/app_router.dart";
import "package:dmsky_client/state_notifier/note_create_page/note_create_state_notifier.dart";
import "package:dmsky_client/view/common/account_scope.dart";
import "package:dmsky_client/view/common/dialog/dialog_state.dart";
import "package:dmsky_client/view/common/modal_indicator.dart";
import "package:dmsky_client/view/drafts_page/drafts_dialog.dart";
import "package:dmsky_client/view/note_create_page/channel_area.dart";
import "package:dmsky_client/view/note_create_page/cw_text_area.dart";
import "package:dmsky_client/view/note_create_page/cw_toggle_button.dart";
import "package:dmsky_client/view/note_create_page/file_preview.dart";
import "package:dmsky_client/view/note_create_page/mfm_preview.dart";
import "package:dmsky_client/view/note_create_page/note_create_setting_top.dart";
import "package:dmsky_client/view/note_create_page/note_emoji.dart";
import "package:dmsky_client/view/note_create_page/renote_area.dart";
import "package:dmsky_client/view/note_create_page/reply_area.dart";
import "package:dmsky_client/view/note_create_page/reply_to_area.dart";
import "package:dmsky_client/view/note_create_page/vote_area.dart";
import "package:dmsky_client/view/themes/app_theme.dart";
import "package:misskey_dart/misskey_dart.dart";

final noteInputTextProvider =
    ChangeNotifierProvider.autoDispose<TextEditingController>((ref) {
      final controller = TextEditingController();

      return controller;
    });
final noteFocusProvider = ChangeNotifierProvider.autoDispose(
  (ref) => FocusNode(),
);

final cwInputTextProvider =
    ChangeNotifierProvider.autoDispose<TextEditingController>((ref) {
      final controller = TextEditingController();

      return controller;
    });

final cwFocusProvider = ChangeNotifierProvider.autoDispose(
  (ref) => FocusNode(),
);

enum NoteCreationMode { update, recreate }

@RoutePage()
class NoteCreatePage extends HookConsumerWidget implements AutoRouteWrapper {
  final Account initialAccount;
  final String? initialText;
  final List<String>? initialMediaFiles;
  final bool exitOnNoted;
  final CommunityChannel? channel;
  final Note? reply;
  final Note? renote;
  final Note? note;
  final NoteCreationMode? noteCreationMode;
  final String? draftId;

  const NoteCreatePage({
    required this.initialAccount,
    super.key,
    this.initialText,
    this.initialMediaFiles,
    this.exitOnNoted = false,
    this.channel,
    this.reply,
    this.renote,
    this.note,
    this.noteCreationMode,
    this.draftId,
  });

  static const shareExtensionMethodChannel = MethodChannel(
    "info.shiosyakeyakini.miria/share_extension",
  );

  @override
  Widget wrappedRoute(BuildContext context) =>
      AccountContextScope.as(account: initialAccount, child: this);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusNode = ref.watch(noteFocusProvider);
    final notifier = ref.read(noteCreateProvider.notifier);
    final controller = ref.watch(noteInputTextProvider);

    Future<void> schedulePost() async {
      final account = ref.read(accountContextProvider).postAccount;
      final currentState = ref.read(noteCreateProvider);
      final misskey = ref.read(misskeyGetContextProvider);
      final limit = account.i.policies.scheduledNoteLimit ?? 0;
      final endpoints = await misskey.endpoints();
      final legacySchedule = endpoints.contains("notes/schedule/create");
      final canSchedule = limit > 0 || legacySchedule;
      if (!canSchedule) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("このサーバーは予約投稿に対応していません")),
        );
        return;
      }
      if (!_hasDraftContent(currentState)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("予約投稿する内容を入力してください")),
        );
        return;
      }
      final now = DateTime.now();
      final initialDate = now.add(const Duration(days: 1));
      final date = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
      );
      if (date == null || !context.mounted) return;
      final initialTime = TimeOfDay.fromDateTime(initialDate);
      final time = await showTimePicker(
        context: context,
        initialTime: initialTime,
      );
      if (time == null || !context.mounted) return;
      final scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (!scheduledAt.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("現在より後の日時を指定してください")),
        );
        return;
      }
      try {
        final state = ref.read(noteCreateProvider);
        if (state.selectedDraftId != null) {
          await _saveDraft(ref, state, scheduledAt: scheduledAt);
        } else {
          NotesCreatePollRequest? poll;
          if (state.isVote &&
              state.voteContent.any((choice) => choice.trim().isNotEmpty)) {
            DateTime? expiresAt;
            Duration? expiredAfter;
            switch (state.voteExpireType) {
              case VoteExpireType.date:
                expiresAt = state.voteDate;
              case VoteExpireType.duration:
                if (state.voteDuration != null) {
                  expiredAfter = Duration(
                    seconds: switch (state.voteDurationType) {
                      VoteExpireDurationType.seconds => state.voteDuration!,
                      VoteExpireDurationType.minutes => state.voteDuration! * 60,
                      VoteExpireDurationType.hours => state.voteDuration! * 3600,
                      VoteExpireDurationType.day => state.voteDuration! * 86400,
                    },
                  );
                }
              case VoteExpireType.unlimited:
                break;
            }
            poll = NotesCreatePollRequest(
              choices: state.voteContent
                  .where((choice) => choice.trim().isNotEmpty)
                  .toList(),
              multiple: state.isVoteMultiple,
              expiresAt: expiresAt,
              expiredAfter: expiredAfter,
            );
          }
          final fileIds = state.files
              .map(
                (file) => switch (file) {
                  ImageFileAlreadyPostedFile(id: final id) => id,
                  UnknownAlreadyPostedFile(id: final id) => id,
                  _ => null,
                },
              )
              .whereType<String>()
              .toList();
          final payload = <String, dynamic>{
            "visibility": state.noteVisibility.name,
            "visibleUserIds": state.replyTo.map((user) => user.id).toList(),
            "text": state.text.trim().isEmpty ? null : state.text,
            "cw": state.isCw && state.cwText.trim().isNotEmpty
                ? state.cwText
                : null,
            "localOnly": state.localOnly,
            "reactionAcceptance": state.reactionAcceptance?.name,
            "fileIds": fileIds.isEmpty ? null : fileIds,
            "replyId": state.reply?.id,
            "renoteId": state.renote?.id,
            "channelId": state.channel?.id,
            "poll": poll?.toJson(),
          }..removeWhere((_, value) => value == null);
          if (legacySchedule) {
            await misskey.apiService.post<dynamic>(
              "notes/schedule/create",
              {
                ...payload,
                "scheduleNote": {
                  "scheduledAt": scheduledAt.millisecondsSinceEpoch,
                },
              },
            );
          } else {
            await misskey.apiService.post<dynamic>(
              "notes/create",
              {
                ...payload,
                "scheduledAt": scheduledAt.millisecondsSinceEpoch,
              },
            );
          }
        }
        if (!context.mounted) return;
        ref.invalidate(noteCreateProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("予約投稿を登録しました: ${scheduledAt.toLocal()}"),
          ),
        );
        Navigator.of(context).pop();
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("予約投稿に失敗しました: $error")),
        );
      }
    }

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((timestamp) async {
        // Load draft if draftId is provided
        if (draftId != null) {
          final draftRepository = ref.read(
            noteDraftRepositoryProvider.notifier,
          );
          final draft = draftRepository.getDraft(draftId!);
          if (draft != null) {
            await notifier.initializeFromDraft(draft);
            return;
          }
        }

        await notifier.initialize(
          channel,
          initialText,
          initialMediaFiles,
          note,
          renote,
          reply,
          noteCreationMode,
        );
      });

      controller.addListener(() {
        notifier.setContentText(ref.read(noteInputTextProvider).text);
      });
      focusNode.addListener(() {
        notifier.setContentTextFocused(focusNode.hasFocus);
      });
      return () => {};
    }, const []);

    ref
      ..listen(noteCreateProvider.select((value) => value.text), (_, next) {
        if (next != ref.read(noteInputTextProvider).text) {
          ref.read(noteInputTextProvider).text = next;
        }
      })
      ..listen(noteCreateProvider.select((value) => value.isNoteSending), (
        _,
        next,
      ) async {
        switch (next) {
          case NoteSendStatus.sending:
            IndicatorView.showIndicator(context);
          case NoteSendStatus.finished:
            IndicatorView.hideIndicator(context);
            if (exitOnNoted) {
              await shareExtensionMethodChannel.invokeMethod("exit");
            } else {
              Navigator.of(context).pop();
            }

          case NoteSendStatus.error:
            IndicatorView.hideIndicator(context);
          case null:
            break;
        }
      });

    final noteDecoration = AppTheme.of(context).noteTextStyle.copyWith(
      hintText: (renote != null || reply != null)
          ? S.of(context).replyNotePlaceholder
          : S.of(context).defaultNotePlaceholder,
      contentPadding: const EdgeInsets.all(5),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final state = ref.read(noteCreateProvider);
        final hasContent = _hasDraftContent(state);
        final draftLimitPolicy =
            ref
                .read(accountContextProvider)
                .postAccount
                .i
                .policies
                .noteDraftLimit ??
            0;

        if (hasContent && draftLimitPolicy > 0) {
          // Show save to draft dialog only if drafts are supported
          final dialogNotifier = ref.read(dialogStateProvider.notifier);
          final choice = await dialogNotifier.showDialog(
            message: (context) => S.of(context).saveToDrafts,
            actions: (context) => [
              S.of(context).discardAndReturn,
              S.of(context).continueEditing,
              S.of(context).saveAndClose,
            ],
          );

          switch (choice) {
            case 0: // Discard
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            case 1: // Cancel
              return;
            case 2: // Save
              await _saveDraft(ref, state);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            default:
              return;
          }
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(S.of(context).note),
          actions: [
            if ((ref
                        .read(accountContextProvider)
                        .postAccount
                        .i
                        .policies
                        .scheduledNoteLimit ??
                    0) >
                0)
              IconButton(
                onPressed: schedulePost,
                icon: const Icon(Icons.schedule_send),
                tooltip: "予約投稿",
              ),
            // Show drafts button only if drafts are supported
            if ((ref
                        .read(accountContextProvider)
                        .postAccount
                        .i
                        .policies
                        .noteDraftLimit ??
                    0) >
                0)
              IconButton(
                onPressed: () async {
                  final selectedDraft = await showDraftsDialog(context, ref);
                  if (selectedDraft != null) {
                    // Load the selected draft into the current page
                    await notifier.initializeFromDraft(selectedDraft);
                  }
                },
                icon: const Icon(Icons.drafts),
                tooltip: S.of(context).drafts,
              ),
            IconButton(
              onPressed: () async => await notifier.note(),
              icon: const Icon(Icons.send),
            ),
          ],
        ),
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(left: 5, right: 5),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      if (noteCreationMode != NoteCreationMode.update)
                        const NoteCreateSettingTop()
                      else
                        const Padding(padding: EdgeInsets.only(top: 30)),
                      const ChannelArea(),
                      const ReplyArea(),
                      const ReplyToArea(),
                      const CwTextArea(),
                      Focus(
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent) {
                            if (event.logicalKey == LogicalKeyboardKey.enter &&
                                HardwareKeyboard.instance.isControlPressed) {
                              unawaited(notifier.note());
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          maxLines: null,
                          minLines: 5,
                          keyboardType: TextInputType.multiline,
                          decoration: noteDecoration,
                          autofocus: true,
                        ),
                      ),
                      Row(
                        children: [
                          if (noteCreationMode != NoteCreationMode.update) ...[
                            IconButton(
                              onPressed: () async =>
                                  await notifier.chooseFile(),
                              icon: const Icon(Icons.image),
                            ),
                            if (noteCreationMode != NoteCreationMode.update)
                              IconButton(
                                onPressed: () {
                                  ref
                                      .read(noteCreateProvider.notifier)
                                      .toggleVote();
                                },
                                icon: const Icon(Icons.how_to_vote),
                              ),
                          ],
                          const CwToggleButton(),
                          if (noteCreationMode != NoteCreationMode.update)
                            IconButton(
                              onPressed: () async => notifier.addReplyUser(),
                              icon: const Icon(Icons.mail_outline),
                            ),
                          IconButton(
                            onPressed: () async {
                              final selectedEmoji = await context
                                  .pushRoute<MisskeyEmojiData>(
                                    ReactionPickerRoute(
                                      account: ref
                                          .read(accountContextProvider)
                                          .postAccount,
                                      isAcceptSensitive: true,
                                    ),
                                  );
                              if (selectedEmoji == null) return;
                              switch (selectedEmoji) {
                                case CustomEmojiData():
                                  ref
                                      .read(noteInputTextProvider)
                                      .insert(":${selectedEmoji.baseName}:");
                                case UnicodeEmojiData():
                                  ref
                                      .read(noteInputTextProvider)
                                      .insert(selectedEmoji.char);
                                default:
                                  break;
                              }
                              ref.read(noteFocusProvider).requestFocus();
                            },
                            icon: const Icon(Icons.tag_faces),
                          ),
                        ],
                      ),
                      const MfmPreview(),
                      if (noteCreationMode != NoteCreationMode.update)
                        const FilePreview()
                      else if (note?.files.isNotEmpty == true)
                        Text(S.of(context).hasMediaButCannotEdit),
                      const RenoteArea(),
                      if (noteCreationMode != NoteCreationMode.update)
                        const VoteArea()
                      else if (note?.poll != null)
                        Text(S.of(context).hasVoteButCannotEdit),
                    ],
                  ),
                ),
              ),
            ),
            const NoteEmoji(),
          ],
        ),
      ),
    );
  }

  /// 下書きとして保存する価値のあるコンテンツがあるかどうかを判定
  bool _hasDraftContent(NoteCreate state) {
    return state.text.trim().isNotEmpty ||
        (state.isCw && state.cwText.trim().isNotEmpty) ||
        state.files.isNotEmpty ||
        (state.isVote &&
            state.voteContent.any((content) => content.trim().isNotEmpty));
  }

  /// 現在の状態を下書きとして保存
  Future<void> _saveDraft(
    WidgetRef ref,
    NoteCreate state, {
    DateTime? scheduledAt,
  }) async {
    final notifier = ref.read(noteCreateProvider.notifier);
    final draftRepository = ref.read(noteDraftRepositoryProvider.notifier);

    NotesCreatePollRequest? poll;
    if (state.isVote &&
        state.voteContent.any((content) => content.trim().isNotEmpty)) {
      DateTime? expiresAt;
      Duration? expiredAfter;

      switch (state.voteExpireType) {
        case VoteExpireType.date:
          expiresAt = state.voteDate;
        case VoteExpireType.duration:
          if (state.voteDuration != null) {
            final duration = Duration(
              seconds: switch (state.voteDurationType) {
                VoteExpireDurationType.seconds => state.voteDuration!,
                VoteExpireDurationType.minutes => state.voteDuration! * 60,
                VoteExpireDurationType.hours => state.voteDuration! * 3600,
                VoteExpireDurationType.day => state.voteDuration! * 86400,
              },
            );
            expiredAfter = duration;
          }
        case VoteExpireType.unlimited:
          break;
      }

      poll = NotesCreatePollRequest(
        choices: state.voteContent
            .where((content) => content.trim().isNotEmpty)
            .toList(),
        multiple: state.isVoteMultiple,
        expiresAt: expiresAt,
        expiredAfter: expiredAfter,
      );
    }

    // 共通のパラメータを準備
    final text = state.text.trim().isEmpty ? null : state.text;
    final cw = state.isCw && state.cwText.trim().isNotEmpty
        ? state.cwText
        : null;
    final fileIds = () {
      final fileIds = state.files
          .where(
            (file) =>
                file is ImageFileAlreadyPostedFile ||
                file is UnknownAlreadyPostedFile,
          )
          .map(
            (file) => switch (file) {
              ImageFileAlreadyPostedFile(id: final id) => id,
              UnknownAlreadyPostedFile(id: final id) => id,
              _ => throw UnsupportedError(
                "Unsupported file type for draft: ${file.runtimeType}",
              ),
            },
          )
          .toList();
      return fileIds.isEmpty ? null : fileIds;
    }();

    // 既存の下書きIDがある場合は更新、ない場合は新規作成
    if (state.selectedDraftId != null) {
      await draftRepository.update(
        draftId: state.selectedDraftId!,
        text: text,
        cw: cw,
        visibility: state.noteVisibility,
        localOnly: state.localOnly,
        reactionAcceptance: state.reactionAcceptance,
        fileIds: fileIds,
        replyId: state.reply?.id,
        renoteId: state.renote?.id,
        channelId: state.channel?.id,
        poll: poll,
        scheduledAt: scheduledAt,
        isActuallyScheduled: scheduledAt != null,
      );
    } else {
      final newDraft = await draftRepository.create(
        text: text,
        cw: cw,
        visibility: state.noteVisibility,
        localOnly: state.localOnly,
        reactionAcceptance: state.reactionAcceptance,
        fileIds: fileIds,
        replyId: state.reply?.id,
        renoteId: state.renote?.id,
        channelId: state.channel?.id,
        poll: poll,
        scheduledAt: scheduledAt,
        isActuallyScheduled: scheduledAt != null,
      );
      // 新規作成の場合は下書きIDを設定
      notifier.setSelectedDraftId(newDraft.id);
    }
  }
}
