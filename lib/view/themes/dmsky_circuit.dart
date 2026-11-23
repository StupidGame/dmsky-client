// SPDX-FileCopyrightText: 2026 DMSKY contributors
// SPDX-License-Identifier: AGPL-3.0-only

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:dmsky_client/model/color_theme.dart";

const dmskyLightThemeId = "5d2c7a22-5492-4fb6-95b5-ef92e6135c16";
const dmskyDarkThemeId = "a4582ef4-3242-4e29-a91d-92cc45fb1741";

// The values come from DMSKY's l-dmsky.json5 and d-dmsky.json5.
const dmskyColorThemes = [
  ColorTheme(
    id: dmskyLightThemeId,
    name: "DMSKY Circuit Light",
    isDarkTheme: false,
    primary: Color(0xff087eb8),
    primaryDarken: Color(0xff05618d),
    primaryLighten: Color(0xff5ae7ff),
    accentedBackground: Color(0x1f087eb8),
    background: Color(0xffe6f4fa),
    foreground: Color(0xff143047),
    renote: Color(0xff087c64),
    mention: Color(0xff9a4e00),
    hashtag: Color(0xff075eaa),
    link: Color(0xff075eaa),
    divider: Color(0x3d1d73a1),
    buttonBackground: Color(0xffd8edf8),
    buttonGradateA: Color(0xff087eb8),
    buttonGradateB: Color(0xff326ad0),
    panel: Color(0xfff7fcff),
    panelBackground: Color(0xffe6f5fd),
  ),
  ColorTheme(
    id: dmskyDarkThemeId,
    name: "DMSKY Circuit Dark",
    isDarkTheme: true,
    primary: Color(0xff31d8f5),
    primaryDarken: Color(0xff12b9e9),
    primaryLighten: Color(0xff71e7ff),
    accentedBackground: Color(0x2931d8f5),
    background: Color(0xff081321),
    foreground: Color(0xffe8f6ff),
    renote: Color(0xff62d6b3),
    mention: Color(0xffffc775),
    hashtag: Color(0xff71e7ff),
    link: Color(0xff71e7ff),
    divider: Color(0x3d68dcff),
    buttonBackground: Color(0xff1b3a56),
    buttonGradateA: Color(0xff12b9e9),
    buttonGradateB: Color(0xff4a82ff),
    panel: Color(0xff12263b),
    panelBackground: Color(0xff173450),
  ),
];

bool isDmskyTheme(ColorTheme theme) =>
    theme.id == dmskyLightThemeId || theme.id == dmskyDarkThemeId;

const dmskyGold = Color(0xffffc953);
const dmskyGoldLight = Color(0xffffeaa5);
const dmskyGoldInk = Color(0xff38240a);
const dmskyCyan = Color(0xff51edff);
const dmskySilver = Color(0xff8ea6b8);
const dmskyFrameShape = BeveledRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(10)),
);

enum DmskyPanelStyle { blue, surface }

