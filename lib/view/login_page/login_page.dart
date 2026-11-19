import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:dmsky_client/l10n/app_localizations.dart";
import "package:dmsky_client/view/login_page/api_key_login.dart";
import "package:dmsky_client/view/login_page/mi_auth_login.dart";
import "package:dmsky_client/view/themes/dmsky_circuit.dart";

@RoutePage()
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: DmskyBackdrop(
          dark: true,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 960;
                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(wide ? 48 : 20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: wide
                          ? Row(
                              children: [
                                const Expanded(child: _Welcome()),
                                const SizedBox(width: 64),
                                SizedBox(width: 440, child: _LoginPanel()),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const DmskyBrand(large: true),
                                const SizedBox(height: 28),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 440,
                                  ),
                                  child: _LoginPanel(),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  "あなたのサーバーから、つながる世界へ。",
                                  style: TextStyle(color: Color(0xffd7edfb)),
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DmskyBrand(large: true),
        SizedBox(height: 40),
        Text(
          "あなたのサーバーから、\nつながる世界へ。",
          style: TextStyle(
            fontSize: 36,
            height: 1.5,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 20),
        Text(
          "好きな話題も、いつもの仲間も。\nMisskey の世界を、DMSKY の画面で。",
          style: TextStyle(fontSize: 16, height: 1.9, color: Color(0xffd7edfb)),
        ),
        SizedBox(height: 36),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _FeatureChip(Icons.hub_outlined, "複数アカウント"),
            _FeatureChip(Icons.auto_awesome_outlined, "MFM・リアクション"),
            _FeatureChip(Icons.view_column_outlined, "デッキ表示"),
          ],
        ),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DmskyPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: dmskyCyan, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _LoginPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DmskyPanel(
      style: DmskyPanelStyle.surface,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DmskyHeader(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Text(
                  S.of(context).login,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: dmskyGoldLight,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Text("利用している Misskey サーバーのアドレスを入力してください。"),
            ),
            Container(
              color: const Color(0xff0c2035),
              child: TabBar(
                tabs: [
                  Tab(text: S.of(context).loginAsMiAuth),
                  Tab(text: S.of(context).loginAsAPIKey),
                ],
              ),
            ),
            const SizedBox(
              height: 290,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: TabBarView(children: [MiAuthLogin(), ApiKeyLogin()]),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "DMSKY Client · Based on Miria · AGPL-3.0",
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
