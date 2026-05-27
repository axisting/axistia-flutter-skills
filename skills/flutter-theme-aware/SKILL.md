---
name: flutter-theme-aware
description: Enforces ThemeData discipline in Flutter widgets. Triggers automatically whenever the model is about to write a Color, TextStyle, or Decoration in a widget. Hardcoded colors (Colors.blue, 0xFFFFFFFF, Color(0xFFXXXXXX) inline) are forbidden in widget code. All colors must come from Theme.of(context).colorScheme.* or a custom ColorScheme extension. All text styles must come from Theme.of(context).textTheme.* with optional copyWith. The theme itself is defined ONCE in a central theme file, supports both light and dark modes, and uses Material 3 ColorScheme.fromSeed for color generation unless a brand requires exact hex values.
---

# Flutter Theme-Aware Widget Discipline

Rule: a widget should look correct in light mode, dark mode, and a brand-recolored variant without code changes. If you have to find-and-replace hex values to retheme an app, the app is wrong.

## The Two Rules That Cover 95% of Cases

### Rule 1: Colors come from `Theme.of(context).colorScheme.*`

```dart
// BAD
Container(color: Colors.blue)
Container(color: Color(0xFF1A73E8))
Container(color: const Color.fromRGBO(26, 115, 232, 1))

// GOOD
Container(color: Theme.of(context).colorScheme.primary)
Container(color: Theme.of(context).colorScheme.surfaceContainerHighest)
```

The Material 3 ColorScheme tokens you should know:
- `primary`, `onPrimary`, `primaryContainer`, `onPrimaryContainer`
- `secondary`, `onSecondary`, `secondaryContainer`, `onSecondaryContainer`
- `tertiary`, `onTertiary`, `tertiaryContainer`, `onTertiaryContainer`
- `error`, `onError`, `errorContainer`, `onErrorContainer`
- `surface`, `onSurface`, `surfaceContainerLowest/Low/-/High/Highest`
- `outline`, `outlineVariant`

The `on*` colors are the foreground color guaranteed to be readable on the matching background. Use them together:

```dart
Container(
  color: theme.colorScheme.primaryContainer,
  child: Text(
    label,
    style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
  ),
)
```

### Rule 2: Text styles come from `Theme.of(context).textTheme.*`

```dart
// BAD
Text('Title', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600))

// GOOD
Text('Title', style: Theme.of(context).textTheme.headlineSmall)
```

Material 3 text theme scale (use the closest match, do not invent new sizes):
- `displayLarge`, `displayMedium`, `displaySmall` (very large hero text)
- `headlineLarge`, `headlineMedium`, `headlineSmall` (screen titles, dialog headers)
- `titleLarge`, `titleMedium`, `titleSmall` (card titles, list section headers)
- `bodyLarge`, `bodyMedium`, `bodySmall` (default body text)
- `labelLarge`, `labelMedium`, `labelSmall` (buttons, chips, captions)

If you need a small tweak, use `copyWith`:
```dart
Theme.of(context).textTheme.titleMedium?.copyWith(
  color: theme.colorScheme.primary,
  fontWeight: FontWeight.w700,
)
```

Do NOT invent fontSize values mid-widget. If `titleMedium` is not right, the theme is wrong, fix the theme, not the widget.

## Central Theme File

Every project should have `lib/core/theme/app_theme.dart` (or similar) that exports `lightTheme` and `darkTheme`:

```dart
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Brand color (seed)
  static const Color _seedColor = Color(0xFF1A73E8);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
      ),
      // ... extend as needed
    );
  }
}
```

Then in main.dart:
```dart
MaterialApp(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: ThemeMode.system,
  // ...
)
```

## Custom Tokens via ThemeExtension

When the design needs colors or values that don't fit into ColorScheme (brand-specific tints, custom spacing scale, semantic colors like "success" or "warning"), use ThemeExtension instead of inventing globals:

```dart
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color success;
  final Color warning;
  final Color info;

  const AppSemanticColors({
    required this.success,
    required this.warning,
    required this.info,
  });

  @override
  AppSemanticColors copyWith({Color? success, Color? warning, Color? info}) {
    return AppSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}
```

Register in theme:
```dart
ThemeData(
  // ...
  extensions: [
    AppSemanticColors(
      success: const Color(0xFF22C55E),
      warning: const Color(0xFFF59E0B),
      info: const Color(0xFF3B82F6),
    ),
  ],
)
```

Use in widgets:
```dart
final semantic = Theme.of(context).extension<AppSemanticColors>()!;
Icon(Icons.check_circle, color: semantic.success);
```

## When Brand Forces Exact Hex Values

Sometimes the brand spec says "primary must be exactly #FF6B00". In that case, define a manual ColorScheme instead of `fromSeed`:

```dart
const colorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFFFF6B00),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFFFE0CC),
  onPrimaryContainer: Color(0xFF3D1A00),
  // ... fill in all required slots
);
```

This is more work but lets you keep all widgets theme-aware. The brand hex value lives in ONE place (the theme file), not scattered across 50 widgets.

## Material You / Dynamic Color (Optional)

If the app benefits from picking up the user's Android wallpaper colors, use the `dynamic_color` package:

```dart
DynamicColorBuilder(
  builder: (lightDynamic, darkDynamic) {
    final lightScheme = lightDynamic?.harmonized()
        ?? ColorScheme.fromSeed(seedColor: _seedColor);
    final darkScheme = darkDynamic?.harmonized()
        ?? ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark);
    return MaterialApp(
      theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
      darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
      // ...
    );
  },
)
```

## Dark Mode Testing Checklist

Before declaring a screen done:
- [ ] Switch the device/emulator to dark mode, verify nothing is invisible (white text on white background, etc.)
- [ ] Verify no widget uses `Colors.white` or `Colors.black` directly
- [ ] Verify shadows and elevation still work (Material 3 uses surface tint, not just shadow)
- [ ] Verify `SystemUiOverlayStyle` matches (status bar icons readable on the actual background)

## Strict Rules

- DO NOT use `Colors.*` constants in widget code (`Colors.blue`, `Colors.grey[800]`, etc.)
- DO NOT use raw `Color(0xFF...)` or `Color.fromRGBO(...)` in widget code
- DO NOT use inline `TextStyle(fontSize: ...)` in widget code
- DO NOT define theme values inline in MaterialApp, always extract to a central theme file
- DO NOT skip dark theme, even if the app is "light only" launch, define a dark theme anyway, users have system dark mode preferences
- DO NOT use `useMaterial3: false`, Material 2 is deprecated, all new code is Material 3
- DO use `Theme.of(context).colorScheme.*` and `Theme.of(context).textTheme.*` everywhere
- DO put one-off brand colors and semantic colors in a ThemeExtension, not in scattered constants
