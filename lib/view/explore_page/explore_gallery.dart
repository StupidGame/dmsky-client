import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/router/app_router.dart";
import "package:misskey_dart/misskey_dart.dart" hide Clip;

class ExploreGallery extends HookConsumerWidget {
  const ExploreGallery({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final misskey = ref.watch(misskeyGetContextProvider);
    final account = ref.watch(accountContextProvider).postAccount;
    final revision = useState(0);

    Future<void> createPost() async {
      final data = await _showGalleryEditor(context, ref, account: account);
      if (data == null) return;
      if (data.fileIds.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("画像を1枚以上選択してください")),
          );
        }
        return;
      }
      try {
        await misskey.gallery.posts.create(
          GalleryPostsCreateRequest(
            title: data.title,
            description: data.description,
            fileIds: data.fileIds,
            isSensitive: data.isSensitive,
          ),
        );
        revision.value++;
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("ギャラリー投稿を作成できませんでした: $error")),
          );
        }
      }
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createPost,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text("投稿する"),
      ),
      body: DefaultTabController(
        length: 5,
        child: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: "新着"),
                  Tab(text: "おすすめ"),
                  Tab(text: "人気"),
                  Tab(text: "自分の投稿"),
                  Tab(text: "いいね"),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _GalleryList(
                    revision: revision.value,
                    onChanged: () => revision.value++,
                    future: () => misskey.gallery.posts.posts(
                      const GalleryPostsRequest(limit: 100),
                    ),
                  ),
                  _GalleryList(
                    revision: revision.value,
                    future: () => misskey.gallery.featured(
                      const GalleryFeaturedRequest(limit: 100),
                    ),
                  ),
                  _GalleryList(
                    revision: revision.value,
                    future: () => misskey.gallery.popular(),
                  ),
                  _GalleryList(
                    revision: revision.value,
                    future: () => misskey.i.gallery.posts(
                      const IGalleryPostsRequest(limit: 100),
                    ),
                  ),
                  _GalleryList(
                    revision: revision.value,
                    future: () async => (await misskey.i.gallery.likes(
                      const IGalleryLikesRequest(limit: 100),
                    )).map((item) => item.post),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryList extends HookWidget {
  final int revision;
  final VoidCallback onChanged;
  final Future<Iterable<GalleryPost>> Function() future;

  const _GalleryList({
    required this.revision,
    required this.onChanged,
    required this.future,
  });

  @override
  Widget build(BuildContext context) {
    final postsFuture = useMemoized(future, [revision]);
    return FutureBuilder<Iterable<GalleryPost>>(
      future: postsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text("ギャラリーを読み込めませんでした。\n${snapshot.error}"),
            ),
          );
        }
        final posts = snapshot.data?.toList() ?? const <GalleryPost>[];
        if (posts.isEmpty) {
          return const Center(child: Text("ギャラリーの投稿はありません。"));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: posts.length,
          itemBuilder: (context, index) => _GalleryPostTile(
            post: posts[index],
            onChanged: onChanged,
          ),
        );
      },
    );
  }
}

class _GalleryPostTile extends StatelessWidget {
  final GalleryPost post;
  final VoidCallback onChanged;

