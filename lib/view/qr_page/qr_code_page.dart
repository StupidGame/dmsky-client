import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:dmsky_client/model/account.dart";
import "package:qr_flutter/qr_flutter.dart";
import "package:url_launcher/url_launcher.dart";

class QrCodePage extends StatelessWidget {
  const QrCodePage({required this.account, super.key});

  final Account account;

  String get profileUrl {
    final username = account.i.username;
    return Uri(
      scheme: account.scheme ?? "https",
      host: account.host,
      port: account.port,
      path: "/@$username",
    ).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("プロフィールQRコード")),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              account.i.name ?? account.i.username,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              "@${account.i.username}@${account.host}",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Center(
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: QrImageView(
                    data: profileUrl,
                    version: QrVersions.auto,
                    size: 260,
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(profileUrl, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: profileUrl));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("プロフィールURLをコピーしました")),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text("URLをコピー"),
            ),
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(profileUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text("プロフィールを開く"),
            ),
          ],
        ),
    );
  }
}
