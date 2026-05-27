---
name: flutter-error-handling
description: Implements systematic error handling in Flutter with Riverpod. Trigger this skill whenever the user asks about "handle error", "what if the API fails", "show error state", "error message", "retry on failure", "AsyncValue error", "API hatası", "hata göster", or when writing any provider that performs async work. Covers the domain error model with Freezed sealed classes, Dio exception mapping, AsyncValue UI patterns, retry logic, and when to use SnackBar vs inline error vs full-screen error state. Prevents silent error swallowing and technical error messages leaking to users.
---

# Flutter Error Handling

Rule: every async operation either delivers data or delivers a typed, user-friendly error. `try/catch` that swallows the exception and returns null is not error handling — it is data loss.

## The Three-Layer Model

```
Network / SDK layer    →    Domain error layer    →    Presentation layer
(Dio, Supabase, etc.)       (sealed Failure class)      (AsyncValue UI)
```

Each layer has one job. Network exceptions are caught and mapped once, at the repository boundary. The rest of the app speaks only in domain errors. The UI speaks only in user-facing messages.

## Layer 1: Domain Error Model

Define a `Failure` sealed class per feature, or one shared one for simple apps:

```dart
// lib/core/errors/failures.dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'failures.freezed.dart';

@freezed
sealed class Failure with _$Failure {
  const factory Failure.network({
    required String message,
    int? statusCode,
  }) = NetworkFailure;

  const factory Failure.notFound() = NotFoundFailure;

  const factory Failure.unauthorized() = UnauthorizedFailure;

  const factory Failure.validation({
    required Map<String, String> fieldErrors,
  }) = ValidationFailure;

  const factory Failure.unknown({
    required String message,
  }) = UnknownFailure;
}
```

Run `dart run build_runner build` to generate the Freezed code.

## Layer 2: Repository Error Mapping

Catch exceptions exactly once — at the repository or datasource boundary. Never catch and re-throw in providers, use-cases, or widgets.

```dart
// lib/features/items/data/repositories/items_repository_impl.dart
import 'package:dio/dio.dart';

class ItemsRepositoryImpl implements ItemsRepository {
  final Dio _dio;
  ItemsRepositoryImpl(this._dio);

  @override
  Future<List<Item>> fetchItems() async {
    try {
      final response = await _dio.get('/items');
      return (response.data as List)
          .map((json) => Item.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapDioError(e);
    } catch (e) {
      throw Failure.unknown(message: e.toString());
    }
  }

  Failure _mapDioError(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        const Failure.network(message: 'No internet connection'),
      DioExceptionType.badResponse => switch (e.response?.statusCode) {
          401 => const Failure.unauthorized(),
          404 => const Failure.notFound(),
          _ => Failure.network(
              message: 'Server error',
              statusCode: e.response?.statusCode,
            ),
        },
      _ => Failure.unknown(message: e.message ?? 'Unexpected error'),
    };
  }
}
```

For Supabase projects, map `PostgrestException` and `AuthException` the same way.

## Layer 3: Provider — AsyncValue Pattern

Let Riverpod capture exceptions automatically. Do NOT wrap provider bodies in try/catch unless you need to transform the error.

```dart
// lib/features/items/presentation/providers/items_provider.dart
@riverpod
Future<List<Item>> items(Ref ref) async {
  final repo = ref.watch(itemsRepositoryProvider);
  return repo.fetchItems();   // exceptions become AsyncValue.error automatically
}
```

If you need to transform the Failure before it reaches the UI:

```dart
@riverpod
Future<List<Item>> items(Ref ref) async {
  final repo = ref.watch(itemsRepositoryProvider);
  try {
    return await repo.fetchItems();
  } on Failure catch (f) {
    // optionally log, then rethrow so AsyncValue.error captures it
    ref.read(loggerProvider).warning('items fetch failed: $f');
    rethrow;
  }
}
```

## Layer 3: UI — AsyncValue.when Pattern

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final itemsAsync = ref.watch(itemsProvider);

  return itemsAsync.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) => _ErrorView(
      message: _errorMessage(error, context),
      onRetry: () => ref.invalidate(itemsProvider),
    ),
    data: (items) => _ItemList(items: items),
  );
}

String _errorMessage(Object error, BuildContext context) {
  if (error is Failure) {
    return switch (error) {
      NetworkFailure() => context.l10n.errorNetwork,
      UnauthorizedFailure() => context.l10n.errorUnauthorized,
      NotFoundFailure() => context.l10n.errorNotFound,
      ValidationFailure(:final fieldErrors) =>
        fieldErrors.values.first,   // show first field error inline
      UnknownFailure(:final message) => context.l10n.errorUnknown,
    };
  }
  return context.l10n.errorUnknown;
}
```

Use `maybeWhen` when you only care about one state:

```dart
// Show a banner only on error, keep existing content on reload
final error = ref.watch(itemsProvider).asError;
if (error != null) {
  // show error banner without replacing content
}
```

## Error UI: Which Widget to Use

| Scenario | Widget | Why |
|----------|--------|-----|
| Background operation failed (save, send message) | `SnackBar` | Non-blocking, doesn't lose user's place |
| Form field fails async validation | Inline text under field | Tied to the specific input |
| Critical data failed to load (whole page is empty) | Full-screen error with retry button | Content cannot be shown at all |
| Non-critical data failed (a widget inside a loaded page) | Inline small error inside that widget | Keep the rest of the page usable |
| Auth error, session expired | Navigate to login page | No point showing retry |

### Full-Screen Error Widget

```dart
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.buttonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
```

### SnackBar Error (for mutations)

```dart
void _showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: context.l10n.buttonDismiss,
        textColor: Theme.of(context).colorScheme.onError,
        onPressed: () =>
            ScaffoldMessenger.of(context).hideCurrentSnackBar(),
      ),
    ),
  );
}
```

## Retry Pattern

Use `ref.invalidate` to clear the cache and re-fetch:

```dart
// Retry immediately
onRetry: () => ref.invalidate(itemsProvider),

// Retry after a user action in a notifier
class ItemsNotifier extends _$ItemsNotifier {
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(itemsRepositoryProvider).fetchItems());
  }
}
```

`AsyncValue.guard` wraps the future and automatically converts exceptions to `AsyncValue.error`.

## Forbidden Patterns

```dart
// BAD: swallowed exception — data silently disappears
try {
  final items = await repo.fetchItems();
  state = AsyncValue.data(items);
} catch (_) {
  state = const AsyncValue.data([]);  // ← error hidden, user sees empty screen
}

// BAD: print() as "logging"
} catch (e) {
  print('Error: $e');   // disappears in production, no context
}

// BAD: technical message shown to user
Text(error.toString())     // "DioException [bad response]: 401..." — useless and embarrassing

// BAD: catching in the provider AND the widget
// If the repository already threw a Failure, don't re-catch in the provider and in the widget.
// Catch once, map once, display once.

// BAD: not handling error state in .when()
itemsAsync.when(
  loading: () => ...,
  data: (items) => ...,
  // error: omitted — Riverpod throws a runtime exception
)
```
