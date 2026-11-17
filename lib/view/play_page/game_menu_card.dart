import 'package:flutter/material.dart';

class GameMenuCard extends StatelessWidget {
  const GameMenuCard({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 5),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
    ),
    child: child,
  );
}
