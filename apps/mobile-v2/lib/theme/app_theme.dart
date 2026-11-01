/// Design tokens — Material theme assembly.
///
/// Wires the palette ([AppColors]) and the type scale ([AppTypography]) into a
/// single [ThemeData]. Screens read colour and type through
/// `Theme.of(context)` / the token classes; this file is the only place where
/// raw tokens become widget defaults.
///
/// TextTheme slot mapping (design-spec §2.3 — seven levels, no more):
///
/// | TextTheme slot     | scale level | ink                  |
/// | ------------------ | ----------- | -------------------- |
/// | displayLarge       | Display     | `--ink`              |
/// | displayMedium      | Title       | `--ink`              |
/// | displaySmall       | H2          | `--ink`              |
/// | headlineLarge      | Title       | `--ink`              |
/// | headlineMedium     | H2          | `--ink`              |
/// | headlineSmall      | H2          | `--ink`              |
/// | titleLarge         | H2          | `--ink`              |
/// | titleMedium        | Body 600    | `--ink`              |
/// | titleSmall         | Body        | `--ink`              |
/// | bodyLarge          | Reading     | `--ink`              |
/// | bodyMedium         | Body        | `--ink`              |
/// | bodySmall          | Meta        | `--ink-3`            |
/// | labelLarge         | Body 600    | `--ink`              |
/// | labelMedium        | Meta        | `--ink-2`            |
/// | labelSmall         | Label       | `--ink-2`            |
///
/// `bodyMedium` is the app-wide `DefaultTextStyle`, so plain `Text` inherits
/// Body/ink without any per-call styling.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Hand-written light scheme (design-spec §2.1).
///
/// Deliberately not `ColorScheme.fromSeed`: seeding invents tonal colours that
/// are not in the paper palette (M3 would derive a lavender tertiary and a
/// neutral surface ramp). Every slot below points at a named token instead.
const ColorScheme appColorScheme = ColorScheme(
  brightness: Brightness.light,
  // Brand: violet means "actionable / current / selected" and nothing else.
  primary: AppColors.primary,
  onPrimary: AppColors.onPrimary,
  primaryContainer: AppColors.primarySoft,
  onPrimaryContainer: AppColors.primaryStrong,
  // Warm accent: decorative, so its container text uses `--accent-strong`.
  secondary: AppColors.accent,
  onSecondary: AppColors.ink,
  secondaryContainer: AppColors.accentSoft,
  onSecondaryContainer: AppColors.accentStrong,
  // Quiet information (quiz labels, static notes).
  tertiary: AppColors.tealInk,
  onTertiary: AppColors.surface,
  tertiaryContainer: AppColors.tealBg,
  onTertiaryContainer: AppColors.tealInk,
  // Blocked / cannot continue.
  error: AppColors.dangerInk,
  onError: AppColors.onPrimary,
  errorContainer: AppColors.dangerBg,
  onErrorContainer: AppColors.dangerInk,
  // Paper surfaces: elevation is expressed by tone steps, never by shadow.
  surface: AppColors.surface,
  onSurface: AppColors.ink,
  onSurfaceVariant: AppColors.ink2,
  surfaceDim: AppColors.paperDeep,
  surfaceBright: AppColors.surfaceRaised,
  surfaceContainerLowest: AppColors.surfaceRaised,
  surfaceContainerLow: AppColors.surface,
  surfaceContainer: AppColors.surfaceSunken,
  surfaceContainerHigh: AppColors.surfaceSunken,
  surfaceContainerHighest: AppColors.paperDeep,
  outline: AppColors.lineStrong,
  outlineVariant: AppColors.line,
  // Shadows are ink-tinted (app.css `--shadow-card` alpha stops), not black.
  shadow: AppColors.ink,
  scrim: AppColors.ink,
  inverseSurface: AppColors.ink,
  onInverseSurface: AppColors.paper,
  inversePrimary: AppColors.primarySoft,
);

/// Status-bar / gesture-bar treatment: transparent status bar over paper, dark
/// icons (design-spec §2.1 uses a warm paper status band, never a dark bar).
const SystemUiOverlayStyle appSystemOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: AppColors.paper,
  systemNavigationBarIconBrightness: Brightness.dark,
);

/// CTA geometry (design-spec §2.4): 56 dp tall, pill, 20 dp gutters.
const Size _ctaMinimumSize = Size(0, 56);
const EdgeInsetsGeometry _ctaPadding = EdgeInsets.symmetric(horizontal: 20);
const OutlinedBorder _pillShape = StadiumBorder();

