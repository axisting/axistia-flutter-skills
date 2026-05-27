---
name: flutter-responsive-design
description: Enforces responsive and adaptive Flutter layouts. Triggers automatically whenever the model is about to write a Widget that contains hardcoded width, height, padding, font size, or icon size. Hardcoded dimensions are forbidden except for hairline borders (1-2px), icon sizes that come from a design system token, and intentional fixed-size art elements. Use MediaQuery for screen metrics, LayoutBuilder for parent constraints, Flexible/Expanded inside Row/Column, and breakpoints (mobile under 600px, tablet 600-900, desktop above 900) for switching layouts. Critical for any Flutter app that targets both phones and tablets, or supports foldables.
---

# Flutter Responsive and Adaptive Design

The rule: a Flutter widget should look correct on a 320px-wide phone and a 1024px-wide iPad without code changes. If a widget breaks on either, it is wrong.

## Two Concepts, Different Tools

**Responsive** = same UI, scales naturally with available space. Use `Flexible`, `Expanded`, percentage-based sizing.

**Adaptive** = different UI per device class. Use breakpoints to switch between layouts (e.g., bottom nav on mobile, side rail on tablet).

Most screens need both: responsive within a class, adaptive across classes.

## Tool Selection

| Need | Use |
|------|-----|
| Whole-screen size, orientation, padding (notch/home indicator), text scale | `MediaQuery.of(context)` |
| Available space INSIDE a parent widget | `LayoutBuilder` |
| Switch layout per orientation | `OrientationBuilder` |
| Distribute space in Row/Column | `Flexible`, `Expanded`, `Spacer` |
| Keep content out of system UI areas | `SafeArea` |
| Constrain max width on large screens | `ConstrainedBox(maxWidth: ...)` or `Center(child: SizedBox(width: ...))` |

## Breakpoints (Use These Exactly)

```dart
class Breakpoints {
  static const double mobile = 600;   // < 600: phone
  static const double tablet = 900;   // 600-900: small tablet, large phone landscape
  static const double desktop = 1200; // 900-1200: large tablet, small desktop
  // > 1200: full desktop
}

extension ScreenSize on BuildContext {
  bool get isMobile => MediaQuery.of(this).size.width < Breakpoints.mobile;
  bool get isTablet => MediaQuery.of(this).size.width >= Breakpoints.mobile
                    && MediaQuery.of(this).size.width < Breakpoints.tablet;
  bool get isDesktop => MediaQuery.of(this).size.width >= Breakpoints.tablet;
}
```

Save this as `lib/core/responsive/breakpoints.dart` in new projects.

## Reference Patterns

### Pattern 1: Single screen, fluid layout (most common)

```dart
class ProductListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth < 600 ? 2
                : constraints.maxWidth < 900 ? 3
                : 4;
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (_, i) => ProductCard(/* ... */),
            );
          },
        ),
      ),
    );
  }
}
```

### Pattern 2: Adaptive navigation (mobile vs tablet)

```dart
class AdaptiveScaffold extends StatelessWidget {
  final Widget body;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  const AdaptiveScaffold({
    super.key,
    required this.body,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < Breakpoints.mobile) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: destinations,
        ),
      );
    }

    // Tablet and above: side rail
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            extended: width >= Breakpoints.tablet,
            destinations: destinations
                .map((d) => NavigationRailDestination(
                      icon: d.icon,
                      label: Text(d.label),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}
```

### Pattern 3: Constrain max width on big screens

Reading-focused or form screens look bad stretched across a 1200px desktop. Cap the width:

```dart
SafeArea(
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: LoginForm(),
      ),
    ),
  ),
)
```

## Things to AVOID

### Hardcoded widths on whole screens
```dart
// BAD
Container(width: 360, child: ...)  // phones smaller than 360 will overflow

// GOOD
Container(width: double.infinity, child: ...)
// or
Expanded(child: ...)
```

### Hardcoded font sizes everywhere
```dart
// BAD
Text('Title', style: TextStyle(fontSize: 24))

// GOOD (uses Theme + automatic text scaling)
Text('Title', style: Theme.of(context).textTheme.headlineSmall)
```

(See `flutter-theme-aware` for full Theme guidance.)

### Hardcoded padding for screen edges
```dart
// BAD (ignores notch, home indicator)
Padding(padding: EdgeInsets.all(20), child: Scaffold(...))

// GOOD
SafeArea(child: Padding(padding: EdgeInsets.all(20), child: ...))
```

### Ignoring textScaleFactor
Users can crank font size in OS settings. Apps that hardcode font sizes break for users with poor vision.

```dart
// BAD
fontSize: 14

// GOOD
fontSize: 14 * MediaQuery.textScalerOf(context).scale(1)
// OR just use Theme.of(context).textTheme.* which respects textScaler automatically
```

### Forgetting orientation
Some screens (camera, video, games) must adapt to landscape. Most screens just need to handle landscape without crashing.

```dart
OrientationBuilder(
  builder: (context, orientation) {
    return orientation == Orientation.portrait
        ? PortraitLayout()
        : LandscapeLayout();
  },
)
```

## When `flutter_screenutil` is Acceptable

The `flutter_screenutil` package scales sizes proportional to a reference design (e.g., 375x812 iPhone). Use ONLY if:
1. The project has a strict pixel-perfect design spec from Figma based on a fixed reference size
2. The team agrees on the reference size

Otherwise, prefer Flutter's native constraint-based approach. ScreenUtil can produce worse layouts on extreme screen sizes (foldables, ultrawide tablets) than `Flexible` + `LayoutBuilder`.

## Strict Rules

- DO NOT hardcode width/height on full-screen widgets, ever
- DO NOT skip SafeArea on screens with edge-to-edge content
- DO NOT assume 16px padding on all screen edges, use SafeArea + MediaQuery.padding
- DO NOT skip orientation testing, even if the app is portrait-locked, foldables can present unexpected orientations
- DO NOT use `MediaQuery.of(context).size.width` to drive sub-widget layouts, use `LayoutBuilder` so child gets actual available space, not screen width
- DO NOT use `flutter_screenutil` without team agreement
- DO test on at least one phone (360-400px), one large phone (430px), and one tablet (768px+) emulator before declaring a screen done
