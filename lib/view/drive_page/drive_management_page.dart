import "package:auto_route/auto_route.dart";
import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:dio/dio.dart";
import "package:url_launcher/url_launcher.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/model/account.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/view/common/account_scope.dart";
import "package:misskey_dart/misskey_dart.dart";

class DriveManagementPage extends HookConsumerWidget
    implements AutoRouteWrapper {
  const DriveManagementPage({
    required this.account,
    this.selectFolder = false,
    super.key,
  });

  final Account account;
  final bool selectFolder;

  @override
  Widget wrappedRoute(BuildContext context) =>
      AccountContextScope.as(account: account, child: this);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = useState<List<DriveFolder>>([]);
    final selectedFiles = useState<List<DriveFile>>([]);
    final revision = useState(0);
    final misskey = ref.watch(misskeyGetContextProvider);
    final folderId = path.value.isEmpty ? null : path.value.last.id;
    final folderItems = useState<List<DriveFolder>>([]);
    final fileItems = useState<List<DriveFile>>([]);
    final folderHasMore = useState(true);
    final fileHasMore = useState(true);
    final loadingFolders = useState(false);
    final loadingFiles = useState(false);
    useEffect(() {
      selectedFiles.value = [];
      folderItems.value = [];
      fileItems.value = [];
      folderHasMore.value = true;
      fileHasMore.value = true;
      return null;
    }, [folderId]);
    final contents = useMemoized(
      () => _loadContents(misskey, folderId),
      [misskey, folderId, revision.value],
    );

    Future<void> refresh() async {
      folderItems.value = [];
      fileItems.value = [];
      folderHasMore.value = true;
      fileHasMore.value = true;
      revision.value++;
    }

    Future<void> showError(Object error) async {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("操作に失敗しました: $error")),
      );
    }

    Future<void> loadMoreFolders(List<DriveFolder> visible) async {
      if (loadingFolders.value || !folderHasMore.value || visible.isEmpty) {
        return;
      }
      loadingFolders.value = true;
      try {
        final next = (await misskey.drive.folders.folders(
          DriveFoldersRequest(
            folderId: folderId,
            limit: 100,
            untilId: visible.last.id,
          ),
        )).toList();
        folderItems.value = [...visible, ...next];
        folderHasMore.value = next.length == 100;
      } catch (error) {
        await showError(error);
      } finally {
        loadingFolders.value = false;
      }
    }

    Future<void> loadMoreFiles(List<DriveFile> visible) async {
      if (loadingFiles.value || !fileHasMore.value || visible.isEmpty) return;
      loadingFiles.value = true;
      try {
        final next = (await misskey.drive.files.files(
          DriveFilesRequest(
            folderId: folderId,
            limit: 100,
            untilId: visible.last.id,
          ),
        )).toList();
        fileItems.value = [...visible, ...next];
        fileHasMore.value = next.length == 100;
      } catch (error) {
        await showError(error);
      } finally {
        loadingFiles.value = false;
      }
    }

    Future<_DriveFolderDestination?> chooseDestination() {
      return Navigator.of(context).push<_DriveFolderDestination>(
        MaterialPageRoute(
          builder: (routeContext) => DriveManagementPage(
            account: account,
            selectFolder: true,
          ).wrappedRoute(routeContext),
        ),
      );
    }

    Future<void> moveFile(DriveFile file) async {
      final destination = await chooseDestination();
      if (destination == null || !context.mounted) return;
      if (destination.folderId == file.folderId) return;
      try {
        await misskey.drive.files.update(
          DriveFilesUpdateRequest(
            fileId: file.id,
            folderId: destination.folderId,
          ),
        );
        await refresh();
      } catch (error) {
        await showError(error);
      }
    }

    Future<void> moveSelectedFiles() async {
      final selected = selectedFiles.value;
      if (selected.isEmpty) return;
      final destination = await chooseDestination();
      if (destination == null || !context.mounted) return;
      try {
        await misskey.drive.files.moveBulk(
          DriveFilesMoveBulkRequest(
            fileIds: selected.map((file) => file.id).toList(),
            folderId: destination.folderId,
          ),
        );
        selectedFiles.value = [];
        await refresh();
      } catch (error) {
        await showError(error);
      }
    }

    Future<void> deleteSelectedFiles() async {
      final selected = selectedFiles.value;
      if (selected.isEmpty) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("ファイルを一括削除"),
          content: Text("${selected.length}件のファイルを削除しますか？"),
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
        await Future.wait(
          selected.map(
            (file) => misskey.drive.files.delete(
              DriveFilesDeleteRequest(fileId: file.id),
            ),
          ),
        );
        selectedFiles.value = [];
        await refresh();
      } catch (error) {
        await showError(error);
      }
    }

    Future<void> moveFolder(DriveFolder folder) async {
      final destination = await chooseDestination();
      if (destination == null || !context.mounted) return;
      if (destination.folderId == folder.id ||
          destination.folderId == folder.parentId) {
        return;
      }
      try {
        await misskey.drive.folders.update(
          DriveFoldersUpdateRequest(
            folderId: folder.id,
            parentId: destination.folderId,
          ),
        );
        await refresh();
      } catch (error) {
        await showError(error);
      }
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
              if (file.type.startsWith("image/") ||
                  file.type.startsWith("video/") ||
                  file.type.startsWith("audio/"))
                ListTile(
                  leading: const Icon(Icons.visibility_outlined),
                  title: const Text("プレビュー"),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    previewFile(file);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text("ダウンロード"),
                onTap: () {
                  Navigator.pop(sheetContext);
                  downloadFile(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text("名前を変更"),
                onTap: () {
                  Navigator.pop(sheetContext);
                  renameFolder(folder);
                },
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined),
                title: const Text("移動"),
                onTap: () {
                  Navigator.pop(sheetContext);
                  moveFolder(folder);
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

    Future<void> downloadFile(DriveFile file) async {
      try {
        final response = await ref.read(dioProvider).get<List<int>>(
          file.url,
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = response.data;
        if (bytes == null || bytes.isEmpty) {
          throw StateError("ファイルの内容が空です");
        }
        final saved = await FilePicker.saveFile(
          fileName: file.name,
          bytes: bytes,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved == null ? "保存をキャンセルしました" : "ファイルを保存しました",
            ),
          ),
        );
      } catch (error) {
        await showError(error);
      }
    }

    Future<void> previewFile(DriveFile file) async {
      if (file.type.startsWith("image/")) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => Dialog(
            child: InteractiveViewer(
              child: Image.network(
                file.url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text("画像を表示できませんでした"),
                ),
              ),
            ),
          ),
        );
      } else {
        await launchUrl(
          Uri.parse(file.url),
          mode: LaunchMode.externalApplication,
        );
      }
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
                leading: const Icon(Icons.drive_file_move_outlined),
                title: const Text("移動"),
                onTap: () {
                  Navigator.pop(sheetContext);
                  moveFile(file);
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
        title: Text(selectFolder ? "移動先を選択" : "ドライブ"),
        leading: selectFolder && path.value.isNotEmpty
            ? IconButton(
                tooltip: "上のフォルダーへ",
                onPressed: () => path.value = path.value.sublist(
                  0,
                  path.value.length - 1,
                ),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        actions: [
          if (!selectFolder && selectedFiles.value.isNotEmpty) ...[
            Text(
              "${selectedFiles.value.length}件選択",
              style: Theme.of(context).textTheme.labelLarge,
            ),
            IconButton(
              tooltip: "選択解除",
              onPressed: () => selectedFiles.value = [],
              icon: const Icon(Icons.close),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == "move") {
                  moveSelectedFiles();
                }
                if (value == "delete") {
                  deleteSelectedFiles();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: "move",
                  child: ListTile(
                    leading: Icon(Icons.drive_file_move_outlined),
                    title: Text("選択したファイルを移動"),
                  ),
                ),
                PopupMenuItem(
                  value: "delete",
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text("選択したファイルを削除"),
                  ),
                ),
              ],
            ),
          ] else if (selectFolder)
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(
                _DriveFolderDestination(folderId),
              ),
              icon: const Icon(Icons.check),
              label: const Text("ここに移動"),
            )
          else ...[
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
                    onPressed: selectFolder
                        ? () => Navigator.of(context).pop(
                              const _DriveFolderDestination(null),
                            )
                        : path.value.isEmpty
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
          final visibleFolders = folderItems.value.isEmpty
              ? data.folders
              : folderItems.value;
          final visibleFiles = fileItems.value.isEmpty
              ? data.files
              : fileItems.value;
          folderHasMore.value = folderItems.value.isEmpty
              ? data.folders.length == 100
              : folderHasMore.value;
          fileHasMore.value = fileItems.value.isEmpty
              ? data.files.length == 100
              : fileHasMore.value;
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
                if (selectFolder)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(
                        _DriveFolderDestination(folderId),
                      ),
                      icon: const Icon(Icons.drive_file_move),
                      label: Text(
                        folderId == null ? "ドライブ直下を移動先にする" : "このフォルダーを移動先にする",
                      ),
                    ),
                  ),
                if (folderHasMore.value && visibleFolders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: OutlinedButton.icon(
                      onPressed: loadingFolders.value
                          ? null
                          : () => loadMoreFolders(visibleFolders),
                      icon: loadingFolders.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more),
                      label: Text(
                        loadingFolders.value
                            ? "フォルダーを読み込み中…"
                            : "フォルダーをさらに読み込む",
                      ),
                    ),
                  ),
                if (visibleFolders.isEmpty && visibleFiles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text("このフォルダーは空です")),
                  ),
                for (final folder in visibleFolders)
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(folder.name),
                    trailing: selectFolder
                        ? IconButton(
                            tooltip: "このフォルダーを選択",
                            onPressed: () => Navigator.of(context).pop(
                              _DriveFolderDestination(folder.id),
                            ),
                            icon: const Icon(Icons.check_circle_outline),
                          )
                        : IconButton(
                            tooltip: "フォルダー操作",
                            onPressed: () => showFolderActions(folder),
                            icon: const Icon(Icons.more_vert),
                          ),
                    onTap: () => path.value = [...path.value, folder],
                    onLongPress: () {
                      if (!selectFolder) showFolderActions(folder);
                    },
                  ),
                if (!selectFolder && visibleFiles.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            final next = selectedFiles.value.toList();
                            for (final file in visibleFiles) {
                              if (!next.any((selected) => selected.id == file.id)) {
                                next.add(file);
                              }
                            }
                            selectedFiles.value = next;
                          },
                          icon: const Icon(Icons.select_all),
                          label: const Text("表示中のファイルをすべて選択"),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: selectedFiles.value.isEmpty
                              ? null
                              : () => selectedFiles.value = [],
                          child: const Text("解除"),
                        ),
                      ],
                    ),
                  ),
                for (final file in visibleFiles)
                  if (!selectFolder)
                    ListTile(
                    leading: Checkbox(
                      value: selectedFiles.value.any(
                        (selected) => selected.id == file.id,
                      ),
                      onChanged: (checked) {
                        final next = selectedFiles.value.toList();
                        if (checked == true) {
                          if (!next.any((selected) => selected.id == file.id)) {
                            next.add(file);
                          }
                        } else {
                          next.removeWhere((selected) => selected.id == file.id);
                        }
                        selectedFiles.value = next;
                      },
                    ),
                    title: Text(file.name),
                    subtitle: Text(
                      "${file.type} • ${_formatBytes(file.size)}"
                      "${file.isSensitive ? " • センシティブ" : ""}",
                    ),
                    trailing: IconButton(
                      tooltip: selectedFiles.value.any((selected) => selected.id == file.id)
                          ? "選択解除"
                          : "選択",
                      onPressed: () {
                        final next = selectedFiles.value.toList();
                        final index = next.indexWhere(
                          (selected) => selected.id == file.id,
                        );
                        if (index >= 0) {
                          next.removeAt(index);
                        } else {
                          next.add(file);
                        }
                        selectedFiles.value = next;
                      },
                      icon: Icon(
                        selectedFiles.value.any((selected) => selected.id == file.id)
                            ? Icons.check_circle
                            : Icons.more_vert,
                      ),
                    ),
                    onLongPress: () {
                      if (!selectedFiles.value.any((selected) => selected.id == file.id)) {
                        selectedFiles.value = [...selectedFiles.value, file];
                      }
                    },
                    onTap: () {
                      if (selectedFiles.value.isNotEmpty) {
                        final next = selectedFiles.value.toList();
                        final index = next.indexWhere(
                          (selected) => selected.id == file.id,
                        );
                        if (index >= 0) {
                          next.removeAt(index);
                        } else {
                          next.add(file);
                        }
                        selectedFiles.value = next;
                      } else {
                        showFileActions(file);
                      }
                    },
                  ),
                if (!selectFolder && fileHasMore.value && visibleFiles.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: OutlinedButton.icon(
                      onPressed: loadingFiles.value
                          ? null
                          : () => loadMoreFiles(visibleFiles),
                      icon: loadingFiles.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more),
                      label: Text(
                        loadingFiles.value
                            ? "ファイルを読み込み中…"
                            : "ファイルをさらに読み込む",
                      ),
                    ),
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

class _DriveFolderDestination {
  const _DriveFolderDestination(this.folderId);

  final String? folderId;
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return "$bytes B";
  final kb = bytes / 1024;
  if (kb < 1024) return "${kb.toStringAsFixed(1)} KB";
  final mb = kb / 1024;
  if (mb < 1024) return "${mb.toStringAsFixed(1)} MB";
  return "${(mb / 1024).toStringAsFixed(2)} GB";
}
