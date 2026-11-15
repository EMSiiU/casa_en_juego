import 'package:flutter/material.dart';

abstract final class AppTheme {
  static final light = _build(Brightness.light);
  static final dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF8869BA),
          brightness: brightness,
        ).copyWith(
          primary: isDark ? const Color(0xFFCBBDF8) : const Color(0xFF60408D),
          onPrimary: isDark ? const Color(0xFF1A1B22) : Colors.white,
          primaryContainer: isDark
              ? const Color(0xFF39334F)
              : const Color(0xFFEDE2FF),
          onPrimaryContainer: isDark ? Colors.white : const Color(0xFF282035),
          surface: isDark ? const Color(0xFF242531) : Colors.white,
          onSurface: isDark ? Colors.white : const Color(0xFF242130),
          onSurfaceVariant: isDark
              ? const Color(0xFFB8B9C9)
              : const Color(0xFF5B5368),
          outline: isDark ? const Color(0xFF9F9EB2) : const Color(0xFF6D637B),
          surfaceContainerHighest: isDark
              ? const Color(0xFF333543)
              : const Color(0xFFEAE5F1),
          error: isDark ? const Color(0xFFF3A69B) : const Color(0xFFA52A24),
          onError: isDark ? const Color(0xFF1A1B22) : Colors.white,
        );
    final background = isDark
        ? const Color(0xFF1A1B22)
        : const Color(0xFFF8F5FB);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'DM Sans',
      extensions: [isDark ? AppStatusColors.dark : AppStatusColors.light],
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }
}

extension AppThemeContext on BuildContext {
  ColorScheme get appColors => Theme.of(this).colorScheme;
  AppStatusColors get statusColors =>
      Theme.of(this).extension<AppStatusColors>() ??
      (appColors.brightness == Brightness.dark
          ? AppStatusColors.dark
          : AppStatusColors.light);
}

class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.approved,
    required this.approvedContainer,
    required this.pending,
    required this.pendingContainer,
  });

  static const dark = AppStatusColors(
    approved: Color(0xFF91D5C6),
    approvedContainer: Color(0xFF26413E),
    pending: Color(0xFFF2C978),
    pendingContainer: Color(0xFF423B2F),
  );
  static const light = AppStatusColors(
    approved: Color(0xFF246055),
    approvedContainer: Color(0xFFDFF4EC),
    pending: Color(0xFF714800),
    pendingContainer: Color(0xFFFFEBCB),
  );

  final Color approved;
  final Color approvedContainer;
  final Color pending;
  final Color pendingContainer;

  @override
  AppStatusColors copyWith({
    Color? approved,
    Color? approvedContainer,
    Color? pending,
    Color? pendingContainer,
  }) => AppStatusColors(
    approved: approved ?? this.approved,
    approvedContainer: approvedContainer ?? this.approvedContainer,
    pending: pending ?? this.pending,
    pendingContainer: pendingContainer ?? this.pendingContainer,
  );

  @override
  AppStatusColors lerp(covariant AppStatusColors? other, double t) {
    if (other == null) return this;
    return AppStatusColors(
      approved: Color.lerp(approved, other.approved, t)!,
      approvedContainer: Color.lerp(
        approvedContainer,
        other.approvedContainer,
        t,
      )!,
      pending: Color.lerp(pending, other.pending, t)!,
      pendingContainer: Color.lerp(
        pendingContainer,
        other.pendingContainer,
        t,
      )!,
    );
  }
}
