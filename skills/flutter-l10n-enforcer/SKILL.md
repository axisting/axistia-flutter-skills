---
name: flutter-l10n-enforcer
description: Enforces Flutter localization (l10n) discipline. Triggers automatically whenever the model is about to write a user-visible string in any Widget (Text, AppBar title, SnackBar, AlertDialog, button labels, validators, error messages, tooltips, semantics labels). Hardcoded strings are forbidden. Every string must go into the lib/l10n/app_en.arb file with a camelCase key and be referenced via AppLocalizations.of(context). If other language ARBs exist (app_tr.arb, app_de.arb, etc.), add a placeholder entry to ALL of them in parallel so translators can fill in later. Sets up l10n.yaml + flutter generate: true on first use if missing. Critical for any Flutter app that will ship to multiple stores.
---

# Flutter l10n Enforcer

Volkan's rule: NEVER write a hardcoded user-visible string in a Flutter widget. Always go through ARB.

This skill exists because Claude/Copilot, left alone, will write `Text('Welcome back')` instead of `Text(AppLocalizations.of(context)!.welcomeBack)`. That string then becomes a forever-debt that someone (Volkan) has to dig out later when adding a new language.

## Phase 0: Check if l10n is Configured

Before writing any string, verify these exist in the project:

1. `pubspec.yaml` has:
   ```yaml
   dependencies:
     flutter_localizations:
       sdk: flutter
     intl: ^latest

   flutter:
     generate: true
   ```

2. `l10n.yaml` exists in project root:
   ```yaml
   arb-dir: lib/l10n
   template-arb-file: app_en.arb
   output-localization-file: app_localizations.dart
   ```

3. `lib/l10n/app_en.arb` exists (at minimum)

4. `MaterialApp` includes:
   ```dart
   localizationsDelegates: AppLocalizations.localizationsDelegates,
   supportedLocales: AppLocalizations.supportedLocales,
   ```

If ANY of these are missing, set them up before writing the string. The Phase 1 section below covers first-time setup.

## Phase 1: First-Time l10n Setup

If l10n is not configured yet, do this in one go:

```bash
# 1. Update pubspec.yaml dependencies and add generate: true
# 2. Create l10n.yaml in project root
# 3. Create lib/l10n/ directory
# 4. Create lib/l10n/app_en.arb with template
```

`l10n.yaml`:
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

`lib/l10n/app_en.arb` starter:
```json
{
  "@@locale": "en",
  "appName": "App Name",
  "@appName": {
    "description": "The name of the application"
  }
}
```

Then in `main.dart` / wherever MaterialApp is built:
```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  // ... rest
)
```

Run `flutter pub get`, the generated class appears automatically.

## Phase 2: Adding a New String

When you (the model) want to write a user-visible string, follow this exact sequence:

### Step 1: Pick a camelCase key

The key should describe the string's PURPOSE, not its content. Future translations may change the wording but the key stays.

- `Text('Welcome back')` → key: `welcomeBackTitle` (NOT `welcomeBack` if there might be a `welcomeBackSubtitle` later)
- `Text('Login')` → key: `loginButtonLabel` (NOT `login` because that is too generic)
- Validation message "Email is required" → key: `validationEmailRequired`
- SnackBar "Saved" → key: `feedbackSavedSuccess`

Group keys by section prefix:
- `validation*` for form validation
- `feedback*` for snackbars and confirmations
- `error*` for error messages
- `button*` for button labels
- `title*` for screen and section titles
- `hint*` for input placeholders
- `tooltip*` for tooltips
- `dialog*` for dialog content

### Step 2: Add to lib/l10n/app_en.arb

Open `app_en.arb`, add the entry with description metadata:

```json
{
  "@@locale": "en",
  "welcomeBackTitle": "Welcome back",
  "@welcomeBackTitle": {
    "description": "Greeting on the login screen after the user enters their email"
  }
}
```

The description is mandatory. Translators rely on it.

### Step 3: Check for parallel language files

List all `app_*.arb` files in `lib/l10n/`. For EVERY file other than `app_en.arb`, add the same key with a placeholder marker.

If `app_tr.arb`, `app_de.arb`, `app_pt_BR.arb` exist, add to each:

```json
{
  "@@locale": "tr",
  "welcomeBackTitle": "[TODO:tr] Welcome back"
}
```