/// A clipped metal bezel around a blue display or a readable content surface.
class DmskyPanel extends StatelessWidget {
  const DmskyPanel({
    required this.child,
    this.active = false,
    this.style = DmskyPanelStyle.blue,
    this.clipBehavior = Clip.antiAlias,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final bool active;
  final DmskyPanelStyle style;
  final Clip clipBehavior;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = style == DmskyPanelStyle.surface;
    final accent = active ? dmskyGold : dmskyCyan;
    final fill = active
        ? const [Color(0xfffff0ad), Color(0xffffc33b), Color(0xffba7419)]
        : surface
        ? [
            Color.alphaBlend(
              accent.withValues(alpha: .045),
              theme.colorScheme.surface,
            ),
            theme.colorScheme.surface,
            Color.alphaBlend(
              accent.withValues(alpha: .025),
              theme.colorScheme.surface,
            ),
          ]
        : const [Color(0xff1678bf), Color(0xff123e77), Color(0xff0b2246)];
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: dmskyFrameShape.copyWith(
            side: const BorderSide(color: Color(0xff061321)),
          ),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xffe2edf1),
              Color(0xff71899c),
              Color(0xffd7e9f2),
              Color(0xff263c52),
            ],
            stops: [0, .32, .51, 1],
          ),
          shadows: [
            BoxShadow(
              color: active
                  ? dmskyGold.withValues(alpha: .35)
                  : const Color(0x39000814),
              offset: Offset(0, 2),
              blurRadius: active ? 8 : 3,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(2.5),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: const BeveledRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                side: BorderSide(color: Color(0xff071525), width: 1.5),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: fill,
                stops: const [0, .46, 1],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(1.5),
              child: ClipPath(
                clipBehavior: clipBehavior,
                clipper: const ShapeBorderClipper(
                  shape: BeveledRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(7)),
                  ),
                ),
                child: CustomPaint(
                  foregroundPainter: _PanelEdgePainter(
                    accent: accent,
                    subtle: surface,
                  ),
                  child: Padding(padding: padding, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelEdgePainter extends CustomPainter {
  const _PanelEdgePainter({required this.accent, required this.subtle});
  final Color accent;
  final bool subtle;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final outline = const BeveledRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(7)),
    ).getOuterPath(rect.deflate(.5));
    canvas.drawPath(
      outline,
      Paint()
        ..color = accent.withValues(alpha: subtle ? .35 : .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    if (!subtle) {
      final scan = Paint()..color = Colors.white.withValues(alpha: .035);
      for (double y = 4; y < size.height; y += 4) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), scan);
      }
      canvas.drawLine(
        Offset(10, 2),
        Offset(size.width - 10, 2),
        Paint()
          ..color = Colors.white.withValues(alpha: .45)
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_PanelEdgePainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.subtle != subtle;
}

/// Static decoration stays behind content and never intercepts taps.
class DmskyBackdrop extends StatelessWidget {
  const DmskyBackdrop({required this.child, this.dark, super.key});
  final Widget child;
  final bool? dark;

  @override
  Widget build(BuildContext context) {
    final isDark = dark ?? Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xff10345a), Color(0xff07182d), Color(0xff0b2441)]
              : const [Color(0xffd9f5ff), Color(0xffedf9fd), Color(0xffbcdff1)],
        ),
      ),
      child: CustomPaint(
        painter: _CircuitGridPainter(dark: isDark),
        child: child,
      ),
    );
  }
}

class _CircuitGridPainter extends CustomPainter {
  const _CircuitGridPainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = (dark ? dmskyCyan : const Color(0xff136e9a)).withValues(
        alpha: dark ? .065 : .05,
      )
      ..strokeWidth = .6;
    for (double x = -size.height; x < size.width; x += 72) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height * .3, size.height),
        grid,
      );
    }
    for (double y = 0; y < size.height; y += 72) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y - size.width * .07),
        grid,
      );
    }
    final circuit = Paint()
      ..color = dmskyCyan.withValues(alpha: dark ? .25 : .28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(
      Path()
        ..moveTo(size.width - 76, 0)
        ..lineTo(size.width - 76, 28)
        ..lineTo(size.width - 28, 76)
        ..lineTo(size.width, 76),
      circuit,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - 96)
        ..lineTo(24, size.height - 96)
        ..lineTo(56, size.height - 64)
        ..lineTo(56, size.height),
      circuit,
    );
  }

  @override
  bool shouldRepaint(_CircuitGridPainter oldDelegate) =>
      oldDelegate.dark != dark;
}

class DmskyHeader extends StatelessWidget {
  const DmskyHeader({this.child = const SizedBox.expand(), super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff124e80), Color(0xff091c34), Color(0xff103966)],
      ),
      border: Border(bottom: BorderSide(color: dmskyCyan, width: 1.5)),
    ),
    child: child,
  );
}

/// Decodes the shared emblem at its display resolution instead of full size.
class DmskyEmblem extends StatelessWidget {
  const DmskyEmblem({this.size = 48, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      "assets/branding/dmsky-emblem.png",
      width: size,
      height: size,
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
      excludeFromSemantics: true,
    );
  }
}

class DmskyBrand extends StatelessWidget {
  const DmskyBrand({this.large = false, super.key});

