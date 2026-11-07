import "package:auto_route/auto_route.dart";
import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/model/account.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/view/common/account_scope.dart";
import "package:misskey_dart/misskey_dart.dart";

class DriveManagementPage extends HookConsumerWidget
    implements AutoRouteWrapper {
  const DriveManagementPage({required this.account, super.key});

  final Account account;

  @override
  Widget wrappedRoute(BuildContext context) =>
      AccountContextScope.as(account: account, child: this);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = useState<List<DriveFolder>>([]);
    final revision = useState(0);
    final misskey = ref.watch(misskeyGetContextProvider);
    final folderId = path.value.isEmpty ? null : path.value.last.id;
    final contents = useMemoized(
      () => _loadContents(misskey, folderId),
      [misskey, folderId, revision.value],
    );

    Future<void> refresh() async {
      await _loadContents(misskey, folderId);
      revision.value++;
    }

    Future<void> showError(Object error) async {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("操作に失敗しました: $error")),
      );
    }

    Future<void> createFolder() async {
      final controller = TextEditingController();
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("フォルダーを作成"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: "フォルダー名"),
            onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("キャンセル"),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text("作成"),
            ),
          ],
        ),
      );
      controller.dispose();
      if (name == null || name.isEmpty || !context.mounted) return;
      try {
        await misskey.drive.folders.create(
          DriveFoldersCreateRequest(name: name, parentId: folderId),
        );
        await refresh();
      } catch (error) {
        await showError(error);
      }
    }

    Future<void> uploadFiles() async {
      final picked = await FilePicker.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (picked == null || !context.mounted) return;
      try {
        for (final file in picked.files) {
          final bytes = file.bytes;
          if (bytes == null) continue;
          await misskey.drive.files.createAsBinary(
            DriveFilesCreateRequest(name: file.name, folderId: folderId),
            bytes,
          );
        }
        await refresh();
      } catch (error) {
        await showError(error);
      }
    }

    Future<void> renameFolder(DriveFolder folder) async {
      final controller = TextEditingController(text: folder.name);
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("フォルダー名を変更"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: "フォルダー名"),
            onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("キャンセル"),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text("保存"),
            ),
          ],
        ),
      );
      controller.dispose();
      if (name == null || name.isEmpty || name == folder.name || !context.mounted) {
        return;
      }
      try {
        await misskey.drive.folders.update(
          DriveFoldersUpdateRequest(folderId: folder.id, name: name),
        );
        await refresh();
      } catch (error) {
        await showError(error);
      }
    }

    Future<void> deleteFolder(DriveFolder folder) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("フォルダーを削除"),
          content: Text("「${folder.name}」を削除しますか？"),
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
      if (confirmed != true || !context.mounted) return;
      try {
        await misskey.drive.folders.delete(
          DriveFoldersDeleteRequest(folderId: folder.id),
        );
        await refresh();
      } catch (error) {
        await showError(error);
      }
    }

    Future<void> showFolderActions(DriveFolder folder) async {
      await showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text("名前を変更"),
                onTap: () {
                  Navigator.pop(sheetContext);
                  renameFolder(folder);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text("削除"),
                iconColor: Theme.of(context).colorScheme.error,
                onTap: () {
                  Navigator.pop(sheetContext);
                  deleteFolder(folder);
                },
              ),
            ],
          ),
        ),
      );
    }

    Future<void> showFileActions(DriveFile file) async {
      await showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text("名前を変更"),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final controller = TextEditingController(text: file.name);
                  final name = await showDialog<String>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text("ファイル名を変更"),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: "ファイル名"),
                        onSubmitted: (value) =>
                            Navigator.pop(dialogContext, value.trim()),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text("キャンセル"),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(
                            dialogContext,
                            controller.text.trim(),
                          ),
                          child: const Text("保存"),
                        ),
                      ],
                    ),
                  );
                  controller.dispose();
                  if (name == null || name.isEmpty || name == file.name) return;
                  try {
                    await misskey.drive.files.update(
                      DriveFilesUpdateRequest(fileId: file.id, name: name),
                    );
                    await refresh();
                  } catch (error) {
                    await showError(error);
                  }
                },
              ),
              ListTile(
                leading: Icon(
                  file.isSensitive ? Icons.visibility : Icons.visibility_off,
                ),
                title: Text(file.isSensitive ? "センシティブ指定を解除" : "センシティブに指定"),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  try {
                    await misskey.drive.files.update(
                      DriveFilesUpdateRequest(
                        fileId: file.id,
                        isSensitive: !file.isSensitive,
                      ),
                    );
                    await refresh();
                  } catch (error) {
                    await showError(error);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text("削除"),
                iconColor: Theme.of(context).colorScheme.error,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text("ファイルを削除"),
                      content: Text("「${file.name}」を削除しますか？"),
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
                  if (confirmed != true || !context.mounted) return;
                  try {
                    await misskey.drive.files.delete(
                      DriveFilesDeleteRequest(fileId: file.id),
                    );
                    await refresh();
                  } catch (error) {
                    await showError(error);
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("ドライブ"),
        actions: [
          IconButton(
            tooltip: "更新",
            onPressed: refresh,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == "folder") createFolder();
              if (value == "upload") uploadFiles();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: "folder", child: Text("フォルダーを作成")),
              PopupMenuItem(value: "upload", child: Text("ファイルをアップロード")),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: path.value.isEmpty
                        ? null
                        : () => path.value = [],
                    icon: const Icon(Icons.cloud_outlined),
                    label: const Text("ドライブ"),
                  ),
                  for (var index = 0; index < path.value.length; index++)
                    TextButton(
                      onPressed: index == path.value.length - 1
                          ? null
                          : () => path.value = path.value.sublist(0, index + 1),
                      child: Text(path.value[index].name),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<_DriveContents>(
        future: contents,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 42),
                    const SizedBox(height: 12),
                    Text("ドライブを読み込めませんでした: ${snapshot.error}"),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text("再試行"),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (folderId == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "使用容量",
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: data.stats.capacity == 0
                              ? 0
                              : (data.stats.usage / data.stats.capacity)
                                  .clamp(0.0, 1.0),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "${_formatBytes(data.stats.usage)} / ${_formatBytes(data.stats.capacity)}",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                if (data.folders.isEmpty && data.files.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text("このフォルダーは空です")),
                  ),
                for (final folder in data.folders)
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(folder.name),
                    trailing: const Icon(Icons.more_vert),
                    onTap: () => path.value = [...path.value, folder],
                    onLongPress: () => showFolderActions(folder),
                  ),
                for (final file in data.files)
                  ListTile(
                    leading: file.type.startsWith("image/")
                        ? const Icon(Icons.image_outlined)
                        : file.type.startsWith("video/")
                            ? const Icon(Icons.movie_outlined)
                            : const Icon(Icons.insert_drive_file_outlined),
                    title: Text(file.name),
                    subtitle: Text(
                      "${file.type} • ${_formatBytes(file.size)}"
                      "${file.isSensitive ? " • センシティブ" : ""}",
                    ),
                    trailing: IconButton(
                      tooltip: "ファイル操作",
                      onPressed: () => showFileActions(file),
                      icon: const Icon(Icons.more_vert),
                    ),
                    onTap: () => showFileActions(file),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          builder: (sheetContext) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.create_new_folder_outlined),
                  title: const Text("フォルダーを作成"),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    createFolder();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text("アップロード"),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    uploadFiles();
                  },
                ),
              ],
            ),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<_DriveContents> _loadContents(Misskey misskey, String? folderId) async {
  final results = await Future.wait([
    misskey.drive.folders.folders(
      DriveFoldersRequest(folderId: folderId, limit: 100),
    ),
    misskey.drive.files.files(
      DriveFilesRequest(folderId: folderId, limit: 100),
    ),
    if (folderId == null) misskey.drive.drive(),
  ]);
  return _DriveContents(
    folders: (results[0] as Iterable<DriveFolder>).toList(),
    files: (results[1] as Iterable<DriveFile>).toList(),
    stats: folderId == null
        ? results[2] as DriveResponse
        : const DriveResponse(capacity: 0, usage: 0),
  );
}

class _DriveContents {
  const _DriveContents({
    required this.folders,
    required this.files,
    required this.stats,
  });

  final List<DriveFolder> folders;
  final List<DriveFile> files;
  final DriveResponse stats;
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return "$bytes B";
  final kb = bytes / 1024;
  if (kb < 1024) return "${kb.toStringAsFixed(1)} KB";
  final mb = kb / 1024;
  if (mb < 1024) return "${mb.toStringAsFixed(1)} MB";
  return "${(mb / 1024).toStringAsFixed(2)} GB";
}
