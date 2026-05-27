---
name: flutter-package-version-checker
description: Verifies Flutter project dependencies are up-to-date and warns about outdated, deprecated, or abandoned packages. Trigger this skill whenever the user mentions "update packages", "outdated dependencies", "should I upgrade", "pub get failed", "Dart SDK conflict", or before any release. Checks pub.dev for the latest stable version of each direct dependency, compares to current pinned version, flags major version gaps, identifies abandoned packages (no release in 2+ years, Pub Points under 100), and suggests safe upgrade paths.
---

# Flutter Package Version Checker

Stay current. Volkan's rule: latest stable, always.

## When to Run This Skill

- Before any production release
- When adding a new dependency (use the latest version, not what last project used)
- When `pub get` fails with version constraint errors
- When user asks "is X package still maintained?"
- Quarterly maintenance check on each project

## Step 1: Snapshot Current State

```bash
flutter pub outdated --show-all
dart pub deps -s compact
```

Output of `pub outdated` has columns:
- Current: what's pinned in pubspec.lock
- Upgradable: what you'd get with `pub upgrade` (respecting constraints)
- Resolvable: what you'd get if you bumped constraints
- Latest: absolute latest published

Focus on packages where Latest is much higher than Current.

## Step 2: Categorize Each Direct Dependency

For each direct dependency in pubspec.yaml, check on pub.dev (https://pub.dev/packages/PACKAGE_NAME):

- **Latest version** — what the package authors recommend
- **Pub Points score** — out of 160. Under 100 is a yellow flag, under 80 is a red flag.
- **Likes count** — popularity proxy
- **Last published date** — over 1 year without updates is yellow, over 2 years is red (unless it's a stable utility with no need to change, like uuid or crypto)
- **Verified publisher** — Google-verified, Flutter-team, Dart-team have higher trust
- **Flutter Favorite badge** — gold standard for that category

Common categories and current recommendations (2026):

| Need | Recommended Package | Notes |
|------|-------------------|-------|
| State management | flutter_riverpod + riverpod_annotation | Riverpod 3.x with codegen |
| Models | freezed + freezed_annotation | Freezed 3.x with sealed classes |
| Navigation | go_router | Official Flutter team package |
| HTTP | dio | Better than http for most apps |
| Local storage | shared_preferences + hive_ce | Hive Community Edition (the maintained fork after the original Hive went unmaintained) |
| Secure storage | flutter_secure_storage | Keychain on iOS, KeyStore on Android |
| Firebase | firebase_core, firebase_auth, etc. | All FlutterFire packages, latest stable |
| Supabase | supabase_flutter | Latest stable |
| IAP | purchases_flutter | RevenueCat's official |
| Image loading | cached_network_image | Standard |
| SVG | flutter_svg | Standard |
| Logging | logger | Better than print |
| Date formatting | intl | Same as for l10n |
| Permissions | permission_handler | Standard |
| Connectivity | connectivity_plus | Plus-variant maintained, original abandoned |
| Device info | device_info_plus | Plus-variant maintained |
| Package info | package_info_plus | Plus-variant maintained |
| Deep links | app_links | Replaces uni_links which is less actively maintained |

## Step 3: Watch for Deprecated / Abandoned Packages

Packages to FLAG if found:

- **hive** (original, not _ce) — original is unmaintained, migrate to `hive_ce`
- **uni_links** — less actively maintained, consider `app_links`
- **flutter_webview_plugin** — abandoned, use `webview_flutter` (official)
- **fluttertoast** — has issues, consider `bot_toast` or inline SnackBar
- **provider** — still works but Riverpod is preferred for new code
- **get** (GetX) — controversial, many devs migrating away due to anti-patterns
- **scoped_model** — abandoned, do NOT use in new code
- **firebase_dynamic_links** — Firebase deprecated this, migrate to Branch.io or custom deep links
- Anything matching `flutter_*_old`, `*_deprecated`, `*_unmaintained` in description

## Step 4: Suggest Upgrade Path

For each package needing an update, suggest one of:

**Patch/Minor (safe):** `flutter pub upgrade PACKAGE`
- Same major version, automatic upgrade is safe
- Example: 2.1.3 → 2.1.5

**Major (review breaking changes):**
- Open the package's CHANGELOG.md on pub.dev
- Look for "Breaking changes" section
- Update pubspec.yaml constraint manually
- Example: ^2.1.0 → ^3.0.0
- Run `flutter pub get`, fix compile errors

**Dart/Flutter SDK upgrade:**
- Check Flutter version: `flutter --version`
- Check what's pinned in `pubspec.yaml` (`environment: sdk: ">=3.5.0 <4.0.0"`)
- For SDK upgrades, run `flutter upgrade`, then `flutter pub get`

## Step 5: Report

```
PACKAGE UPDATE REPORT — <project-name>

UP-TO-DATE: [count] packages
NEEDS PATCH UPDATE (safe): [list with versions]
NEEDS MAJOR UPDATE (review changelog): [list with versions]
DEPRECATED / ABANDONED (migrate): [list with recommended replacement]
LOW PUB POINTS (<100): [list with current score]

RECOMMENDED ACTIONS:
1. Run `flutter pub upgrade` to get all patch+minor updates
2. Review major updates one at a time
3. Schedule deprecation migrations
```

## How to Check a Single Package Quickly

The simplest way to verify a package on pub.dev (without leaving the terminal):

```bash
# Get latest version of a package
curl -s "https://pub.dev/api/packages/PACKAGE_NAME" | grep -oP '"latest":\{[^}]*"version":"[^"]+"' | head -1
```

For a Flutter project, search the dependency on https://pub.dev/packages/PACKAGE_NAME, look at:
- Top banner shows latest version + last published
- Right sidebar shows Pub Points, Likes, Popularity
- Scores tab shows full breakdown
- Versions tab shows release history

## Special Case: Firebase

FlutterFire packages should ALL be on the same major version. If you have:
```yaml
firebase_core: ^3.0.0
firebase_auth: ^4.0.0  # MISMATCH
```

This will cause runtime errors. Always upgrade all FlutterFire packages together:
```bash
flutter pub upgrade --major-versions firebase_core firebase_auth firebase_messaging cloud_firestore firebase_analytics firebase_crashlytics
```

Or use `flutterfire configure` which keeps them in sync.

## Strict Rules

- DO NOT pin to old versions unless there's a specific compatibility reason documented in a comment
- DO NOT use `any` as a version constraint, always use `^major.minor.patch`
- DO NOT downgrade to silence warnings, fix the affected code
- DO NOT mix major versions of Firebase packages
- DO run `flutter pub outdated` at least monthly on active projects
- DO check Pub Points before adding any new dependency, even popular-sounding ones can be abandoned
