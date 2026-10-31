import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:dmsky_client/l10n/app_localizations.dart";
import "package:dmsky_client/providers.dart";
import "package:dmsky_client/view/common/account_scope.dart";
import "package:dmsky_client/view/federation_page/federation_announcements.dart";

@RoutePage()
class AnnouncementPage extends StatelessWidget implements AutoRouteWrapper {
  final AccountContext accountContext;

  const AnnouncementPage({required this.accountContext, super.key});

  @override
  Widget wrappedRoute(BuildContext context) =>
      AccountContextScope(context: accountContext, child: this);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).announcement)),
      body: Padding(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: FederationAnnouncements(host: accountContext.getAccount.host),
      ),
    );
  }
}
