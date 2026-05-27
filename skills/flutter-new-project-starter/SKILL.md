---
name: flutter-new-project-starter
description: Bootstraps a new Flutter project with Volkan's standard stack and folder structure. Trigger this skill when the user says "new Flutter project", "start a new app", "set up a Flutter project from scratch", or when running `flutter create` is being considered. Sets up Riverpod 3.x with codegen, Freezed 3.x, GoRouter, Dio, flutter_localizations with English ARB, strict analysis_options.yaml, feature-first folder structure (data/domain/presentation), and base theme. Default stack reflects HST, Livestock Manager, Kap Kurtar patterns.
---

# Flutter New Project Starter

For when Volkan starts a new Flutter app. Skip the boilerplate, ship features.

## Default Stack (override only if user specifies otherwise)

| Concern | Choice | Why |
|---------|--------|-----|
| State | Riverpod 3.x + codegen (@riverpod) | Type-safe, testable, Volkan's default |
| Models | Freezed 3.x sealed classes | Immutable, copyWith, sealed unions |
| Navigation | GoRouter | Declarative, deep-link friendly |
| HTTP | Dio | Interceptors, FormData, easier than http |
| Auth | Firebase (default) OR Supabase (if user prefers) | See flutter-auth-firebase / flutter-auth-supabase |
| IAP | RevenueCat | See flutter-iap-revenuecat |
| Local storage | shared_preferences (settings) + hive_ce (structured) | Hive Community Edition, the maintained fork |
| Secure storage | flutter_secure_storage | For tokens, sensitive data |
| l10n | flutter_localizations + intl + ARB | See flutter-l10n-enforcer |
| Logging | logger | Better than print, structured output |
| Lints | flutter_lints + stricter custom rules | See analysis_options.yaml below |

## Setup Sequence

### Step 1: Create the project

```bash
flutter create --org com.axistia --platforms=ios,android my_app
cd my_app
```

Adjust `--org` to match user's bundle ID prefix. Volkan uses `com.axistia.*` for Axistia apps.

### Step 2: Configure pubspec.yaml

Replace the default with this baseline (check pub.dev for latest versions before pinning):

```yaml
name: my_app
description: A new Flutter project
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: ">=3.5.0 <4.0.0"
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # State and models
  flutter_riverpod: ^latest
  riverpod_annotation: ^latest
  freezed_annotation: ^latest
  json_annotation: ^latest

  # Navigation
  go_router: ^latest

  # HTTP
  dio: ^latest

  # l10n
  intl: ^latest

  # Storage
  shared_preferences: ^latest
  flutter_secure_storage: ^latest
  hive_ce: ^latest
  hive_ce_flutter: ^latest

  # Logging
  logger: ^latest

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^latest
  build_runner: ^latest
  riverpod_generator: ^latest
  freezed: ^latest
  json_serializable: ^latest
  custom_lint: ^latest
  riverpod_lint: ^latest

flutter:
  uses-material-design: true
  generate: true
```

Run `flutter pub get`.

### Step 3: analysis_options.yaml (strict mode)

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    invalid_annotation_target: ignore  # Required for Freezed + json_serializable
    missing_required_param: error
    missing_return: error
    todo: warning
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - "lib/generated/**"

linter:
  rules:
    # Style
    prefer_single_quotes: true
    sort_constructors_first: true
    sort_unnamed_constructors_first: true
    require_trailing_commas: true

    # Safety
    avoid_print: true
    avoid_dynamic_calls: true
    no_runtimeType_toString: true
    unawaited_futures: true
    use_build_context_synchronously: true

    # Performance
    prefer_const_constructors: true
    prefer_const_constructors_in_immutables: true
    prefer_const_declarations: true
    prefer_const_literals_to_create_immutables: true

custom_lint:
  rules:
    - missing_provider_scope
    - avoid_manual_providers_as_generated_provider_dependency
