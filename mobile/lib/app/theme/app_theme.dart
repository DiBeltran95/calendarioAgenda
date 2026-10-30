import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_module.dart';
import 'palette.dart';
import 'tokens.dart';

/// Plus Jakarta Sans va incluida en la app (`assets/fonts`): se ve igual desde
/// la primera apertura, aunque no haya internet.
const fuenteApp = 'PlusJakartaSans';

TextStyle _t(double size, FontWeight peso, double alto, double espaciado, Color color) =>
    TextStyle(fontFamily: fuenteApp, fontSize: size, fontWeight: peso, height: alto, letterSpacing: espaciado, color: color);

/// Construye el [ThemeData] de un módulo en un brillo dado.
///
/// Todo sale de tokens: ningún widget debería necesitar un hex propio.
ThemeData buildTheme(Brightness brightness, AppModule module) {
  final p = Palette.of(brightness, module.accent(brightness), module.secondary(brightness));
  final dark = brightness == Brightness.dark;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.accent,
    onPrimary: p.onAccent,
    primaryContainer: Color.alphaBlend(p.accent.withValues(alpha: 0.18), p.surface),
    onPrimaryContainer: p.text,
    secondary: p.accent2,
    onSecondary: p.onAccent,
    secondaryContainer: Color.alphaBlend(p.accent2.withValues(alpha: 0.18), p.surface),
    onSecondaryContainer: p.text,
    tertiary: p.gold,
    onTertiary: p.onAccent,
    error: p.danger,
    onError: dark ? const Color(0xFF1F0707) : Colors.white,
    surface: p.surface,
    onSurface: p.text,
    onSurfaceVariant: p.textSecondary,
    surfaceContainerLowest: p.bg,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surfaceHigh,
    surfaceContainerHighest: p.surfaceHighest,
    outline: p.border,
    outlineVariant: p.border,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: p.text,
    onInverseSurface: p.bg,
    inversePrimary: p.accent,
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(
    useMaterial3: true,
    fontFamily: fuenteApp,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    extensions: [p],
  );

  final textTheme = base.textTheme.copyWith(
    // Escala de la app: nada por debajo de 12 px.
    displaySmall: _t(34, FontWeight.w800, 1.15, -0.8, p.text),
    headlineMedium: _t(28, FontWeight.w700, 1.2, -0.5, p.text),
    headlineSmall: _t(24, FontWeight.w700, 1.25, -0.4, p.text),
    titleLarge: _t(20, FontWeight.w600, 1.3, -0.2, p.text),
    titleMedium: _t(17, FontWeight.w600, 1.35, -0.1, p.text),
    titleSmall: _t(15, FontWeight.w600, 1.35, 0, p.text),
    bodyLarge: _t(16, FontWeight.w400, 1.5, 0, p.text),
    bodyMedium: _t(15, FontWeight.w400, 1.5, 0, p.text),
    bodySmall: _t(13.5, FontWeight.w400, 1.45, 0, p.textSecondary),
    labelLarge: _t(14, FontWeight.w600, 1.2, 0, p.text),
    labelMedium: _t(13, FontWeight.w500, 1.2, 0, p.textSecondary),
    labelSmall: _t(12, FontWeight.w600, 1.2, 0.2, p.textSecondary),
  );

  final fieldBorder = OutlineInputBorder(
    borderRadius: Radii.rMd,
    borderSide: BorderSide(color: p.border),
  );

  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    iconTheme: IconThemeData(color: p.text, size: IconSizes.lg),
    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      foregroundColor: p.text,
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: Radii.rLg, side: BorderSide(color: p.bordeTarjeta)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.md),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(borderSide: BorderSide(color: p.accent, width: 1.6)),
      errorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: p.danger)),
      focusedErrorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: p.danger, width: 1.6)),
      labelStyle: textTheme.bodyMedium?.copyWith(color: p.textSecondary),
      floatingLabelStyle: textTheme.bodyMedium?.copyWith(color: p.accent, fontWeight: FontWeight.w600),
      hintStyle: textTheme.bodyMedium?.copyWith(color: p.textSecondary.withValues(alpha: 0.8)),
      helperStyle: textTheme.bodySmall,
      errorStyle: textTheme.bodySmall?.copyWith(color: p.danger),
      prefixIconColor: p.textSecondary,
      suffixIconColor: p.textSecondary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
        shape: RoundedRectangleBorder(borderRadius: Radii.rMd),
        textStyle: textTheme.labelLarge,
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        disabledBackgroundColor: p.surfaceHighest,
        disabledForegroundColor: p.textSecondary.withValues(alpha: 0.6),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        shape: RoundedRectangleBorder(borderRadius: Radii.rMd),
        side: BorderSide(color: p.border),
        foregroundColor: p.text,
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        foregroundColor: p.accent,
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: Radii.rSm),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: p.text),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.accent,
      foregroundColor: p.onAccent,
      elevation: 2,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(borderRadius: Radii.rLg),
      extendedTextStyle: textTheme.labelLarge?.copyWith(color: p.onAccent),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surfaceHigh,
      selectedColor: Color.alphaBlend(p.accent.withValues(alpha: 0.22), p.surfaceHigh),
      side: BorderSide(color: p.border),
      shape: RoundedRectangleBorder(borderRadius: Radii.rSm),
      labelStyle: textTheme.labelMedium?.copyWith(color: p.text),
      secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: p.text),
      checkmarkColor: p.accent,
      padding: const EdgeInsets.symmetric(horizontal: Gap.xs, vertical: Gap.xxs),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: p.surface,
      showDragHandle: true,
      dragHandleColor: p.textSecondary.withValues(alpha: 0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
      modalBarrierColor: Colors.black.withValues(alpha: 0.55),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: Radii.rXl),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: p.textSecondary),
      barrierColor: Colors.black.withValues(alpha: 0.55),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? p.surfaceHighest : p.text,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: dark ? p.text : p.bg),
      actionTextColor: p.accent,
      shape: RoundedRectangleBorder(borderRadius: Radii.rMd),
      insetPadding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Color.alphaBlend(p.accent.withValues(alpha: 0.2), p.surface),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => textTheme.labelMedium?.copyWith(
            color: s.contains(WidgetState.selected) ? p.text : p.textSecondary,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? p.accent : p.textSecondary,
            size: IconSizes.lg,
          )),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onAccent : p.textSecondary),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.surfaceHighest),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : Colors.transparent),
      checkColor: WidgetStateProperty.all(p.onAccent),
      side: BorderSide(color: p.textSecondary, width: 1.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.surfaceHighest,
      circularTrackColor: p.surfaceHighest,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: dark ? p.surfaceHighest : p.text, borderRadius: Radii.rSm),
      textStyle: textTheme.bodySmall?.copyWith(color: dark ? p.text : p.bg),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.textSecondary,
      textColor: p.text,
      shape: RoundedRectangleBorder(borderRadius: Radii.rMd),
      contentPadding: const EdgeInsets.symmetric(horizontal: Gap.md),
      minVerticalPadding: Gap.sm,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: Color.alphaBlend(p.accent.withValues(alpha: 0.15), p.surface),
      headerForegroundColor: p.text,
      shape: RoundedRectangleBorder(borderRadius: Radii.rXl),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: Radii.rXl),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
