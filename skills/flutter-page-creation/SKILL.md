---
name: flutter-page-creation
description: Scaffolds a new Flutter screen or page correctly. Trigger this skill whenever the user says "create a screen", "add a page", "build a view", "new settings screen", "detail page", "onboarding screen", "profile page", or any request to write a new top-level UI surface. Enforces feature-first file placement, GoRouter route registration, Scaffold + SafeArea anatomy, correct scroll strategy, Riverpod AsyncValue state skeleton, and a completion checklist before the page is handed off. Does NOT duplicate color, text style, string, or layout rules — those are owned by flutter-theme-aware, flutter-l10n-enforcer, and flutter-responsive-design respectively.
---

# Flutter Page Creation

Rule: a new page is not "done" when it compiles. It is done when it handles loading, error, and empty states, uses no hardcoded strings or colors, works on a 320px phone and a 768px tablet, and dismisses the keyboard correctly.

## Step 1: File Placement

Feature-first structure, always:

```
lib/
  features/
    <feature_name>/
      data/
      domain/
      presentation/
        pages/
          <feature>_page.dart      ← new file goes here
        widgets/                   ← page-local reusable widgets
```

Name the file `<feature>_page.dart`, not `<feature>_screen.dart` or `<feature>_view.dart`. Keep naming consistent across the project.

One page = one file. If the page has complex sub-sections, extract them to `widgets/` — not additional files in `pages/`.

## Step 2: Route Registration (GoRouter)

Every new page must be registered before it can be navigated to.

```dart
// In lib/core/router/app_router.dart (or wherever GoRouter is configured)
GoRoute(
  path: '/settings',
  name: AppRoutes.settings,           // always use named routes
  builder: (context, state) => const SettingsPage(),
),
```

Add the route name constant:

```dart
// lib/core/router/app_routes.dart
class AppRoutes {
  static const settings = 'settings';
}
```

If the page receives parameters:

```dart
GoRoute(
  path: '/item/:id',
  name: AppRoutes.itemDetail,
  builder: (context, state) {
    final id = state.pathParameters['id']!;
    return ItemDetailPage(id: id);
  },
),
```

Navigate with the name, never with a hardcoded path string:

```dart
context.goNamed(AppRoutes.settings);
context.goNamed(AppRoutes.itemDetail, pathParameters: {'id': item.id});
```

## Step 3: Page Anatomy

Every page starts with this skeleton. Do not deviate without a documented reason.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(/* l10n key */),
      ),
      body: SafeArea(
        child: _buildBody(context, ref),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    // content here
  }
}
```

Rules:
- `Scaffold` is always the root widget of a page. Never nest a `Scaffold` inside another `Scaffold`.
- `SafeArea` wraps the body, not the Scaffold. The AppBar already handles the top inset; `SafeArea` here protects bottom home indicator and side notches.
- Use `ConsumerWidget` (not `StatelessWidget`) for any page that reads Riverpod providers. Do not reach for `StatefulWidget` unless you need a `TickerProvider` (animations) or `ScrollController` that cannot live in a provider.

### Scroll Strategy Selection

| Situation | Widget |
|-----------|--------|
| Content guaranteed to fit on screen (settings toggles, confirmation dialogs) | No scroll — use `Column` directly |
| Content might overflow on small screens, single-child | `SingleChildScrollView` + `Column` |
| Long list of items | `ListView.builder` or `SliverList` inside `CustomScrollView` |
| Mixed pinned header + scrolling content | `CustomScrollView` + `SliverAppBar` + `SliverList` |
| Nested horizontal+vertical scroll | Outer `ListView`, inner `SingleChildScrollView` with explicit height from `LayoutBuilder` |

Never use `SingleChildScrollView` around a `ListView` — it breaks infinite scroll and causes layout exceptions.

## Step 4: Async State Skeleton

Any page that loads remote data must use `AsyncValue`. No exceptions.

```dart
class ItemListPage extends ConsumerWidget {
  const ItemListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(itemsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(/* l10n key */)),
      body: SafeArea(
        child: itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorView(
            message: _mapErrorToMessage(error, context),
            onRetry: () => ref.invalidate(itemsProvider),
          ),
          data: (items) => items.isEmpty
              ? _EmptyView()
              : _ItemList(items: items),
        ),
      ),
    );
  }
}
```

Always handle all three states: `loading`, `error`, `data`. Never silently swallow an error state by returning an empty `Container`.

The empty state is not the same as the error state. Write both separately.

For error message mapping, see `flutter-error-handling` skill.

## Step 5: Forbidden Patterns

```dart
// BAD: Scaffold inside Scaffold
Scaffold(
  body: Scaffold(   // ← runtime warning, broken layout
    body: ...,
  ),
)