  final bool large;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DmskyEmblem(size: large ? 88 : 48),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "DMSKY",
              style: TextStyle(
                fontSize: large ? 34 : 25,
                letterSpacing: 4,
                fontWeight: FontWeight.w900,
                color: dmskyGoldLight,
                shadows: const [
                  Shadow(color: Color(0xff06131f), offset: Offset(1, 2)),
                ],
              ),
            ),
            const Text(
              "MISSKEY CLIENT",
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.5,
                color: dmskyCyan,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class DmskyMenuTile extends StatelessWidget {
  const DmskyMenuTile({
    required this.leading,
    required this.title,
    required this.onTap,
    this.selected = false,
    this.style = DmskyPanelStyle.blue,
    super.key,
  });

  final Widget leading;
  final Widget title;
  final VoidCallback onTap;
  final bool selected;
  final DmskyPanelStyle style;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? dmskyGoldInk
        : style == DmskyPanelStyle.surface
        ? Theme.of(context).colorScheme.onSurface
        : const Color(0xfff1fbff);
    return DmskyPanel(
      active: selected,
      style: style,
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              shape: const BeveledRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(7)),
                side: BorderSide(color: Color(0x8851edff)),
              ),
              gradient: LinearGradient(
                colors: selected
                    ? const [Color(0xfffff1b3), Color(0xffc58b26)]
                    : const [Color(0xff146fac), Color(0xff0c2d57)],
              ),
            ),
            child: IconTheme(
              data: IconThemeData(
                color: selected ? dmskyGoldInk : Colors.white,
                size: 21,
              ),
              child: leading,
            ),
          ),
          title: title,
          trailing: Icon(
            Icons.chevron_right,
            color: foreground.withValues(alpha: .7),
            size: 18,
          ),
          titleTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: foreground,
          ),
          textColor: foreground,
          iconColor: foreground,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 2,
          ),
          minVerticalPadding: 8,
          onTap: onTap,
        ),
      ),
    );
  }
}

ThemeData applyDmskyCircuit(ThemeData base, ColorTheme colors) {
  if (!isDmskyTheme(colors)) return base;

  final framedButton =
      ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xff124e80),
        disabledForegroundColor: Colors.white.withValues(alpha: .45),
        minimumSize: const Size(48, 48),
        shape: dmskyFrameShape,
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ).copyWith(
        backgroundBuilder: (context, states, child) => Opacity(
          opacity: states.contains(WidgetState.disabled) ? .5 : 1,
          child: DmskyPanel(child: child ?? const SizedBox()),
        ),
      );

  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: colors.panel,
    colorScheme: base.colorScheme.copyWith(
      surface: colors.panel,
      onSurface: colors.foreground,
      onPrimary: colors.isDarkTheme ? const Color(0xff06131f) : Colors.white,
      secondary: dmskyGold,
      onSecondary: dmskyGoldInk,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: const Color(0xff0a203b),
      foregroundColor: const Color(0xfff1fbff),
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: .6,
        color: dmskyGoldLight,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      shape: const Border(bottom: BorderSide(color: dmskyCyan, width: 1.5)),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Color(0xff0a1b2e),
      shape: Border(right: BorderSide(color: dmskyCyan, width: 1.5)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: framedButton),
    filledButtonTheme: FilledButtonThemeData(style: framedButton),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            foregroundColor: const Color(0xfff1fbff),
            minimumSize: const Size(48, 48),
            shape: dmskyFrameShape,
            textStyle: base.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ).copyWith(
            backgroundBuilder: (context, states, child) =>
                DmskyPanel(child: child ?? const SizedBox()),
          ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: dmskyGold,
      foregroundColor: dmskyGoldInk,
      shape: BeveledRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: dmskyGoldLight, width: 2),
      ),
    ),
    tabBarTheme: base.tabBarTheme.copyWith(
      labelColor: dmskyGoldInk,
      unselectedLabelColor: const Color(0xffd7edfb),
      labelStyle: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: const ShapeDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [dmskyGoldLight, dmskyGold, Color(0xffdba13b)],
          stops: [0, .5, 1],
        ),
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: dmskySilver, width: 1.5),
        ),
      ),
      overlayColor: WidgetStatePropertyAll(dmskyCyan.withValues(alpha: .12)),
    ),
    bottomAppBarTheme: const BottomAppBarThemeData(color: Color(0xff0c2035)),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xff0a1b2e),
      selectedItemColor: dmskyGold,
      unselectedItemColor: Color(0xffd7edfb),
    ),
    cardTheme: CardThemeData(
      color: colors.panel,
      elevation: 0,
      shape: BeveledRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: dmskySilver),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.panel,
      shape: const BeveledRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: dmskySilver, width: 2),
      ),
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: colors.isDarkTheme ? dmskyGoldLight : colors.foreground,
        fontWeight: FontWeight.w700,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.panel,
      shape: const BeveledRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: dmskySilver),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.panel,
      shape: const BeveledRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        side: BorderSide(color: dmskySilver),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      radius: const Radius.circular(2),
      thickness: const WidgetStatePropertyAll(4),
      thumbColor: WidgetStatePropertyAll(colors.primary.withValues(alpha: .7)),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: colors.isDarkTheme
          ? const Color(0xff091e35)
          : const Color(0xfff3fbff),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: colors.isDarkTheme ? dmskySilver : const Color(0xff5d7f98),
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: colors.primary, width: 2),
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}