```

### Step 4: l10n.yaml

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

### Step 5: Folder Structure

```
lib/
├── main.dart
├── app/
│   ├── app.dart                    # MaterialApp + theme + router setup
│   ├── router.dart                 # GoRouter config
│   └── observer.dart               # Riverpod provider observer for debug logs
├── core/
│   ├── theme/
│   │   ├── app_theme.dart          # AppTheme.light, AppTheme.dark
│   │   └── theme_extensions.dart   # AppSemanticColors, AppSpacing, etc.
│   ├── responsive/
│   │   └── breakpoints.dart        # Mobile/tablet/desktop breakpoints
│   ├── network/
│   │   ├── dio_provider.dart       # Configured Dio instance
│   │   └── interceptors/
│   ├── storage/
│   │   ├── secure_storage.dart
│   │   └── prefs.dart
│   ├── errors/
│   │   ├── app_exception.dart      # Sealed exception hierarchy
│   │   └── failure.dart            # Failure model for Result<T> pattern
│   └── utils/
│       └── logger.dart             # Configured logger instance
├── features/
│   └── <feature_name>/
│       ├── data/
│       │   ├── datasources/
│       │   ├── models/             # Freezed models with JSON
│       │   └── repositories/       # Repository implementations
│       ├── domain/
│       │   ├── entities/           # Pure Dart, no Freezed dependencies
│       │   └── repositories/       # Repository interfaces (abstract)
│       └── presentation/
│           ├── providers/          # Riverpod providers
│           ├── screens/
│           └── widgets/
└── l10n/
    └── app_en.arb
```

For SMALL apps (under 5 features), it's okay to skip the domain layer and use data + presentation only. Don't over-engineer.

### Step 6: main.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: App()));
}
```

### Step 7: app.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'My App',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

### Step 8: router.dart

```dart
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

@riverpod
GoRouter router(RouterRef ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      // Add more routes as features grow
    ],
  );
}
```

### Step 9: app_en.arb

```json
{
  "@@locale": "en",
  "appName": "My App",
  "@appName": {
    "description": "The name of the application"
  }
}
```

### Step 10: Initial commit

```bash
git init
git add .
git commit -m "Initial Flutter project setup with axistia standard stack"
```

### Step 11: First codegen run

```bash
dart run build_runner build --delete-conflicting-outputs
flutter pub get
```

This generates `router.g.dart`, `app_localizations.dart`, and any other codegen outputs.

## Verify Setup

After all steps, run:
```bash
flutter analyze
flutter test
flutter run
```

If `flutter analyze` shows zero errors and the app launches showing the home screen, setup is complete.

## Optional Additions (Ask Before Adding)

These are common but project-specific:

- **Firebase:** add `firebase_core`, `firebase_auth`, `cloud_firestore`, etc. Configure via `flutterfire configure`
- **Supabase:** add `supabase_flutter`. Get URL + anon key from dashboard
- **RevenueCat:** add `purchases_flutter`. Configure API keys
- **AdMob:** add `google_mobile_ads`. Configure ATT
- **Crashlytics:** add `firebase_crashlytics`
- **Analytics:** add `firebase_analytics` OR `posthog_flutter`
- **Notifications:** add `firebase_messaging` + `flutter_local_notifications`
- **Sentry:** add `sentry_flutter` if not using Crashlytics

## Reusable Project Templates

After running this setup once, save the result as a template repo on GitHub:
```bash
gh repo create axisting/flutter-app-template --public --template
```

Then for next project: `gh repo create new-app --template axisting/flutter-app-template --public`.

This saves 30 minutes per new project.

## Strict Rules

- DO NOT skip `analysis_options.yaml`, every Flutter project deserves strict linting from day one
- DO NOT skip l10n setup, even if launching English-only, the infrastructure is needed for future languages
- DO NOT skip the theme file, hardcoded colors creep in fast otherwise
- DO NOT add packages you do not need yet, pubspec bloat slows down CI and adds privacy manifest burden
- DO NOT skip `dart run build_runner build` after first setup, the generated files are needed for the app to compile