/// `--dur-fast`: press / colour transitions settle in 150 ms.
const Duration _buttonMotion = Duration(milliseconds: 150);

/// Filled CTA (`.btn--primary` in app.css): brand fill, white label, pressed
/// fill deepens to `--primary-strong`, disabled uses the `.btn:disabled` pair.
ButtonStyle _ctaStyle({
  required Color fill,
  required Color pressedFill,
  required Color label,
}) {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll<Size>(_ctaMinimumSize),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(_ctaPadding),
    shape: const WidgetStatePropertyAll<OutlinedBorder>(_pillShape),
    elevation: const WidgetStatePropertyAll<double>(0),
    animationDuration: _buttonMotion,
    textStyle: WidgetStatePropertyAll<TextStyle>(
      AppTypography.body.copyWith(fontWeight: FontWeight.w600),
    ),
    backgroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) return AppColors.disabledFill;
        if (states.contains(WidgetState.pressed)) return pressedFill;
        return fill;
      },
    ),
    foregroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) return AppColors.disabledInk;
        return label;
      },
    ),
  );
}

/// Ghost / text action (`.btn--ghost`): transparent, 46 dp tall, `--primary`
/// label, `--ink-3` when disabled.
ButtonStyle _textActionStyle() {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 46)),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(_ctaPadding),
    shape: const WidgetStatePropertyAll<OutlinedBorder>(_pillShape),
    animationDuration: _buttonMotion,
    textStyle: WidgetStatePropertyAll<TextStyle>(
      AppTypography.body.copyWith(fontWeight: FontWeight.w600),
    ),
    foregroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) {
        if (states.contains(WidgetState.disabled)) return AppColors.ink3;
        return AppColors.primary;
      },
    ),
  );
}

TextTheme _buildTextTheme() {
  return TextTheme(
    displayLarge: AppTypography.display.copyWith(color: AppColors.ink),
    displayMedium: AppTypography.title.copyWith(color: AppColors.ink),
    displaySmall: AppTypography.h2.copyWith(color: AppColors.ink),
    headlineLarge: AppTypography.title.copyWith(color: AppColors.ink),
    headlineMedium: AppTypography.h2.copyWith(color: AppColors.ink),
    headlineSmall: AppTypography.h2.copyWith(color: AppColors.ink),
    titleLarge: AppTypography.h2.copyWith(color: AppColors.ink),
    titleMedium: AppTypography.body
        .copyWith(fontWeight: FontWeight.w600, color: AppColors.ink),
    titleSmall: AppTypography.body.copyWith(color: AppColors.ink),
    bodyLarge: AppTypography.reading.copyWith(color: AppColors.ink),
    bodyMedium: AppTypography.body.copyWith(color: AppColors.ink),
    bodySmall: AppTypography.meta.copyWith(color: AppColors.ink3),
    labelLarge: AppTypography.body
        .copyWith(fontWeight: FontWeight.w600, color: AppColors.ink),
    labelMedium: AppTypography.meta.copyWith(color: AppColors.ink2),
    labelSmall: AppTypography.label.copyWith(color: AppColors.ink2),
  );
}

ThemeData _createAppTheme() {
  final TextTheme textTheme = _buildTextTheme();
  final ButtonStyle cta = _ctaStyle(
    fill: AppColors.primary,
    pressedFill: AppColors.primaryStrong,
    label: AppColors.onPrimary,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: appColorScheme,
    // Page ground: warm paper, not the scheme's white surface.
    scaffoldBackgroundColor: AppColors.paper,
    canvasColor: AppColors.paper,
    primaryColor: AppColors.primary,
    dividerColor: AppColors.line,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarThemeData(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: 20,
      titleTextStyle: AppTypography.body
          .copyWith(fontWeight: FontWeight.w600, color: AppColors.ink),
      systemOverlayStyle: appSystemOverlayStyle,
    ),
    filledButtonTheme: FilledButtonThemeData(style: cta),
    elevatedButtonTheme: ElevatedButtonThemeData(style: cta),
    textButtonTheme: TextButtonThemeData(style: _textActionStyle()),
    dividerTheme: const DividerThemeData(color: AppColors.line),
  );
}

/// Built once: `StoryApp` rebuilds on every locale swap, and handing
/// `MaterialApp` an identical instance keeps the theme animation idle.
final ThemeData _appTheme = _createAppTheme();

/// The app theme. Pure (no `BuildContext`), so tests and screens can read
/// tokens without a widget tree.
ThemeData buildAppTheme() => _appTheme;
