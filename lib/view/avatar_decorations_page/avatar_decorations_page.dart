import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/model/account.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/view/common/avatar_icon.dart";
import "package:misskey_dart/misskey_dart.dart";

class AvatarDecorationsPage extends HookConsumerWidget {
  const AvatarDecorationsPage({required this.account, super.key});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentAccount = ref.watch(accountsProvider).firstWhere(
      (item) => item == account,
      orElse: () => account,
    );
    final misskey = ref.watch(misskeyProvider(account));
    final refreshVersion = useState(0);
    final catalogFuture = useMemoized(
      () => misskey.getAvatarDecorations(),
      [misskey, refreshVersion.value],
    );
    final catalogSnapshot = useFuture(catalogFuture);
    final decorations = useState<List<UserAvatarDecoration>>(
      currentAccount.i.avatarDecorations.toList(),
    );

    useEffect(() {
      decorations.value = currentAccount.i.avatarDecorations.toList();
      return null;
    }, [currentAccount.i.avatarDecorations]);

    Future<void> save(List<UserAvatarDecoration> value) async {
      try {
        await misskey.i.update(
          IUpdateRequest(
            avatarDecorations: value
                .map(
                  (decoration) => IUpdateAvatarDecoration(
                    id: decoration.id,
                    angle: decoration.angle,
                    flipH: decoration.flipH,
                    offsetX: decoration.offsetX,
                    offsetY: decoration.offsetY,
                  ),
                )
                .toList(),
          ),
        );
        await ref
            .read(accountRepositoryProvider.notifier)
            .updateI(currentAccount);
        if (!context.mounted) return;
        decorations.value = ref
            .read(accountsProvider)
            .firstWhere((item) => item == account)
            .i
            .avatarDecorations
            .toList();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("アバター装飾を更新しました")),
        );
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("更新に失敗しました: $error")),
        );
      }
    }

    Future<UserAvatarDecoration?> editDecoration({
      required String id,
      required String url,
      required String name,
      UserAvatarDecoration? initial,
    }) {
      return showDialog<UserAvatarDecoration>(
        context: context,
        builder: (dialogContext) => _AvatarDecorationEditor(
          name: name,
          url: url,
          initial: initial,
        ),
      );
    }

    final limit = (currentAccount.i.policies?.avatarDecorationLimit ?? 1)
        .ceil()
        .clamp(0, 100);
    final remaining = (limit - decorations.value.length).clamp(0, limit);

    return Scaffold(
      appBar: AppBar(
        title: const Text("アバター装飾"),
        actions: [
          IconButton(
            tooltip: "一覧を更新",
            onPressed: () => refreshVersion.value++,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: catalogSnapshot.connectionState == ConnectionState.waiting
          ? const Center(child: CircularProgressIndicator.adaptive())
          : catalogSnapshot.hasError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 40),
                        const SizedBox(height: 8),
                        Text("装飾一覧を取得できませんでした: ${catalogSnapshot.error}"),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () => refreshVersion.value++,
                          child: const Text("再試行"),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildContent(
                  context,
                  decorations: decorations.value,
                  catalog: catalogSnapshot.data?.toList() ?? const [],
                  limit: limit,
                  remaining: remaining,
                  currentAccount: currentAccount,
                  onReorder: (oldIndex, newIndex) {
                    final next = decorations.value.toList();
                    if (newIndex > oldIndex) newIndex--;
                    final item = next.removeAt(oldIndex);
                    next.insert(newIndex, item);
                    decorations.value = next;
                    save(next);
                  },
                  onRemove: (index) {
                    final next = index < 0
                        ? <UserAvatarDecoration>[]
                        : decorations.value.toList()..removeAt(index);
                    decorations.value = next;
                    save(next);
                  },
                  onEdit: (index) async {
                    final current = decorations.value[index];
                    final catalogItem = catalogSnapshot.data
                        ?.where((item) => item.id == current.id)
                        .firstOrNull;
                    final updated = await editDecoration(
                      id: current.id,
                      url: current.url,
                      name: catalogItem?.name ?? "装飾",
                      initial: current,
                    );
                    if (updated == null || !context.mounted) return;
                    final next = decorations.value.toList();
                    next[index] = updated;
                    decorations.value = next;
                    await save(next);
                  },
                  onAdd: (item) async {
                    final roles = currentAccount.i.roles ?? const [];
                    final canUse = item.roleIdsThatCanBeUsedThisDecoration
                        .isEmpty ||
                        roles.any(
                          (role) => item.roleIdsThatCanBeUsedThisDecoration
                              .contains(role.id),
                        );
                    if (!canUse) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("この装飾を使用する権限がありません"),
                        ),
                      );
                      return;
                    }
                    if (decorations.value.length >= limit) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("装飾の上限は $limit 件です")),
                      );
                      return;
                    }
                    final created = await editDecoration(
                      id: item.id,
                      url: item.url.toString(),
                      name: item.name,
                    );
                    if (created == null || !context.mounted) return;
                    if (decorations.value.any((e) => e.id == created.id)) {
                      return;
                    }
                    final next = [...decorations.value, created];
                    decorations.value = next;
                    await save(next);
                  },
                ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required List<UserAvatarDecoration> decorations,
    required List<GetAvatarDecorationsResponse> catalog,
    required int limit,
    required int remaining,
    required Account currentAccount,
    required void Function(int, int) onReorder,
    required void Function(int) onRemove,
    required Future<void> Function(int) onEdit,
    required Future<void> Function(GetAvatarDecorationsResponse) onAdd,
  }) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AvatarIcon(user: currentAccount.i, height: 76),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentAccount.i.name ??
                              currentAccount.i.username,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text("装着中: ${decorations.length} / $limit"),
                        Text("残り: $remaining"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (decorations.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text("装着中（ドラッグして順番を変更）"),
            ),
          ),
          SliverToBoxAdapter(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: true,
              itemCount: decorations.length,
              onReorder: onReorder,
              itemBuilder: (context, index) {
                final decoration = decorations[index];
                final entry = catalog.where((e) => e.id == decoration.id)
                    .firstOrNull;
                return ListTile(
                  key: ValueKey(decoration.id),
                  leading: SizedBox(
                    width: 44,
                    height: 44,
                    child: Image.network(
                      decoration.url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                  title: Text(entry?.name ?? "装飾"),
                  subtitle: Text(
                    "角度 ${(decoration.angle ?? 0).toStringAsFixed(2)}"
                    " / X ${decoration.offsetX.toStringAsFixed(2)}"
                    " / Y ${decoration.offsetY.toStringAsFixed(2)}",
                  ),
                  trailing: Wrap(
                    spacing: 0,
                    children: [
                      IconButton(
                        tooltip: "位置・角度を調整",
                        onPressed: () => onEdit(index),
                        icon: const Icon(Icons.tune),
                      ),
                      IconButton(
                        tooltip: "装飾を外す",
                        onPressed: () => onRemove(index),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () => onRemove(-1),
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text("すべて外す"),
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text("装飾カタログ"),
          ),
        ),
        if (catalog.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text("利用できる装飾はありません")),
            ),
          )
        else
          SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisExtent: 170,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: catalog.length,
            itemBuilder: (context, index) {
              final item = catalog[index];
              final isAdded = decorations.any((e) => e.id == item.id);
              final roles = currentAccount.i.roles ?? const [];
              final canUse = item.roleIdsThatCanBeUsedThisDecoration.isEmpty ||
                  roles.any(
                    (role) => item.roleIdsThatCanBeUsedThisDecoration
                        .contains(role.id),
                  );
              return Card(
                clipBehavior: Clip.hardEdge,
                child: InkWell(
                  onTap: isAdded || !canUse || remaining <= 0
                      ? null
                      : () => onAdd(item),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Image.network(
                            item.url.toString(),
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.image_not_supported_outlined,
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        if (isAdded)
                          const Text("装着中")
                        else if (!canUse)
                          const Text("権限が必要"),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

class _AvatarDecorationEditor extends HookWidget {
  const _AvatarDecorationEditor({
    required this.id,
    required this.name,
    required this.url,
    this.initial,
  });

  final String id;
  final String name;
  final String url;
  final UserAvatarDecoration? initial;

  @override
  Widget build(BuildContext context) {
    final angle = useState(initial?.angle ?? 0.0);
    final offsetX = useState(initial?.offsetX ?? 0.0);
    final offsetY = useState(initial?.offsetY ?? 0.0);
    final flipH = useState(initial?.flipH ?? false);

    return AlertDialog(
      title: Text(name),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 130,
                child: Transform.translate(
                  offset: Offset(offsetX.value * 100, offsetY.value * 100),
                  child: Transform.rotate(
                    angle: angle.value * 6.283185307179586,
                    child: Transform.flip(
                      flipX: flipH.value,
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.image_not_supported, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
              ListTile(
                title: const Text("回転"),
                subtitle: Slider(
                  value: angle.value.clamp(-0.5, 0.5),
                  min: -0.5,
                  max: 0.5,
                  onChanged: (value) => angle.value = value,
                ),
                trailing: IconButton(
                  onPressed: () => angle.value = 0,
                  icon: const Icon(Icons.refresh),
                ),
              ),
              ListTile(
                title: const Text("左右位置"),
                subtitle: Slider(
                  value: offsetX.value.clamp(-0.25, 0.25),
                  min: -0.25,
                  max: 0.25,
                  onChanged: (value) => offsetX.value = value,
                ),
                trailing: IconButton(
                  onPressed: () => offsetX.value = 0,
                  icon: const Icon(Icons.refresh),
                ),
              ),
              ListTile(
                title: const Text("上下位置"),
                subtitle: Slider(
                  value: offsetY.value.clamp(-0.25, 0.25),
                  min: -0.25,
                  max: 0.25,
                  onChanged: (value) => offsetY.value = value,
                ),
                trailing: IconButton(
                  onPressed: () => offsetY.value = 0,
                  icon: const Icon(Icons.refresh),
                ),
              ),
              SwitchListTile(
                title: const Text("左右反転"),
                value: flipH.value,
                onChanged: (value) => flipH.value = value,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("キャンセル"),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            UserAvatarDecoration(
              id: id,
              url: url,
              angle: angle.value,
              offsetX: offsetX.value,
              offsetY: offsetY.value,
              flipH: flipH.value,
            ),
          ),
          child: const Text("適用"),
        ),
      ],
    );
  }
}
