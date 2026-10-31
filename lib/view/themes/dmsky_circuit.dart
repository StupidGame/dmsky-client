// SPDX-FileCopyrightText: 2026 DMSKY contributors
// SPDX-License-Identifier: AGPL-3.0-only

import "package:flutter/material.dart";
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
const dmskySilver = Color(0xff697c91);

/// The same layered metallic frame and blue screen used by the DMSKY web UI.
class DmskyPanel extends StatelessWidget {
  const DmskyPanel({
    required this.child,
    this.active = false,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final bool active;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xffd0e0e9),
            dmskySilver,
            Color(0xffd2e4ee),
            Color(0xff3f566d),
          ],
          stops: [0, .3, .52, 1],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000814),
            offset: Offset(0, 2),
            blurRadius: 3,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: active ? dmskyGold : const Color(0xff254158),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: active
                ? [dmskyGoldLight, dmskyGold]
                : [const Color(0xff195f9c), const Color(0xff103e80)],
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
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
        Image.asset(
          "assets/branding/dmsky-emblem.png",
          width: large ? 88 : 48,
          height: large ? 88 : 48,
          excludeFromSemantics: true,
        ),
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
                color: const Color(0xffeefaff),
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
    super.key,
  });

  final Widget leading;
  final Widget title;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return DmskyPanel(
      active: selected,
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: leading,
          title: title,
          textColor: selected ? dmskyGoldInk : const Color(0xfff1fbff),
          iconColor: selected ? dmskyGoldInk : const Color(0xfff1fbff),
          minVerticalPadding: 6,
          visualDensity: VisualDensity.compact,
          onTap: onTap,
        ),
      ),
    );
  }
}

ThemeData applyDmskyCircuit(ThemeData base, ColorTheme colors) {
  if (!isDmskyTheme(colors)) return base;

  final goldButton =
      ElevatedButton.styleFrom(
        foregroundColor: dmskyGoldInk,
        backgroundColor: dmskyGold,
        disabledForegroundColor: dmskyGoldInk.withValues(alpha: .45),
        minimumSize: const Size(48, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ).copyWith(
        backgroundBuilder: (context, states, child) => DmskyPanel(
          active: !states.contains(WidgetState.disabled),
          child: child ?? const SizedBox(),
        ),
      );

  return base.copyWith(
    scaffoldBackgroundColor: colors.background,
    canvasColor: colors.panel,
    colorScheme: base.colorScheme.copyWith(
      surface: colors.panel,
      onSurface: colors.foreground,
      onPrimary: colors.isDarkTheme ? const Color(0xff06131f) : Colors.white,
      secondary: dmskyGold,
      onSecondary: dmskyGoldInk,
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: const Color(0xff0c2035),
      foregroundColor: const Color(0xfff1fbff),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xfff1fbff),
      ),
      shape: const Border(bottom: BorderSide(color: dmskySilver, width: 2)),
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Color(0xff0a1b2e),
      shape: Border(right: BorderSide(color: dmskySilver, width: 2)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: goldButton),
    filledButtonTheme: FilledButtonThemeData(style: goldButton),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            foregroundColor: const Color(0xfff1fbff),
            minimumSize: const Size(48, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ).copyWith(
            backgroundBuilder: (context, states, child) =>
                DmskyPanel(child: child ?? const SizedBox()),
          ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: dmskyGold,
      foregroundColor: dmskyGoldInk,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(5)),
        side: BorderSide(color: dmskySilver, width: 2),
      ),
    ),
    tabBarTheme: base.tabBarTheme.copyWith(
      labelColor: dmskyGoldLight,
      unselectedLabelColor: const Color(0xffc3dce9),
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: dmskyGold, width: 3),
      ),
    ),
    bottomAppBarTheme: const BottomAppBarThemeData(color: Color(0xff0c2035)),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xff0a1b2e),
      selectedItemColor: dmskyGold,
      unselectedItemColor: Color(0xffd7edfb),
    ),
    cardTheme: CardThemeData(
      color: colors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: dmskySilver),
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: colors.divider),
        borderRadius: BorderRadius.circular(4),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: colors.primary, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}
