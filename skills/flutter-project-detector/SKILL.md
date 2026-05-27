---
name: flutter-project-detector
description: Routes Flutter work to the correct specialist skill by reading pubspec.yaml. Activate this skill whenever the user is working in a Flutter project (any .dart file, pubspec.yaml, lib/ folder, or mention of Flutter, Dart, Riverpod, Provider, BLoC). It detects the project's stack (Firebase vs Supabase, Riverpod vs others, navigation, monetization) and tells the model which sibling skills to consult next. Trigger this skill BEFORE writing any Flutter code so the resulting code matches the project's existing patterns instead of imposing new ones. Critical for solo founders maintaining multiple Flutter apps with different stacks.
---

# Flutter Project Detector

This is the master router for the axistia-flutter-skills collection. Its job is simple: figure out what kind of Flutter project this is, then point to the right specialist skills.

## Always Run This First

Before any Flutter-related task (writing code, reviewing, refactoring, adding features), run this detection sequence. Cache the result for the current session.

### Step 1: Confirm this is a Flutter project

Check for these files in the project root:
- `pubspec.yaml` (mandatory for any Flutter project)
- `lib/main.dart` (entry point)
- `ios/Runner.xcodeproj` or `android/app/build.gradle` (platform folders)

If none exist, this is not a Flutter project. Stop, do not load any Flutter skills.

### Step 2: Read pubspec.yaml

Read the entire `pubspec.yaml`. Build a mental map of:

**Authentication stack:**
- `firebase_auth` present → Firebase auth project
- `supabase_flutter` present → Supabase auth project
- Both present → Hybrid (rare, ask user which is primary)
- Neither → No auth yet, project may need it later

**State management:**
- `flutter_riverpod` or `riverpod_annotation` → Riverpod (preferred default)
- `flutter_bloc` → BLoC
- `provider` → Legacy Provider
- `get` → GetX
- `mobx` → MobX
- None of above → User has not chosen yet, default to Riverpod for new code

**Navigation:**
- `go_router` → GoRouter (preferred)
- `auto_route` → AutoRoute
- Neither → MaterialApp default Navigator

**Monetization:**
- `purchases_flutter` → RevenueCat
- `in_app_purchase` → Direct StoreKit/Play Billing (rare, less robust)
- Neither → No IAP yet

**Localization:**
- `flutter_localizations` + `intl` + `generate: true` in flutter section → l10n configured
- `lib/l10n/*.arb` files exist → Active l10n
- Neither → No l10n yet, must enforce when writing new strings

**Code generation:**
- `freezed` and `freezed_annotation` → Freezed for models
- `json_annotation` + `json_serializable` → JSON serialization
- `build_runner` in dev_deps → Codegen is set up

**Networking:**
- `dio` → Dio HTTP client
- `http` → Default http package
- Neither → No HTTP yet

### Step 3: Route to specialist skills

Based on detection, load only the skills that match. Do not load skills for stacks that are not in the project.

| Detected | Load Skill |
|----------|-----------|
| `firebase_auth` | flutter-auth-firebase |
| `supabase_flutter` | flutter-auth-supabase |
| `purchases_flutter` | flutter-iap-revenuecat |
| User writing a new string anywhere in lib/ | flutter-l10n-enforcer |
| User creating any Widget | flutter-responsive-design + flutter-theme-aware |
| User creating a new screen, page, view, or route | flutter-page-creation |
| User building a form, adding input fields, or handling validation | flutter-form-handling |
| User handling errors, API failures, retry logic, or async error states | flutter-error-handling |
| User asks "is this app ready to submit?" | flutter-store-review-checker |
| User asks for security audit or before any release | flutter-security-audit |
| User asks "are packages up to date?", `pub get` fails, outdated deps, or preparing for release | flutter-package-version-checker |
| User says "let's start a new app" or no pubspec exists | flutter-new-project-starter |

### Step 4: State the detection out loud

Briefly tell the user what you found, in one or two sentences, so they can correct you if needed. Example:

> "I see this is a Firebase + Riverpod + GoRouter project with RevenueCat. I'll use those patterns and ignore Supabase/BLoC/etc. Continuing..."

This is not optional. Solo founders maintain multiple apps with different stacks and a misdetection wastes hours.

## Default Stack for New Projects

If the user is starting from scratch (no pubspec yet, or said "new project"), default to this stack unless told otherwise:

- **State:** Riverpod 3.x with codegen (`@riverpod` annotation)
- **Models:** Freezed 3.x with sealed classes
- **Navigation:** GoRouter
- **HTTP:** Dio
- **Auth:** Firebase (default, unless user picks Supabase)
- **IAP:** RevenueCat
- **l10n:** Configured from day one with English ARB
- **Architecture:** Feature-first folders (data / domain / presentation)
- **Lints:** Strict `analysis_options.yaml`

This default reflects the patterns Volkan uses across HST, Livestock Manager, and Kap Kurtar.

## Cross-Cutting Rules (Apply Everywhere)

These rules apply regardless of stack:

1. **Never use em dash (—).** Use regular hyphens, commas, parentheses, or colons instead. Applies to all output: code comments, docstrings, README files, commit messages, l10n strings, everywhere.

2. **Never hardcode strings in widgets.** Every user-visible string must go through `AppLocalizations.of(context)`. See `flutter-l10n-enforcer`.

3. **Never hardcode colors or text styles.** Use `Theme.of(context).colorScheme.*` and `Theme.of(context).textTheme.*`. See `flutter-theme-aware`.

4. **Never hardcode dimensions for whole-screen layouts.** Use `MediaQuery`, `LayoutBuilder`, `Flexible`, `Expanded`. See `flutter-responsive-design`.

5. **Always use the latest stable package versions.** When adding a dependency, check pub.dev for the latest version, do not copy outdated examples. See `flutter-package-version-checker`.

6. **Always run `dart format . && flutter analyze && flutter test` before committing.** This is non-negotiable.

7. **Always run `dart run build_runner build --delete-conflicting-outputs` after editing Freezed models or Riverpod providers.** Otherwise generated files become stale.

## What This Skill Does NOT Do

This skill is a router, not a worker. It does not write code, fix bugs, or review architecture. It only detects context and delegates. For actual work, the specialist skills do the lifting.