// BAD: hardcoded dimensions that cause overflow on small screens
SizedBox(width: 400, child: ...)    // use ConstrainedBox or Flexible instead
Container(height: 700, child: ...)  // this overflows on iPhone SE

// BAD: StatefulWidget for async data loading
class _ItemPageState extends State<ItemPage> {
  List<Item>? _items;
  void initState() { _loadItems(); }  // use Riverpod provider instead
}

// BAD: navigation with hardcoded path string
context.go('/settings');    // breaks if path changes
context.push('/item/123');  // use goNamed/pushNamed

// BAD: missing error and empty states
data: (items) => ItemList(items: items),   // what if items is empty? what if provider throws?
```

## Step 6: Before You Call This Page Done

Run through this checklist. If any item is NO, fix it before moving on.

| # | Check | Pass? |
|---|-------|-------|
| 1 | `SafeArea` wraps the body | |
| 2 | All user-visible strings use `AppLocalizations.of(context)!.*` | |
| 3 | All colors use `Theme.of(context).colorScheme.*` | |
| 4 | All text styles use `Theme.of(context).textTheme.*` | |
| 5 | Loading state is handled (spinner or skeleton) | |
| 6 | Error state is handled (message + retry button) | |
| 7 | Empty state is handled (not just a blank screen) | |
| 8 | Keyboard dismisses when tapping outside a text field | |
| 9 | Back navigation works and pops the correct route | |
| 10 | No layout overflow on a 320px-wide screen (check with `flutter run` on small emulator or use `debugPaintSizeEnabled`) | |

For form pages, also check keyboard `FocusNode` chain and submit behavior — see `flutter-form-handling` skill.

## Reference Templates

### Template A: Content List Page

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ItemListPage extends ConsumerWidget {
  const ItemListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(itemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.itemListTitle),
      ),
      body: SafeArea(
        child: itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.errorGenericMessage,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(itemsProvider),
                  child: Text(context.l10n.buttonRetry),
                ),
              ],
            ),
          ),
          data: (items) => items.isEmpty
              ? Center(child: Text(context.l10n.itemListEmpty))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.title),
                      onTap: () => context.goNamed(
                        AppRoutes.itemDetail,
                        pathParameters: {'id': item.id},
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
```

### Template B: Form Page

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EditProfilePage extends ConsumerWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(editProfileFormProvider);
    final formNotifier = ref.read(editProfileFormProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.editProfileTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formNotifier.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  initialValue: formState.displayName,
                  decoration: InputDecoration(
                    labelText: context.l10n.fieldDisplayName,
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? context.l10n.validationRequired
                      : null,
                  onChanged: formNotifier.updateDisplayName,
                ),
                const SizedBox(height: 16),
                // ... more fields
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: formState.isSubmitting
                      ? null
                      : () => formNotifier.submit(context),
                  child: formState.isSubmitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.l10n.buttonSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

See `flutter-form-handling` for the full `editProfileFormProvider` implementation including async validation, FocusNode chain, and error handling.

## Skill Composition

This skill is intentionally thin on detail for colors, strings, layout, and form logic because those are covered precisely by sibling skills:

- **Colors and text styles** → `flutter-theme-aware`
- **All user-visible strings** → `flutter-l10n-enforcer`
- **Responsive layout and breakpoints** → `flutter-responsive-design`
- **Form fields, validation, keyboard** → `flutter-form-handling`
- **Error states and retry logic** → `flutter-error-handling`

When writing a page, all five skills apply simultaneously. This skill governs the page's outer structure; the others govern what goes inside.
