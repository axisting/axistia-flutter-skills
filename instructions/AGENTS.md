# AGENTS.md (Volkan / Axistia Defaults)

Copy this file (or symlink it) to the root of every Flutter project. It applies to ALL Claude/Copilot interactions in that project.

## Style and Output

- **NEVER use em dash (—).** Use regular hyphens, commas, parentheses, or colons. This applies to ALL output: code comments, docstrings, README files, commit messages, LinkedIn posts, l10n strings, everywhere.
- Write in clear, direct English. No marketing fluff in code comments.
- Use British English for written content if context suggests (Volkan publishes content for global audience).

## Flutter-Specific Defaults

These apply globally, every Flutter project:

1. **Flutter 3.24+ / Dart 3.5+** minimum SDK versions
2. **Riverpod 3.x with codegen** (@riverpod annotation) for state, unless project already uses BLoC/Provider
3. **Freezed 3.x sealed classes** for all data models, never raw classes
4. **GoRouter** for navigation, never raw Navigator unless trivial
5. **Dio** for HTTP, never bare `http` package unless trivial
6. **Feature-first folder structure** (lib/features/X/data/domain/presentation), not layer-first
7. **l10n from day one**, even if launching English-only. See flutter-l10n-enforcer skill.
8. **Theme-aware widgets always**, no hardcoded colors or font sizes. See flutter-theme-aware skill.
9. **Responsive layouts always**, no hardcoded screen-level widths. See flutter-responsive-design skill.
10. **Always run `dart format . && flutter analyze && flutter test` before any commit**

## Before Writing Code

When asked to do anything in a Flutter project:

1. Run `flutter-project-detector` skill first to identify the stack
2. Load the relevant specialist skills based on detection
3. State the detected stack out loud in 1-2 sentences so the user can correct you

## Code Conventions

- **Single quotes** for strings (`'hello'` not `"hello"`)
- **Trailing commas** in multi-line argument lists (formatter likes it, diffs are cleaner)
- **const everywhere possible** (lints will catch missed ones)
- **No print()** in any code that ships, use `logger` package
- **No TODO without an owner and date** (e.g., `// TODO(volkan, 2026-02): refactor this`)
- **Public APIs documented** with `///` Dartdoc comments
- **camelCase** for variables/functions, **PascalCase** for types, **snake_case** for file names

## Codegen Discipline

When working with Freezed models or Riverpod providers:
- After ANY edit to a `.dart` file containing `@freezed` or `@riverpod`, run:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```
- Generated files (`.g.dart`, `.freezed.dart`) are git-tracked
- Generated files are excluded from `analysis_options.yaml`

## Multi-Language Strings

- **Never hardcode user-visible strings.** All Text widgets reference `AppLocalizations.of(context)!.someKey`
- When adding a string to `lib/l10n/app_en.arb`, add `[TODO:xx]` placeholder to ALL other language ARBs in the same commit
- See `flutter-l10n-enforcer` for details

## Theme Discipline

- **Never hardcode Color.** Use `Theme.of(context).colorScheme.*`
- **Never hardcode TextStyle.** Use `Theme.of(context).textTheme.*` with optional `copyWith`
- Theme defined ONCE in `lib/core/theme/app_theme.dart`
- Material 3 with `useMaterial3: true`, both light and dark modes defined

## Release Discipline

Before any release:
1. Run `flutter-package-version-checker` skill (update outdated packages)
2. Run `flutter-security-audit` skill (catch leaked secrets, OWASP issues)
3. Run `flutter-store-review-checker` skill (catch App Store / Play Store rejection causes)

## Volkan-Specific Project Context

Volkan runs Axistia (sole proprietorship, NACE 62.10.00). Active projects:

- **Habit Score Tracker (HST)** — habit tracking app, recently submitted to iOS App Store, RevenueCat subscriptions in 5 languages, Sign in with Apple, ATT tracking
- **Livestock Manager** — Android live, iOS submission pending
- **Kap Kurtar** (formerly Ye Kurtardi) — Too Good To Go-style food rescue platform, demo at yekurtar.axisting.com, KOSGEB Is Gelistirme Destegi 2026 applicant

Volkan's two websites:
- **axisting.com** — personal site (creative, personal content)
- **axistia.org** — company site (business/products)

Do NOT confuse the two domains in code, README files, or content.

## Apple Developer Info

- Team ID: AT67W42339 (Axistia)
- Bundle ID prefix: com.axistia.* for new apps
- HST already submitted, RevenueCat configured

## When Updating This File

Edits to AGENTS.md propagate to every project on next install. Treat it as a contract.
