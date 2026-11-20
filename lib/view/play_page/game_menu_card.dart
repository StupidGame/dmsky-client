import 'package:flutter/material.dart';
import 'package:dmsky_client/view/themes/dmsky_circuit.dart';

class GameMenuCard extends StatelessWidget {
  const GameMenuCard({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => DmskyPanel(
    style: DmskyPanelStyle.surface,
    margin: const EdgeInsets.symmetric(vertical: 6),
    child: Material(color: Colors.transparent, child: child),
  );
}
