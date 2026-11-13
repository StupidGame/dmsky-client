import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";
import "package:webview_flutter/webview_flutter.dart";

bool isPlayUri(Uri uri) =>
    (uri.scheme == "https" || uri.scheme == "http") &&
    uri.host.isNotEmpty &&
    uri.userInfo.isEmpty &&
    (uri.pathSegments.length == 1 || uri.pathSegments.length == 2) &&
    uri.pathSegments.first == "play";

bool isSamePlayOrigin(Uri uri, Uri origin) =>
    (uri.scheme == "https" || uri.scheme == "http") &&
    uri.host.isNotEmpty &&
    origin.host.isNotEmpty &&
    uri.userInfo.isEmpty &&
    origin.userInfo.isEmpty &&
    uri.origin == origin.origin;

Future<void> openPlay(BuildContext context, Uri uri, {String? title}) async {
  if (!isPlayUri(uri)) {
    throw ArgumentError.value(uri, "uri", "Invalid Play URL");
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => PlayPage(uri: uri, title: title),
    ),
  );
}

/// Runs the server's Play frontend, including its AiScript runtime, in a WebView.
/// The web session is separate from the client's API account credentials.
class PlayPage extends StatefulWidget {
  const PlayPage({required this.uri, this.title, super.key});
  final Uri uri;
  final String? title;

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  WebViewController? controller;
  int progress = 0;
  bool canGoBack = false;
  String? error;

  @override
  void initState() {
    super.initState();
    if (isPlayUri(widget.uri) && WebViewPlatform.instance != null) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    try {
      final view = WebViewController();
      await view.setJavaScriptMode(JavaScriptMode.unrestricted);
      await view.setBackgroundColor(const Color(0xff081321));
      await view.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) async {
            final target = Uri.tryParse(request.url);
            if (target == null) return NavigationDecision.prevent;
            if (isSamePlayOrigin(target, widget.uri)) {
              return NavigationDecision.navigate;
            }
            if ((target.scheme == "https" || target.scheme == "http") &&
                target.host.isNotEmpty &&
                target.userInfo.isEmpty) {
              await launchUrl(target, mode: LaunchMode.externalApplication);
            }
            return NavigationDecision.prevent;
          },
          onProgress: (value) {
            if (mounted) setState(() => progress = value);
          },
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                progress = 0;
                error = null;
              });
            }
          },
          onPageFinished: (_) => _updateHistory(),
          onUrlChange: (_) => _updateHistory(),
          onWebResourceError: (failure) {
            if (failure.isForMainFrame == true && mounted) {
              setState(() => error = "Playを読み込めませんでした");
            }
          },
        ),
      );
      if (!mounted) return;
      setState(() => controller = view);
      await view.loadRequest(widget.uri);
    } catch (_) {
      if (mounted) setState(() => error = "Playを読み込めませんでした");
    }
  }

  Future<void> _updateHistory() async {
    if (!mounted || controller == null) return;
    try {
      final back = await controller!.canGoBack();
      if (mounted) {
        setState(() {
          canGoBack = back;
          progress = 100;
        });
      }
    } catch (_) {
      // The native view may have been detached while a page was finishing.
    }
  }

  Future<void> _back() async {
    if (await controller?.canGoBack() ?? false) {
      await controller!.goBack();
      await _updateHistory();
    } else if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _reload() async {
    setState(() {
      error = null;
      progress = 0;
    });
    try {
      if (controller == null) {
        await _initialize();
      } else {
        await controller!.reload();
      }
    } catch (_) {
      if (mounted) setState(() => error = "Playを読み込めませんでした");
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = controller;
    final supported = WebViewPlatform.instance != null && isPlayUri(widget.uri);
    return PopScope<void>(
      canPop: !canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _back,
            icon: const Icon(Icons.arrow_back),
            tooltip: "戻る",
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title ?? "Play",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(widget.uri.host, style: const TextStyle(fontSize: 11)),
            ],
          ),
          actions: [
            if (supported)
              IconButton(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                tooltip: "再読み込み",
              ),
          ],
        ),
        body: SafeArea(
          child: !supported
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("この環境ではブラウザーでPlayを開けます"),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: isPlayUri(widget.uri)
                              ? () => launchUrl(
                                  widget.uri,
                                  mode: LaunchMode.externalApplication,
                                )
                              : null,
                          child: const Text("ブラウザーで開く"),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (progress < 100 && error == null)
                      LinearProgressIndicator(value: progress / 100),
                    Expanded(
                      child: error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(error!),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: _reload,
                                    child: const Text("再試行"),
                                  ),
                                ],
                              ),
                            )
                          : view == null
                          ? const Center(child: CircularProgressIndicator())
                          : WebViewWidget(controller: view),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
