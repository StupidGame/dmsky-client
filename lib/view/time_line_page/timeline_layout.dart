import "package:flutter/widgets.dart";

/// Selects a timeline layout without building the inactive layout.
class TimelineLayout extends StatelessWidget {
  final bool deckMode;
  final WidgetBuilder compactBuilder;
  final WidgetBuilder deckBuilder;

  const TimelineLayout({
    required this.deckMode,
    required this.compactBuilder,
    required this.deckBuilder,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Use the shortest side so rotating a phone keeps the compact layout.
    final canShowDeck = MediaQuery.sizeOf(context).shortestSide >= 600;
    return (deckMode && canShowDeck ? deckBuilder : compactBuilder)(context);
  }
}