The `[TODO:tr]` prefix makes untranslated strings visible at runtime so translators (or Volkan) can spot them. Do NOT translate yourself unless explicitly asked. The point is to keep all ARBs structurally in sync.

### Step 4: Use in code with placeholders if dynamic

Static:
```dart
Text(AppLocalizations.of(context)!.welcomeBackTitle)
```

With placeholder:
```json
{
  "welcomeBackUser": "Welcome back, {name}!",
  "@welcomeBackUser": {
    "description": "Personalized greeting",
    "placeholders": {
      "name": {
        "type": "String",
        "example": "Volkan"
      }
    }
  }
}
```
```dart
Text(AppLocalizations.of(context)!.welcomeBackUser('Volkan'))
```

With plural:
```json
{
  "itemCount": "{count, plural, =0{No items} =1{One item} other{{count} items}}",
  "@itemCount": {
    "description": "Item count label on the cart screen",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
}
```
```dart
Text(AppLocalizations.of(context)!.itemCount(cart.length))
```

Never use string concatenation like `'Hello ' + name`. Word order changes across languages.

### Step 5: Regenerate

Run `flutter gen-l10n` or just `flutter pub get` (which auto-runs gen-l10n when `generate: true` is set).

## Phase 3: Bulk Migration of Existing Hardcoded Strings

If the user asks "fix all hardcoded strings in this project", use this sequence:

1. Run `flutter analyze` to find all `Text()`, `Tooltip()`, `Semantics()` calls
2. For each, extract the string, generate a camelCase key (use the section prefix system above)
3. Add all keys to `app_en.arb` in one commit
4. Add parallel `[TODO:xx]` entries to all other language ARBs
5. Replace each hardcoded string with `AppLocalizations.of(context)!.theKey`
6. Add `const` removal where needed (widgets using AppLocalizations cannot be const)

A helper script is in `scripts/audit-hardcoded-strings.sh` (see Resources below).

## Phase 4: Common Pitfalls

### Trying to use AppLocalizations in main.dart or before context is ready
The AppLocalizations delegate needs a `BuildContext` that lives below MaterialApp. Inside `main()` or above MaterialApp, it does not exist.
Solution: Use it inside `home:` or in routes, not in `main()`.

### const widget breakage
After replacing a string, widgets that were `const` no longer can be. Remove `const`.

```dart
// BEFORE
const Text('Welcome')

// AFTER
Text(AppLocalizations.of(context)!.welcomeBackTitle)  // no const
```

### Forgetting to add new strings to all ARBs
This is the #1 reason l10n drift happens. The Step 3 parallel-add rule prevents this. Never edit `app_en.arb` without touching every other ARB in the same commit.

### Using context.l10n shortcut without setup
Many projects define `extension on BuildContext { AppLocalizations get l10n => AppLocalizations.of(this)!; }`. If this extension exists in the project, use it (`context.l10n.welcomeBackTitle`). If not, do not invent it. Use `AppLocalizations.of(context)!`.

### Pluralization in Turkish
Turkish does not pluralize the same way as English. ARB plural syntax handles this correctly when each ARB defines its own plural cases. Do not assume English plural rules apply to Turkish.

## Phase 5: Resources

`scripts/audit-hardcoded-strings.sh` — Greps for hardcoded strings in lib/ and lists files needing migration.

```bash
#!/bin/bash
# Finds candidate hardcoded strings in Flutter widgets.
# Heuristic: literal strings in Text(), Tooltip(), AppBar(title:), etc.
grep -rn --include="*.dart" -E "(Text|Tooltip|AppBar.*title:|Semantics.*label:|SnackBar.*content:|AlertDialog.*title:)\s*\(\s*['\"]" lib/ \
  | grep -v "AppLocalizations" \
  | grep -v "context.l10n"
```

## Strict Rules (Do NOT Cross These)

- DO NOT write any `Text('literal')` in a widget, ever
- DO NOT add to `app_en.arb` without adding parallel `[TODO:xx]` entries to all other ARBs
- DO NOT translate to other languages yourself unless explicitly asked
- DO NOT use string concatenation for dynamic strings, use ARB placeholders
- DO NOT skip the `description` metadata in ARB entries, translators need it
- DO NOT name keys after the content (`hello`), name them after the purpose (`greetingTitle`)
