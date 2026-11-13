import "package:flutter/material.dart";
import "package:dmsky_client/model/tab_setting.dart";
import "package:dmsky_client/view/common/tab_icon_view.dart";
import "package:dmsky_client/view/themes/dmsky_circuit.dart";

/// Keeps account identity visible, including when tabs share the same name.
class TimelineTabLabel extends StatelessWidget {
  const TimelineTabLabel({required this.tabSetting, this.color, super.key});

  final TabSetting tabSetting;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final title = tabSetting.name ?? tabSetting.tabType.displayName(context);
    return Tooltip(
      message: "$title\n${tabSetting.acct}",
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            tabSetting.acct.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 10, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class TimelineTabButton extends StatelessWidget {
  const TimelineTabButton({
    required this.tabSetting,
    required this.active,
    required this.onPressed,
    super.key,
  });

  final TabSetting tabSetting;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = active ? dmskyGoldInk : Colors.white;
    return DmskyPanel(
      active: active,
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: Semantics(
        selected: active,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TabIconView(icon: tabSetting.icon, color: color, size: 22),
                const SizedBox(width: 6),
                Flexible(
                  child: TimelineTabLabel(tabSetting: tabSetting, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
