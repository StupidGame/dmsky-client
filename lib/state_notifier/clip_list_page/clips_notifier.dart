import "package:dmsky_client/l10n/app_localizations.dart";
import "package:dmsky_client/model/clip_settings.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/view/common/dialog/dialog_state.dart";
import "package:misskey_dart/misskey_dart.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "clips_notifier.g.dart";

@Riverpod(dependencies: [misskeyPostContext])
class ClipsNotifier extends _$ClipsNotifier {
  @override
  Future<List<Clip>> build() async {
    return await loadClips();
  }

  Future<List<Clip>> loadClips({String? untilId, int limit = 10}) async {
    final response = await ref
        .read(misskeyPostContextProvider)
        .clips
        .list(ClipsListRequest(untilId: untilId, limit: limit));
    final clips = untilId != null
        ? response.where((clip) => clip.id.compareTo(untilId) < 0)
        : response;
    state = AsyncValue.data([...?state.value, ...clips]);
    return clips.toList();
  }

  Future<void> create(ClipSettings settings) async {
    await ref.read(dialogStateProvider.notifier).guard(() async {
      final list = await ref
          .read(misskeyPostContextProvider)
          .clips
          .create(
            ClipsCreateRequest(
              name: settings.name,
              description: settings.description,
              isPublic: settings.isPublic,
            ),
          );
      state = AsyncValue.data([...?state.value, list]);
    });
  }

  Future<void> delete(String clipId) async {
    final result = await ref
        .read(dialogStateProvider.notifier)
        .showDialog(
          message: (context) => S.of(context).confirmDeleteClip,
          actions: (context) => [
            S.of(context).willDelete,
            S.of(context).cancel,
          ],
        );
    if (result != 0) return;

    await ref.read(dialogStateProvider.notifier).guard(() async {
      await ref
          .read(misskeyPostContextProvider)
          .clips
          .delete(ClipsDeleteRequest(clipId: clipId));
      state = AsyncValue.data([...?state.value?.where((e) => e.id != clipId)]);
    });
  }

  Future<void> updateClip(String clipId, ClipSettings settings) async {
    await ref.read(dialogStateProvider.notifier).guard(() async {
      final clip = await ref
          .read(misskeyPostContextProvider)
          .clips
          .update(
            ClipsUpdateRequest(
              clipId: clipId,
              name: settings.name,
              description: settings.description,
              isPublic: settings.isPublic,
            ),
          );
      state = AsyncValue.data([
        for (final e in [...?state.value]) e.id == clipId ? clip : e,
      ]);
    });
  }
}
