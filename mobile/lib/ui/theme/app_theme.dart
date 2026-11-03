import 'package:flutter/material.dart';

/// Light-theme tokens from docs/DESIGN.md. Keep their values in sync with it.
class AppColors {
  static const primary = Color(0xFF2563EB);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFDBEAFE);
  static const onPrimaryContainer = Color(0xFF1E3A8A);
  static const secondary = Color(0xFF0F766E);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFCCFBF1);
  static const onSecondaryContainer = Color(0xFF134E4A);
  static const tertiary = Color(0xFF7C3AED);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFFEDE9FE);
  static const onTertiaryContainer = Color(0xFF4C1D95);
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1F5F9);
  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF475569);
  static const textDisabled = Color(0xFF64748B);
  static const outline = Color(0xFFCBD5E1);
  static const outlineVariant = Color(0xFFE2E8F0);
  static const outlineStrong = Color(0xFF64748B);
  static const success = Color(0xFF15803D);
  static const onSuccess = Color(0xFFFFFFFF);
  static const successContainer = Color(0xFFDCFCE7);
  static const onSuccessContainer = Color(0xFF14532D);
  static const warning = Color(0xFFB45309);
  static const onWarning = Color(0xFFFFFFFF);
  static const warningContainer = Color(0xFFFEF3C7);
  static const onWarningContainer = Color(0xFF78350F);
  static const error = Color(0xFFB91C1C);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFEE2E2);
  static const onErrorContainer = Color(0xFF7F1D1D);
  static const scrim = Color(0x7A0F172A);
}

class AppSpacing {
  static const small = 8.0;
  static const control = 12.0;
  static const medium = 16.0;
  static const card = 20.0;
  static const page = 24.0;
  static const section = 32.0;
  static const touchTarget = 48.0;
}

class AppTheme {
  static const _controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );
  static const _cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    side: BorderSide(color: AppColors.outlineVariant),
  );

  static const _display = TextStyle(
    fontSize: 36,
    height: 44 / 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.72,
  );
  static const _pageTitle = TextStyle(
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.42,
  );
  static const _sectionTitle = TextStyle(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const _title = TextStyle(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const _bodyLarge = TextStyle(
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const _body = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const _bodySmall = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const _label = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const _labelSmall = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.12,
  );

  static ThemeData get light {
    // Explicit overrides preserve the DESIGN palette instead of seed-generated colors.
    final colors = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.textMuted,
      surfaceDim: AppColors.surfaceMuted,
      surfaceBright: AppColors.surface,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.surfaceMuted,
      surfaceContainer: AppColors.surfaceMuted,
      surfaceContainerHigh: AppColors.surfaceMuted,
      surfaceContainerHighest: AppColors.surfaceMuted,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      inverseSurface: AppColors.text,
      onInverseSurface: AppColors.surface,
      inversePrimary: AppColors.primaryContainer,
      scrim: AppColors.scrim,
    );
    // Several Material roles share one DESIGN token; no extra font sizes are invented.
    final text =
        const TextTheme(
          displayLarge: _display,
          displayMedium: _display,
          displaySmall: _display,
          headlineLarge: _pageTitle,
          headlineMedium: _pageTitle,
          headlineSmall: _sectionTitle,
          titleLarge: _sectionTitle,
          titleMedium: _title,
          titleSmall: _label,
          bodyLarge: _bodyLarge,
          bodyMedium: _body,
          bodySmall: _bodySmall,
          labelLarge: _label,
          labelMedium: _label,
          labelSmall: _labelSmall,
        ).apply(
          fontFamily: 'Inter',
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        );
    const inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: AppColors.outlineStrong),
    );
    const target = Size(AppSpacing.touchTarget, AppSpacing.touchTarget);
    const padding = EdgeInsets.all(AppSpacing.control);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Inter',
      textTheme: text,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      disabledColor: AppColors.textDisabled,
      hoverColor: AppColors.surfaceMuted,
      iconTheme: const IconThemeData(color: AppColors.textMuted, size: 24),
      appBarTheme: AppBarThemeData(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleMedium,
        toolbarHeight: 56,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              minimumSize: target,
              padding: padding,
              shape: _controlShape,
              textStyle: text.labelLarge,
              disabledBackgroundColor: AppColors.surfaceMuted,
              disabledForegroundColor: AppColors.textDisabled,
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.surfaceMuted;
                }
                if (states.contains(WidgetState.hovered)) {
                  return AppColors.primaryContainer;
                }
                return AppColors.primary;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.textDisabled;
                }
                if (states.contains(WidgetState.hovered)) {
                  return AppColors.onPrimaryContainer;
                }
                return AppColors.onPrimary;
              }),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              minimumSize: target,
              padding: padding,
              shape: _controlShape,
              foregroundColor: AppColors.secondary,
              disabledForegroundColor: AppColors.textDisabled,
              textStyle: text.labelLarge,
            ).copyWith(
              side: WidgetStateProperty.resolveWith(
                (states) => BorderSide(
                  color: states.contains(WidgetState.disabled)
                      ? AppColors.outline
                      : AppColors.secondary,
                ),
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) =>
                    states.contains(WidgetState.hovered) &&
                        !states.contains(WidgetState.disabled)
                    ? AppColors.secondaryContainer
                    : AppColors.surface,
              ),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: target,
          padding: padding,
          shape: _controlShape,
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.textDisabled,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: target,
          padding: padding,
          foregroundColor: AppColors.textMuted,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.error)
              ? AppColors.errorContainer
              : AppColors.surface,
        ),
        contentPadding: padding,
        constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
        labelStyle: text.labelLarge?.copyWith(color: AppColors.textMuted),
        hintStyle: text.bodyMedium?.copyWith(color: AppColors.textMuted),
        helperStyle: text.bodySmall?.copyWith(color: AppColors.textMuted),
        errorStyle: text.bodySmall?.copyWith(color: AppColors.error),
        errorMaxLines: 3,
        counterStyle: text.labelSmall?.copyWith(color: AppColors.textMuted),
        prefixIconColor: AppColors.textMuted,
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: _cardShape,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: AppColors.surface,
        shape: _controlShape,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall?.copyWith(color: AppColors.textMuted),
        iconColor: AppColors.textMuted,
        contentPadding: padding,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceMuted,
        selectedColor: AppColors.primaryContainer,
        disabledColor: AppColors.surfaceMuted,
        labelStyle: text.bodySmall?.copyWith(color: AppColors.textMuted),
        secondaryLabelStyle: text.bodySmall?.copyWith(
          color: AppColors.onPrimaryContainer,
        ),
        deleteIconColor: AppColors.textMuted,
        shape: const StadiumBorder(),
        side: BorderSide.none,
        padding: const EdgeInsets.all(AppSpacing.small),
      ),
      checkboxTheme: const CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        constraints: const BoxConstraints(maxWidth: 480),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outlineVariant,
        thickness: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primaryContainer,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.text,
        contentTextStyle: text.bodySmall?.copyWith(color: AppColors.surface),
        behavior: SnackBarBehavior.floating,
        shape: _controlShape,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primaryContainer,
        selectionHandleColor: AppColors.primary,
      ),
    );
  }
}
