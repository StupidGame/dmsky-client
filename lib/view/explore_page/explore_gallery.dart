import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/providers.dart";
import "package:misskey_dart/misskey_dart.dart";

/// Misskey ギャラリーの閲覧画面。
class ExploreGallery extends ConsumerWidget {
  const ExploreGallery({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final misskey = ref.watch(misskeyGetContextProvider);

    return DefaultTabController(
      length: 3,
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
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _GalleryList(
                  future: () => misskey.gallery.posts(
                    const GalleryPostsRequest(limit: 100),
                  ),
                ),
                _GalleryList(
                  future: () => misskey.gallery.featured(
                    const GalleryFeaturedRequest(limit: 100),
                  ),
                ),
                _GalleryList(future: () => misskey.gallery.popular()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryList extends ConsumerWidget {
  final Future<Iterable<GalleryPost>> Function() future;

  const _GalleryList({required this.future});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Iterable<GalleryPost>>(
      future: Future(future),
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
          itemBuilder: (context, index) => _GalleryPostTile(post: posts[index]),
        );
      },
    );
  }
}

class _GalleryPostTile extends StatelessWidget {
  final GalleryPost post;

  const _GalleryPostTile({required this.post});

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
          builder: (_) => _GalleryPostDetail(post: post),
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

  const _GalleryPostDetail({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = useState(post.isLiked ?? false);
    final likeCount = useState(post.likedCount);
    final busy = useState(false);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(post.title, style: Theme.of(context).textTheme.titleLarge),
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
              Text(post.description!),
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
                          final api = ref.read(misskeyGetContextProvider).gallery.posts;
                          if (liked.value) {
                            await api.unlike(
                              GalleryPostsUnlikeRequest(postId: post.id),
                            );
                            liked.value = false;
                            likeCount.value = (likeCount.value - 1).clamp(0, 1 << 31);
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
                              SnackBar(content: Text("いいねを更新できませんでした: $error")),
                            );
                          }
                        } finally {
                          busy.value = false;
                        }
                      },
                icon: Icon(liked.value ? Icons.favorite : Icons.favorite_border),
                label: Text("${likeCount.value}"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