  const _GalleryPostTile({required this.post, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final image = post.files.firstOrNull;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => _GalleryPostDetail(
            post: post,
            onChanged: onChanged,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image != null)
              SizedBox(
                width: double.infinity,
                height: 180,
                child: post.isSensitive
                    ? const ColoredBox(
                        color: Colors.black87,
                        child: Center(
                          child: Text(
                            "閲覧注意",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                    : Image.network(
                        image.thumbnailUrl ?? image.url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ListTile(
              title: Text(
                post.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                "@${post.user.username} · ♥ ${post.likedCount}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryPostDetail extends HookConsumerWidget {
  final GalleryPost post;
  final VoidCallback onChanged;

  const _GalleryPostDetail({
    required this.post,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = useState(post.isLiked ?? false);
    final likeCount = useState(post.likedCount);
    final busy = useState(false);
    final account = ref.watch(accountContextProvider).postAccount;
    final misskey = ref.watch(misskeyGetContextProvider);
    final isOwner = post.userId == account.i.id;

    Future<void> editPost() async {
      final data = await _showGalleryEditor(
        context,
        ref,
        account: account,
        initialTitle: post.title,
        initialDescription: post.description ?? "",
        initialFiles: post.files,
        initialSensitive: post.isSensitive,
      );
      if (data == null) return;
      try {
        await misskey.gallery.posts.update(
          GalleryPostsUpdateRequest(
            postId: post.id,
            title: data.title,
            description: data.description,
            fileIds: data.fileIds,
            isSensitive: data.isSensitive,
          ),
        );
        onChanged();
        onChanged();
        if (context.mounted) Navigator.of(context).pop();
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("投稿を更新できませんでした: $error")),
          );
        }
      }
    }

    Future<void> deletePost() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("投稿を削除"),
          content: const Text("このギャラリー投稿を削除しますか？この操作は取り消せません。"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("キャンセル"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("削除"),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        await misskey.gallery.posts.delete(
          GalleryPostsDeleteRequest(postId: post.id),
        );
        if (context.mounted) Navigator.of(context).pop();
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("投稿を削除できませんでした: $error")),
          );
        }
      }
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    post.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (isOwner)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == "edit") editPost();
                      if (value == "delete") deletePost();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: "edit",
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text("編集"),
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
            const SizedBox(height: 6),
            Text("@${post.user.username}"),
            const SizedBox(height: 12),
            if (post.isSensitive)
              const SizedBox(
                height: 160,
                child: Center(child: Text("この投稿にはセンシティブな画像が含まれます。")),
              )
            else
              ...post.files.map(
                (file) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      file.url,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 120,
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
                ),
              ),
            if (post.description?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              SelectableText(post.description!),
            ],
            if (post.tags?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: post.tags!
                    .map((tag) => Chip(label: Text("#$tag")))
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: busy.value
                    ? null
                    : () async {
                        busy.value = true;
                        try {
                          final api = misskey.gallery.posts;
                          if (liked.value) {
                            await api.unlike(
                              GalleryPostsUnlikeRequest(postId: post.id),
                            );
                            liked.value = false;
                            likeCount.value =
                                (likeCount.value - 1).clamp(0, 1 << 31).toInt();
                          } else {
                            await api.like(
                              GalleryPostsLikeRequest(postId: post.id),
                            );
                            liked.value = true;
                            likeCount.value += 1;
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("いいねを更新できませんでした: $error"),
                              ),
                            );
                          }
                        } finally {
                          busy.value = false;
                        }
                      },
                icon: Icon(
                  liked.value ? Icons.favorite : Icons.favorite_border,
                ),
                label: Text("${likeCount.value}"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _GalleryEditorData = ({
  String title,
  String description,
  List<String> fileIds,
  bool isSensitive,
});

Future<_GalleryEditorData?> _showGalleryEditor(
  BuildContext context,
  WidgetRef ref, {
  required Account account,
  String initialTitle = "",
  String initialDescription = "",
  List<DriveFile> initialFiles = const [],
  bool initialSensitive = false,
}) async {
  final titleController = TextEditingController(text: initialTitle);
  final descriptionController = TextEditingController(text: initialDescription);
  var selectedFiles = [...initialFiles];
  var isSensitive = initialSensitive;

  final result = await showDialog<_GalleryEditorData>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(initialTitle.isEmpty ? "ギャラリーに投稿" : "ギャラリー投稿を編集"),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: "タイトル"),
                  maxLength: 100,
                ),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: "説明"),
                  minLines: 2,
                  maxLines: 6,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final files = await dialogContext.pushRoute<List<DriveFile>>(
                      DriveFileSelectRoute(account: account, allowMultiple: true),
                    );
                    if (files != null && context.mounted) {
                      setState(() => selectedFiles = files);
                    }
                  },
                  icon: const Icon(Icons.folder_open),
                  label: Text("画像を選択 (${selectedFiles.length}件)"),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isSensitive,
                  onChanged: (value) => setState(() => isSensitive = value),
                  title: const Text("センシティブな内容"),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("キャンセル"),
          ),
          FilledButton(
            onPressed: titleController.text.trim().isEmpty ||
                    selectedFiles.isEmpty
                ? null
                : () => Navigator.pop(
                    dialogContext,
                    (
                      title: titleController.text.trim(),
                      description: descriptionController.text.trim(),
                      fileIds: selectedFiles.map((file) => file.id).toList(),
                      isSensitive: isSensitive,
                    ),
                  ),
            child: const Text("保存"),
          ),
        ],
      ),
    ),
  );
  titleController.dispose();
  descriptionController.dispose();
  return result;
}
