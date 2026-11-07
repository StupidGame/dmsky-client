import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_hooks/flutter_hooks.dart";
import "package:hooks_riverpod/hooks_riverpod.dart";
import "package:dmsky_client/model/account.dart";
import "package:dmsky_client/view/common/account_scope.dart";
import "package:mobile_scanner/mobile_scanner.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";

class QrScannerPage extends HookConsumerWidget {
  const QrScannerPage({required this.account, super.key});

  final Account account;

  String get historyKey => "qr_read_history_${account.host}_${account.userId}";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedValue = useState<String?>(null);
    final history = useState<List<String>>([]);
    final loadingHistory = useState(true);
    final scanner = useMemoized(
      () => MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      ),
    );

    Future<void> persistHistory(List<String> values) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(historyKey, values);
    }

    Future<void> addHistory(String value) async {
      final next = [
        value,
        ...history.value.where((item) => item != value),
      ].take(30).toList();
      history.value = next;
      await persistHistory(next);
    }

    useEffect(() {
      Future<void> load() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          history.value = prefs.getStringList(historyKey) ?? [];
        } finally {
          loadingHistory.value = false;
        }
      }

      load();
      return () {
        scanner.dispose();
      };
    }, [scanner]);

    Future<void> resumeScanner() async {
      selectedValue.value = null;
      await scanner.start();
    }

    Future<void> deleteHistory(String value) async {
      final next = history.value.where((item) => item != value).toList();
      history.value = next;
      await persistHistory(next);
    }

    Future<void> openValue(String value) async {
      final uri = Uri.tryParse(value);
      if (uri == null ||
          (uri.scheme != "https" && uri.scheme != "http") ||
          uri.host.isEmpty) {
        await Clipboard.setData(ClipboardData(text: value));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("URLではないため、内容をコピーしました")),
        );
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    final unsupported = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows);

    return AccountContextScope.as(
      account: account,
      child: Scaffold(
        appBar: AppBar(title: const Text("QRコード読み取り")),
        body: unsupported
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    "このプラットフォームではカメラ読み取りに対応していません。"
                    "Android・iOS・macOS、またはカメラに対応したブラウザーで利用してください。",
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: selectedValue.value == null
                          ? MobileScanner(
                              controller: scanner,
                              onDetect: (capture) {
                                if (selectedValue.value != null ||
                                    capture.barcodes.isEmpty) {
                                  return;
                                }
                                final value = capture.barcodes
                                    .map((barcode) => barcode.rawValue)
                                    .firstWhere(
                                      (value) => value != null && value.isNotEmpty,
                                      orElse: () => null,
                                    );
                                if (value == null) return;
                                selectedValue.value = value;
                                scanner.stop();
                                addHistory(value);
                              },
                              errorBuilder: (context, error) => ColoredBox(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      "カメラを開始できませんでした: ${error.errorCode}",
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : ColoredBox(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: SelectableText(
                                    selectedValue.value!,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (selectedValue.value != null) ...[
                    FilledButton.icon(
                      onPressed: () => openValue(selectedValue.value!),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text("読み取ったURLを開く／内容をコピー"),
                    ),
                    OutlinedButton.icon(
                      onPressed: resumeScanner,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text("もう一度読み取る"),
                    ),
                  ] else
                    const ListTile(
                      leading: Icon(Icons.center_focus_strong),
                      title: Text("QRコードをカメラの枠内に合わせてください"),
                      subtitle: Text("読み取り後、履歴に保存されます"),
                    ),
                  const Divider(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "読み取り履歴",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: history.value.isEmpty
                            ? null
                            : () async {
                                history.value = [];
                                await persistHistory([]);
                              },
                        child: const Text("すべて削除"),
                      ),
                    ],
                  ),
                  if (loadingHistory.value)
                    const Center(child: CircularProgressIndicator.adaptive())
                  else if (history.value.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text("履歴はありません"),
                    )
                  else
                    for (final value in history.value)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.qr_code),
                        title: Text(
                          value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          selectedValue.value = value;
                          scanner.stop();
                        },
                        trailing: IconButton(
                          tooltip: "履歴から削除",
                          onPressed: () => deleteHistory(value),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                ],
              ),
      ),
    );
  }
}
